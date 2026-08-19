extends Node3D

@onready var xr_origin = $XROrigin3D
@onready var camera = $XROrigin3D/XRCamera3D
@onready var left_hand = $XROrigin3D/LeftHand
@onready var right_hand = $XROrigin3D/RightHand
@onready var playerbody = $XROrigin3D/PlayerBody
@onready var avatar = $XROrigin3D/Avatar

@onready var gravity_provider = $XROrigin3D/PlayerBody/CustomGravityProvider

var spawn_transform : Transform3D

@onready var menu = $XROrigin3D/Menu

var test_vis: bool =  false

var server_spawn: bool = true

var is_falling := false
var allow_fall_detection := false
var previous_body_y := 0.0

const FALL_START_THRESHOLD := 4.0  # meters per second

@onready var fog_sphere = $XROrigin3D/XRCamera3D/FogSphere

enum HeldItem {
	FUSE,
	FIREWORK
}

@onready var firework := $XROrigin3D/RightHand/Firework
@onready var fuse := $XROrigin3D/RightHand/Fuse


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready():
	await get_tree().process_frame
	if !is_multiplayer_authority(): 
		return
	
	_init_player()
	
func _init_player():
	camera.current = true
	
	Global.player = self
	
	avatar.is_visualiser = false
	avatar.set_global_avatar(Global.player_slot)
	
	firework.visible = false
	fuse.visible = false
	Global.firework = firework
	Global.fuse = fuse
	
	if fog_sphere:
		fog_sphere.visible = false
	
	
	var flash = $XROrigin3D/XRCamera3D/ImpactFlashMesh
	flash.visible = false
	var mat = flash.get_active_material(0)
	mat.set_shader_parameter("intensity", 0.0)
				
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	allow_fall_detection = true
	
	spawn_transform = global_transform
				
func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	_update_fall_detection(delta)

func _process(_delta):
		
	if multiplayer.has_multiplayer_peer():
		HighLevelNetworkHandler.send_avatar_data(Global.player_slot, get_avatar_sync_data())
	
	avatar.head = camera.global_transform
	avatar.left_hand = left_hand.global_transform
	avatar.right_hand = right_hand.global_transform
	
	
func _update_fall_detection(delta: float):
	if not allow_fall_detection:
		return

	var grounded = playerbody.is_on_floor()
	
	var down_dir = gravity_provider.gravity_direction.normalized()
	var vertical_speed = playerbody.velocity.dot(down_dir)

	# --- Falling Ended ---
	if is_falling and grounded:
		is_falling = false
		#Fall stopped
		HighLevelNetworkHandler._send_marker_to_acqknowledge(str(Global.player_slot) + "2")
		avatar.set_falling_state(false)
		FallEffectManager.on_fall_stopped(self)
			
	# --- Falling Started ---
	# Only start fall if actually moving downward fast enough
	if not is_falling and vertical_speed > FALL_START_THRESHOLD:
		is_falling = true
		#Fall started
		HighLevelNetworkHandler._send_marker_to_acqknowledge(str(Global.player_slot) + "1")
		avatar.set_falling_state(true)
		FallEffectManager.on_fall_started(self)

	# --- While Falling ---
	if is_falling:
		FallEffectManager.update_falling(self, delta)
		
	# Impact update
	if FallEffectManager.has_active_impact():
		FallEffectManager.update_impact(self, delta)
		
	
func teleport_to_spawn():
	enable_fog()
	playerbody.velocity = Vector3.ZERO

	xr_origin.global_transform.origin.y = spawn_transform.origin.y
	xr_origin.global_transform.origin.y += 0.5
	
func rotate_player():
	var angle = PI
	var axis = Vector3.UP
	var rot = Basis(axis, angle)

	# Rotate position around center
	var offset = xr_origin.global_transform.origin - Global.calibrated_center
	xr_origin.global_transform.origin = Global.calibrated_center + rot * offset

	# Rotate orientation
	xr_origin.global_transform.basis = rot * xr_origin.global_transform.basis
	

		
func get_avatar_sync_data() -> Dictionary:	
	var data := {
		"head": Global.world_to_tracking(camera.global_transform),
		"left_hand": Global.world_to_tracking(left_hand.global_transform),
		"right_hand": Global.world_to_tracking(right_hand.global_transform),
		"avatar_position": Global.world_to_tracking(avatar.global_transform),
		"is_falling": is_falling,
		"fog_enabled": fog_sphere.visible
	}

	# --- Feet (optional) ---
	if avatar.left_foot_target and avatar.right_foot_target:
		data["left_foot"] = Global.world_to_tracking(avatar.left_foot_target.global_transform)
		data["right_foot"] = Global.world_to_tracking(avatar.right_foot_target.global_transform)

	# --- Hand item (optional) ---
	var hand_item := firework if firework else fuse
	if hand_item:
		data["hand_item"] = Global.world_to_tracking(hand_item.global_transform)

	return data
		
func set_held_item(item: HeldItem) -> void:
	match item:
		HeldItem.FIREWORK:
			# Remove fuse
			if is_instance_valid(fuse):
				fuse.queue_free()
				fuse = null

			# Ensure firework exists
			if not is_instance_valid(firework):
				firework = Global.firework_scene.instantiate()
				firework.name = "Firework"
				right_hand.add_child(firework)

			firework.visible = true

		HeldItem.FUSE:
			# Remove firework
			if is_instance_valid(firework):
				firework.queue_free()
				firework = null

			# Ensure fuse exists
			if not is_instance_valid(fuse):
				fuse = Global.fuse_scene.instantiate()
				fuse.name = "Fuse"
				right_hand.add_child(fuse)

			fuse.visible = true
			
func enable_firework() -> void:
	if !Global.is_baseline:
		set_held_item(HeldItem.FIREWORK)
	
func enable_fuse() -> void:
	if !Global.is_baseline:
		set_held_item(HeldItem.FUSE)
	
func enable_fog():
	if fog_sphere:
		fog_sphere.visible = true
		HighLevelNetworkHandler.fog_ack(Global.player_slot, true)

func disable_fog():
	if fog_sphere:
		fog_sphere.visible = false
		HighLevelNetworkHandler.fog_ack(Global.player_slot, false)
		
	
func _on_left_hand_button_pressed(button_name: String) -> void:
	match button_name:
		"ax_button": 
			#rotate_player()
			#Global.debug._activate_debug()
			pass
		"by_button": 
			#Global.switch_passthrough()
			pass
		"trigger_click":
			#calibrate_player_orientation()
			pass
		"grip_click": 
			#enable_fog()
			pass
			
#func _on_left_hand_button_released(button_name: String) -> void:
	#match button_name:
		#"ax_button": pass
		#"by_button": pass
		#"trigger_click": pass
		#"grip_click": pass
			#
#func _on_right_hand_button_pressed(button_name: String) -> void:
	#match button_name:
		#"ax_button": 
			#Global.debug._activate_debug()	
		#"by_button": pass
		#"trigger_click": pass
		#"grip_click": 
			#disable_fog()
#
#func _on_right_hand_button_released(button_name: String) -> void:
	#match button_name:
		#"ax_button": pass
		#"by_button": pass
		#"trigger_click": pass
		#"grip_click": pass
	#

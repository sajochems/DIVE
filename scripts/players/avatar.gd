extends Node3D

@export var skeleton: Skeleton3D


# --- XR input ---
var head: Transform3D
var left_hand: Transform3D
var right_hand: Transform3D

# --- Targets (world space) ---
@onready var head_target: Marker3D = $HeadTarget
@onready var left_hand_target: Marker3D = $LeftArmTarget
@onready var right_hand_target: Marker3D = $RightArmTarget
@onready var left_foot_target: Marker3D = $LeftLegTarget
@onready var right_foot_target: Marker3D = $RightLegTarget

# --- Poles ---
@onready var left_elbow_pole: Marker3D = $LeftArmPole
@onready var right_elbow_pole: Marker3D = $RightArmPole
@onready var left_knee_pole: Marker3D = $LeftLegPole
@onready var right_knee_pole: Marker3D = $RightLegPole

# --- IK solvers ---
@onready var left_arm_ik: TwoBoneIK3D = $Armature/GeneralSkeleton/LeftArmIK
@onready var right_arm_ik: TwoBoneIK3D = $Armature/GeneralSkeleton/RightArmIK
@onready var left_leg_ik: TwoBoneIK3D = $Armature/GeneralSkeleton/LeftLegIK
@onready var right_leg_ik: TwoBoneIK3D = $Armature/GeneralSkeleton/RightLegIK
@onready var spine_ik: FABRIK3D = $Armature/GeneralSkeleton/SpineIK

const MODEL_ROTATION_OFFSET = 180

@export var player_height: float = 1.837
var balanced_scale: float = 1.00

const MODEL_HEIGHT_DEFAULT: float = 1.837

const HEAD_OFFSET: Vector3 = Vector3(0.0, 0.1, 0.05)
const LEFT_HAND_OFFSET: Vector3 = Vector3(0.03, -0.035, -0.19)
const RIGHT_HAND_OFFSET: Vector3 = Vector3(-0.03, -0.035, -0.19)

# Determines how much the hands influence the hip position
const hand_influence: float = 0.02

var _filtered_body_forward: Vector3 = Vector3.FORWARD
var _filtered_hips_pos: Vector3

const HIP_BACK_OFFSET := 0.17

const BODY_POSITION_SMOOTH := 0.20


var rest_poses := {}

const HIDDEN_BODY_LAYER: int = 1 << 1
var body_parts: Array = []
var body_parts_original_layers: Array = []

var server_spawn: bool = true

var reconstructor_slot: int = -1
var is_visualiser: bool = true


# --- Foot placement tuning ---
enum FootState { PLANTED, SWING }

const FOOT_SPACING := 0.18
const STEP_DISTANCE := 0.35
const STEP_HEIGHT := 0.12
const STEP_DURATION := 0.35
const FOOT_GROUND_OFFSET := 0.02
const VELOCITY_DEADZONE := 0.05

var left_state: FootState = FootState.PLANTED
var right_state: FootState = FootState.PLANTED

var left_t := 1.0
var right_t := 1.0

var left_from: Vector3
var left_to: Vector3
var right_from: Vector3
var right_to: Vector3

var left_home_local: Vector3
var right_home_local: Vector3
var left_foot_world: Vector3
var right_foot_world: Vector3

var hips_velocity := Vector3.ZERO
var prev_hips_pos := Vector3.ZERO

var is_falling: bool = false

var last_received_time: int = 0


func _ready():
	#if !is_multiplayer_authority():
		#return
		
	await get_tree().process_frame
		
	_filtered_hips_pos = global_transform.origin
	
	#skeleton.transform = skeleton.transform.rotated(Vector3.UP, deg_to_rad(MODEL_ROTATION_OFFSET))
	#rotate_y(deg_to_rad(180))
		
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		player_height = XRTools.get_player_standard_height()
		#Logger.log("player height: " + str(player_height))
		# Scale avatar to player height
		set_player_height(player_height)
	
	
	# Setup VR tracking
	_setup_vr_tracking()
	
	left_arm_ik.active = false
	right_arm_ik.active = false
	left_leg_ik.active = false
	right_leg_ik.active = false
	spine_ik.active = false
	
	await get_tree().process_frame
	_align_body_to_vr(0.0) 
	
	await get_tree().process_frame
	_initialize_feet()
	
	if xr_interface and xr_interface.is_initialized():
		await get_tree().process_frame
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
		

		_collect_body_parts()
		if XRServer.primary_interface and XRServer.primary_interface.is_initialized() and !is_visualiser:
			_hide_local_body()
			
	last_received_time = Time.get_ticks_msec()
	
	left_arm_ik.active = true
	right_arm_ik.active = true
	left_leg_ik.active = true
	right_leg_ik.active = true
	spine_ik.active = true

func _process(delta: float) -> void:
	if !is_visualiser:
		update(delta)
		pass

		
func update(delta: float) -> void:
	if is_visualiser:
		return
	
	_align_body_to_vr(delta)

	head_target.global_transform = head
	head_target.global_transform.origin += head_target.global_transform * (HEAD_OFFSET * balanced_scale)
	
	left_hand_target.global_transform = left_hand
	
	right_hand_target.global_transform = right_hand
	
	_update_feet(delta)

	
func _update_visual() -> void:
			
	head_target.global_transform = head
	head_target.global_transform.origin += head_target.global_transform * (HEAD_OFFSET * balanced_scale)

	left_hand_target.global_transform = left_hand
	right_hand_target.global_transform = right_hand

		
func set_global_avatar(slot : int) -> void:
	if slot == 1:
		Global.avatar_1 = self
	else:
		Global.avatar_2 = self

	
func apply_avatar_sync_data(data: Dictionary) -> void:
	if data.has("head"):
		head = Global.tracking_to_world(data["head"])

	if data.has("left_hand"):
		left_hand = Global.tracking_to_world(data["left_hand"])

	if data.has("right_hand"):
		right_hand = Global.tracking_to_world(data["right_hand"])

	if data.has("avatar_position"):
		global_transform = Global.tracking_to_world(data["avatar_position"])

	if data.has("left_foot") and left_foot_target:
		left_foot_target.global_transform = Global.tracking_to_world(data["left_foot"])

	if data.has("right_foot") and right_foot_target:
		right_foot_target.global_transform = Global.tracking_to_world(data["right_foot"])
		
	if data.has("is_falling"):
		set_falling_state(data["is_falling"])
		
	_update_visual()
	
func _initialize_feet():

	left_home_local = Vector3(FOOT_SPACING, 0, 0)
	right_home_local = Vector3(-FOOT_SPACING, 0, 0)

	left_foot_world = _project_to_ground(global_transform * left_home_local)
	right_foot_world = _project_to_ground(global_transform * right_home_local)

	_apply_feet_to_targets()
	
func _apply_feet_to_targets():
	var foot_basis = _get_foot_basis()

	left_foot_target.global_transform = Transform3D(foot_basis, left_foot_world)
	right_foot_target.global_transform = Transform3D(foot_basis, right_foot_world)
	
func _update_feet(delta: float):
	if is_visualiser:
		return
	
	if !left_foot_target or !right_foot_target:
		return
		
	if is_falling:
		_force_feet_under_body()
		return

	_update_velocity(delta)

	var move_dir_local = _get_local_move_dir()

	_process_step(true, move_dir_local)
	_process_step(false, move_dir_local)

	_update_swing(true, delta)
	_update_swing(false, delta)
	
	_apply_feet_to_targets()
	
func _update_velocity(delta: float):
	var current = global_transform.origin
	var raw = (current - prev_hips_pos) / max(delta, 0.0001)
	prev_hips_pos = current
	
	hips_velocity = hips_velocity.lerp(raw, 0.15)
	
func _get_local_move_dir() -> Vector3:
	var v = global_transform.basis.inverse() * hips_velocity
	v.y = 0
	
	if v.length() < VELOCITY_DEADZONE:
		return Vector3(0, 0, -1) # forward fallback
	
	return v.normalized()
	
func _get_foot_basis() -> Basis:
	# Horizontal forward direction of the player
	var forward = -global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	# Up vector is vertical (floor normal)
	var up = Vector3.UP
	
	# Right vector perpendicular to forward and up
	var right = up.cross(forward).normalized()
	
	# Recompute forward to ensure orthonormal basis
	var corrected_forward = right.cross(up).normalized()
	
	# Build basis with correct orientation: right, up, forward
	return Basis(right, -corrected_forward, up).orthonormalized().rotated(Vector3.UP, deg_to_rad(MODEL_ROTATION_OFFSET))
	
func _process_step(is_left: bool, move_dir_local: Vector3):
	
	if is_left and right_state == FootState.SWING:
		return
	if !is_left and left_state == FootState.SWING:
		return

	var state = left_state if is_left else right_state
	if state != FootState.PLANTED:
		return

	var foot_global = left_foot_world if is_left else right_foot_world
	
	var foot_local = global_transform.affine_inverse() * foot_global
	var home = left_home_local if is_left else right_home_local

	var offset = foot_local - home
	offset.y = 0

	var forward_offset = offset.z

	if abs(forward_offset) > STEP_DISTANCE:
		_start_step(is_left, move_dir_local)

func _start_step(is_left: bool, move_dir_local: Vector3):

	var home = left_home_local if is_left else right_home_local
	
	var forward_component = move_dir_local.z
	var stride = forward_component * STEP_DISTANCE

	var target_local = Vector3(
		home.x,   # enforce lateral spacing every step
		0,
		home.z + stride
	)

	var from_global = left_foot_world if is_left else right_foot_world
	var to_global_space = global_transform * target_local
	to_global_space = _project_to_ground(to_global_space)

	if is_left:
		left_state = FootState.SWING
		left_t = 0.0
		left_from = from_global
		left_to = to_global_space
	else:
		right_state = FootState.SWING
		right_t = 0.0
		right_from = from_global
		right_to = to_global_space

func _update_swing(is_left: bool, delta: float):

	var state = left_state if is_left else right_state
	if state != FootState.SWING:
		return

	var t = (left_t if is_left else right_t) + delta / STEP_DURATION
	t = clamp(t, 0.0, 1.0)

	var from = left_from if is_left else right_from
	var to = left_to if is_left else right_to

	var pos = from.lerp(to, t)

	# smooth arc
	pos.y += sin(t * PI) * STEP_HEIGHT

	pos = _project_to_ground(pos)


	if is_left:
		left_t = t
		left_foot_world = pos
		if t >= 1.0:
			left_state = FootState.PLANTED
	else:
		right_t = t
		right_foot_world = pos
		if t >= 1.0:
			right_state = FootState.PLANTED
			
func _place_foot_immediate(is_left: bool, local_pos: Vector3):
	var global_pos = global_transform * local_pos
	global_pos = _project_to_ground(global_pos)

	var foot_basis = _get_foot_basis()

	if is_left:
		left_foot_target.global_transform = Transform3D(foot_basis, global_pos)
	else:
		right_foot_target.global_transform = Transform3D(foot_basis, global_pos)
		
func _force_feet_under_body():
	_place_foot_immediate(true, left_home_local)
	_place_foot_immediate(false, right_home_local)
	
func _project_to_ground(pos: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	
	var from = pos + Vector3.UP * 0.5
	var to = pos - Vector3.UP * 2.0
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# --- IMPORTANT ---
	# Exclude the avatar from raycast
	query.exclude = [self]
	
	# Optional: restrict to ground collision layer (recommended)
	query.collision_mask = 1 << 0  # if floor is on layer 1
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position + Vector3.UP * FOOT_GROUND_OFFSET
	
	return pos
		

func ensure_child(node_name: String, type: String):
		var existing = skeleton.get_node_or_null(node_name)
		if existing:
			return existing
		var node = null 
		match type:
			"Node3D":
				node = Node3D.new()
			"SkeletonIK3D":
				node = SkeletonIK3D.new()
			_:
				AppLogger.warn("⚠️ Unknown type for ensure_child: %s" % type)
				return null
		node.name = node_name
		skeleton.add_child(node)
		#Logger.log("Created new %s node: %s" % [type, node_name])
		return node

# --- Align skeleton root (hips) based on head & hands, keep feet grounded ---
func _align_body_to_vr(delta: float):

	if not rest_poses.has("Head") or not rest_poses.has("Hips"):
		return

	var head_pos = head.origin
	var left_pos = left_hand.origin
	var right_pos = right_hand.origin

	# -----------------------------
	# HEAD FORWARD (PRIMARY DRIVER)
	# -----------------------------
	var raw_head_forward = -head.basis.z

	# Project onto horizontal plane
	var head_forward = raw_head_forward
	head_forward.y = 0.0

	# If too vertical → fallback to previous stable direction
	if head_forward.length_squared() < 0.001:
		head_forward = _filtered_body_forward
	else:
		head_forward = head_forward.normalized()

	# -----------------------------
	# HAND-BASED YAW OFFSET (SMALL INFLUENCE ONLY)
	# -----------------------------
	var hand_dir = (right_pos - left_pos)
	hand_dir.y = 0

	var hand_forward: Vector3 = head_forward

	if hand_dir.length_squared() > 0.001:
		hand_dir = hand_dir.normalized()
		hand_forward = Vector3.UP.cross(hand_dir).normalized()

		# Prevent flipping
		if hand_forward.dot(head_forward) < 0:
			hand_forward = -hand_forward

	# -----------------------------
	# BLEND (HEAD DOMINANT)
	# -----------------------------
	var target_forward = head_forward.slerp(hand_forward, 0.15)
	target_forward = target_forward.normalized()
	
	# Prevent sudden 180° flips
	if target_forward.dot(_filtered_body_forward) < 0.0:
		target_forward = _filtered_body_forward

	# -----------------------------
	# SMOOTH ROTATION
	# -----------------------------
	var smoothing := 8.0  # higher = snappier
	_filtered_body_forward = _filtered_body_forward.slerp(
		target_forward,
		clamp(delta * smoothing, 0.0, 1.0)
	)

	# -----------------------------
	# HIP POSITION
	# -----------------------------
	var target_hips = head_pos

	# backward offset
	target_hips -= _filtered_body_forward * HIP_BACK_OFFSET * balanced_scale

	# small hand influence (position only, not rotation)
	var avg_hands = (left_pos + right_pos) * 0.5

	var hips_xz = Vector3(target_hips.x, 0.0, target_hips.z)
	var hands_xz = Vector3(avg_hands.x, 0.0, avg_hands.z)

	hips_xz = hips_xz.lerp(hands_xz, hand_influence)

	target_hips.x = hips_xz.x
	target_hips.z = hips_xz.z

	# vertical offset
	target_hips.y = head_pos.y - (_get_head_to_hips_offset() + 0.8) * balanced_scale

	# -----------------------------
	# SMOOTH HIP MOVEMENT
	# -----------------------------
	if is_falling:
		target_hips.y = global_transform.origin.y
		_filtered_hips_pos = target_hips
	else:
		_filtered_hips_pos = _filtered_hips_pos.lerp(target_hips, BODY_POSITION_SMOOTH)

	# -----------------------------
	# APPLY TRANSFORM
	# -----------------------------
	var hips_rot = safe_looking_at(_filtered_body_forward)

	global_transform.origin = _filtered_hips_pos
	global_transform.basis = hips_rot
	global_transform = global_transform.rotated(Vector3.UP, PI)
	global_transform.origin.x = -global_transform.origin.x
	global_transform.origin.z = -global_transform.origin.z
	
func _get_head_to_hips_offset() -> float:
	var head_idx = skeleton.find_bone("Head")
	var hips_idx = skeleton.find_bone("Hips")

	if head_idx == -1 or hips_idx == -1:
		return 0.9

	var head_rest = skeleton.get_bone_rest(head_idx)
	var hips_rest = skeleton.get_bone_rest(hips_idx)

	return abs(head_rest.origin.y - hips_rest.origin.y)
	
func _compute_target_hips() -> Vector3:
	var head_pos = head.origin
	var hips = head_pos
	hips.y -= _get_head_to_hips_offset() * balanced_scale
	return hips


# --- Cache rest poses ---
func _setup_vr_tracking():
	var bones = ["Head", "LeftHand", "RightHand", "Hips", "LeftFoot", "RightFoot"]
	for b in bones:
		var idx = skeleton.find_bone(b)
		if idx != -1:
			rest_poses[b] = skeleton.get_bone_rest(idx)
		else:
			AppLogger.warn("⚠️ Missing bone in rest pose: " + b)
			
	



# --- Player height scaling ---
func set_player_height(desired_height_m: float) -> void:
	if desired_height_m <= 0.0:
		AppLogger.warn("⚠️ Invalid height: %s" % desired_height_m)
		return
	var scale_factor = desired_height_m / MODEL_HEIGHT_DEFAULT
	self.scale = Vector3.ONE * scale_factor
	balanced_scale = scale_factor	
	#Logger.log("Scaled avatar by: " + str(scale_factor))
	_recache_rest_poses_after_scale()

func _recache_rest_poses_after_scale():
	rest_poses.clear()
	for k in ["Head", "LeftHand", "RightHand", "Hips", "LeftFoot", "RightFoot"]:
		var idx = skeleton.find_bone(k)
		if idx != -1:
			rest_poses[k] = skeleton.get_bone_rest(idx)
			
func _collect_body_parts() -> void:
	if not skeleton:
		AppLogger.warn("⚠️ No skeleton assigned for body part collection")
		return
			
	body_parts.clear()
	body_parts_original_layers.clear()
	
	var keywords: Array = ["head", "eye", "teeth", "hair", "leg", "foot", "toe", "toes", "bottom", "body", "top"]
	
	_collect_body_parts_recursive(skeleton, keywords)
	
	
func _collect_body_parts_recursive(node: Node, keywords: Array) -> void:
	for child in node.get_children():
		# If the child is a MeshInstance3D (or inherited), test its name
		if child is MeshInstance3D:
			if _matches_keywords(child.name, keywords):
				body_parts.append(child)
				body_parts_original_layers.append(child.layers)
		# Recurse
		_collect_body_parts_recursive(child, keywords)

# Accept untyped Array to avoid strict typed-array mismatch
func _matches_keywords(mesh_name: String, keywords: Array) -> bool:
	var lower := mesh_name.to_lower()
	for kw in keywords:
		# ensure kw is a string to avoid errors
		if typeof(kw) == TYPE_STRING and kw in lower:
			return true
	return false
	
func _find_xr_camera() -> XRCamera3D:
	var root := get_tree().get_current_scene()
	return root.find_child("XRCamera3D", true, false)
	
func _hide_local_body() -> void:
	var cam = _find_xr_camera()
	if not cam:
		AppLogger.warn("⚠️ XR camera not assigned; cannot hide local body.")
		return

	# Move meshes to hidden layer
	for mesh in body_parts:
		if mesh and mesh is MeshInstance3D:
			mesh.layers = HIDDEN_BODY_LAYER

	# Ensure XR camera doesn't render that layer
	cam.cull_mask &= ~HIDDEN_BODY_LAYER
	
func _show_local_body() -> void:
	var cam = _find_xr_camera()
	if not cam:
		AppLogger.warn("⚠️ XR camera not assigned; cannot show local body.")
		return

	# Restore original mesh layers
	for i in range(body_parts.size()):
		var mesh = body_parts[i]
		if mesh and mesh is MeshInstance3D:
			mesh.layers = body_parts_original_layers[i]

	# Re-enable rendering of that layer in the camera
	cam.cull_mask |= HIDDEN_BODY_LAYER
	
func apply_frame(a: Dictionary, b: Dictionary, t: float):
	# --- Head ---
	var head_pos = a["head_pos"].lerp(b["head_pos"], t)

	var head_dir = a["head_dir"].lerp(b["head_dir"], t)
	if head_dir.length_squared() < 0.0001:
		head_dir = Vector3.FORWARD
	else:
		head_dir = head_dir.normalized()

	var head_basis := safe_looking_at(head_dir)
	head = Transform3D(head_basis, head_pos)

	# --- Left Hand ---
	var l_pos = a["l_pos"].lerp(b["l_pos"], t)

	var l_dir = a["l_dir"].lerp(b["l_dir"], t)
	if l_dir.length_squared() < 0.0001:
		l_dir = Vector3.FORWARD
	else:
		l_dir = l_dir.normalized()

	var l_basis := safe_looking_at(l_dir)
	left_hand = Transform3D(l_basis, l_pos)

	# --- Right Hand ---
	var r_pos = a["r_pos"].lerp(b["r_pos"], t)

	var r_dir = a["r_dir"].lerp(b["r_dir"], t)
	if r_dir.length_squared() < 0.0001:
		r_dir = Vector3.FORWARD
	else:
		r_dir = r_dir.normalized()

	var r_basis := safe_looking_at(r_dir)
	right_hand = Transform3D(r_basis, r_pos)
	
	var pos_offset = Vector3(-0.008, 0.0, 0.03)

	var rot_offset = Basis.from_euler(Vector3(
		deg_to_rad(-53.7),
		deg_to_rad(8.6),
		deg_to_rad(0.0)
	))

	var offset_transform = Transform3D(rot_offset, pos_offset)

	var item_transform = right_hand * offset_transform
	
	Global.set_hand_item(reconstructor_slot + 1, item_transform)
	
	if visible == false:
		Global.spectator.set_hands_transform(left_hand, right_hand)
	
	# --- player body---
	var body_pos = a["body_pos"].lerp(b["body_pos"], t)

	var body_dir = a["body_dir"].lerp(b["body_dir"], t)
	if body_dir.length_squared() < 0.0001:
		body_dir = Vector3.FORWARD
	else:
		body_dir = body_dir.normalized()

	var body_basis := safe_looking_at(body_dir)
	global_transform = Transform3D(body_basis, body_pos)
	
	# --- left foot---
	var lfoot_pos = a["lfoot_pos"].lerp(b["lfoot_pos"], t)

	var lfoot_dir = a["lfoot_dir"].lerp(b["lfoot_dir"], t)
	if lfoot_dir.length_squared() < 0.0001:
		lfoot_dir = Vector3.FORWARD
	else:
		lfoot_dir = lfoot_dir.normalized()

	var lfoot_basis := safe_looking_at(lfoot_dir)
	if left_foot_target:
		left_foot_target.global_transform = Transform3D(lfoot_basis, lfoot_pos)
	
	# --- right foot---
	var rfoot_pos = a["rfoot_pos"].lerp(b["rfoot_pos"], t)

	var rfoot_dir = a["rfoot_dir"].lerp(b["rfoot_dir"], t)
	if rfoot_dir.length_squared() < 0.0001:
		rfoot_dir = Vector3.FORWARD
	else:
		rfoot_dir = rfoot_dir.normalized()

	var rfoot_basis := safe_looking_at(rfoot_dir)
	if right_foot_target:
		right_foot_target.global_transform = Transform3D(rfoot_basis, rfoot_pos)
		
	_update_visual()
	
func safe_looking_at(dir: Vector3) -> Basis:
	if dir.length_squared() < 0.0001:
		return Basis.IDENTITY
	
	dir = dir.normalized()
	
	var up = Vector3.UP
	
	# If nearly vertical → choose alternative up
	if abs(dir.dot(up)) > 0.98:
		up = Vector3.FORWARD
	
	return Basis.looking_at(dir, up)
	
func position_avatar_for_reconstruction():
	transform.origin.x = 0.0
	transform.origin.y = 1.0
	if reconstructor_slot == 0:
		transform.origin.z = (Global._distance / 2.0) + 1.25
	elif reconstructor_slot == 1:
		transform = transform.rotated(Vector3.UP, deg_to_rad(180.0))
		transform.origin.z = -((Global._distance / 2.0) + 1.25)
	else:
		AppLogger.err("No slot assigned for reconstruction spawning")
		
		
func set_falling_state(state: bool):
	is_falling = state

	if state:
		_on_fall_enter()
	else:
		_on_fall_exit()
		
		
func _on_fall_enter():
	if is_visualiser:
		return

	var hips_pos = global_transform.origin
	var right = global_transform.basis.x

	var left_pos = hips_pos - right * FOOT_SPACING
	var right_pos = hips_pos + right * FOOT_SPACING
	
	if left_foot_target and right_foot_target:
		left_foot_world = left_pos + Vector3(0.0, -10.0, 0.0)
		right_foot_world = right_pos + Vector3(0.0, -10.0, 0.0)
	
	var target_hips = _compute_target_hips()
	var dist = _filtered_hips_pos.distance_to(target_hips)

	if dist > 0.5:
		_filtered_hips_pos = target_hips
	else:
		_filtered_hips_pos = _filtered_hips_pos.lerp(target_hips, BODY_POSITION_SMOOTH)
		
	left_leg_ik.active = false
	right_leg_ik.active = false
	spine_ik.active = false
	
func _on_fall_exit():
	if is_visualiser:
		return

	var hips_pos = global_transform.origin
	var right = global_transform.basis.x

	if left_foot_target and right_foot_target:
		left_foot_world = hips_pos - right * FOOT_SPACING + Vector3(0.0, -10.0, 0.0)
		right_foot_world = hips_pos + right * FOOT_SPACING + Vector3(0.0, -10.0, 0.0)
	
	var target_hips = _compute_target_hips()
	var dist = _filtered_hips_pos.distance_to(target_hips)

	if dist > 0.5:
		_filtered_hips_pos = target_hips
	else:
		_filtered_hips_pos = _filtered_hips_pos.lerp(target_hips, BODY_POSITION_SMOOTH)
		
	left_leg_ik.active = true
	right_leg_ik.active = true
	spine_ik.active = true
		
	

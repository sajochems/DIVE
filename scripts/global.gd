extends Node

var scene_loader

var calibration
var debug_calibration
var calibrated_center : Vector3 = Vector3.ZERO

var xr_interface
var menu_manager
var environment

var debug
var player
var avatar_1
var avatar_2

var spectator

var main

const SAVE_PATH := "user://settings.json"

var selected_level : String
var level : String
var _height : float
var _distance : float
var _width : float
var platform_length : float
var _platform_width : float

var is_baseline := false
var BASELINE_DURATION := 900.0

var platform

var spawner
var player_slot = 1
var id = -1

var passthrough_enabled = false

@onready var sample_timer := Timer.new()
var SAMPLE_FREQUENCY_HZ := 90.0

var local_samples: Array = []
var sample_file_path := "user://pending_samples.csv"
var sample_file: FileAccess

var experiment_start_time: int = 0
var experiment_started: bool = false
var experiment_time_ms: int = 0
var finished_sending: bool = false

var reconstruction_path = ""
var replay_controller
var replay_ui

var acqknowledge_url = ""

@onready var firework_scene: PackedScene = preload("res://scenes/interaction/firework.tscn")
@onready var fuse_scene: PackedScene = preload("res://scenes/interaction/fuse.tscn")
var firework : Node3D
var fuse : Node3D

func _ready():
	load_all()

	#Handle XR initialization
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		AppLogger.log("OpenXR initialized successfully")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		AppLogger.log("OpenXR not initialized switching to PC mode, if this is unintentional please check if your headset is connected")
		xr_interface = null
	
		
func _process(_delta):
		experiment_time_ms = Time.get_ticks_msec() - experiment_start_time


func print_save_file():
	var full_path = OS.get_user_data_dir() + "/" + SAVE_PATH.replace("user://", "")
	AppLogger.log("Full file path: " + full_path)

	if not FileAccess.file_exists(SAVE_PATH):
		AppLogger.log("File does not exist yet.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var contents = file.get_as_text()
		file.close()
		AppLogger.log("File contents:\n" + str(contents))
	else:
		AppLogger.log("Failed to open the file.")
		
func save_all():
	var data := {
		"ip_address": HighLevelNetworkHandler.IP_ADDRESS,
		"file_location": HighLevelNetworkHandler.SERVER_LOG_PATH,
		"reconstruction_path": reconstruction_path,
		"SAMPLE_FREQUENCY_HZ": SAMPLE_FREQUENCY_HZ,
		"acqknowledge_url": acqknowledge_url,
		"baseline_duration": BASELINE_DURATION,
		"selected_level": selected_level,
		"level": level,
		"height": _height,
		"distance": _distance,
		"width": _width,
		"platform_width": _platform_width,
		"falling_effect": FallEffectManager.get_selected_effect(FallEffectManager.FallStage.FALLING),
		"impact_effect": FallEffectManager.get_selected_effect(FallEffectManager.FallStage.IMPACT),
		"player_slot": player_slot
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	
	print(file.get_as_text())
	file.close()
	
func load_all():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(json) != TYPE_DICTIONARY:
		return
		
	HighLevelNetworkHandler.IP_ADDRESS = str(json.get("ip_address", "localhost"))
	HighLevelNetworkHandler.SERVER_LOG_PATH = str(json.get("file_location", "user://tracking_data.csv"))
	reconstruction_path = str(json.get("reconstruction_path", ""))
	SAMPLE_FREQUENCY_HZ = float(json.get("SAMPLE_FREQUENCY_HZ", 90.0))
	acqknowledge_url = str(json.get("acqknowledge_url", "http://169.254.243.80:15010/RPC2"))
	BASELINE_DURATION = float(json.get("baseline_duration", 900.0))
	selected_level = str(json.get("selected_level", "res://scenes/levels/city.tscn"))
	level = str(json.get("level", "city"))
	_height = float(json.get("height", 40.0))
	_distance = float(json.get("distance", 6.0))
	_width = float(json.get("width", 1.0))
	_platform_width = float(json.get("platform_width", 2.5))
	
	var saved_falling = str(json.get("falling_effect", FallEffectManager.DEFAULT_FALLING))
	var saved_impact = str(json.get("impact_effect", FallEffectManager.DEFAULT_IMPACT))
	
	player_slot = int(json.get("player_slot", 1))

	# Validate before applying (important if files were removed)
	if FallEffectManager.effect_registry[FallEffectManager.FallStage.FALLING].has(saved_falling):
		FallEffectManager.set_selected_effect(
			FallEffectManager.FallStage.FALLING,
			saved_falling
		)

	if FallEffectManager.effect_registry[FallEffectManager.FallStage.IMPACT].has(saved_impact):
		FallEffectManager.set_selected_effect(
			FallEffectManager.FallStage.IMPACT,
			saved_impact
		)
	
		
func get_sync_data() -> Dictionary:
	return {
		"selected_level": selected_level,
		"level": level,
		"_height": _height,
		"_width": _width,
		"_distance": _distance,
		"is_baseline": is_baseline,
		"_platform_width": _platform_width
	}
	
func set_hand_item(slot: int, trans: Transform3D):
	if slot == 1:
		if is_instance_valid(firework):
			firework.global_transform = tracking_to_world(trans)
		else:
			firework = firework_scene.instantiate()
			firework.name = "Firework"
			get_tree().root.add_child(firework)
	else:
		if is_instance_valid(fuse):
			fuse.global_transform = tracking_to_world(trans)
		else:
			fuse = fuse_scene.instantiate()
			fuse.name = "Fuse"
			get_tree().root.add_child(fuse)
			
func remove_hand_item(slot: int):
	if slot == 1:
		if is_instance_valid(firework):
			firework.queue_free()
			firework = null
	else:
		if is_instance_valid(fuse):
			fuse.queue_free()
			fuse = null
		
func _debug_message(message):
	AppLogger.log(message)
	
func start_experiment(frequency_hz: float):
	finished_sending = false
	SAMPLE_FREQUENCY_HZ = frequency_hz
	experiment_start_time = Time.get_ticks_msec()
	experiment_time_ms = 0
	local_samples.clear()
	
	sample_file = FileAccess.open(sample_file_path, FileAccess.WRITE)
	_start_sampling()

func _start_sampling():
	if sample_timer:
		sample_timer.queue_free()
		
	sample_timer = Timer.new()
	sample_timer.wait_time = 1.0 / SAMPLE_FREQUENCY_HZ
	sample_timer.autostart = true
	sample_timer.timeout.connect(_sample_tracking)
	add_child(sample_timer)
	
func stop_experiment():
	_stop_sampling()
	
	if sample_file:
		sample_file.close()
		HighLevelNetworkHandler.send_samples_from_disk(sample_file_path)
		sample_file = null
	else:
		HighLevelNetworkHandler._send_samples_to_server()
		
	
	finished_sending = true
	
func _stop_sampling():
	if sample_timer:
		sample_timer.stop()
		sample_timer.queue_free()
		sample_timer = null
		
func _sample_tracking():

	if !Global.player:
		return

	var p = Global.player

	var t := Time.get_ticks_msec() - experiment_start_time

	var head = Global.world_to_tracking(p.camera.global_transform)
	var left = Global.world_to_tracking(p.left_hand.global_transform)
	var right = Global.world_to_tracking(p.right_hand.global_transform)
	var body = Global.world_to_tracking(p.avatar.global_transform)

	var left_foot = Global.world_to_tracking(p.avatar.left_foot_target.global_transform)
	var right_foot = Global.world_to_tracking(p.avatar.right_foot_target.global_transform)

	var row =[
		Global.player_slot,
		t,

		head.origin.x, head.origin.y, head.origin.z,
		-head.basis.z.x, -head.basis.z.y, -head.basis.z.z,

		left.origin.x, left.origin.y, left.origin.z,
		-left.basis.z.x, -left.basis.z.y, -left.basis.z.z,

		right.origin.x, right.origin.y, right.origin.z,
		-right.basis.z.x, -right.basis.z.y, -right.basis.z.z,

		body.origin.x, body.origin.y, body.origin.z,
		-body.basis.z.x, -body.basis.z.y, -body.basis.z.z,
		
		left_foot.origin.x, left_foot.origin.y, left_foot.origin.z,
		-left_foot.basis.z.x, -left_foot.basis.z.y, -left_foot.basis.z.z,
		
		right_foot.origin.x, right_foot.origin.y, right_foot.origin.z,
		-right_foot.basis.z.x, -right_foot.basis.z.y, -right_foot.basis.z.z,
		
		int(p.is_falling), int(p.fog_sphere.visible)
	]
	
	local_samples.append(row)
	
	if sample_file:
		sample_file.store_line(",".join(row.map(func(v): return str(v))))
	
func add_spectator():	
	# ADD A SPECTATOR CAMERA SCENE FOR HOST
	var spectator_instance = preload("res://scenes/players/spectator_camera.tscn").instantiate()
	get_tree().root.add_child(spectator_instance)


func switch_passthrough():
	if not xr_interface:
		AppLogger.err("OpenXR interface not found")
		return

	if xr_interface.is_passthrough_supported():
		AppLogger.log("passthrough is supported")
		if passthrough_enabled:
			xr_interface.stop_passthrough()
			passthrough_enabled = false		
			AppLogger.log("Stopped passthrough")
		else:
			if xr_interface.start_passthrough():
				passthrough_enabled = true
				AppLogger.log("Started passthrough")
			else:
				AppLogger.err("Failed to start passthrough")
	else:
		# Fallback: use environment blend modes
		var modes = xr_interface.get_supported_environment_blend_modes()
		if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			get_viewport().transparent_bg = true
		elif XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ADDITIVE
			get_viewport().transparent_bg = false
		else:
			AppLogger.err("No supported blend mode for passthrough/AR")
			return

		# Adjust environment settings as you did
		environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

		passthrough_enabled = !passthrough_enabled
		AppLogger.log("Switched to environment‐blend based passthrough mode")
		
		
# =========================
#   ROOMSCALE CALIBRATION
# =========================
func calibrate_roomscale_full() -> bool:
	if xr_interface == null or multiplayer.is_server():
		AppLogger.err("XR interface missing for calibration")
		calibration = null
		return false

	var points: PackedVector3Array = xr_interface.get_play_area()
	if points.size() < 3:
		AppLogger.err("Not enough boundary points")
		return false

	# -------------------------
	# 1. Compute centroid
	# -------------------------
	var center := Vector3.ZERO
	for p in points:
		center += p
	center /= points.size()
	

	# -------------------------
	# 2. Compute covariance (XZ plane only)
	# -------------------------
	var xx := 0.0
	var zz := 0.0
	var xz := 0.0

	for p in points:
		var d = p - center
		xx += d.x * d.x
		zz += d.z * d.z
		xz += d.x * d.z

	xx /= points.size()
	zz /= points.size()
	xz /= points.size()

	# -------------------------
	# 3. Solve eigenvector (principal axis)
	# -------------------------
	var trace = xx + zz
	var det = xx * zz - xz * xz

	var lambda = trace * 0.5 + sqrt(max(0.0, (trace * trace * 0.25) - det))

	var axis := Vector3(lambda - zz, 0.0, xz)

	if axis.length() < 0.001:
		axis = Vector3(1, 0, 0)  # fallback

	axis = axis.normalized()

	# -------------------------
	# 4. Deterministic direction fix
	# -------------------------
	var ref_dir := Vector3(0, 0, -1)  # global forward reference

	if axis.dot(ref_dir) < 0:
		axis = -axis

	# -------------------------
	# 5. Build orthonormal basis
	# -------------------------
	var z = axis
	var x = Vector3.UP.cross(z).normalized()
	var y = Vector3.UP

	var basis = Basis(x, y, z).orthonormalized()

	# -------------------------
	# 6. Store calibration
	# -------------------------
	calibration = Transform3D(basis, center)
	calibrated_center = center

	#if debug_calibration:
		#debug_calibration.draw_roomscale_debug(points, center, basis)
		
	return true
	
func world_to_tracking(t: Transform3D) -> Transform3D:
	if calibration == null:
		return t

	# Reconstruct the exact world transform you applied
	var world_t := Transform3D(calibration.basis, -calibration.origin)
	world_t = world_t.rotated(Vector3.UP, PI)

	# Convert player into "centered world space"
	return world_t.affine_inverse() * t
	
func tracking_to_world(t: Transform3D) -> Transform3D:
	if calibration == null:
		return t
		
	var world_t := Transform3D(calibration.basis, -calibration.origin)
	world_t = world_t.rotated(Vector3.UP, PI)
	
	return world_t * t
	
#func wait(seconds: float) -> void:
	#await get_tree().create_timer(seconds).timeout

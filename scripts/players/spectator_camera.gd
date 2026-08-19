extends Node3D

@onready var camera = $Camera3D

enum CameraMode {
	FREE,
	PLAYER1,
	PLAYER2
}

var camera_mode: CameraMode = CameraMode.FREE

@onready var fog_sphere :=  $Camera3D/FogSphere

@export var move_speed := 10.0
@export var fast_speed := 25.0
@export var mouse_sensitivity := 0.15

@onready var fog_button_player1 : Button = $CanvasLayer/UI/LeftPanel/VBoxContainer/FogButtonP1
@onready var fog_label_player1 : Label = $CanvasLayer/UI/LeftPanel/VBoxContainer/FogLabelP1
@onready var teleport_button_player1 : Button = $CanvasLayer/UI/LeftPanel/VBoxContainer/TeleportButtonP1
@onready var player_1_connection_label : Label = $CanvasLayer/UI/LeftPanel/VBoxContainer/ConnectionStatusPlayer1
@onready var rotate_button_player1 : Button = $CanvasLayer/UI/LeftPanel/VBoxContainer/RotateButtonP1

@onready var fog_button_player2 : Button = $CanvasLayer/UI/RightPanel/VBoxContainer/FogButtonP2
@onready var fog_label_player2 : Label = $CanvasLayer/UI/RightPanel/VBoxContainer/FogLabelP2
@onready var teleport_button_player2 : Button = $CanvasLayer/UI/RightPanel/VBoxContainer/TeleportButtonP2
@onready var player_2_connection_label : Label = $CanvasLayer/UI/RightPanel/VBoxContainer/ConnectionStatusPlayer2
@onready var rotate_button_player2 : Button = $CanvasLayer/UI/RightPanel/VBoxContainer/RotateButtonP2

@onready var timer_spinbox : SpinBox = $CanvasLayer/UI/BottomPanel/GlobalPanel/VBoxContainer/HBoxContainer/TimerSetBox
@onready var timer_start_button : Button = $CanvasLayer/UI/BottomPanel/GlobalPanel/VBoxContainer/HBoxContainer2/TimerStartButton
@onready var timer_stop_button : Button = $CanvasLayer/UI/BottomPanel/GlobalPanel/VBoxContainer/HBoxContainer2/TimerStopButton
@onready var teleport_button : Button = $CanvasLayer/UI/BottomPanel/GlobalPanel/VBoxContainer/ResetPlayersButton
@onready var fog_button : Button = $CanvasLayer/UI/BottomPanel/GlobalPanel/VBoxContainer/PlayersFogButton

@onready var remaining_timer_label : Label = $CanvasLayer/UI/BottomPanel/TimerPanel/VBoxContainer/RemainingTimeLabel
@onready var running_timer_label : Label = $CanvasLayer/UI/BottomPanel/TimerPanel/VBoxContainer/RunningTimeLabel
@onready var system_timer_label : Label = $CanvasLayer/UI/BottomPanel/TimerPanel/VBoxContainer/SystemTimeLabel

var last_sent_duration_ms := 0

var experiment_start_time_ms: int = 0
var experiment_running := false

@onready var experiment_label : Label = $CanvasLayer/UI/BottomPanel/ExperimentPanel/VBoxContainer/ExperimentState
#@onready var calibrate_players_button : Button = $CanvasLayer/UI/BottomPanel/ExperimentPanel/VBoxContainer/CalibrateButton
@onready var quit_button : Button = $CanvasLayer/UI/BottomPanel/ExperimentPanel/VBoxContainer/LeaveButton

@onready var logger_scroll_container : ScrollContainer = $CanvasLayer/UI/BottomPanel/LoggerPanel/ScrollContainer
@onready var logger_label : Label = $CanvasLayer/UI/BottomPanel/LoggerPanel/ScrollContainer/LoggerLabel

@onready var experiment_ui := $CanvasLayer

var yaw := 0.0
var pitch := 0.0
var mouse_captured := false

var player_1_connected := false
var player_2_connected := false

var avatar1: Node3D
var avatar2: Node3D
var left_hand
var right_hand
var cached_left_hand: Transform3D
var cached_right_hand: Transform3D

var player_1_fog_state := false
var player_2_fog_state := false

func _ready():
	# Spectator camera should always be active on the host
	var spawn_position = Vector3(1.5 * Global._distance, 2, 0)
	global_position = spawn_position

	look_at(Vector3.ZERO, Vector3.UP)
	
	var rot = rotation_degrees
	pitch = rot.x
	yaw = rot.y
	
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	experiment_label.text = "Press + to start the experiment"
	
	player_1_connection_label.text = "Not connected"
	player_2_connection_label.text = "Not connected"
	
	Global.spectator = self
	
	fog_button_player1.pressed.connect(_on_toggle_fog_p1)
	fog_button_player2.pressed.connect(_on_toggle_fog_p2)

	teleport_button_player1.pressed.connect(_on_teleport_player1)
	teleport_button_player2.pressed.connect(_on_teleport_player2)
	
	rotate_button_player1.pressed.connect(_on_rotate_player1)
	rotate_button_player2.pressed.connect(_on_rotate_player2)
	
	#calibrate_button_player1.pressed.connect(_on_calibrate_player1)
	#calibrate_button_player2.pressed.connect(_on_calibrate_player2)
	
	teleport_button.pressed.connect(_on_teleport_player)
	fog_button.pressed.connect(_on_toggle_fog)
	timer_start_button.pressed.connect(_on_timer_start)
	timer_stop_button.pressed.connect(_on_timer_stop)
	
	timer_spinbox.value = Global.BASELINE_DURATION
	timer_spinbox.value_changed.connect(_on_timer_value_changed)
	
	#calibrate_players_button.pressed.connect(_on_calibrate_players)
	
	quit_button.pressed.connect(_on_quit_pressed)
	
	AppLogger.log_added.connect(_on_log_added)
	
	fog_sphere.visible = false


func _input(event):
	if camera_mode != CameraMode.FREE:
		return
	
	if Input.is_action_pressed("experiment-start-stop"):
		HighLevelNetworkHandler.switch_experiment()
		experiment_running = !experiment_running
		
		if experiment_running:
			experiment_start_time_ms = Time.get_ticks_msec()
			experiment_label.text = "Experiment is running.\nPress + to stop the experiment"
			experiment_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # green
		else:
			experiment_label.text = "Press + to start the experiment"
			experiment_label.add_theme_color_override("font_color", Color(1, 1, 1)) # white
	
	# Toggle mouse capture with right mouse button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		mouse_captured = !mouse_captured

		if mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Mouse look
	if mouse_captured and event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -89.0, 89.0)

		rotation_degrees = Vector3(pitch, yaw, 0)


func _process(delta):
	_update_timers(delta)
	
	_update_fog()
	
	if camera_mode != CameraMode.FREE:
		left_hand.global_transform = cached_left_hand
		right_hand.global_transform = cached_right_hand
		_update_follow_camera()
		
		return
		
	if !mouse_captured:
		return
		

	var speed := move_speed
	if Input.is_action_pressed("ui_shift"):
		speed = fast_speed

	var direction := Vector3.ZERO

	if Input.is_action_pressed("forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("back"):
		direction += transform.basis.z
	if Input.is_action_pressed("left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("right"):
		direction += transform.basis.x
	if Input.is_action_pressed("jump"):
		direction += Vector3.UP
	if Input.is_action_pressed("crouch"):
		direction -= Vector3.UP
		

	if direction != Vector3.ZERO:
		global_position += direction.normalized() * speed * delta
		
		
func connect_player(slot: int):
	if slot == 1:
		player_1_connected = true
		player_1_connection_label.text = "Connected successfully"
	else:
		player_2_connected = true
		player_2_connection_label.text = "Connected successfully"
		
func buffer_player(slot: int):
	if slot == 1:
		player_1_connected = false
		player_1_connection_label.text = "Connection failing\nattempting to reconnect"
	else:
		player_2_connected = false
		player_2_connection_label.text = "Connection failing\nattempting to reconnect"
		
func on_player_disconnected(slot: int):
	if slot == 1:
		player_1_connected = false
		player_1_connection_label.text = "Not connected"
	else:
		player_2_connected = false
		player_2_connection_label.text = "Not connected"
		
func format_time(ms: int) -> String:
	var hours = ms / 3600000
	var minutes = (ms % 3600000) / 60000
	var seconds = (ms % 60000) / 1000
	var milliseconds = ms % 1000
	
	return "%02d:%02d:%02d:%03d" % [hours, minutes, seconds, milliseconds]
	
func _update_timers(_delta: float) -> void:
	var now = Time.get_ticks_msec()
	
	# --- Remaining Timer (Countdown) ---
	var remaining = HighLevelNetworkHandler.get_baseline_remaining_ms()
	remaining_timer_label.text = format_time(remaining)
	
	
	# --- Running Timer (Count Up) ---
	if experiment_running:
		var elapsed = now - experiment_start_time_ms
		running_timer_label.text = format_time(elapsed)
	else:
		running_timer_label.text = "00:00:00:000"
	
	
	# --- System Time ---
	var datetime = Time.get_datetime_dict_from_system()
	var ms = now % 1000
	
	var system_string = "%02d:%02d:%02d:%03d" % [
		datetime.hour,
		datetime.minute,
		datetime.second,
		ms
	]
	
	system_timer_label.text = system_string
	
		
func update_fog_ui():
	if HighLevelNetworkHandler.player_1_fog_state:
		fog_label_player1.text = "Enabled"
		fog_label_player1.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		fog_label_player1.text = "Disabled"
		fog_label_player1.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		
	if HighLevelNetworkHandler.player_2_fog_state:
		fog_label_player2.text = "Enabled"
		fog_label_player2.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		fog_label_player2.text = "Disabled"
		fog_label_player2.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
			
func set_experiment_ui(vis: bool) -> void:
	experiment_ui.visible = vis
	
func _on_toggle_fog_p1():
	if !player_1_connected:
		AppLogger.warn("Player 1 not connected")
		return
	HighLevelNetworkHandler.server_set_fog(1, !HighLevelNetworkHandler.player_1_fog_state)

func _on_toggle_fog_p2():
	if !player_2_connected:
		AppLogger.warn("Player 2 not connected")
		return
	HighLevelNetworkHandler.server_set_fog(2, !HighLevelNetworkHandler.player_2_fog_state)
	
func _on_toggle_fog():
	HighLevelNetworkHandler.server_set_fog(1, !HighLevelNetworkHandler.player_1_fog_state)
	HighLevelNetworkHandler.server_set_fog(2, !HighLevelNetworkHandler.player_2_fog_state)

func _on_teleport_player1():
	if !player_1_connected:
		AppLogger.warn("Player 1 not connected")
		return
	HighLevelNetworkHandler.server_teleport_player(1)

func _on_teleport_player2():
	if !player_2_connected:
		AppLogger.warn("Player 2 not connected")
		return
	HighLevelNetworkHandler.server_teleport_player(2)
	
func _on_rotate_player1():
	if !player_1_connected:
		AppLogger.warn("Player 1 not connected")
		return
	HighLevelNetworkHandler.server_rotate_player(1)
	
func _on_rotate_player2():
	if !player_2_connected:
		AppLogger.warn("Player 2 not connected")
		return
	HighLevelNetworkHandler.server_rotate_player(2)
	
func _on_teleport_player():
	HighLevelNetworkHandler.server_teleport_player(1)
	HighLevelNetworkHandler.server_teleport_player(2)
	
#func _on_calibrate_player1():
	#if !player_1_connected:
		#AppLogger.warn("Player 1 not connected")
		#return
		#
	#HighLevelNetworkHandler.server_calibrate()
	#
#func _on_calibrate_player2():
	#if !player_2_connected:
		#AppLogger.warn("Player 2 not connected")
		#return
		#
	#HighLevelNetworkHandler.server_calibrate()
	#
#func _on_calibrate_players():	
	#if !player_1_connected:
		#AppLogger.warn("Player 1 not connected")
	#else:
		#HighLevelNetworkHandler.server_calibrate()
		#
	#if !player_2_connected:
		#AppLogger.warn("Player 2 not connected")
	#else:
		#HighLevelNetworkHandler.server_calibrate()
		
	
	

func _on_quit_pressed():
	HighLevelNetworkHandler.server_end_session()
	
func _on_timer_start():
	var new_duration_ms = int(timer_spinbox.value * 1000.0)

	# If running → PAUSE
	if HighLevelNetworkHandler.baseline_running and !HighLevelNetworkHandler.baseline_paused:
		HighLevelNetworkHandler.server_pause_baseline()
		timer_start_button.text = "Start"
		#Timer Paused
		AcqknowledgeConnector.send_marker("32")
		return
	
	# If paused OR stopped → START / RESUME
	HighLevelNetworkHandler.server_start_or_resume_baseline(new_duration_ms)
	
	last_sent_duration_ms = new_duration_ms
	timer_start_button.text = "Pause"
	#Timer start
	AcqknowledgeConnector.send_marker("31")
	
func _on_timer_stop():
	HighLevelNetworkHandler.server_stop_baseline()
	timer_start_button.text = " Play "
	
func _on_timer_value_changed(value):
	Global.BASELINE_DURATION = value
	Global.save_all()
	
func _on_log_added(text: String) -> void:
	if !is_instance_valid(logger_label):
		return

	logger_label.text += text + "\n"

	await get_tree().process_frame
	logger_scroll_container.scroll_vertical = int(logger_scroll_container.get_v_scroll_bar().max_value)
	
func set_avatars(a1: Node3D, a2: Node3D):
	avatar1 = a1
	avatar2 = a2
	
func set_hands(left: Node3D, right: Node3D):
	left_hand = left
	right_hand = right
	
func set_hands_transform(left: Transform3D, right: Transform3D):
	cached_left_hand = left
	cached_right_hand = right
	
func set_camera_free():
	camera_mode = CameraMode.FREE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	left_hand.visible = false
	right_hand.visible = false
	
	if avatar1:
		avatar1.visible = true
	if avatar2:
		avatar2.visible = true

func set_camera_player1():
	camera_mode = CameraMode.PLAYER1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	left_hand.visible = true
	right_hand.visible = true
	
	if avatar1:
		avatar1.visible = false
	if avatar2:
		avatar2.visible = true

func set_camera_player2():
	camera_mode = CameraMode.PLAYER2
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	left_hand.visible = true
	right_hand.visible = true
	
	if avatar1:
		avatar1.visible = true
	if avatar2:
		avatar2.visible = false
	
func _update_follow_camera():
	var target_avatar: Node3D = null

	if camera_mode == CameraMode.PLAYER1:
		target_avatar = avatar1
	elif camera_mode == CameraMode.PLAYER2:
		target_avatar = avatar2

	if target_avatar == null:
		return

	# Use head transform from your replay system
	var head_transform: Transform3D = target_avatar.head

	# Optional: slight offset to avoid clipping
	var offset := head_transform.basis * Vector3(0, 0.05, 0.05)

	global_transform = Transform3D(
		head_transform.basis,
		head_transform.origin + offset
	)
	
func _update_fog():
	if camera_mode == CameraMode.PLAYER1:
		fog_sphere.visible = player_1_fog_state
	elif camera_mode == CameraMode.PLAYER2:
		fog_sphere.visible = player_2_fog_state
	else:
		fog_sphere.visible = false

func _exit_tree():
	if Global.spectator == self:
		Global.spectator = null

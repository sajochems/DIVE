extends CharacterBody3D

@export var CAMERA_CONTROLLER : Camera3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var MOUSE_SENSITIVITY : float = 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)

var _mouse_input : bool = false
var _mouse_rotation : Vector3
var _rotation_input : float
var _tilt_input : float
var _player_rotation : Vector3
var _camera_rotation : Vector3

var camera
var left_hand
var right_hand
var menu_vis
var playerbody

var debug_open := false

var is_falling: bool = false

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	await get_tree().process_frame
	if is_multiplayer_authority():
		Global.player = self
		playerbody = self
	
		position.y = 1.0
		if Global.spawn_slot == 0:
			position.z = (Global._distance/2.0) + 1.25
		else:
			position.z = -((Global._distance/2.0) + 1.25)
			
		CAMERA_CONTROLLER.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED	
			
	else:
		CAMERA_CONTROLLER.current = false
	
	

func _input(event):
	if !is_multiplayer_authority():
		return
		
	if event.is_action_pressed("exit"):
		get_tree().quit()
		
	if event.is_action_pressed("debug"):
		debug_open = !debug_open
		
		if debug_open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		Global.debug._activate_debug()

func _unhandled_input(event: InputEvent):
	if !is_multiplayer_authority():
		return
		
	_mouse_input = event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y
		
func _update_camera(delta):
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta
	
	_player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
	_camera_rotation = Vector3(_mouse_rotation.x, 0.0, 0.0)
	
	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
	CAMERA_CONTROLLER.rotation.z = 0.0
	
	global_transform.basis = Basis.from_euler(_player_rotation)
	
	_rotation_input = 0.0
	_tilt_input = 0.0

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	_update_camera(delta)
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
func _process(_delta: float) -> void:
	
	if is_falling and is_on_floor():
		stop_falling()
	
	if !is_multiplayer_authority():
		return
		
	if !debug_open and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	camera = CAMERA_CONTROLLER.global_transform
	left_hand = CAMERA_CONTROLLER.global_transform
	left_hand = CAMERA_CONTROLLER.global_transform
	
	
func get_avatar_sync_data() -> Dictionary:
	return {
		"head": CAMERA_CONTROLLER.global_transform,
		"left_hand": CAMERA_CONTROLLER.global_transform,
		"right_hand": CAMERA_CONTROLLER.global_transform,
		"avatar_position": global_transform
	}
	
func start_falling():
	is_falling = true
	AppLogger.log("player started falling")
	
func stop_falling():
	is_falling = false
	AppLogger.log("player stopped falling")

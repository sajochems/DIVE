extends FallEffect

const MAX_GRAVITY := 9.81
const MIN_GRAVITY := 0.50
const CONSTANT_PHASE := 0.1

const MAX_TERMINAL_VELOCITY := 18.0
const MIN_TERMINAL_VELOCITY := 0.5 

var active := false

func start(player):
	active = true
	player.gravity_provider.gravity_direction = Vector3.DOWN
	_apply_gravity_and_terminal(player, MAX_GRAVITY)

func update(player, _delta):
	if not active:
		return
		
	#player.playerbody.velocity.x = 0
	#player.playerbody.velocity.z = 0

	var current_y = player.playerbody.global_transform.origin.y
	var total_height = Global._height

	if total_height <= 0.0:
		return

	var progress = clamp(abs(current_y) / total_height, 0.0, 1.0)

	if progress <= CONSTANT_PHASE:
		_apply_gravity_and_terminal(player, MAX_GRAVITY)
	else:
		var t = (progress - CONSTANT_PHASE) / (1.0 - CONSTANT_PHASE)
		var gravity = lerp(MAX_GRAVITY, MIN_GRAVITY, t)
		_apply_gravity_and_terminal(player, gravity)

func stop(player):
	active = false
	_apply_gravity_and_terminal(player, MAX_GRAVITY)
	
func _apply_gravity_and_terminal(player, gravity_value):
	player.gravity_provider.gravity_strength = gravity_value
	
	# Scale terminal velocity proportionally
	var gravity_ratio = gravity_value / MAX_GRAVITY
	var terminal = lerp(MIN_TERMINAL_VELOCITY, MAX_TERMINAL_VELOCITY, gravity_ratio)

	player.gravity_provider.terminal_velocity = terminal

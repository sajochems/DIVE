class_name CustomGravityProvider
extends XRToolsMovementProvider

@export var order: int = 100

@export var gravity_strength: float = 9.81
@export var gravity_direction: Vector3 = Vector3.DOWN
@export var override_physics_gravity: bool = true
@export var terminal_velocity = 18.0

func physics_pre_movement(delta: float, player_body: XRToolsPlayerBody) -> void:

	if player_body == null:
		return

	var down = gravity_direction.normalized()
	var gravity = down * gravity_strength

	player_body.velocity += gravity * delta

	# Terminal velocity
	var vertical_speed = player_body.velocity.dot(down)

	if vertical_speed > terminal_velocity:
		var lateral = player_body.velocity - down * vertical_speed
		player_body.velocity = lateral + down * terminal_velocity

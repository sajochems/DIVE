extends Node3D

@export var speed := 12.0
@export var fuse_time := 2.5

var velocity: Vector3
var active := false

@onready var mesh = $Body
@onready var explosion_particles = $ExplosionParticles
@onready var trail_particles = $TrailParticles

func _ready() -> void:
	trail_particles.emitting = false
	explosion_particles.emitting = false

func launch(direction: Vector3):
	active = true
	velocity = direction.normalized() * speed
	trail_particles.emitting = true
	start_fuse()

func _process(delta):
	if not active:
		return

	# Move
	translate(velocity * delta)

func start_fuse():
	await get_tree().create_timer(fuse_time).timeout
	explode()

func explode():
	active = false
	mesh.visible = false

	# Stop trail
	trail_particles.restart()
	trail_particles.emitting = false

	# Play explosion
	explosion_particles.restart()
	explosion_particles.emitting = true
	
	for i in range(3):
		await get_tree().create_timer(0.2).timeout
		explosion_particles.restart()

	# Optional: sound
	# $AudioStreamPlayer3D.play()

	await get_tree().create_timer(2.0).timeout
	queue_free()
	
	
func launch_from(interactor):
	var pos = global_position
	
	# Safe reparent
	if get_parent():
		get_parent().remove_child(self)

	interactor.get_tree().root.add_child(self)
	
	global_position = pos

	global_rotation = Vector3.ZERO

	launch(Vector3.UP)

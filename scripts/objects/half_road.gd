@tool
extends Node3D

@export var ROADLENGTH: float = 20.0:
	set(value):
		ROADLENGTH = value
		_update_road()

@onready var _road = %Road
@onready var _sidewalkleft = %Sidewalk

func _ready() -> void:
	#if Engine.is_editor_hint():
	_update_road()

func _update_road() -> void:
	if not _road or not _sidewalkleft:
		return

	# Duplicate meshes if they're shared
	if _road.mesh:
		_road.mesh = _road.mesh.duplicate()
	if _sidewalkleft.mesh:
		_sidewalkleft.mesh = _sidewalkleft.mesh.duplicate()

	# Now safe to edit per-instance
	_road.mesh.size.z = ROADLENGTH
	_sidewalkleft.mesh.size.z = ROADLENGTH

extends Node3D

var DISTANCE : float
var HEIGHT : float

@export var PLATFORMLENGTH : float
@export var HEIGHTOFFSET : float

var leave_button_scene := preload("res://scenes/interaction/leave_button.tscn")
@onready var leave_button_parent_node : Node3D = $ElevatorDoor

@onready var scalable : Node3D = $Scalable
	
func _init_platform(flipped : bool) -> void:
	Global.platform_length = PLATFORMLENGTH
	if flipped:
		_set_height(0.0 - HEIGHTOFFSET)
		_set_distance(-((Global._distance/2.0) + PLATFORMLENGTH))
	else:
		_set_height(0.0 - HEIGHTOFFSET)
		_set_distance((Global._distance/2.0) + PLATFORMLENGTH)
		
	Global.platform = self
	
	if Global._platform_width <= 2.0:
		scale.x =  Global._platform_width / 2.5
	else:
		scalable.scale.x = Global._platform_width / 2.5
	
func _set_height(newHeight : float) -> void:
	HEIGHT = newHeight
	_update_position()
	
func _set_distance(newDist : float) -> void:
	DISTANCE = newDist
	_update_position()

func _update_position() -> void:
	position = Vector3(0.0, HEIGHT, DISTANCE)
	
func activate_leave_button() -> void:
	var button_instance = leave_button_scene.instantiate()
	leave_button_parent_node.add_child(button_instance)
	pass
	

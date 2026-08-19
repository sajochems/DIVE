extends Node3D


var DISTANCE : float
var HEIGHT : float

@export var BUIDLINGWIDTH : float
@export var DISTANCEOFFSET : float

func _initBuilding(flipped : bool) -> void:
	if flipped:
		_set_height(Global._height)
		_set_distance(-((Global._distance/2.0) + BUIDLINGWIDTH + DISTANCEOFFSET))
	else:
		_set_height(Global._height)
		_set_distance((Global._distance/2.0) + BUIDLINGWIDTH + DISTANCEOFFSET)
	
func _set_distance(newDist : float) -> void:
	DISTANCE = newDist
	_update_position()
	
func _set_height(newHeight : float) -> void:
	HEIGHT = newHeight
	_update_position()

func _update_position() -> void:
	position = Vector3(0.0, -HEIGHT, DISTANCE)

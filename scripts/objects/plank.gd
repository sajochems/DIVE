extends Node3D


var DISTANCE : float
var HEIGHT : float

var PlANKWIDTH : float

@export var HEIGHTOFFSET : float

	
func _init_plank(flipped : bool) -> void:
	if flipped:
		_set_height(0.0 - HEIGHTOFFSET)
		_set_distance(-(Global._distance/4.0))
		_set_width(Global._width)
	else:
		_set_height(0.0 - HEIGHTOFFSET)
		_set_distance(Global._distance/4.0)
		_set_width(Global._width)
	
func _set_height(newHeight : float) -> void:
	HEIGHT = newHeight
	_update_position()
	
func _set_distance(newDist : float) -> void:
	DISTANCE = newDist
	_update_position()
	
func _set_width(newWidth : float) -> void:
	PlANKWIDTH = newWidth
	_update_position()

func _update_position() -> void:
	scale.z = DISTANCE * 2.0
	scale.x = PlANKWIDTH

	position = Vector3(0.0, HEIGHT, DISTANCE)	

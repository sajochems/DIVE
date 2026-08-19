extends Node3D
class_name Interactable

@export var actions: Array[Node] = []

var cooldown := 1.5
var last_time := 0.0

@export var allowed_interactor_groups: Array[String] = []

func interact(interactor):
	if Time.get_ticks_msec() / 1000.0 - last_time < cooldown:
		return
	last_time = Time.get_ticks_msec() / 1000.0
	
	for action in actions:
		if action.has_method("execute"):
			action.execute(self, interactor)
			
			
			
func can_interact_with(interactor):
	if allowed_interactor_groups.is_empty():
		return true

	for group in allowed_interactor_groups:
		if interactor.is_in_group(group):
			return true

	return false

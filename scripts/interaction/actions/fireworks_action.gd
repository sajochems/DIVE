extends InteractionAction
class_name ActionFireworks

func execute(_interactable, _interactor):
	if Global.platform:
		Global.platform.activate_leave_button()
		
	var firework = Global.firework
	if firework:
		_launch_firework(firework, _interactor)
		#await get_tree().create_timer(1.0).timeout
		
		
func _launch_firework(firework, interactor):
	# Launch upward
	firework.call_deferred("launch_from", interactor)

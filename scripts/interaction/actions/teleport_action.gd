extends InteractionAction
class_name ActionTeleport

func execute(interactable, interactor):
	if Global.player:
		Global.player.enable_fog()
		Global.player.teleport_to_spawn()
		
		await get_tree().create_timer(2.0).timeout
		Global.player.disable_fog()
	

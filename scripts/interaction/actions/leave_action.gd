extends InteractionAction
class_name ActionLeave

func execute(interactable, interactor):
	if Global.player:
		Global.player.enable_fog()
		await get_tree().create_timer(1.0).timeout
		
	Global.stop_experiment()
	
	while !Global.finished_sending:
		pass
		
	Global.remove_hand_item(Global.player_slot)
	
	HighLevelNetworkHandler.send_disconnect_avatar(Global.player_slot)
	
	HighLevelNetworkHandler.leave_session()
	Global.scene_loader.switch_scene("res://scenes/levels/xr_menu_scene.tscn")
		
	if Global.player:
		Global.player.disable_fog()
		await get_tree().create_timer(1.0).timeout
	

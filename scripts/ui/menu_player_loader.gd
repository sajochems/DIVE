extends Node3D

var player_scene := preload("res://scenes/players/xr_player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.xr_interface:
		await get_tree().process_frame
		if !Global.player:
			var player_instance = player_scene.instantiate()
			player_instance.server_spawn = true
			player_instance.name = str(multiplayer.get_unique_id())
			get_tree().current_scene.add_child(player_instance)
		
		AppLogger.log("loading game in xr mode")
	else:
		AppLogger.log("loading game in normal mode")
		await get_tree().process_frame
		Global.scene_loader.switch_scene("res://scenes/levels/host_menu_scene.tscn")

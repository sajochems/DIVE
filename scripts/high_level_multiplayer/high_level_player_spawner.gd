extends MultiplayerSpawner

@export var network_test_player: PackedScene
@export var network_client_xr_player: PackedScene
@export var network_server_xr_player: PackedScene

func _ready():
	Global.spawner = self


func has_player(peer_id: int) -> bool:
	var parent := get_node(spawn_path)
	return parent.has_node(str(peer_id))
	
	
func spawn_server_player(peer_id: int, slot: int):
	var parent := get_node(spawn_path)
	var name_str := str(peer_id)

	var player = network_server_xr_player.instantiate()
	
	#var player = network_player.instantiate()
	
	player.name = name_str
	player.set_global_avatar(slot)
	parent.add_child(player)
	player.visible = false
	
	#AppLogger.log("[SPAWNER] Spawned server peer " + name_str + " in slot " + str(slot))
	
	
func spawn_client_player(peer_id: int, slot: int):
	if multiplayer.is_server():
		return
		
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		return
		
	AppLogger.log("spawning client player: " + str(peer_id))

	var parent := get_node(spawn_path)
	var name_str := str(peer_id)

	if parent.has_node(name_str):
		return

	var player  = network_test_player.instantiate()
	
	#var player = network_player.instantiate()
	
	player.name = name_str
	parent.add_child(player)
	
	AppLogger.log("[SPAWNER] Spawned client peer " + name_str + " in slot " + str(slot))

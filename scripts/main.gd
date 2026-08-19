extends Node3D


@onready var environment : Environment = $WorldEnvironment.environment
@onready var world : Node3D = $World
@onready var world_env : Node3D = $World/Environment
@onready var bridgecontroller : Node3D = $World/BridgeController

var plank_nodes: Array[Node3D] = []
var platform_nodes: Array[Node3D] = []

var spawner = preload("res://scenes/multiplayer_spawner.tscn")
var reset_button = preload("res://scenes/interaction/reset_button.tscn")


func _ready():
	Global.main = self
	Global.environment = environment
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	if Global.calibrate_roomscale_full():
		world.global_transform = Global.tracking_to_world(world.global_transform)
	
	var instance_spawner = spawner.instantiate()
	add_child(instance_spawner)
	instance_spawner.spawn_path = get_path()
	Global.spawner = instance_spawner
		
	spawn_platform(Global.level)
	spawn_plank(Global.level)
	spawn_structure(Global.level)
	
	set_height(Global._height)
			
	if !Global.is_baseline:
		var instance_reset_button = reset_button.instantiate()
		bridgecontroller.add_child(instance_reset_button)
		place_reset_button(instance_reset_button, Global.player_slot)
		
		var instance_reset_button2 = reset_button.instantiate()
		bridgecontroller.add_child(instance_reset_button2)
		place_reset_button(instance_reset_button2, 3 - Global.player_slot)
		
		#if multiplayer.is_server():
			#var instance_reset_button2 = reset_button.instantiate()
			#bridgecontroller.add_child(instance_reset_button2)
			#place_reset_button(instance_reset_button2, 3 - Global.player_slot)
			
	if multiplayer.is_server() and !Global.replay_controller:
		Global.add_spectator()
		HighLevelNetworkHandler._spawn_fixed_avatars()
		
func set_height(height: float) -> void:
	if world_env:
		world_env.position.y = -height
		

func spawn_platform(type_name: String) -> Node:
	var scene_path := "res://scenes/bridge_files/platforms/" + type_name + "_platform.tscn"
	
	var packed_scene := load(scene_path)
	if packed_scene == null:
		AppLogger.err("Failed to load scene at path: %s" % scene_path + " switching to default")
		packed_scene = load("res://scenes/bridge_files/platforms/city_platform.tscn")

	var instance = packed_scene.instantiate()
	bridgecontroller.add_child(instance)
	instance._init_platform(false)
	platform_nodes.append(instance)
	
	var instance2 = packed_scene.instantiate()
	instance2.rotate(Vector3.UP, deg_to_rad(180))
	bridgecontroller.add_child(instance2)
	instance2._init_platform(true)
	platform_nodes.append(instance2)

	return instance
	
	
func spawn_plank(type_name: String) -> Node:
	var scene_path := "res://scenes/bridge_files/planks/" + type_name + "_plank.tscn"
	
	var packed_scene := load(scene_path)
	if packed_scene == null:
		AppLogger.err("Failed to load scene at path: %s" % scene_path + " switching to default")
		packed_scene = load("res://scenes/bridge_files/planks/city_plank.tscn")

	var instance = packed_scene.instantiate()
	bridgecontroller.add_child(instance)
	instance._init_plank(false)
	plank_nodes.append(instance)
	
	var instance2 = packed_scene.instantiate()
	instance2.rotate(Vector3.UP, deg_to_rad(180))
	bridgecontroller.add_child(instance2)
	instance2._init_plank(true)
	plank_nodes.append(instance2)

	return instance
		
		
func spawn_structure(type_name: String) -> Node:
	var scene_path := "res://scenes/bridge_files/spawn_structures/" + type_name + "_structure.tscn"
	
	var packed_scene := load(scene_path)
	if packed_scene == null:
		AppLogger.err("Failed to load scene at path: %s" % scene_path + " switching to default")
		packed_scene = load("res://scenes/bridge_files/spawn_structures/city_structure.tscn")

	var instance = packed_scene.instantiate()
	bridgecontroller.add_child(instance)
	instance._initBuilding(false)
	
	var instance2 = packed_scene.instantiate()
	instance2.rotate(Vector3.UP, deg_to_rad(180))
	bridgecontroller.add_child(instance2)
	instance2._initBuilding(true)

	return instance
	
func place_reset_button(button : Node3D, slot : int) -> void:
	var new_y = -Global._height
	var new_z = (Global._distance/2.0) + Global.platform_length
	
	if slot == 2:
		new_z = -new_z
		
	button.position = Vector3(0.0, new_y, new_z)
	
	
	
	

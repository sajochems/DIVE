extends Node

@onready var xr_viewport : XRToolsViewport2DIn3D = $Viewport2Din3D
@onready var keyboard : XRToolsViewport2DIn3D = $VirtualKeyboard

const MAIN_MENU_SCENE = preload("res://scenes/ui/menu/main_menu.tscn")
const SETTINGS_MENU_SCENE = preload("res://scenes/ui/menu/settings_menu.tscn")
const RECONSTRUCTION_MENU_SCENE = preload("res://scenes/ui/menu/reconstruction_menu.tscn")

var current_menu: Control = null


func _ready() -> void:
	Global.menu_manager = self
	show_main_menu()
	
func set_xr_viewport_visibility(vis : bool):
	if xr_viewport:
		xr_viewport.visible = vis
	
func set_keyboard_visibility(vis : bool):
	if keyboard:
		keyboard.visible = vis


# ---------------------------------------------------------
# Scene Loading Helpers
# ---------------------------------------------------------
func load_menu(scene: PackedScene) -> void:
	# Clear previous menu
	if current_menu:
		current_menu.queue_free()
		current_menu = null

	# Instance new menu
	current_menu = scene.instantiate()
	if Global.xr_interface:	
		xr_viewport.scene = scene
	else:
		add_child(current_menu)


func show_main_menu() -> void:
	load_menu(MAIN_MENU_SCENE)
	set_keyboard_visibility(false)

func show_settings_menu() -> void:
	load_menu(SETTINGS_MENU_SCENE)
	set_keyboard_visibility(true)
	
func show_reconstruction_menu() -> void:
	load_menu(RECONSTRUCTION_MENU_SCENE)

# ---------------------------------------------------------
# Button Handlers
# ---------------------------------------------------------
func _on_host_pressed():
	Global.is_baseline = false
	Global.load_all()
	
	_start_host()
		
func _on_host_baseline_pressed():
	Global.is_baseline = true

	Global._height = 0.75
	Global._width = 2.5
	_start_host()
	
func _start_host():
	var level = Global.selected_level
	if level == "":
		AppLogger.log("No level selected!")
		return
		
	HighLevelNetworkHandler.start_server(level)

		
func _on_join_pressed():
	Global.save_all()
	HighLevelNetworkHandler.start_client()
	set_multiplayer_authority(multiplayer.get_unique_id())

func _on_settings_pressed() -> void:
	show_settings_menu()
	
func _on_reconstruction_pressed() -> void:
	show_reconstruction_menu()
	
func _on_start_reconstruction_pressed() -> void:
	Global.save_all()
	get_tree().change_scene_to_file("res://scenes/reconstructor.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	show_main_menu()

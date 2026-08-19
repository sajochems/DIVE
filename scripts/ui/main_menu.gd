extends Control

signal start_pressed
signal settings_pressed
signal quit_pressed

@onready var join_button: Button = $Panel/HBoxContainer/VBoxContainer2/JoinButton
@onready var settings_button: Button = $Panel/HBoxContainer/VBoxContainer/HostSettingsButton
@onready var quit_button: Button = $Panel/HBoxContainer/VBoxContainer3/QuitButton

# Set your level paths here OR allow the menu_manager to override them.
var level_paths := [
	"res://scenes/levels/city.tscn",
]

func _ready() -> void:
	join_button.pressed.connect(_join_pressed)
	settings_button.pressed.connect(_settings_pressed)
	quit_button.pressed.connect(_quit_pressed)

func _join_pressed():
	Global.menu_manager._on_join_pressed()

func _settings_pressed(): 
	Global.menu_manager._on_settings_pressed()
		
func _quit_pressed(): 
	Global.menu_manager._on_quit_pressed()
	

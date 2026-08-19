extends Control


@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var fileloc_textedit: LineEdit = $Panel/VBoxContainer/FileBox/FileLocationBox
@onready var back_button: Button = $Panel/VBoxContainer/BackButton



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	fileloc_textedit.text = Global.reconstruction_path
	fileloc_textedit.text_changed.connect(_on_fileloc_changed)
	
	back_button.pressed.connect(func(): Global.menu_manager._on_back_pressed())
	start_button.pressed.connect(func(): Global.menu_manager._on_start_reconstruction_pressed())

	
func _on_fileloc_changed(value: String) -> void:
	Global.reconstruction_path = value
	Global.save_all()

extends Control

@onready var player_selector : CheckButton = $Panel/HBoxContainer/PlayerSelector

@onready var falling_dropdown : OptionButton = $Panel/VBoxContainer/FallingDropdown
@onready var impact_dropdown : OptionButton = $Panel/VBoxContainer/ImpactDropdown

@onready var back_button : Button = $Panel/BackButton

func _ready():
	_populate_dropdown(
		falling_dropdown,
		FallEffectManager.FallStage.FALLING
	)

	_populate_dropdown(
		impact_dropdown,
		FallEffectManager.FallStage.IMPACT
	)

	falling_dropdown.item_selected.connect(_on_falling_selected)
	impact_dropdown.item_selected.connect(_on_impact_selected)
	
	back_button.pressed.connect(func(): Global.menu_manager._on_back_pressed())
	
	if Global.player_slot == 2:
		player_selector.button_pressed = true
	else:
		player_selector.button_pressed = false
		
	player_selector.toggled.connect(_on_player_slot_selected)
	
	
func _populate_dropdown(dropdown: OptionButton, stage: int):
	dropdown.clear()

	var effect_ids = FallEffectManager.get_effect_ids(stage)

	effect_ids.sort()

	var selected_id = FallEffectManager.get_selected_effect(stage)

	for i in range(effect_ids.size()):
		var id = effect_ids[i]
		var readable_name = _format_name(id)

		dropdown.add_item(readable_name, i)

		if id == selected_id:
			dropdown.select(i)
			
func _on_falling_selected(index: int):
	var id = FallEffectManager.get_effect_ids(
		FallEffectManager.FallStage.FALLING
	)[index]

	FallEffectManager.set_selected_effect(
		FallEffectManager.FallStage.FALLING,
		id
	)
	
	Global.save_all()

func _on_impact_selected(index: int):
	var id = FallEffectManager.get_effect_ids(
		FallEffectManager.FallStage.IMPACT
	)[index]

	FallEffectManager.set_selected_effect(
		FallEffectManager.FallStage.IMPACT,
		id
	)
	
	Global.save_all()
	
func _format_name(id: String) -> String:
	var res_name = id.replace("_effect", "")
	res_name = res_name.replace("_", " ")
	return res_name.capitalize()
	
func _on_player_slot_selected(pressed: bool):
	if pressed:
		Global.player_slot = 2
	else:
		Global.player_slot = 1
		
	Global.save_all()
	

extends Node

enum FallStage {
	FALLING,
	IMPACT
}

const FALLING_PATH := "res://scripts/effects/falling_effects"
const IMPACT_PATH := "res://scripts/effects/impact_effects"

const DEFAULT_FALLING := "normal_fall_effect"
const DEFAULT_IMPACT := "no_impact_effect"

var effect_registry := {
	FallStage.FALLING: {},
	FallStage.IMPACT: {}
}

var selected_effects := {
	FallStage.FALLING: DEFAULT_FALLING,
	FallStage.IMPACT: DEFAULT_IMPACT
}

var active_falling_effect : FallEffect = null

var active_impact_effect : FallEffect = null
var impact_active := false

func register_effect(stage: int, id: String, effect: Object):
	if not effect_registry.has(stage):
		effect_registry[stage] = {}
		
	effect_registry[stage][id] = effect
	
func _ready():
	_load_effects_from_folder(FALLING_PATH, FallStage.FALLING)
	_load_effects_from_folder(IMPACT_PATH, FallStage.IMPACT)
	
	Global.load_all()

	# Ensure defaults exist
	if not effect_registry[FallStage.FALLING].has(DEFAULT_FALLING):
		push_error("Default falling effect not found.")

	if not effect_registry[FallStage.IMPACT].has(DEFAULT_IMPACT):
		push_error("Default impact effect not found.")
		
func _load_effects_from_folder(path: String, stage: int):
	var files = ResourceLoader.list_directory(path)

	if files.is_empty():
		push_warning("No files found in: " + path)
		return

	for file_name in files:
		if file_name.ends_with(".gd"):
			var id = file_name.replace(".gd", "")
			var script_path = path + "/" + file_name

			var script = load(script_path)
			if script == null:
				push_warning("Failed to load: " + script_path)
				continue

			effect_registry[stage][id] = script.new()
	
func get_effect_ids(stage: int) -> Array:
	return effect_registry[stage].keys()

func set_selected_effect(stage: int, id: String):
	if effect_registry[stage].has(id):
		selected_effects[stage] = id
	else:
		push_warning("Effect ID not found: " + id)

func get_selected_effect(stage: int) -> String:
	return selected_effects[stage]
	
func on_fall_started(player):
	var effect_id = selected_effects[FallStage.FALLING]
	var effect = effect_registry[FallStage.FALLING].get(effect_id)

	if effect:
		active_falling_effect = effect
		active_falling_effect.start(player)
		
func update_falling(player, delta):
	if active_falling_effect:
		active_falling_effect.update(player, delta)
		
func has_active_impact() -> bool:
	return active_impact_effect != null
	
func clear_active_impact() -> void:
	active_impact_effect = null
		
func update_impact(player, delta):
	if not impact_active:
		return

	active_impact_effect.update(player, delta)
		
func on_fall_stopped(player):
	if active_falling_effect:
		active_falling_effect.stop(player)
		active_falling_effect = null

	var effect_id = selected_effects[FallStage.IMPACT]
	var effect = effect_registry[FallStage.IMPACT].get(effect_id)

	if effect:
		active_impact_effect = effect
		active_impact_effect.start(player)
		impact_active = true

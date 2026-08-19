extends Node3D

@onready var controller := $ReplayController
@onready var avatar1 := $Avatar1
@onready var avatar2 := $Avatar2

@onready var left_hand := $LeftHand
@onready var right_hand := $RightHand

func _ready():
	controller.load_csv(Global.reconstruction_path)
	controller.time_changed.connect(_on_time_changed)
	
	avatar1.reconstructor_slot = 0
	avatar2.reconstructor_slot = 1
	
	left_hand.visible = false
	right_hand.visible = false
	
	load_world()
	
	
func load_world():
	var world_scene := load(Global.selected_level)
	var instance = world_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	
	_on_time_changed(0.0)
	
	Global.add_spectator()

	Global.spectator.set_experiment_ui(false)
	Global.spectator.set_avatars(avatar1, avatar2)
	
	Global.set_hand_item(1, Transform3D.IDENTITY) 
	Global.set_hand_item(2, Transform3D.IDENTITY)
	
	Global.spectator.set_hands(left_hand, right_hand)

func _on_time_changed(time_ms: float) -> void:
	var f1 = controller.frames_by_player.get(avatar1.reconstructor_slot, [])
	var f2 = controller.frames_by_player.get(avatar2.reconstructor_slot, [])

	if f1.size() > 0:
		var fp1 = controller.get_frame_pair(f1, time_ms) 
		avatar1.apply_frame(fp1[0], fp1[1], fp1[2])
		if Global.spectator:
			Global.spectator.player_1_fog_state = bool(fp1[1]["fog_enabled"])

	if f2.size() > 0:
		var fp2 = controller.get_frame_pair(f2, time_ms) 
		avatar2.apply_frame(fp2[0], fp2[1], fp2[2])
		if Global.spectator:
			Global.spectator.player_2_fog_state = fp2[1]["fog_enabled"]

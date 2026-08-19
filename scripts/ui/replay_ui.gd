extends Control


@onready var play_button := $PlayButton
@onready var timeline := $TimeLine
@onready var quit_button := $QuitButton

@onready var playback_box := $PlaybackBox

@onready var time_label := $TimeLabel

@onready var free_cam_button := $FreeCamButton
@onready var p1_cam_button := $Player1Button
@onready var p2_cam_button := $Player2Button

var is_scrubbing := false


func _ready():
	play_button.pressed.connect(_on_play_pressed)
	timeline.value_changed.connect(_on_timeline_value_changed)
	quit_button.pressed.connect(_on_quit_pressed)
	timeline.drag_started.connect(_on_timeline_drag_started)
	timeline.drag_ended.connect(_on_timeline_drag_ended)
	playback_box.value_changed.connect(_on_playback_changed)

	Global.replay_controller.time_changed.connect(_on_time_changed)
	
	free_cam_button.pressed.connect(func(): Global.spectator.set_camera_free())
	p1_cam_button.pressed.connect(func(): Global.spectator.set_camera_player1())
	p2_cam_button.pressed.connect(func(): Global.spectator.set_camera_player2())

	timeline.min_value = 0
	timeline.max_value = Global.replay_controller.duration_ms
	timeline.step = 1
	
	time_label.text = "00:00:000"
	
	Global.replay_ui = self

func _on_play_pressed():
	Global.replay_controller.toggle_play()
	
func _on_quit_pressed():
	get_tree().quit()

func _on_time_changed(time_ms: float):
	if not is_scrubbing:
		timeline.value = time_ms
		time_label.text = format_time_ms(time_ms)
	
func _on_timeline_value_changed(value):
	Global.replay_controller.seek(value)
	time_label.text = format_time_ms(value)
	
func _on_timeline_drag_started():
	is_scrubbing = true
	Global.replay_controller.pause()

func _on_timeline_drag_ended(value_changed):
	is_scrubbing = false
	Global.replay_controller.seek(timeline.value)
	Global.replay_controller.play()
	
func _on_playback_changed(value):
	Global.replay_controller.playback_speed = value
	
func refresh():
	timeline.max_value = Global.replay_controller.duration_ms
	
func format_time_ms(time_ms: float) -> String:
	var total_ms := int(time_ms)

	var minutes := total_ms / 60000
	var seconds := (total_ms % 60000) / 1000
	var milliseconds := total_ms % 1000

	return "%02d:%02d:%03d" % [minutes, seconds, milliseconds]
	

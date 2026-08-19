extends Node3D

@export var playback_speed := 1.0
@export var loop := true

signal time_changed(time_ms: float)

var frames_by_player := {}

var is_playing := false

var _last_tick_ms := 0
var duration_ms = 0.0

var playback_time_ms := 0.0

func _ready() -> void:
	Global.replay_controller = self
	_last_tick_ms = Time.get_ticks_msec()
	
func _process(_delta: float) -> void:
	var now_ms := Time.get_ticks_msec()
	if not is_playing or frames_by_player.is_empty():
		_last_tick_ms = now_ms
		return
	
	var elapsed_ms := now_ms - _last_tick_ms
	_last_tick_ms = now_ms

	playback_time_ms += elapsed_ms * playback_speed

	if playback_time_ms > duration_ms:
		if loop:
			playback_time_ms = 0.0
		else:
			playback_time_ms = duration_ms
			is_playing = false

	elif playback_time_ms < 0.0:
		if loop:
			playback_time_ms = duration_ms
		else:
			playback_time_ms = 0.0
			is_playing = false

	emit_signal("time_changed", playback_time_ms)
	
func get_frame_pair(frames: Array, time_ms: float):
	if frames.size() == 0:
		return [null, null, 0.0]

	for i in range(frames.size() - 1):
		var a = frames[i]
		var b = frames[i + 1]

		if a["time_ms"] <= time_ms and b["time_ms"] >= time_ms:
			var span = b["time_ms"] - a["time_ms"]
			var t = 0.0 if span == 0 else (time_ms - a["time_ms"]) / span
			return [a, b, t]

	# fallback (end)
	return [frames[-1], frames[-1], 0.0]
	
func load_csv(path: String) -> void:
	frames_by_player.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		AppLogger.err("Failed to open CSV file")
		return
		
	var settings = file.get_line().strip_edges()
	load_settings(settings)

	file.get_line() # discard header

	while file.get_position() < file.get_length():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue

		var cols := line.split(",")

		var player_id := cols[0].to_int() - 1

		if not frames_by_player.has(player_id):
			frames_by_player[player_id] = []

		var frame := {
			"time_ms": cols[1].to_int(),

			"head_pos": Vector3(cols[2].to_float(), cols[3].to_float(), cols[4].to_float()),
			"head_dir": Vector3(cols[5].to_float(), cols[6].to_float(), cols[7].to_float()),

			"l_pos": Vector3(cols[8].to_float(), cols[9].to_float(), cols[10].to_float()),
			"l_dir": Vector3(cols[11].to_float(), cols[12].to_float(), cols[13].to_float()),

			"r_pos": Vector3(cols[14].to_float(), cols[15].to_float(), cols[16].to_float()),
			"r_dir": Vector3(cols[17].to_float(), cols[18].to_float(), cols[19].to_float()),

			"body_pos": Vector3(cols[20].to_float(), cols[21].to_float(), cols[22].to_float()),
			"body_dir": Vector3(cols[23].to_float(), cols[24].to_float(), cols[25].to_float()),
			
			"lfoot_pos": Vector3(cols[26].to_float(), cols[27].to_float(), cols[28].to_float()),
			"lfoot_dir": Vector3(cols[29].to_float(), cols[30].to_float(), cols[31].to_float()),
			
			"rfoot_pos": Vector3(cols[32].to_float(), cols[33].to_float(), cols[34].to_float()),
			"rfoot_dir": Vector3(cols[35].to_float(), cols[36].to_float(), cols[37].to_float()),

			"is_falling": cols[38].to_int(), "fog_enabled": cols[39].to_int()
		}

		frames_by_player[player_id].append(frame)

	duration_ms = 0.0
	for p in frames_by_player.keys():
		var arr = frames_by_player[p]
		if arr.size() == 0:
			continue
		
		duration_ms = max(duration_ms, arr[-1]["time_ms"])
		var start_time = arr[0]["time_ms"]

		for f in arr:
			f["time_ms"] -= start_time
			
	if Global.replay_ui:
		Global.replay_ui.refresh()
		
		

func load_settings(line: String):
	var cols := line.split(",")

	Global.selected_level = cols[0]
	Global.level = cols[1]
	Global._height = cols[2].to_float()
	Global._width = cols[3].to_float()
	Global._distance = cols[4].to_float()
	
func seek(time_ms: float) -> void:
	playback_time_ms = clamp(time_ms, 0.0, duration_ms)
	emit_signal("time_changed", playback_time_ms)
	

func play() -> void:
	if not is_playing:
		_last_tick_ms = Time.get_ticks_msec()
		is_playing = true

func pause() -> void:
	is_playing = false

func stop() -> void:
	is_playing = false
	playback_time_ms = 0.0

func toggle_play() -> void:
	is_playing = !is_playing

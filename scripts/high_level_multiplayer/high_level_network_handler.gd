extends Node

var IP_ADDRESS: String
const PORT: int = 42069

const DISCOVERY_PORT: int = 42070
const SERVER_NAME := "MyGodotServer"
var SERVER_LOG_PATH := "user://tracking_data.csv"
var file_path := ""

var peer: ENetMultiplayerPeer

var discovery_udp := PacketPeerUDP.new()
var discovery_timer := Timer.new()
var discovered_servers := {}

var last_heartbeat := {}
const HEARTBEAT_TIMEOUT := 3000
var heartbeat_active := false
var last_server_packet := 0

var reconnect_timer : Timer
var reconnect_attempts := 0
const MAX_RECONNECT_ATTEMPTS := 10
const RECONNECT_DELAY := 2.0
var reconnecting := false

var baseline_duration_ms: int = 0
var baseline_start_time_ms: int = 0
var baseline_timeout_fired := false

var baseline_running := false
var baseline_paused := false
var baseline_pause_time_ms := 0
var intentional_disconnect := false
var quit_flag := false

# Client readiness
var _sent_ready := false
var _ready_acknowledged := false
var _ready_retry_timer: Timer

# Server state
var player_slots: Dictionary = {} # peer_id -> int
var clients_ready: Dictionary = {} # peer_id -> bool
var combined_file_path: String
var latest_samples := {} # peer_id -> Dictionary

var player_samples := {}        # peer_id -> Array of samples
var completed_uploads := {}     # peer_id -> bool
var completed_counter : int = 0

const SAMPLE_CHUNK_SIZE := 200

# Client state
var player_1_fog_state : bool = false
var player_2_fog_state : bool = false



func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	reconnect_timer = Timer.new()
	reconnect_timer.wait_time = RECONNECT_DELAY
	reconnect_timer.one_shot = false
	reconnect_timer.timeout.connect(_attempt_reconnect)
	add_child(reconnect_timer)
	
	_ready_retry_timer = Timer.new()
	_ready_retry_timer.wait_time = 1.5
	_ready_retry_timer.one_shot = false
	_ready_retry_timer.timeout.connect(_retry_client_ready)
	add_child(_ready_retry_timer)
	
func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
			return
			
	if !multiplayer.is_server():
			
		if !multiplayer.has_multiplayer_peer():
			return
			
		if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return
			
		if !heartbeat_active:
			return
		
		if Time.get_ticks_msec() - last_server_packet > 6000:
			AppLogger.err("Lost connection to server")
			multiplayer.multiplayer_peer.close()
			
		if multiplayer.has_multiplayer_peer():
			rpc_id(1, "heartbeat")
		return
		
	var now = Time.get_ticks_msec()

	for id in last_heartbeat.keys():
		if now - last_heartbeat[id] > HEARTBEAT_TIMEOUT:
			AppLogger.warn("Peer timed out: " + str(id))
			
			var player_slot := -1

			if player_slots.has(1) and player_slots[1] == id:
				player_slot = 1
			elif player_slots.has(2) and player_slots[2] == id:
				player_slot = 2

			if player_slot != -1 and Global.spectator:
				Global.spectator.buffer_player(player_slot)
			
			last_heartbeat.erase(id)
			multiplayer.multiplayer_peer.disconnect_peer(id)
			
	if multiplayer.is_server() and baseline_running and !baseline_paused:
		if !baseline_timeout_fired and get_baseline_remaining_ms() <= 0:
			
			baseline_timeout_fired = true
			
			_on_baseline_timeout()

# --------------------------------------------------------------------
# Server start / discovery
# --------------------------------------------------------------------

func start_server(level : String) -> void:
	Global.scene_loader.switch_scene(level)
	await get_tree().process_frame
	await get_tree().physics_frame
	
	
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 2)
	if err != OK:
		AppLogger.err("[SERVER] Failed to start: " + str(err))
		return
		
	multiplayer.multiplayer_peer = peer
	
	AppLogger.log("[SERVER] Started on port " + str(PORT))
		

	#_start_lan_broadcast()
	#
#func _start_lan_broadcast():
	#discovery_udp.close()
	#discovery_udp.set_broadcast_enabled(true)
	#discovery_udp.connect_to_host("255.255.255.255", DISCOVERY_PORT)
#
	#discovery_timer.wait_time = 1.0
	#discovery_timer.one_shot = false
	#discovery_timer.timeout.connect(_broadcast_server)
	#add_child(discovery_timer)
	#discovery_timer.start()
#
	#Logger.log("[SERVER] LAN broadcast started")
	#
	#
#func _broadcast_server():
	#var msg := {
		#"name": SERVER_NAME,
		#"port": PORT
	#}
	#var json := JSON.stringify(msg)
	#discovery_udp.put_packet(json.to_utf8_buffer())
	
# --------------------------------------------------------------------
# Client start / discovery
# --------------------------------------------------------------------
	
func start_client() -> void:
	_reset_client_join_state()

	peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
	AppLogger.log("[CLIENT] Connecting to server...")
	
func _start_reconnect():

	if reconnecting:
		return

	reconnecting = true
	reconnect_attempts = 0

	AppLogger.log("Starting reconnect attempts...")
	reconnect_timer.start()
	
func _attempt_reconnect():

	if reconnect_attempts >= MAX_RECONNECT_ATTEMPTS:
		AppLogger.err("Reconnect failed after max attempts")
		reconnect_timer.stop()
		reconnecting = false
		return

	reconnect_attempts += 1

	AppLogger.log("Reconnect attempt %d..." % reconnect_attempts)

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(IP_ADDRESS, PORT)

	if err != OK:
		AppLogger.err("Reconnect create_client failed")
		return

	multiplayer.multiplayer_peer = peer
	
@rpc("any_peer","unreliable")
func heartbeat():
	var id = multiplayer.get_remote_sender_id()
	last_heartbeat[id] = Time.get_ticks_msec()
	rpc_id(id, "heartbeat_ack")
	
@rpc("any_peer","unreliable")
func heartbeat_ack():
	last_server_packet = Time.get_ticks_msec()
	heartbeat_active = true

#func _listen_for_lan_servers():
	#discovery_udp.close()
	#discovery_udp.bind(DISCOVERY_PORT)
#
	#Logger.log("[CLIENT] Searching for LAN servers...")
#
			#
#func _process(_delta):
	#if discovery_udp.get_available_packet_count() > 0:
		#var packet = discovery_udp.get_packet()
		#var data = packet.get_string_from_utf8()
#
		#var json = JSON.parse_string(data)
		#if typeof(json) == TYPE_DICTIONARY:
			#var ip = discovery_udp.get_packet_ip()
			#discovered_servers[ip] = json
#
			#Logger.log("[CLIENT] Found server at " + ip)
#
			#_connect_to_discovered_server(ip)
			#
		#
#
#func _connect_to_discovered_server(ip: String):
	#discovery_udp.close()
#
	#peer = ENetMultiplayerPeer.new()
	#peer.create_client(ip, PORT)
	#multiplayer.multiplayer_peer = peer
#
	#Logger.log("[CLIENT] Connecting to discovered server at " + ip)
	#
# --------------------------------------------------------------------
# Data tracking 
# --------------------------------------------------------------------	
	
func _init_combined_csv():
	if !multiplayer.is_server():
		return

	if !_ensure_directory(SERVER_LOG_PATH):
		AppLogger.err("Failed to create log directory")
		return

	var filename := "combined_%s.csv" % _generate_run_filename()
	combined_file_path = join_path(SERVER_LOG_PATH, filename)

	var file := FileAccess.open(combined_file_path, FileAccess.WRITE)
	
	file.store_line(Global.selected_level + "," +
		Global.level + "," + str(Global._height) + "," + str(Global._width) + "," + str(Global._distance)) 

	file.store_line(",".join([
		"player",
		"time_ms",

		"head_px","head_py","head_pz",
		"head_dx","head_dy","head_dz",

		"l_px","l_py","l_pz",
		"l_dx","l_dy","l_dz",

		"r_px","r_py","r_pz",
		"r_dx","r_dy","r_dz",

		"body_est_px","body_est_py","body_est_pz",
		"body_est_dx","body_est_dy","body_est_dz",
		
		"lfoot_est_px","lfoot_est_py","lfoot_est_pz",
		"lfoot_est_dx","lfoot_est_dy","lfoot_est_dz",
		
		"rfoot_est_px","rfoot_est_py","rfoot_est_pz",
		"rfoot_est_dx","rfoot_est_dy","rfoot_est_dz",

		"is_falling", "fog_enabled"
	]))

	file.close()
	
func join_path(base: String, dir_name: String) -> String:
	if base.ends_with("/"):
		return base + dir_name
	return base + "/" + dir_name

	
func _generate_run_filename() -> String:
	var t := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d" % [
		t.year, t.month, t.day,
		t.hour, t.minute, t.second
	]
	var suffix := str(randi() % 100000)
	return "run_%s_%s" % [stamp, suffix]
	
func _ensure_directory(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir != null:
		return true  # already exists

	var parent := path.get_base_dir()
	var dir_name := path.get_file()

	if parent == "" or dir_name == "":
		AppLogger.err("Invalid directory path: " + path)
		return false

	if !_ensure_directory(parent):
		return false

	var parent_dir := DirAccess.open(parent)
	if parent_dir == null:
		AppLogger.err("Cannot open parent directory: " + parent)
		return false

	parent_dir.make_dir(dir_name)
	return true
	
func switch_experiment():
	if Global.experiment_started:
		server_stop_experiment()
	else:
		server_start_experiment(Global.SAMPLE_FREQUENCY_HZ)
		
		
func server_start_experiment(frequency_hz: float):
	if !multiplayer.is_server():
		return
		
		
	Global.experiment_start_time = Time.get_ticks_msec()
	Global.experiment_started = true
	#experiment start
	AcqknowledgeConnector.send_marker("01")
	
	_init_combined_csv()
	
	rpc("_start_experiment", frequency_hz)
	
@rpc("any_peer", "reliable")
func _start_experiment(frequency_hz: float):
	AppLogger.log("Experiment started for peer: " + str(multiplayer.get_unique_id()))
	if !multiplayer.is_server():
		Global.start_experiment(frequency_hz)
		
func server_stop_experiment():
	if !multiplayer.is_server():
		return	
		
	Global.experiment_started = false
	
	#experimment stopped
	AcqknowledgeConnector.send_marker("02")
	rpc("_stop_experiment")
	
@rpc("any_peer", "reliable")
func _stop_experiment():
	AppLogger.log("Experiment stopped for peer: " + str(multiplayer.get_unique_id()))
	if !multiplayer.is_server():
		Global.stop_experiment()

func _send_samples_to_server():
	var index := 0
	while index < Global.local_samples.size():
		var chunk := Global.local_samples.slice(index, index + SAMPLE_CHUNK_SIZE)
		rpc_id(1, "submit_tracking_chunk", chunk)
		index += SAMPLE_CHUNK_SIZE
		
	rpc_id(1, "submit_tracking_complete")
	
func send_samples_from_disk(sample_file_path: String):
	var file := FileAccess.open(sample_file_path, FileAccess.READ)
	if file == null:
		return

	var chunk := []
	while !file.eof_reached():
		var line = file.get_line()
		chunk.append(Array(line.split(",")))

		if chunk.size() >= SAMPLE_CHUNK_SIZE:
			rpc_id(1, "submit_tracking_chunk", chunk)
			chunk.clear()

	# send remaining
	if chunk.size() > 0:
		rpc_id(1, "submit_tracking_chunk", chunk)

	rpc_id(1, "submit_tracking_complete")
	file.close()
	
	
@rpc("any_peer", "reliable")
func submit_tracking_chunk(samples: Array):
	if !multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	
	if !player_samples.has(peer_id):
		player_samples[peer_id] = []

	player_samples[peer_id].append_array(samples)
		
@rpc("any_peer", "reliable")
func submit_tracking_complete():
	if !multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	completed_uploads[peer_id] = true

	AppLogger.log("Completed upload for peer %d" % peer_id)

	# Wait until both players finished
	#if completed_uploads.size() < 2:
		#return

	completed_counter += 1
	_write_combined_dataset()
	

func _write_combined_dataset():

	if player_samples.is_empty():
		return

	var file := FileAccess.open(combined_file_path, FileAccess.READ_WRITE)
	file.seek_end()

	for peer_id in player_samples.keys():

		var rows = player_samples[peer_id]

		for row in rows:
			file.store_line(",".join(row.map(func(v): return str(v))))

	file.close()
	
	AppLogger.log("Finished writing")

	player_samples.clear()
	completed_uploads.clear()
	
	if completed_counter >= 2: 
		if baseline_timeout_fired:
			_finished_baseline_write()
		elif quit_flag:
			leave_session()

		

# --------------------------------------------------------------------
# Join state helpers
# --------------------------------------------------------------------

func _reset_client_join_state():
	intentional_disconnect = false
	_sent_ready = false
	_ready_acknowledged = false
	_ready_retry_timer.stop()
	
func _reset_session_state():
	AppLogger.log("Resetting session state")

	player_slots.clear()
	clients_ready.clear()
	player_samples.clear()
	completed_uploads.clear()
	completed_counter = 0
	last_heartbeat.clear()

	_sent_ready = false
	_ready_acknowledged = false

	reconnecting = false
	reconnect_attempts = 0

	heartbeat_active = false
	last_server_packet = 0
	
# --------------------------------------------------------------------
# Avatar sync
# --------------------------------------------------------------------
	
func send_avatar_data(slot: int, data: Dictionary):
	if multiplayer.multiplayer_peer == null:
		return
		
	if !multiplayer.has_multiplayer_peer():
		return
	
	if !multiplayer.is_server():
		rpc("sync_avatar", slot, data)
		
@rpc("any_peer", "unreliable_ordered")
func sync_avatar(slot: int, data: Dictionary):	
	if !Global.avatar_1 or !Global.avatar_2:
		_spawn_fixed_avatars()
		AppLogger.log("One or more avatars not initialized")
		return

	if slot == 1:
		Global.avatar_1.visible = true
		Global.avatar_1.apply_avatar_sync_data(data)
	else:
		Global.avatar_2.visible = true
		Global.avatar_2.apply_avatar_sync_data(data)

	if data.has("hand_item"):
		Global.set_hand_item(slot, data["hand_item"])
	else:
		Global.remove_hand_item(slot)
		
			
func _spawn_fixed_avatars():
	Global.spawner.spawn_server_player(1, 1)
	Global.spawner.spawn_server_player(2, 2)
	
func send_disconnect_avatar(slot: int):
	if multiplayer.multiplayer_peer == null:
		return
		
	if !multiplayer.has_multiplayer_peer():
		return
	
	if !multiplayer.is_server():
		rpc("_disconnect_avatar", slot)
	
@rpc("any_peer", "reliable")
func _disconnect_avatar(slot: int):
	if slot == 1:
		Global.avatar_1.visible = false
	else:
		Global.avatar_2.visible = false
		

func _send_marker_to_acqknowledge(message : String):
	if !multiplayer.is_server():
		return
	
	rpc_id(1, "acqknowledge_marker", message)
	
@rpc("any_peer", "reliable")	
func acqknowledge_marker(message : String):
	AcqknowledgeConnector.send_marker(message)
	
# --------------------------------------------------------------------
# Client initialization handshake
# --------------------------------------------------------------------

@rpc("any_peer", "reliable")
func client_initialized(peer_id: int):
	if !multiplayer.is_server():
		return

	#Logger.log("[SERVER] Client initialized: " + str(peer_id))
	
	rpc_id(peer_id, "sync_globals", Global.get_sync_data())
		
# --------------------------------------------------------------------
# Global + level sync (client)
# --------------------------------------------------------------------	

@rpc("any_peer", "call_local", "reliable")
func sync_globals(data: Dictionary):
	#Logger.log("[CLIENT] Received global sync: " + str(data))

	for k in data.keys():
		Global.set(k, data[k])
		
	Global.save_all()
	_start_ready_retry()
		
@rpc("any_peer", "call_local", "reliable")
func _do_load_level(level_path: String):
	#Logger.log("[CLIENT] Loading level: " + level_path)
	Global.scene_loader.switch_scene(level_path)
	if !Global.player:
		var player_scene := load("res://scenes/players/player.tscn")
		var player_instance = player_scene.instantiate()
		player_instance.name = str(multiplayer.get_unique_id())
		get_tree().current_scene.add_child(player_instance)
	else:
		Global.player.global_transform.origin.y += 0.3

	# WAIT 1 FRAME so the scene actually exists
	await get_tree().process_frame
	await get_tree().physics_frame
	
	if Global.player_slot == 1:
		Global.player.enable_firework()
	else:
		Global.player.enable_fuse()
	
	rpc_id(1, "client_loaded_level", Global.player_slot)
	
@rpc("any_peer", "reliable")
func client_loaded_level(slot : int):
	var peer_id = multiplayer.get_remote_sender_id()
	
	if slot <= 0:
		AppLogger.log("Unkown peer loaded level")
	
	#Global.spawner.spawn_server_player(peer_id, slot)

	rpc_id(peer_id, "spawn_local_player", peer_id, 3 - slot)


# --------------------------------------------------------------------
# Client ready logic
# --------------------------------------------------------------------

func _start_ready_retry():
	if _sent_ready:
		return

	_sent_ready = true
	_ready_retry_timer.start()
	_retry_client_ready()
	
func _retry_client_ready():
	if multiplayer.is_server():
		return
		
	if _ready_acknowledged:
		_ready_retry_timer.stop()
		return

	rpc_id(1, "client_ready", multiplayer.get_unique_id(), Global.player_slot)
	
@rpc("any_peer", "reliable")
func client_ready(peer_id: int, slot: int):
	if !multiplayer.is_server():
		return

	if peer_id in clients_ready:
		return

	AppLogger.log("[SERVER] Client " + str(peer_id) + " is ready in slot: " + str(slot))

	if slot != 1 and slot != 2:
		AppLogger.err("Invalid slot requested: " + str(slot))
		return

	player_slots[slot] = peer_id
	clients_ready[peer_id] = true

	Global.spectator.connect_player(slot)

	rpc_id(peer_id, "ready_ack")
		

	if clients_ready.size() < multiplayer.get_peers().size():
		return
		
	server_calibrate()
	
	# Tell ONLY this client to load the level
	if Global.selected_level != "":
		rpc_id(peer_id, "_do_load_level", Global.selected_level)

		
@rpc("any_peer", "reliable")
func ready_ack():
	_ready_acknowledged = true
	_ready_retry_timer.stop()
	Global.player.enable_fog()
	AppLogger.log("[CLIENT] Ready acknowledged by server")
		
@rpc("any_peer", "reliable")
func spawn_local_player(peer_id: int, slot: int):
	Global.spawner.spawn_server_player(peer_id, slot)
	
# -------------------------
#   Player control
# -------------------------
func fog_ack(slot: int, state:bool):
	rpc_id(1, "set_server_fog_state", slot, state)

@rpc("any_peer", "reliable")
func set_server_fog_state(slot:int, state:bool):
	if slot == 1:
		player_1_fog_state = state
		if state:
			AcqknowledgeConnector.send_marker("13")
		else:
			AcqknowledgeConnector.send_marker("14")
	else:
		player_2_fog_state = state
		if state:
			AcqknowledgeConnector.send_marker("23")
		else:
			AcqknowledgeConnector.send_marker("24")
		
	Global.spectator.update_fog_ui()

@rpc("any_peer", "reliable")
func set_player_fog(slot:int, enabled:bool):

	if Global.player and Global.player_slot == slot:
		if enabled:
			Global.player.enable_fog()
		else:
			Global.player.disable_fog()

func server_set_fog(slot:int, enabled:bool):
	if !multiplayer.is_server():
		return
		
	rpc("set_player_fog", slot, enabled)
	
@rpc("any_peer", "reliable")
func teleport_player(slot:int):
	if Global.player and Global.player_slot == slot:
		Global.player.teleport_to_spawn()
		
func server_teleport_player(slot:int):
	if !multiplayer.is_server():
		return
		
	rpc("teleport_player", slot)
	
@rpc("any_peer", "reliable")
func rotate_player(slot:int):
	if Global.player and Global.player_slot == slot:
		Global.player.rotate_player()
		
func server_rotate_player(slot:int):
	if !multiplayer.is_server():
		return
		
	rpc("rotate_player", slot)
	
func server_calibrate():
	if !multiplayer.is_server():
		return

	rpc("calibrate")
	
@rpc("any_peer", "call_local", "reliable")
func calibrate():
	if multiplayer.is_server():
		return
		
	if Global.main:
		#Global.player.calibrate_player_orientation()
		if Global.calibration:
			return
		var success = Global.calibrate_roomscale_full()
	
		if not success:
			AppLogger.err("Calibration failed")
			return
			
		Global.main.world.global_transform = Global.tracking_to_world(Global.main.world.global_transform)
	
# -------------------------
#   BASELINE TIMERS
# -------------------------
func server_start_or_resume_baseline(new_duration_ms: int):
	if !multiplayer.is_server():
		return
	
	var now = Time.get_ticks_msec()
	baseline_timeout_fired = false

	# If duration changed → RESET timer
	if baseline_duration_ms != new_duration_ms:
		baseline_duration_ms = new_duration_ms
		baseline_start_time_ms = now
		baseline_running = true
		baseline_paused = false
			
	# If paused → RESUME
	elif baseline_paused:
		var paused_duration = now - baseline_pause_time_ms
		baseline_start_time_ms += paused_duration
		
		baseline_paused = false
		baseline_running = true
		
		AppLogger.log("Baseline timer RESUMED")
	
	# If already running → do nothing
	else:
		AppLogger.log("Baseline already running")
		return

func get_baseline_remaining_ms() -> int:
	if !baseline_running:
		return 0
	
	var now = Time.get_ticks_msec()
	
	var elapsed: int
	
	if baseline_paused:
		elapsed = baseline_pause_time_ms - baseline_start_time_ms
	else:
		elapsed = now - baseline_start_time_ms
	
	var remaining = baseline_duration_ms - elapsed
	return max(remaining, 0)

func server_pause_baseline():
	if !multiplayer.is_server():
		return
	
	if !baseline_running or baseline_paused:
		return
	
	baseline_paused = true
	baseline_pause_time_ms = Time.get_ticks_msec()
	baseline_timeout_fired = false
	

func server_stop_baseline():
	if !multiplayer.is_server():
		return
	
	baseline_running = false
	baseline_paused = false
	baseline_timeout_fired = false
	baseline_duration_ms = 0
	baseline_start_time_ms = 0

func _on_baseline_timeout():
	if !multiplayer.is_server():
		return
		
	if Global.experiment_started:
		server_stop_experiment()
	else:
		leave_session()
		
	AppLogger.log("Baseline finished — returning players to menu")
	

func _finished_baseline_write():
	Global.remove_hand_item(1)
	Global.remove_hand_item(2)

	intentional_disconnect = true
	rpc("_end_session")
	#timer end
	AcqknowledgeConnector.send_marker("33")

	
	
func leave_session():
	if multiplayer.is_server():
		rpc("_end_session")
		
	_reset_session_state()
	
	if Global.spectator:
		Global.spectator.queue_free()
		Global.spectator = null
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	Global.remove_hand_item(1)
	Global.remove_hand_item(2)
		
	Global.scene_loader.switch_scene("res://scenes/levels/xr_menu_scene.tscn")
	

	
@rpc("any_peer", "reliable")
func _end_session():
	intentional_disconnect = true
	
	_reset_session_state()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		
	Global.remove_hand_item(1)
	Global.remove_hand_item(2)
	
	Global.player.disable_fog()
	Global.menu_manager.set_xr_viewport_visibility(true)

	Global.scene_loader.switch_scene("res://scenes/levels/xr_menu_scene.tscn")
	
func server_end_session():
	if !multiplayer.is_server():
		return
	
	AppLogger.log("Server ending session for all peers")

	intentional_disconnect = true
	
			
	if Global.experiment_started:
		baseline_timeout_fired = true
		quit_flag = true
		server_stop_experiment()
	else:
		leave_session()

# -------------------------
#   CALLBACKS
# -------------------------

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		AppLogger.log("Client joined: " + str(id))

func _on_connected_to_server():
	AppLogger.log("Client connected to server!")
	
	reconnecting = false
	reconnect_timer.stop()
	
	Global.id = multiplayer.get_unique_id()
	last_server_packet = Time.get_ticks_msec()
	
	_reset_client_join_state()
	
	if Global.finished_sending:
		Global.stop_experiment()
		
	Global.menu_manager.set_xr_viewport_visibility(false)
	Global.menu_manager.set_keyboard_visibility(false)
	
	rpc_id(1, "client_initialized", Global.id)


func _on_connection_failed():
	AppLogger.log("Connection failed!")
	
	if intentional_disconnect:
		intentional_disconnect = false
		return
	
	_start_reconnect()
	
	if Global.player:
		Global.menu_manager.set_xr_viewport_visibility(true)


func _on_server_disconnected():
	AppLogger.log("Disconnected from server!")
	
	if intentional_disconnect:
		AppLogger.log("Intentional disconnect — no reconnect")
		intentional_disconnect = false
		return
	
	_start_reconnect()
	
func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		AppLogger.log("Client disconnected: " + str(id))
			
		if player_slots[1] == id:
			player_slots.erase(1)
			if Global.spectator:
				Global.spectator.on_player_disconnected(1)
		elif player_slots[2] == id:
			player_slots.erase(2)
			if Global.spectator:
				Global.spectator.on_player_disconnected(2)
		else:
			AppLogger.warn("disconnected peer that was not registerd")
			
			clients_ready.erase(id)
			last_heartbeat.erase(id)


			
	

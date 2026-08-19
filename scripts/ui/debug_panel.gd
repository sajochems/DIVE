extends PanelContainer

@onready var property_container = $MarginContainer/HBoxContainer/PropertyContainer
@onready var logger_label: Label = $MarginContainer/HBoxContainer/ScrollContainer/LoggerLabel
@onready var logger_scroll: ScrollContainer = $MarginContainer/HBoxContainer/ScrollContainer

var frames_per_second : String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_multiplayer_authority():
		Global.debug = self
		AppLogger.log_added.connect(_on_log_added)
	
	visible = false
	
	
func _on_log_added(text: String) -> void:
	if !is_instance_valid(logger_label):
		return

	logger_label.text += text + "\n"

	# Auto-scroll to bottom
	await get_tree().process_frame
	logger_scroll.scroll_vertical = int(logger_scroll.get_v_scroll_bar().max_value)

	
func _process(delta: float) -> void:
	if visible:	
		# --- System Info ---
		Global.debug.add_header("=== System Info ===", 0)
		Global.debug.add_property("OS", OS.get_name(), 1)  
		# Operating system name (e.g. "Windows", "Linux", "Android", "Web").

		Global.debug.add_property("Device", OS.get_model_name(), 2)  
		# Device model (e.g. "Meta Quest 3", "Pixel 7").

		Global.debug.add_property("CPU", OS.get_processor_name(), 3)  
		# CPU name string (e.g. "Intel Core i7-12700H").

		Global.debug.add_property("GPU", RenderingServer.get_video_adapter_name(), 4)  
		# GPU name string (e.g. "NVIDIA GeForce RTX 3060").

		Global.debug.add_property("GPU Vendor", RenderingServer.get_video_adapter_vendor(), 5)  
		# GPU vendor string (e.g. "NVIDIA Corporation", "AMD", "Qualcomm").

		# --- Memory ---
		Global.debug.add_header("=== Memory ===", 6)
		var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024 * 1024) # MB
		var peak = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / (1024 * 1024)
		Global.debug.add_property("Memory (MB)", "%.2f / %.2f" % [mem, peak], 7)  
		# Current / peak memory usage by the engine in MB.
		# Expected good range: depends on target device.  
		#   - Mobile/VR: try to stay < 1000 MB.  
		#   - PC/Console: < 2000–4000 MB is usually safe.  
		# Spikes or continuous growth → possible memory leaks.

		# --- Performance ---
		Global.debug.add_header("=== Performance ===", 8)
		frames_per_second = "%.2f" % (1.0/delta)
		Global.debug.add_property("FPS", frames_per_second, 9)  
		# Should be stable (60+ for most games, 72/90/120+ for VR).

		Global.debug.add_property("FPS (Engine)", Performance.get_monitor(Performance.TIME_FPS), 10)  
		# FPS as measured by the engine (averaged).

		Global.debug.add_property("Process Time (ms)", "%.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0), 11)  
		# Average CPU time spent per frame in _process(), in milliseconds.
		# Expected good range: < 5 ms for smooth 60 FPS.  
		# If this rises > 16 ms → risk of frame drops.

		Global.debug.add_property("Physics Time (ms)", "%.2f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0), 12)  
		# Average CPU time spent in _physics_process(), in milliseconds.
		# Should be very low (< 2 ms typically).  
		# Spikes here indicate expensive physics calculations.

		Global.debug.add_property("Object Count", Performance.get_monitor(Performance.OBJECT_COUNT), 13)  
		# Total number of live engine objects (Nodes + Resources).

		Global.debug.add_property("Node Count", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), 14)  
		# Number of active nodes in the scene tree.

		#Global.debug.add_property("Orphan Nodes", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 15)  
		# Nodes that exist but are not attached to the scene tree.
		# Expected good value: 0.  
		# Non-zero means you forgot to free/remove nodes.

		# --- Rendering Stats ---
		Global.debug.add_header("=== Rendering ===", 16)
		Global.debug.add_property("Draw Calls", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), 17)  
		# Number of draw calls per frame.
		# Expected good range: < 2000 for mid/high-end PCs, < 1000 for mobile/VR.  

		Global.debug.add_property("Objects Drawn", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), 18)  
		# Number of renderable objects drawn each frame.
		# No fixed target, but fewer is better. Optimize instancing/batching if high.

		# --- Misc ---
		Global.debug.add_header("=== Misc ===", 19)
		Global.debug.add_property("Window Size", str(DisplayServer.window_get_size()), 20)  
		# Current window (or screen if fullscreen) resolution in pixels (width x height).	

		Global.debug.add_property("Uptime (s)", str(Time.get_ticks_msec() / 1000.0), 21)  
		# Time since the engine started running, in seconds.
		# Handy for long-session memory/performance testing.

		#Global.debug.add_property("Locale", OS.get_locale(), 21)  
		# Current locale string (e.g. "en_US").
		# Useful when testing localization and input.
		
		#Global.debug.add_property("Engine", str(Engine.get_version_info()), 23)  
		# Engine version info (dict with major/minor/patch/hash).
		# Useful to confirm which Godot build the game is running on.
		
func _activate_debug() -> void:
	visible = !visible
		
func add_property(title: String, value, order):
	var target = property_container.find_child(title, true, false)
	if !target:
		target = Label.new()
		property_container.add_child(target)
		target.name = title
	property_container.move_child(target, order)

	target.text = title + ": " + str(value)

	_apply_color_code(target, title, value)
	
func add_header(title: String, order: int):
	var target = property_container.find_child(title, true, false)
	if !target:
		target = Label.new()
		property_container.add_child(target)
		target.name = title
		target.text = title
		target.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)) 
		target.add_theme_font_size_override("font_size", 16)
		target.add_theme_font_override("font", get_theme_default_font()) 
		target.add_theme_constant_override("margin_top", 6) 
	property_container.move_child(target, order)

	
func _apply_color_code(label: Label, title: String, value) -> void:
	var col = Color(1, 1, 1) # default white

	# Detect if running on VR hardware
	#var is_vr = XRServer.is_initialized()
	var is_vr = true

	match title:
		"FPS", "FPS (Engine)":
			var fps = float(value)
			if is_vr:
				# VR: 72+ FPS is ideal
				if fps >= 72:
					col = Color(0.3, 1.0, 0.3) # green
				elif fps >= 60:
					col = Color(1.0, 1.0, 0.3) # yellow
				else:
					col = Color(1.0, 0.3, 0.3) # red
			else:
				# Non-VR thresholds
				if fps >= 60:
					col = Color(0.3, 1.0, 0.3)
				elif fps >= 30:
					col = Color(1.0, 1.0, 0.3)
				else:
					col = Color(1.0, 0.3, 0.3)

		"Process Time (ms)", "Physics Time (ms)":
			var ms = float(value)
			if is_vr:
				if ms <= 3.0:
					col = Color(0.3, 1.0, 0.3) # green
				elif ms <= 8.0:
					col = Color(1.0, 1.0, 0.3) # yellow
				else:
					col = Color(1.0, 0.3, 0.3) # red
			else:
				if ms <= 5.0:
					col = Color(0.3, 1.0, 0.3)
				elif ms <= 16.0:
					col = Color(1.0, 1.0, 0.3)
				else:
					col = Color(1.0, 0.3, 0.3)

		"Memory (MB)":
			var parts = str(value).split(" / ")
			if parts.size() >= 1:
				var mem = float(parts[0])
				if is_vr:
					if mem < 500: # VR devices have tighter memory limits
						col = Color(0.3, 1.0, 0.3)
					elif mem < 1000:
						col = Color(1.0, 1.0, 0.3)
					else:
						col = Color(1.0, 0.3, 0.3)
				else:
					if mem < 1000:
						col = Color(0.3, 1.0, 0.3)
					elif mem < 2000:
						col = Color(1.0, 1.0, 0.3)
					else:
						col = Color(1.0, 0.3, 0.3)

		"Draw Calls":
			var dc = int(value)
			if is_vr:
				if dc < 500:
					col = Color(0.3, 1.0, 0.3)
				elif dc < 1000:
					col = Color(1.0, 1.0, 0.3)
				else:
					col = Color(1.0, 0.3, 0.3)
			else:
				if dc < 1000:
					col = Color(0.3, 1.0, 0.3)
				elif dc < 2000:
					col = Color(1.0, 1.0, 0.3)
				else:
					col = Color(1.0, 0.3, 0.3)

		"Orphan Nodes":
			var orphans = int(value)
			if orphans == 0:
				col = Color(0.3, 1.0, 0.3)
			else:
				col = Color(1.0, 0.3, 0.3)

	# Apply the color
	label.add_theme_color_override("font_color", col)

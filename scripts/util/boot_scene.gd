extends Node

const XR_STARTUP_TIMEOUT := 2.0

var elapsed := 0.0
var xr_requested := false

func _ready():
	AppLogger.log("Boot: desktop rendering active")
	call_deferred("_begin_xr_detection")
	#get_viewport().use_xr = false
#
	#Global.xr_interface = XRServer.find_interface("OpenXR")
#
	#if Global.xr_interface and Global.xr_interface.is_initialized():
		#Logger.log("Boot: OpenXR runtime found, requesting session")
		#Global.xr_interface.start_session()
		#xr_requested = true
		#set_process(true)
	#else:
		#Global.xr_interface = null
		#Logger.log("Boot: No OpenXR runtime, loading PC mode")
		#_load_pc()
		
		
func _begin_xr_detection():
	# Wait one full frame to ensure SceneTree is running
	await get_tree().process_frame

	var xr_interface := XRServer.find_interface("OpenXR")

	if xr_interface and xr_interface.is_initialized():
		AppLogger.log("Boot: OpenXR runtime found, requesting XR")
		xr_interface.start_session()
		await _wait_for_hmd(xr_interface)
	else:
		_load_pc()
		
func _wait_for_hmd(xr_interface):
	var timeout := 2.0
	var elapsed := 0.0

	while elapsed < timeout:
		if XRServer.get_trackers(XRServer.TRACKER_HEAD).size() > 0:
			_enter_xr()
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_load_pc()



func _process(delta):
	if not xr_requested:
		return

	elapsed += delta

	if XRServer.get_trackers(XRServer.TRACKER_HEAD).size() > 0:
		AppLogger.log("Boot: XR session running")
		_enter_xr()
	elif elapsed >= XR_STARTUP_TIMEOUT:
		AppLogger.log("Boot: XR session failed, loading PC mode")
		_load_pc()


func _enter_xr():
	get_tree().change_scene_to_file("res://scenes/levels/xr_menu_scene.tscn")
	set_process(false)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().use_xr = true

	
	
func _load_pc():
	set_process(false)
	get_viewport().use_xr = false
	get_tree().change_scene_to_file("res://scenes/levels/host_menu_scene.tscn")

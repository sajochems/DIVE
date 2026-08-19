extends Control

signal back_pressed
signal level_selected(level_path: String)

#Global settings
@onready var local_ip_label: Label = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/LocalIP
@onready var ip_textedit: LineEdit = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/IPBox/IPAddressBox

@onready var fileloc_textedit: LineEdit = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/FileBox/FileLocationBox

@onready var frequency_box: SpinBox = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/SampleFrequencyHBoxContainer2/SampleFrequencySpinBox

@onready var select_level: MenuButton = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/HBoxContainer/SelectLevel
@onready var popup: PopupMenu = select_level.get_popup()

@onready var height_box: SpinBox = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/HeightRow/HeightBox
@onready var distance_box: SpinBox = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/DistanceRow/DistanceBox
@onready var distance_label: Label = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/DistanceLabel
@onready var width_box: SpinBox = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/WidthRow/WidthBox
@onready var platform_width_box: SpinBox = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/PlatformWidthRow/PlatformWidthBox

@onready var acq_ip_textedit: LineEdit = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/AcqknowledgeIP
@onready var acq_port_textedit: LineEdit = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/AcqknowledgePort
@onready var test_button: Button = $Panel/HBoxContainer/GlobalSettingsVBoxContainer/TestButton

#Buttons
@onready var host_baseline_button: Button = $Panel/HBoxContainer/ButtonsVBoxContainer/HostBaselineButton
@onready var host_button: Button = $Panel/HBoxContainer/ButtonsVBoxContainer/HostButton
@onready var reconstruction_button: Button = $Panel/HBoxContainer/ButtonsVBoxContainer/ReconstructionButton
@onready var back_button: Button = $Panel/HBoxContainer/ButtonsVBoxContainer/BackButton

#Player settings
@onready var player_selector : CheckButton = $Panel/HBoxContainer/PlayerSettingsVBoxContainer2/HBoxContainer/PlayerSelector
@onready var falling_dropdown : OptionButton = $Panel/HBoxContainer/PlayerSettingsVBoxContainer2/VBoxContainer/FallingDropdown
@onready var impact_dropdown : OptionButton = $Panel/HBoxContainer/PlayerSettingsVBoxContainer2/VBoxContainer/ImpactDropdown


# Level list (can come from menu_manager if preferred)
var level_paths := [
	"res://scenes/levels/city.tscn",
]

func _ready() -> void:
	Global.load_all()
	
	#Global settings
	local_ip_label.text = "Local ip address: " + get_local_ip()
	ip_textedit.text = HighLevelNetworkHandler.IP_ADDRESS
	ip_textedit.text_changed.connect(_on_ip_address_changed)
	
	fileloc_textedit.text = HighLevelNetworkHandler.SERVER_LOG_PATH
	fileloc_textedit.text_changed.connect(_on_fileloc_changed)
	
	frequency_box.value = Global.SAMPLE_FREQUENCY_HZ
	frequency_box.value_changed.connect(_on_sample_frequency_changed)
	
	_populate_level_menu()
	popup.id_pressed.connect(_on_level_chosen)
	
	height_box.value = Global._height
	height_box.value_changed.connect(_on_height_changed)
	
	distance_box.value = Global._distance
	distance_box.value_changed.connect(_on_distance_changed)
	
	distance_label.text = "This makes the distance between players: " + str(Global._distance + 1.5) + "m\n" + "and the length of the room boundary: " + str(Global._distance + 3.0)
	
	width_box.value = Global._width
	width_box.value_changed.connect(_on_width_changed)
	
	platform_width_box.value = Global._platform_width
	platform_width_box.value_changed.connect(_on_platform_width_changed)
	
	acq_ip_textedit.text = get_ip_from_url(Global.acqknowledge_url)
	acq_ip_textedit.text_changed.connect(_on_acq_ip_changed)
	
	acq_port_textedit.text = get_port_from_url(Global.acqknowledge_url)
	acq_port_textedit.text_changed.connect(_on_acq_port_changed)

	test_button.pressed.connect(_test_pressed)
	
	#Buttons
	host_baseline_button.pressed.connect(func(): Global.menu_manager._on_host_baseline_pressed())
	
	host_button.pressed.connect(func(): Global.menu_manager._on_host_pressed())
	
	reconstruction_button.pressed.connect(func(): Global.menu_manager._on_reconstruction_pressed())

	back_button.pressed.connect(func(): Global.menu_manager._on_back_pressed())
	
	#Player settings
	_populate_player_dropdown(
		falling_dropdown,
		FallEffectManager.FallStage.FALLING
	)

	_populate_player_dropdown(
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
	
	

func get_ip_from_url(url: String) -> String:
	if url == "" or !url:
		return ""
	
	var no_protocol = url.replace("http://", "")
	var ip = no_protocol.split(":")[0]
	
	return ip
	
func get_port_from_url(url: String) -> String:
	
	if url == "" or !url:
		return ""
	
	var no_protocol = url.replace("http://", "")
	var port_part = no_protocol.split(":")[1]
	var port = port_part.split("/")[0]
	
	return port

func get_local_ip() -> String:
	var ips = IP.get_local_addresses()
	for ip in ips:
		# pick a private LAN IP
		if ip.begins_with("192.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	# fallback: just return the first one
	return ips[0] if ips.size() > 0 else "Unknown"
	
func _on_ip_address_changed(value: String) -> void:
	HighLevelNetworkHandler.IP_ADDRESS = value
	Global.save_all()

# Parameter Updates
func _on_height_changed(value: float) -> void:
	Global._height = clamp(value, height_box.min_value, height_box.max_value)
	Global.save_all()

func _on_distance_changed(value: float) -> void:
	Global._distance = clamp(value, distance_box.min_value, distance_box.max_value)
	distance_label.text = "This makes the distance between players: " + str(Global._distance + 1.5) + "m\n" + "and the length of the room boundary: " + str(Global._distance + 3.0)
	Global.save_all()

func _on_width_changed(value: float) -> void:
	Global._width = clamp(value, width_box.min_value, width_box.max_value)
	Global.save_all()
	
func _on_platform_width_changed(value: float) -> void:
	Global._platform_width = clamp(value, platform_width_box.min_value, platform_width_box.max_value)
	Global.save_all()
	
func _on_fileloc_changed(value: String) -> void:
	HighLevelNetworkHandler.SERVER_LOG_PATH = value
	Global.save_all()
	
func _on_acq_ip_changed(value: String) -> void:
	var port = get_port_from_url(Global.acqknowledge_url)	
	Global.acqknowledge_url = build_rpc_url(value, port)
	Global.save_all()
	
func _on_acq_port_changed(value: String) -> void:
	var ip = get_ip_from_url(Global.acqknowledge_url)
	Global.acqknowledge_url = build_rpc_url(ip, value)
	Global.save_all()

func _on_sample_frequency_changed(value: float) -> void:
	Global.SAMPLE_FREQUENCY_HZ = clamp(value, frequency_box.min_value, frequency_box.max_value)
	Global.save_all()

# Level Dropdown
func _populate_level_menu() -> void:
	popup.clear()
	for path in level_paths:
		popup.add_item(path.get_file().get_basename())
	
	if Global.level != "":
		select_level.text = Global.level

func _on_level_chosen(id: int) -> void:
	Global.selected_level = level_paths[id]
	Global.level = level_paths[id].get_file().get_basename()
	select_level.text = Global.level

	AppLogger.log("chose level: " + level_paths[id])
	Global.save_all()
	
func build_rpc_url(ip: String, port: String) -> String:
	
	return "http://%s:%s/RPC2" % [ip, port]

func _test_pressed():
	AcqknowledgeConnector.send_marker("00")
	AppLogger.log("Send marker to acqknowledge")
	
	
#Player settings	
func _populate_player_dropdown(dropdown: OptionButton, stage: int):
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

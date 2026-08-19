extends Node3D

@export var top_view_textures: Array[Texture2D]
@export var ground_view_textures: Array[Texture2D]
@export var switch_height: float = 30.0
@export var fully_face_camera: bool = false

# Child quad nodes (must be MeshInstance3D)
@export var top_quad_path: NodePath
@export var ground_quad_path: NodePath

var cam: Camera3D
var top_quad: MeshInstance3D
var ground_quad: MeshInstance3D

func _ready():
	if !is_multiplayer_authority():
		return	
		
	cam = get_viewport().get_camera_3d()
	if cam == null:
		await get_tree().process_frame
		cam = get_viewport().get_camera_3d()

	top_quad = get_node(top_quad_path) as MeshInstance3D
	ground_quad = get_node(ground_quad_path) as MeshInstance3D

func _process(_delta):
	if cam == null or top_quad == null or ground_quad == null:
		return

	var cam_pos = cam.global_position
	var dir = (cam_pos - global_position).normalized()

	var use_top = cam_pos.y > switch_height

	# Show only the correct quad
	#top_quad.visible = use_top
	#ground_quad.visible = not use_top

	# --- Rotate tree around Y for proper texture frame ---
	var angle = atan2(-dir.x, -dir.z)
	var slice = TAU / float(ground_view_textures.size())
	var index = int(round(angle / slice)) % ground_view_textures.size()

	var mat: StandardMaterial3D
	if use_top:
		mat = top_quad.material_override as StandardMaterial3D
		if mat:
			mat.albedo_texture = top_view_textures[index]
	else:
		mat = ground_quad.material_override as StandardMaterial3D
		if mat:
			mat.albedo_texture = ground_view_textures[index]

	# --- Optional: face camera horizontally (Y-axis only) ---
	if fully_face_camera:
		look_at(cam_pos, Vector3.UP)
	else:
		var flat_dir = Vector3(dir.x, 0, dir.z).normalized()
		look_at(global_position - flat_dir, Vector3.UP)

extends Node3D

@export var output_dir: String = "res://billboards/"
@export var num_views: int = 4
@export var image_size: Vector2i = Vector2i(1024, 1024)
@export var target_node_path: NodePath
@export var camera_path: NodePath
@export var viewport_path: NodePath

# Desired camera positions
@export var high_camera_pos: Vector3 = Vector3(0, 75, 6)
@export var low_camera_pos: Vector3 = Vector3(0, 1.8, 6)

# Optional explicit look target (e.g. tree base)
@export var explicit_look_target: Vector3 = Vector3.ZERO
@export var use_explicit_look_target: bool = false

# >1.0 = more padding around object
@export var framing_margin: float = 5

var cam: Camera3D
var vp: SubViewport
var target: Node3D


func _ready():
	cam = get_node_or_null(camera_path)
	vp = get_node_or_null(viewport_path)
	target = get_node_or_null(target_node_path)

	if not cam or not vp or not target:
		AppLogger.err("❌ BillboardBaker: Missing camera, viewport, or target node!")
		return

	vp.size = image_size
	vp.transparent_bg = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true

	await get_tree().process_frame
	await get_tree().process_frame

	await bake_all()


# --- MAIN ENTRY ---
func bake_all() -> void:
	AppLogger.log("📷 Baking HIGH camera views...")
	await bake_height_set(high_camera_pos, "top")

	AppLogger.log("📷 Baking LOW camera views...")
	await bake_height_set(low_camera_pos, "low")

	AppLogger.log("✅ Finished baking all billboards to " + output_dir)


# --- BAKE ONE CAMERA HEIGHT SET ---
func bake_height_set(initial_cam_pos: Vector3, suffix: String) -> void:
	var folder := output_dir.rstrip("/") + "/" + suffix + "/"
	if DirAccess.open(folder) == null:
		DirAccess.make_dir_recursive_absolute(folder)

	var look_target_pos :=  target.global_position
	if use_explicit_look_target: 
		look_target_pos = explicit_look_target
	cam.global_position = initial_cam_pos
	cam.look_at(look_target_pos, Vector3.UP)

	for i in range(num_views):
		var angle_deg = i * 360.0 / num_views
		target.rotation_degrees = Vector3(0, angle_deg, 0)

		await get_tree().process_frame
		await get_tree().process_frame

		var aabb := compute_combined_aabb(target)
		if aabb.size == Vector3.ZERO:
			aabb = AABB(target.global_position - Vector3.ONE * 0.5, Vector3.ONE)

		var center := aabb.position + aabb.size * 0.5
		var radius = max(aabb.size.x, aabb.size.y, aabb.size.z) * 0.5
		if radius <= 0.001:
			radius = 1.0

		var fov_rad := deg_to_rad(cam.fov)
		var dist = (radius / tan(fov_rad * 0.5)) * framing_margin

		var view_dir := (initial_cam_pos - look_target_pos).normalized()
		if view_dir.length() < 0.001:
			view_dir = -cam.global_transform.basis.z.normalized()

		cam.global_position = center + view_dir * dist
		cam.look_at(center, Vector3.UP)

		await get_tree().process_frame
		await get_tree().process_frame

		var tex := vp.get_texture()
		if tex:
			var img := tex.get_image()
			# img.flip_y()  # uncomment if images appear upside-down
			var filename := "%sbillboard_%s_%02d.png" % [folder, suffix, i]
			var err := img.save_png(filename)
			if err == OK:
				AppLogger.log("Saved " + filename)
			else:
				AppLogger.err("❌ Save failed: %s (err=%s)" % [filename, err])
		else:
			AppLogger.err("⚠️ No texture captured for frame %d" % i)


# --- RECURSIVE AABB CALCULATION ---
func compute_combined_aabb(root: Node3D) -> AABB:
	var INF := 1e10
	var minp := Vector3(INF, INF, INF)
	var maxp := Vector3(-INF, -INF, -INF)
	var found_any := false

	_collect_aabb_recursive(root, minp, maxp, found_any)

	if not found_any:
		return AABB(root.global_position - Vector3.ONE * 0.5, Vector3.ONE)

	return AABB(minp, maxp - minp)


func _collect_aabb_recursive(n: Node, minp: Vector3, maxp: Vector3, found_any: bool) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var local_aabb: AABB = mi.mesh.get_aabb()
			for corner in _aabb_corners(local_aabb):
				var world_pt = mi.basis * corner
				minp.x = min(minp.x, world_pt.x)
				minp.y = min(minp.y, world_pt.y)
				minp.z = min(minp.z, world_pt.z)
				maxp.x = max(maxp.x, world_pt.x)
				maxp.y = max(maxp.y, world_pt.y)
				maxp.z = max(maxp.z, world_pt.z)
				found_any = true

	for child in n.get_children():
		if child is Node3D:
			_collect_aabb_recursive(child, minp, maxp, found_any)


func _aabb_corners(aabb: AABB) -> Array:
	var p := aabb.position
	var s := aabb.size
	return [
		Vector3(p.x,        p.y,        p.z),
		Vector3(p.x + s.x,  p.y,        p.z),
		Vector3(p.x,        p.y + s.y,  p.z),
		Vector3(p.x,        p.y,        p.z + s.z),
		Vector3(p.x + s.x,  p.y + s.y,  p.z),
		Vector3(p.x + s.x,  p.y,        p.z + s.z),
		Vector3(p.x,        p.y + s.y,  p.z + s.z),
		Vector3(p.x + s.x,  p.y + s.y,  p.z + s.z)
	]

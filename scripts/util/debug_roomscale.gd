extends Node3D

var line_material: StandardMaterial3D

var squares_drawn := false

func _ready():
	Global.debug_calibration = self
	
	line_material = StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func draw_roomscale_debug(points: PackedVector3Array, center: Vector3, draw_basis: Basis):
	clear()

	_draw_boundary(points)
	_draw_axes(center, draw_basis)
	_draw_center(center)

# -------------------------
# CLEAR OLD DEBUG
# -------------------------
func clear():
	for c in get_children():
		c.queue_free()

# -------------------------
# DRAW BOUNDARY
# -------------------------
func _draw_boundary(points: PackedVector3Array):
	if points.size() < 2:
		return

	for i in points.size():
		var a = points[i]
		var b = points[(i + 1) % points.size()]

		_draw_line(a, b, Color.GREEN)

# -------------------------
# DRAW PCA AXES
# -------------------------
func _draw_axes(center: Vector3, draw_basis: Basis):
	var draw_scale := 2.0  # axis length in meters

	var z_axis = draw_basis.z * draw_scale
	var x_axis = draw_basis.x * draw_scale

	# Z axis (forward / long side)
	_draw_line(center, center + z_axis, Color.RED)

	# X axis (sideways)
	_draw_line(center, center + x_axis, Color.BLUE)

# -------------------------
# DRAW CENTER
# -------------------------
func _draw_center(center: Vector3):
	var mesh := SphereMesh.new()
	mesh.radius = 0.05

	var mi := MeshInstance3D.new()
	mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mi.material_override = mat
	mi.global_position = center

	add_child(mi)

# -------------------------
# DRAW LINE HELPER
# -------------------------
func _draw_line(a: Vector3, b: Vector3, color: Color):
	var mesh := ImmediateMesh.new()

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)

	mesh.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh

	var mat := line_material.duplicate()
	mat.albedo_color = color
	mi.material_override = mat

	add_child(mi)
	
# -------------------------
# DRAW squares
# -------------------------	
func _draw_end_squares(points: PackedVector3Array, center: Vector3, draw_basis: Basis):
	if points.is_empty():
		return
		
	#draw_roomscale_debug(points, center, draw_basis)

	var z_dir := draw_basis.z.normalized()

	var min_proj := INF
	var max_proj := -INF

	# Find furthest points along local Z axis
	for p in points:
		var proj := (p - center).dot(z_dir)

		min_proj = min(min_proj, proj)
		max_proj = max(max_proj, proj)

	var min_pos := center + z_dir * min_proj
	var max_pos := center + z_dir * max_proj
	
	min_pos.y += 0.3
	max_pos.y += 0.3

	# Draw 1x1m squares
	_draw_square(min_pos, draw_basis, 1.0, Color.DARK_RED)
	_draw_square(max_pos, draw_basis, 1.0, Color.DARK_RED)
	
	squares_drawn = true
	
func _draw_square(pos: Vector3, basis: Basis, size: float, color: Color):
	var half := size * 0.5

	var x := basis.x.normalized() * half
	var z := basis.z.normalized() * half

	var p1 := pos - x - z
	var p2 := pos + x - z
	var p3 := pos + x + z
	var p4 := pos - x + z

	_draw_line(p1, p2, color)
	_draw_line(p2, p3, color)
	_draw_line(p3, p4, color)
	_draw_line(p4, p1, color)

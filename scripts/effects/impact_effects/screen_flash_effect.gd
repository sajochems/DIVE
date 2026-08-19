extends FallEffect

const FLASH_DURATION := 5.5

var active := false
var elapsed := 0.0

var flash_mesh : MeshInstance3D
var material : ShaderMaterial

func start(player):
	flash_mesh = player.camera.get_node_or_null("ImpactFlashMesh")

	if flash_mesh == null:
		AppLogger.warn("ImpactFlashMesh not found")
		return

	material = flash_mesh.get_active_material(0)
	if material == null:
		AppLogger.warn("No shader material found")
		return

	active = true
	elapsed = 0.0

	material.set_shader_parameter("intensity", 1.0)
	flash_mesh.visible = true


func update(player, delta):
	if not active:
		return

	elapsed += delta
	var t = clamp(elapsed / FLASH_DURATION, 0.0, 1.0)

	# Ease-out curve feels better in VR
	var fade = 1.0 - pow(t, 2.0)

	material.set_shader_parameter("intensity", fade)

	if t >= 0.99:
		stop(player)
		


func stop(player):
	if flash_mesh:
		flash_mesh.visible = false

	active = false
	FallEffectManager.clear_active_impact()
	

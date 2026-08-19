extends Node3D

func _ready() -> void:
	Global.scene_loader = self
	AppLogger.log("scene loader initialized")
	
	
func clear_scene():
	for child in self.get_children():
		child.queue_free()

func switch_scene(path: String):
	clear_scene()
	await get_tree().process_frame
	var level = load(path).instantiate()
	self.add_child(level)
	
func add_scene(path: String):
	var level = load(path).instantiate()
	self.add_child(level)

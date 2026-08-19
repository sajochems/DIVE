extends Node
class_name InteractionGroup

@export var required: int = 2
@export var target: Node  # e.g. Fireworks

var activated := {}

func register_interaction(source):
	activated[source] = true

	if activated.size() >= required:
		trigger()

func trigger():
	if target and target.has_method("start_fireworks"):
		target.start_fireworks()

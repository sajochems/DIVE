extends Node
class_name Interactor

@export var area: Area3D

var overlapping: Array = []

func _ready():
	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)

func _process(_delta):
		for interactable in overlapping:
			try_interact(interactable)
			

func _on_area_entered(enter_area):
	if enter_area.has_method("get_interactable"):
		var interactable = enter_area.get_interactable()
		if interactable:
			overlapping.append(interactable)

func _on_area_exited(enter_area):
	if enter_area.has_method("get_interactable"):
		var interactable = enter_area.get_interactable()
		overlapping.erase(interactable)

func try_interact(target):
	if target and target.has_method("can_interact_with"):
		if target.can_interact_with(self):
			target.interact(self)

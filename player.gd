extends Person
class_name Player

var movement_controller: Node

func _ready():
	super._ready()
	setup_movement()

func setup_movement():
	movement_controller = preload("res://player_movement.gd").new()
	add_child(movement_controller)
	
	movement_controller.rotation_complete.connect(_on_rotation_complete)

func _on_rotation_complete():
	print("Player rotation completed")
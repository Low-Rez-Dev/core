extends Node2D

var person: Person

func _ready():
	print("Simple test starting...")
	# Create a person directly in 2D space for testing
	person = Person.new()
	person.global_position = Vector2(200, -300)  # Negative Y to appear at bottom after flip
	
	# Override the coordinate system BEFORE adding to scene
	person.coordinate_system = self
	
	add_child(person)
	
	# Wait a frame then check
	await get_tree().process_frame
	print("Person created at: ", person.global_position)
	print("Person has ", person.entity_shapes.size(), " body parts")
	
	# Force a redraw
	person.queue_redraw()

func world_to_screen_direction(world_pos: Vector3) -> Vector2:
	# Simple 1:1 mapping for testing, use Y as vertical screen coordinate
	return Vector2(world_pos.x, -world_pos.y)  # Negative Y so up is up on screen

func _input(event):
	if event.is_action_pressed("move_forward"):
		person.global_position.x += 20
	elif event.is_action_pressed("move_backward"):
		person.global_position.x -= 20
	elif event.is_action_pressed("move_depth_positive"):
		person.global_position.y -= 20
	elif event.is_action_pressed("move_depth_negative"):
		person.global_position.y += 20

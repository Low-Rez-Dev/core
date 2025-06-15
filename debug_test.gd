extends Node2D

var person: Person

func _ready():
	print("=== Character Rendering Debug ===")
	
	# Create a person
	person = Person.new()
	person.global_position = Vector2(300, 400)  # Near bottom of screen
	
	# Override coordinate system for simple testing
	person.coordinate_system = self
	
	add_child(person)
	
	# Wait a frame for initialization
	await get_tree().process_frame
	
	print("Person created with ", person.entity_shapes.size(), " body parts:")
	for part_id in person.entity_shapes.keys():
		var shape = person.entity_shapes[part_id]
		var part_name = get_part_name(part_id)
		print("  ", part_name, " (", part_id, "): color=", shape.color, " size=", shape.size, " offset=", shape.offset)
	
	# Test drawing
	person.queue_redraw()

func get_part_name(part_id: int) -> String:
	match part_id:
		0: return "HEAD"
		1: return "NECK" 
		2: return "BODY"
		3: return "LEFT_ARM_UPPER"
		4: return "LEFT_ARM_LOWER"
		5: return "LEFT_HAND"
		6: return "RIGHT_ARM_UPPER"
		7: return "RIGHT_ARM_LOWER"
		8: return "RIGHT_HAND"
		9: return "LEFT_LEG_UPPER"
		10: return "LEFT_LEG_LOWER"
		11: return "LEFT_FOOT"
		12: return "RIGHT_LEG_UPPER"
		13: return "RIGHT_LEG_LOWER"
		14: return "RIGHT_FOOT"
		_: return "UNKNOWN"

func world_to_screen_direction(world_pos: Vector3) -> Vector2:
	# Simple coordinate mapping with proper Y transformation
	print("DEBUG: Transform input world_pos: ", world_pos)
	var result = Vector2(world_pos.x, world_pos.y)
	print("DEBUG: Transform output: ", result)
	return result

func _draw():
	# Draw a simple background test
	draw_circle(Vector2(100, 100), 20, Color.RED)
	draw_rect(Rect2(150, 150, 50, 50), Color.GREEN)
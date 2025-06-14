extends Node2D
class_name LivingEntity

enum EntityType {
	ANIMAL,
	PLANT
}

enum AnimalPart {
	HEAD,
	NECK,
	BODY,
	LEFT_ARM_UPPER,
	LEFT_ARM_LOWER,
	LEFT_HAND,
	RIGHT_ARM_UPPER,
	RIGHT_ARM_LOWER,
	RIGHT_HAND,
	LEFT_LEG_UPPER,
	LEFT_LEG_LOWER,
	LEFT_FOOT,
	RIGHT_LEG_UPPER,
	RIGHT_LEG_LOWER,
	RIGHT_FOOT
}

enum PlantPart {
	ROOT_SYSTEM,
	MAIN_STEM,
	BRANCH_STEM,
	LEAF,
	FLOWER,
	FRUIT,
	SEED
}

class EntityShape:
	var part_id: int  # Can be AnimalPart or PlantPart enum value
	var shape_type: String  # "rectangle", "circle", "polygon", "line"
	var size: Vector2
	var offset: Vector3
	var rotation: float
	var color: Color
	var thickness: float = 1.0
	var filled: bool = true
	
	func _init(p_id: int, type: String, sz: Vector2, off: Vector3 = Vector3.ZERO):
		part_id = p_id
		shape_type = type
		size = sz
		offset = off
		color = Color.WHITE
		rotation = 0.0

class Joint:
	var parent_part_id: int
	var child_part_id: int
	var pivot_point: Vector3
	var constraints: Vector2  # min/max rotation in radians
	var current_angle: float = 0.0
	
	func _init(parent_id: int, child_id: int, pivot: Vector3):
		parent_part_id = parent_id
		child_part_id = child_id
		pivot_point = pivot
		constraints = Vector2(-PI, PI)  # Full rotation by default

var entity_shapes: Dictionary = {}
var joints: Array[Joint] = []
var coordinate_system: Node

@export var entity_type: EntityType = EntityType.ANIMAL
@export var entity_scale: float = 100.0  # Bigger scale for visibility
@export var base_color: Color = Color(0.8, 0.7, 0.6)

func _ready():
	print("LivingEntity: _ready() called")
	coordinate_system = get_node("/root/CoordinateSystem")
	if not coordinate_system:
		coordinate_system = get_parent()  # Fallback for testing
		print("LivingEntity: using parent as coordinate system")
	define_entity_structure()
	setup_joints()
	print("LivingEntity: _ready() finished, entity_shapes count: ", entity_shapes.size())

func define_entity_structure():
	pass

func setup_joints():
	pass

func add_entity_shape(part_id: int, type: String, size: Vector2, offset: Vector3 = Vector3.ZERO) -> EntityShape:
	var shape = EntityShape.new(part_id, type, size, offset)
	shape.color = base_color
	entity_shapes[part_id] = shape
	return shape

func add_joint(parent_id: int, child_id: int, pivot: Vector3) -> Joint:
	var joint = Joint.new(parent_id, child_id, pivot)
	joints.append(joint)
	return joint

func get_world_position_for_part(part_id: int) -> Vector3:
	if not entity_shapes.has(part_id):
		return Vector3(global_position.x, global_position.y, 0)
	
	var shape = entity_shapes[part_id]
	var world_pos = Vector3(global_position.x, global_position.y, 0) + shape.offset
	
	return world_pos

func get_screen_position_for_part(part_id: int) -> Vector2:
	var world_pos = get_world_position_for_part(part_id)
	if coordinate_system.has_method("world_to_screen_direction"):
		return coordinate_system.world_to_screen_direction(world_pos)
	else:
		return Vector2(world_pos.x, world_pos.y)

func draw_entity():
	queue_redraw()

func _draw():
	for part_id in entity_shapes.keys():
		var shape = entity_shapes[part_id]
		var screen_pos = get_screen_position_for_part(part_id)
		if part_id < 3:  # Debug first 3 parts only
			print("Part ", part_id, " at ", screen_pos, " offset: ", shape.offset)
		draw_entity_part(part_id)

func draw_entity_part(part_id: int):
	if not entity_shapes.has(part_id):
		return
	
	var shape = entity_shapes[part_id]
	var screen_pos = get_screen_position_for_part(part_id)
	var screen_size = shape.size * entity_scale
	
	# Remove debug spam
	
	match shape.shape_type:
		"rectangle":
			draw_rectangle_part(screen_pos, screen_size, shape)
		"circle":
			draw_circle_part(screen_pos, screen_size, shape)
		"line":
			draw_line_part(screen_pos, screen_size, shape)

func draw_rectangle_part(pos: Vector2, size: Vector2, shape: EntityShape):
	var rect = Rect2(pos - size/2, size)
	if shape.filled:
		draw_rect(rect, shape.color)
	else:
		draw_rect(rect, shape.color, false, shape.thickness)

func draw_circle_part(pos: Vector2, size: Vector2, shape: EntityShape):
	var radius = min(size.x, size.y) / 2
	if shape.filled:
		draw_circle(pos, radius, shape.color)
	else:
		draw_arc(pos, radius, 0, PI * 2, 32, shape.color, shape.thickness)

func draw_line_part(pos: Vector2, size: Vector2, shape: EntityShape):
	var end_pos = pos + Vector2(size.x, 0).rotated(shape.rotation)
	draw_line(pos, end_pos, shape.color, shape.thickness)

func set_joint_angle(parent_id: int, child_id: int, angle: float):
	for joint in joints:
		if joint.parent_part_id == parent_id and joint.child_part_id == child_id:
			joint.current_angle = clamp(angle, joint.constraints.x, joint.constraints.y)
			update_joint_positions()
			break

func update_joint_positions():
	pass

func _process(_delta):
	draw_entity()

class_name BodyPart
extends Resource

@export var part_name: String = ""
@export var polygon_points: PackedVector2Array = PackedVector2Array()
@export var attachment_point: Vector2 = Vector2.ZERO
@export var parent_attachment: Vector2 = Vector2.ZERO

# Joint rotation constraints
@export var rotation_limits: RotationConstraint = RotationConstraint.new()

# Layered composition (outside to inside)
@export var layers: Dictionary = {}

# Variability zones for muscle/fat expansion
@export var variability_zones: Array[VariabilityZone] = []

# Parent-child relationships
@export var parent_part: BodyPart = null
@export var child_parts: Array[BodyPart] = []

func _init():
	setup_default_layers()

func setup_default_layers():
	layers = {
		"equipment": {},           # Backpacks, weapons, tools, belts, quivers
		"armor": null,            # Metal/leather protection
		"clothes": null,          # Fabric coverings
		"outer": null,            # Fur/feathers/scales (species-dependent)
		"skin": LayerData.new(),  # Hide/leather source
		"meat": LayerData.new(),  # Food material
		"bone": LayerData.new(),  # Tool/weapon material
		"organs": {}              # Heart, brain, etc. (location-specific)
	}

func add_child_part(child: BodyPart):
	if child not in child_parts:
		child_parts.append(child)
		child.parent_part = self

func remove_child_part(child: BodyPart):
	if child in child_parts:
		child_parts.erase(child)
		child.parent_part = null

func get_world_position() -> Vector2:
	if parent_part:
		return parent_part.get_world_position() + parent_part.attachment_point + attachment_point
	else:
		return attachment_point

func get_polygon_area() -> float:
	if polygon_points.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = polygon_points.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += polygon_points[i].x * polygon_points[j].y
		area -= polygon_points[j].x * polygon_points[i].y
	
	return abs(area) / 2.0

func get_polygon_centroid() -> Vector2:
	if polygon_points.size() < 3:
		return Vector2.ZERO
	
	var centroid = Vector2.ZERO
	var area = get_polygon_area()
	var n = polygon_points.size()
	
	for i in range(n):
		var j = (i + 1) % n
		var cross = polygon_points[i].x * polygon_points[j].y - polygon_points[j].x * polygon_points[i].y
		centroid.x += (polygon_points[i].x + polygon_points[j].x) * cross
		centroid.y += (polygon_points[i].y + polygon_points[j].y) * cross
	
	centroid /= (6.0 * area)
	return centroid

func apply_variability_zones():
	# Apply muscle/fat expansion to specific polygon points
	for zone in variability_zones:
		for point_index in zone.affected_points:
			if point_index < polygon_points.size():
				var direction = (polygon_points[point_index] - get_polygon_centroid()).normalized()
				var expansion = (zone.expansion_factor - 1.0) * zone.max_expansion
				polygon_points[point_index] += direction * expansion

func duplicate_part() -> BodyPart:
	var new_part = BodyPart.new()
	new_part.part_name = part_name + "_copy"
	new_part.polygon_points = polygon_points.duplicate()
	new_part.attachment_point = attachment_point
	new_part.parent_attachment = parent_attachment
	new_part.rotation_limits = rotation_limits.duplicate_constraint()
	
	# Deep copy layers
	for layer_name in layers:
		if layers[layer_name] is LayerData:
			new_part.layers[layer_name] = layers[layer_name].duplicate_layer()
		else:
			new_part.layers[layer_name] = layers[layer_name]
	
	# Deep copy variability zones
	for zone in variability_zones:
		new_part.variability_zones.append(zone.duplicate_zone())
	
	return new_part

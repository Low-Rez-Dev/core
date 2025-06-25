class_name VariabilityZone
extends Resource

@export var zone_name: String = ""               # "muscle", "fat", "bone_growth"
@export var affected_points: Array[int] = []     # Polygon point indices
@export var expansion_factor: float = 1.0        # Current expansion (1.0 = base)
@export var max_expansion: float = 2.0           # Genetic/physical limit
@export var growth_rate: float = 0.1             # How fast this zone responds to stimuli
@export var zone_type: String = "muscle"         # "muscle", "fat", "bone", "scar_tissue"

# Zone painting properties
@export var center_position: Vector2 = Vector2.ZERO  # Center of painted zone
@export var radius: float = 30.0                     # Radius of painted zone

func _init():
	pass

func apply_growth_stimulus(stimulus_amount: float, delta_time: float):
	var growth_change = stimulus_amount * growth_rate * delta_time
	expansion_factor = clamp(expansion_factor + growth_change, 0.1, max_expansion)

func apply_atrophy(atrophy_rate: float, delta_time: float):
	var atrophy_change = atrophy_rate * delta_time
	expansion_factor = max(0.1, expansion_factor - atrophy_change)

func get_expansion_percentage() -> float:
	return ((expansion_factor - 1.0) / (max_expansion - 1.0)) * 100.0

func is_at_maximum() -> bool:
	return expansion_factor >= max_expansion

func is_at_minimum() -> bool:
	return expansion_factor <= 0.1

func get_visual_color() -> Color:
	match zone_type:
		"muscle": return Color.RED.lerp(Color.DARK_RED, (expansion_factor - 1.0) / (max_expansion - 1.0))
		"fat": return Color.YELLOW.lerp(Color.ORANGE, (expansion_factor - 1.0) / (max_expansion - 1.0))
		"bone": return Color.WHITE.lerp(Color.GRAY, (expansion_factor - 1.0) / (max_expansion - 1.0))
		"scar_tissue": return Color.PINK.lerp(Color.PURPLE, (expansion_factor - 1.0) / (max_expansion - 1.0))
		_: return Color.BLUE

func duplicate_zone() -> VariabilityZone:
	var new_zone = VariabilityZone.new()
	new_zone.zone_name = zone_name
	new_zone.affected_points = affected_points.duplicate()
	new_zone.expansion_factor = expansion_factor
	new_zone.max_expansion = max_expansion
	new_zone.growth_rate = growth_rate
	new_zone.zone_type = zone_type
	new_zone.center_position = center_position
	new_zone.radius = radius
	return new_zone

func is_point_in_zone(point: Vector2) -> bool:
	return center_position.distance_to(point) <= radius

func apply_to_polygon(polygon_points: PackedVector2Array, centroid: Vector2) -> PackedVector2Array:
	var modified_points = polygon_points.duplicate()
	
	for point_index in affected_points:
		if point_index < modified_points.size():
			var point = modified_points[point_index]
			var direction = (point - centroid).normalized()
			var expansion = (expansion_factor - 1.0) * max_expansion
			modified_points[point_index] = point + direction * expansion
	
	return modified_points

# Zone presets
static func create_muscle_zone(name: String, points: Array[int]) -> VariabilityZone:
	var zone = VariabilityZone.new()
	zone.zone_name = name
	zone.zone_type = "muscle"
	zone.affected_points = points
	zone.expansion_factor = 1.0
	zone.max_expansion = 1.8
	zone.growth_rate = 0.05
	return zone

static func create_fat_zone(name: String, points: Array[int]) -> VariabilityZone:
	var zone = VariabilityZone.new()
	zone.zone_name = name
	zone.zone_type = "fat"
	zone.affected_points = points
	zone.expansion_factor = 1.0
	zone.max_expansion = 2.5
	zone.growth_rate = 0.1
	return zone

static func create_bone_zone(name: String, points: Array[int]) -> VariabilityZone:
	var zone = VariabilityZone.new()
	zone.zone_name = name
	zone.zone_type = "bone"
	zone.affected_points = points
	zone.expansion_factor = 1.0
	zone.max_expansion = 1.3
	zone.growth_rate = 0.01
	return zone
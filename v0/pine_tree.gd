extends ProceduralEntity
class_name PineTree

# Tree visual properties (20 units = 1 meter scale)
@export var tree_height: float = 100.0  # 100 units = 5 meters tall
@export var trunk_width: float = 16.0   # 16 units = 0.8 meters wide
@export var canopy_layers: int = 4

func _ready():
	super._ready()
	
	# Set tree properties
	entity_size = tree_height
	primary_color = Color(0.2, 0.5, 0.1)  # Dark green
	secondary_color = Color(0.3, 0.6, 0.15)  # Light green
	outline_color = Color(0.6, 0.3, 0.1)  # Brown trunk
	outline_width = 2.0
	
	# Trees are stationary entities - they don't move in virtual space
	# The manifestation range is controlled by SolipsisticCoordinates.perception_radius

func get_entity_type() -> String:
	return "pine_tree"

func get_tree_properties() -> Dictionary:
	"""Return tree-specific properties for the procedural drawer"""
	return {
		"height": tree_height,
		"trunk_width": trunk_width,
		"canopy_layers": canopy_layers
	}

func update_subjective_position():
	"""Override for side-view positioning - trees appear on terrain cross-section"""
	if not is_manifested:
		return
	
	var coords = SolipsisticCoordinates
	var screen_center = coords.CONSCIOUSNESS_CENTER
	
	# Calculate position for side-view (ant farm style)
	var side_view_pos = calculate_side_view_position()
	
	if side_view_pos == Vector2.INF:  # Tree not visible in current cross-section
		visible = false
		return
	
	visible = true
	position = side_view_pos

func calculate_side_view_position() -> Vector2:
	"""Calculate tree position for side-view cross-section display"""
	var coords = SolipsisticCoordinates
	var observer_pos = coords.player_consciousness_pos
	var orientation = coords.current_orientation
	var screen_center = coords.CONSCIOUSNESS_CENTER
	
	# Check if tree is close enough to the current cross-section to be visible
	var cross_section_tolerance = 10.0  # Only show trees within 10 units (0.5 meters) of the cross-section plane
	var horizontal_distance: float
	var depth_distance: float
	
	match orientation:
		coords.Orientation.EAST, coords.Orientation.WEST:
			# Cross-section is North-South, so we're looking along the X axis
			depth_distance = abs(virtual_position.x - observer_pos.x)  # Distance from cross-section plane
			horizontal_distance = virtual_position.y - observer_pos.y  # Position along the cross-section
		coords.Orientation.NORTH, coords.Orientation.SOUTH:
			# Cross-section is East-West, so we're looking along the Y axis  
			depth_distance = abs(virtual_position.y - observer_pos.y)  # Distance from cross-section plane
			horizontal_distance = virtual_position.x - observer_pos.x  # Position along the cross-section
		_:
			return Vector2.INF
	
	# If tree is too far from the cross-section plane, don't show it
	if depth_distance > cross_section_tolerance:
		return Vector2.INF
	
	# Get terrain height at tree's position
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	if not solipsistic_world:
		return Vector2.INF
	
	var tree_terrain_height = solipsistic_world.get_terrain_height_at(virtual_position)
	
	# Calculate perspective scaling based on distance from player
	var distance_from_player = abs(horizontal_distance)
	var perspective_scale = calculate_perspective_scale(distance_from_player)
	
	# Get the same eye level that terrain renderer uses for consistency
	var terrain_renderer = get_tree().get_first_node_in_group("TerrainRenderer")
	var viewport_size = get_viewport().get_visible_rect().size
	var player_eye_level: float
	
	if terrain_renderer and terrain_renderer.has_method("calculate_dynamic_eye_level"):
		player_eye_level = terrain_renderer.calculate_dynamic_eye_level(viewport_size)
	else:
		# Fallback if terrain renderer not found
		player_eye_level = viewport_size.y * 0.85
	
	var horizontal_scale = 3.0  # Same scale as terrain renderer
	var vertical_scale = 2.0    # Same scale as terrain renderer
	
	var screen_x = screen_center.x + horizontal_distance * horizontal_scale * perspective_scale
	var screen_y = player_eye_level - tree_terrain_height * vertical_scale * perspective_scale
	
	# Scale the tree based on distance
	scale = Vector2.ONE * perspective_scale
	
	return Vector2(screen_x, screen_y)

func calculate_perspective_scale(distance: float) -> float:
	"""Calculate perspective scaling - same as terrain renderer"""
	var min_scale = 0.3
	var max_scale = 1.0
	var perspective_distance = 100.0
	
	var scale = max_scale * exp(-distance / perspective_distance)
	return max(min_scale, scale)

func get_terrain_height_offset() -> float:
	"""Get visual offset based on terrain height difference between tree and player"""
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	if not solipsistic_world:
		return 0.0
	
	# Get terrain height at tree's virtual position
	var tree_terrain_height = solipsistic_world.get_terrain_height_at(virtual_position)
	
	# Get terrain height at player's position
	var player_terrain_height = solipsistic_world.get_terrain_height_at(SolipsisticCoordinates.player_consciousness_pos)
	
	# Calculate relative height difference
	var height_difference = tree_terrain_height - player_terrain_height
	
	# Scale the visual offset (positive = tree terrain is higher, so tree appears lower on screen)
	var vertical_scale = 2.0  # Same scale as terrain renderer
	return -height_difference * vertical_scale

extends Node
class_name FocusLaneSystem

# Focus lane rendering system for 2.5D depth management
# Entities render based on their distance from the current focus lane

@export var lane_depth_scale: float = 0.8  # Scale factor for each lane away from focus
@export var lane_alpha_falloff: float = 0.3  # Alpha reduction per lane distance
@export var max_visible_lanes: int = 3  # How many lanes away from focus are visible

var current_focus_lane: Vector3i  # The current focus lane in 3D grid coordinates
var coordinate_system: Node

signal focus_lane_changed(new_focus_lane: Vector3i)

func _ready():
	current_focus_lane = Vector3i(0, 0, 0)  # Start at origin
	
	# Use CSLocator to find coordinate system
	CSLocator.with(self).connect_service_found("coordinate_system", _on_coordinate_system_found)

func set_focus_lane(new_lane: Vector3i):
	if new_lane != current_focus_lane:
		current_focus_lane = new_lane
		focus_lane_changed.emit(current_focus_lane)
		update_all_entity_positions()

# Calculate rendering properties for an entity based on its grid position
func get_entity_render_properties(entity_grid_pos: Vector3i) -> Dictionary:
	var lane_distance = calculate_lane_distance(entity_grid_pos, current_focus_lane)
	
	return {
		"visible": lane_distance <= max_visible_lanes,
		"scale": pow(lane_depth_scale, lane_distance),
		"alpha": max(0.0, 1.0 - (lane_distance * lane_alpha_falloff)),
		"z_index": -lane_distance,  # Closer lanes render on top
		"lane_distance": lane_distance
	}

# Calculate distance between entity and focus lane based on current orientation
func calculate_lane_distance(entity_pos: Vector3i, focus_pos: Vector3i) -> int:
	if not coordinate_system:
		return 0
	
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			# Movement axis is X, depth lanes are Z
			return abs(entity_pos.z - focus_pos.z)
		coordinate_system.Orientation.EAST_WEST:
			# Movement axis is Z, depth lanes are X  
			return abs(entity_pos.x - focus_pos.x)
		_:
			return 0

# Convert 3D grid position to 2D screen position for current orientation
func grid_to_screen_position(grid_pos: Vector3i) -> Vector2:
	if not coordinate_system:
		return Vector2.ZERO
	
	# Get player position for relative positioning
	var player = get_tree().get_first_node_in_group("player")
	var player_grid = Vector3i(0, 0, 0)
	if player and player.has_method("get_grid_position"):
		player_grid = player.get_grid_position()
	
	# Calculate offset from player position
	var relative_pos = grid_pos - player_grid
	
	# For side-view: Only the current movement axis determines horizontal screen position
	var screen_x: float
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			# X axis is movement axis (horizontal on screen)
			screen_x = 320 + (relative_pos.x * GridCoordinates.GRID_SIZE)
		coordinate_system.Orientation.EAST_WEST:
			# Z axis is movement axis (horizontal on screen)  
			screen_x = 320 + (relative_pos.z * GridCoordinates.GRID_SIZE)
		_:
			screen_x = 320
	
	# Y position on terrain (convert height to screen Y)
	var terrain_system = coordinate_system.terrain_system
	var terrain_height = 0.0
	if terrain_system:
		match coordinate_system.current_orientation:
			coordinate_system.Orientation.NORTH_SOUTH:
				terrain_height = terrain_system.get_terrain_height(Vector2i(grid_pos.x, grid_pos.z))
			coordinate_system.Orientation.EAST_WEST:
				terrain_height = terrain_system.get_terrain_height(Vector2i(grid_pos.x, grid_pos.z))
	
	var screen_y = 240 - terrain_height  # Convert terrain height to screen Y
	
	return Vector2(screen_x, screen_y)

# Get all entities that should be rendered for current focus lane
func get_visible_entities() -> Array:
	var visible_entities = []
	
	# Find all entities in the scene
	for entity in get_tree().get_nodes_in_group("entities"):
		if entity.has_method("get_grid_position"):
			var entity_pos = entity.get_grid_position()
			var render_props = get_entity_render_properties(entity_pos)
			
			if render_props.visible:
				visible_entities.append({
					"entity": entity,
					"properties": render_props
				})
	
	# Sort by z_index (closer lanes first)
	visible_entities.sort_custom(func(a, b): return a.properties.z_index > b.properties.z_index)
	
	return visible_entities

# Update all entity rendering based on current focus lane
func update_entity_rendering():
	var visible_entities = get_visible_entities()
	
	for entity_data in visible_entities:
		var entity = entity_data.entity
		var props = entity_data.properties
		
		if entity.has_method("set_render_properties"):
			entity.set_render_properties(props)
		else:
			# Fallback: set basic properties if available
			if entity.has_method("set_modulate"):
				entity.set_modulate(Color(1, 1, 1, props.alpha))
			if entity.has_method("set_scale"):
				entity.set_scale(Vector2(props.scale, props.scale))
			if "z_index" in entity:
				entity.z_index = props.z_index

# Check if a grid position is on the current focus lane
func is_on_focus_lane(grid_pos: Vector3i) -> bool:
	return calculate_lane_distance(grid_pos, current_focus_lane) == 0

# Get the focus lane coordinate for a given movement position
func get_focus_lane_for_movement_pos(movement_pos: Vector2i) -> Vector3i:
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			# Movement is on X axis, preserve current Z (focus lane)
			return Vector3i(movement_pos.x, movement_pos.y, current_focus_lane.z)
		coordinate_system.Orientation.EAST_WEST:
			# Movement is on Z axis, preserve current X (focus lane)
			return Vector3i(current_focus_lane.x, movement_pos.y, movement_pos.x)
		_:
			return Vector3i.ZERO

# Update all entity screen positions (called when player moves)
func update_all_entity_positions():
	for entity in get_tree().get_nodes_in_group("entities"):
		if entity.has_method("update_screen_position"):
			entity.update_screen_position()

# CSLocator callback when coordinate system service is found
func _on_coordinate_system_found(service):
	coordinate_system = service
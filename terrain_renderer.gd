extends GridEntity
class_name TerrainRenderer

# Renders terrain for the current focus lane in side-view

@export var terrain_color: Color = Color(0.15, 0.1, 0.08)  # Dark pottery paint
@export var rock_color: Color = Color(0.2, 0.15, 0.12)   # Medium pottery shade

var terrain_system: TerrainSystem
var render_distance: int = 20  # How many grid cells to render around player

func _ready():
	super._ready()
	
	# Direct access for now until CSLocator is working properly
	call_deferred("_try_direct_access")

func _draw():
	if not terrain_system or not focus_lane_system:
		return
	
	# Get player position for rendering around
	var player_grid = Vector3i(0, 0, 0)  # Default center
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_grid_position"):
		player_grid = player.get_grid_position()
	
	# Render terrain around player position
	render_terrain_around(player_grid)

func render_terrain_around(center_pos: Vector3i):
	# Only render terrain for the current focus lane
	var focus_lane = focus_lane_system.current_focus_lane
	
	# Get the current movement axis for side-view
	var coordinate_system = get_node("/root/CoordinateSystem")
	if not coordinate_system:
		return
	
	
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			# X axis is horizontal movement, render along X, fixed Z (focus lane)
			render_terrain_strip_x(center_pos, focus_lane.z)
		coordinate_system.Orientation.EAST_WEST:
			# Z axis is horizontal movement, render along Z, fixed X (focus lane)
			render_terrain_strip_z(center_pos, focus_lane.x)

func render_terrain_strip_x(center_pos: Vector3i, fixed_z: int):
	# Render terrain along X axis for side-view (fixed Z coordinate)
	var start_x = center_pos.x - render_distance
	var end_x = center_pos.x + render_distance
	
	var terrain_points = []
	
	# Collect terrain heights along the strip
	for x in range(start_x, end_x + 1):
		var terrain_height = terrain_system.get_terrain_height(Vector2i(x, fixed_z))
		var world_x = x * GridCoordinates.GRID_SIZE
		var screen_x = world_x - (center_pos.x * GridCoordinates.GRID_SIZE) + 320  # Center on screen
		var screen_y = 240 - terrain_height  # Convert height to screen Y (flip Y axis)
		
		terrain_points.append(Vector2(screen_x, screen_y))
	
	# Draw terrain as connected line segments with ground fill
	if terrain_points.size() >= 2:
		draw_terrain_profile(terrain_points)

func render_terrain_strip_z(center_pos: Vector3i, fixed_x: int):
	# Render terrain along Z axis for side-view (fixed X coordinate)
	var start_z = center_pos.z - render_distance
	var end_z = center_pos.z + render_distance
	
	var terrain_points = []
	
	# Collect terrain heights along the strip
	for z in range(start_z, end_z + 1):
		var terrain_height = terrain_system.get_terrain_height(Vector2i(fixed_x, z))
		var world_z = z * GridCoordinates.GRID_SIZE
		var screen_x = world_z - (center_pos.z * GridCoordinates.GRID_SIZE) + 320  # Center on screen
		var screen_y = 240 - terrain_height  # Convert height to screen Y (flip Y axis)
		
		terrain_points.append(Vector2(screen_x, screen_y))
	
	# Draw terrain as connected line segments with ground fill
	if terrain_points.size() >= 2:
		draw_terrain_profile(terrain_points)

func draw_terrain_profile(points: Array):
	# Draw the terrain as a filled polygon
	if points.size() < 2:
		return
	
	# Create polygon for ground fill
	var ground_polygon = PackedVector2Array()
	
	# Add terrain points
	for point in points:
		ground_polygon.append(point)
	
	# Close polygon at bottom of screen
	ground_polygon.append(Vector2(points[-1].x, 480))  # Bottom right
	ground_polygon.append(Vector2(points[0].x, 480))   # Bottom left
	
	# Draw filled ground
	draw_colored_polygon(ground_polygon, terrain_color)
	
	# Draw terrain surface line
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], rock_color, 2)

func get_terrain_height_at_screen_x(screen_x: float) -> float:
	# Convert screen X back to world/grid coordinates and get terrain height
	if not terrain_system or not focus_lane_system:
		return 240  # Default ground level
	
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("get_grid_position"):
		return 240
	
	var player_grid = player.get_grid_position()
	var coordinate_system = get_node("/root/CoordinateSystem")
	if not coordinate_system:
		return 240
	
	var world_offset = screen_x - 320  # Offset from screen center
	var terrain_height = 0.0
	
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			var world_x = (player_grid.x * GridCoordinates.GRID_SIZE) + world_offset
			var grid_x = int(world_x / GridCoordinates.GRID_SIZE)
			terrain_height = terrain_system.get_terrain_height(Vector2i(grid_x, focus_lane_system.current_focus_lane.z))
		coordinate_system.Orientation.EAST_WEST:
			var world_z = (player_grid.z * GridCoordinates.GRID_SIZE) + world_offset
			var grid_z = int(world_z / GridCoordinates.GRID_SIZE)
			terrain_height = terrain_system.get_terrain_height(Vector2i(focus_lane_system.current_focus_lane.x, grid_z))
	
	return 240 - terrain_height  # Convert to screen Y

# CSLocator callback when terrain system service is found
func _on_terrain_system_found(service):
	terrain_system = service
	print("TerrainRenderer: Found terrain system via CSLocator")

# Fallback to direct access if CSLocator doesn't work
func _try_direct_access():
	if not terrain_system:
		var coord_system = get_node("/root/CoordinateSystem")
		if coord_system and coord_system.terrain_system:
			terrain_system = coord_system.terrain_system
			# Force a redraw to make sure terrain appears
			queue_redraw()

func _process(_delta):
	# Redraw every frame to keep terrain visible
	queue_redraw()

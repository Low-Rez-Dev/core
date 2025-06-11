extends Node2D
class_name TerrainRenderer

var terrain_system: TerrainSystem
var cross_section_points: PackedVector2Array = PackedVector2Array()

# Visual parameters
var terrain_color: Color = Color(0.6, 0.4, 0.2)  # Brown earth
var rock_color: Color = Color(0.5, 0.5, 0.5)     # Gray rock
var surface_color: Color = Color(0.4, 0.7, 0.3)  # Green grass
var line_width: float = 2.0
var vertical_scale: float = 2.0  # Exaggerate height for visibility

func setup(terrain_sys: TerrainSystem):
	terrain_system = terrain_sys

func _process(delta):
	if terrain_system:
		update_cross_section()
	queue_redraw()

func update_cross_section():
	"""Update terrain cross-section based on current player position and orientation"""
	var coords = SolipsisticCoordinates
	var observer_pos = coords.player_consciousness_pos
	var orientation = coords.current_orientation
	
	# Calculate terrain width based on screen width
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	var horizontal_scale = 3.0  # Same scale used in draw function
	var terrain_width = (viewport_size.x / horizontal_scale) + 50.0  # Extra padding for smooth edges
	
	# Get terrain cross-section from terrain system with screen-width view
	cross_section_points = terrain_system.get_terrain_cross_section(observer_pos, orientation, terrain_width)
	
	# Debug: Print some info about the cross-section
	if cross_section_points.size() > 0:
		print("Cross-section: %d points, first: %s, last: %s" % [
			cross_section_points.size(), 
			cross_section_points[0], 
			cross_section_points[-1]
		])

func _draw():
	if cross_section_points.is_empty():
		return
	
	draw_terrain_cross_section()

func draw_terrain_cross_section():
	"""Draw the perspective side-view terrain cross-section"""
	var screen_center = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Lower the horizon for better perspective view
	var horizon_y = viewport_size.y * 0.7  # Horizon at 70% down the screen
	var player_eye_level = horizon_y - 50  # Player eye level slightly above horizon
	
	# Terrain stays fixed - no height offset when player jumps
	# Only the player moves up/down relative to the fixed terrain
	
	# Convert terrain points to screen coordinates with perspective
	var screen_points = PackedVector2Array()
	var foreground_cutoff = 0.0  # Distance from player where terrain becomes "invisible" (blocked by foreground)
	
	for point in cross_section_points:
		# Calculate perspective scaling based on distance from player
		var distance_from_player = abs(point.x)  # Horizontal distance from player
		var perspective_scale = calculate_perspective_scale(distance_from_player)
		
		# Skip points too close to player (blocked by foreground)
		if distance_from_player < 10.0:  # 10 units is "foreground" - invisible
			continue
			
		var screen_x = screen_center.x + point.x * 3 * perspective_scale
		var screen_y = player_eye_level - point.y * vertical_scale * perspective_scale
		screen_points.append(Vector2(screen_x, screen_y))
		
		# Debug: Print first few points
		if screen_points.size() <= 3:
			print("Point %d: terrain(%s) -> screen(%s) [scale: %.2f]" % [screen_points.size(), point, Vector2(screen_x, screen_y), perspective_scale])
	
	if screen_points.size() < 2:
		print("Not enough points to draw terrain: %d" % screen_points.size())
		return
	
	# Create filled polygon for ant farm style terrain
	var filled_points = PackedVector2Array()
	
	# Extend terrain to screen edges if needed
	var first_point = screen_points[0]
	var last_point = screen_points[-1]
	
	# Add left edge extension if terrain doesn't reach left edge
	if first_point.x > 0:
		filled_points.append(Vector2(0, first_point.y))
	
	# Add all terrain surface points
	for point in screen_points:
		filled_points.append(point)
	
	# Add right edge extension if terrain doesn't reach right edge
	if last_point.x < viewport_size.x:
		filled_points.append(Vector2(viewport_size.x, last_point.y))
	
	# Close the polygon by adding bottom edge points (going back along the bottom)
	# Add bottom-right corner
	filled_points.append(Vector2(viewport_size.x, viewport_size.y))
	# Add bottom-left corner
	filled_points.append(Vector2(0, viewport_size.y))
	
	# Draw filled terrain polygon
	if filled_points.size() >= 3:
		draw_colored_polygon(filled_points, terrain_color)
	
	# Draw terrain surface line on top for definition
	# Draw line from left edge
	if first_point.x > 0:
		draw_line(Vector2(0, first_point.y), screen_points[0], surface_color, line_width)
	
	# Draw terrain surface line
	for i in range(screen_points.size() - 1):
		draw_line(screen_points[i], screen_points[i + 1], surface_color, line_width)
	
	# Draw line to right edge
	if last_point.x < viewport_size.x:
		draw_line(screen_points[-1], Vector2(viewport_size.x, last_point.y), surface_color, line_width)
	
	# Draw player eye level reference (where player stands when on flat ground)
	draw_line(Vector2(0, player_eye_level), Vector2(viewport_size.x, player_eye_level), Color.RED, 2.0)

func calculate_perspective_scale(distance: float) -> float:
	"""Calculate perspective scaling - distant objects appear smaller"""
	var min_scale = 0.3  # Minimum scale for very distant objects
	var max_scale = 1.0  # Scale for nearby objects
	var perspective_distance = 100.0  # Distance at which objects are half scale
	
	# Exponential falloff for more realistic perspective
	var scale = max_scale * exp(-distance / perspective_distance)
	return max(min_scale, scale)

func draw_reference_grid():
	"""Draw subtle grid lines to show meter spacing"""
	var screen_center = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	var viewport_size = get_viewport().get_visible_rect().size
	var grid_color = Color(0.3, 0.3, 0.3, 0.3)  # Subtle gray
	
	# Vertical grid lines (every 10 pixels = 1 meter)
	for x in range(-20, 21):  # -20m to +20m around player
		var screen_x = screen_center.x + x * 10
		if screen_x >= 0 and screen_x <= viewport_size.x:
			draw_line(Vector2(screen_x, 0), Vector2(screen_x, viewport_size.y), grid_color, 1.0)
	
	# Horizontal grid lines (every meter in height)
	for y in range(-10, 11):  # -10m to +10m height
		var screen_y = screen_center.y - y * vertical_scale * 5  # Every 5m height
		if screen_y >= 0 and screen_y <= viewport_size.y:
			draw_line(Vector2(0, screen_y), Vector2(viewport_size.x, screen_y), grid_color, 1.0)

func draw_height_indicators():
	"""Draw height numbers at regular intervals"""
	# This would require a font resource - implement later if needed
	pass

extends Node2D

var person: Player

var current_lane = 0

# Day-night cycle
var day_length: float = 60.0  # 60 seconds for a full day
var current_time: float = 30.0  # Start at midday
var time_speed: float = 1.0

func _ready():
	person = Player.new()
	
	# Set initial position
	person.global_position = Vector2(320, 240)  # Center of screen
	
	add_child(person)
	
	# Add terrain renderer first
	var terrain_renderer = TerrainRenderer.new()
	terrain_renderer.set_grid_position(Vector3i(0, 0, 0))
	add_child(terrain_renderer)
	
	# Add some test trees at different grid positions
	create_test_trees()
	
	await get_tree().process_frame

func create_test_trees():
	# Create trees at various grid positions to test focus lane system
	var tree_positions = [
		Vector3i(15, 0, -2),  # Behind player
		Vector3i(17, 0, -1),  # One lane behind
		Vector3i(16, 0, 0),   # Same lane as player
		Vector3i(18, 0, 1),   # One lane ahead
		Vector3i(19, 0, 2),   # Two lanes ahead
	]
	
	for pos in tree_positions:
		var tree = TestTree.new()
		tree.set_grid_position(pos)
		add_child(tree)
	
	# Terrain renderer is now created in _ready()

func update_person_position():
	# Convert grid position to world position, then to screen coordinates
	var base_world_pos = GridCoordinates.grid_to_world(current_grid_pos)
	var depth_offset = depth_lanes[current_lane] * GridCoordinates.GRID_SIZE
	person.global_position = Vector2(base_world_pos.x, base_world_pos.y + depth_offset)

func world_to_screen_direction(world_pos: Vector3) -> Vector2:
	# Simple direct mapping - no flipping or complex transforms
	return Vector2(world_pos.x, world_pos.y)

func _draw():
	# Day-night cycle background - make it much larger for zoom out
	var sky_color = get_sky_color_for_time(current_time)
	# At 0.8x zoom, we need about 1.25x larger background to cover the screen
	draw_rect(Rect2(-400, -300, 1440, 1080), sky_color)
	
	# Grid removed for cleaner 2.5D view
	
	# Coordinate display removed - using minimap instead
	
	# Let the Player draw itself - no manual drawing needed



var movement_speed = 150.0  # pixels per second for smooth horizontal movement
var current_grid_pos = Vector2i(16, 17)  # Start at grid (16, 17) 
var depth_lanes = [0, -2, 2, -4, 4]  # Depth offsets in grid units from current Y

func _process(delta):
	# Update day-night cycle
	current_time += delta * time_speed
	if current_time >= day_length:
		current_time = 0.0
	queue_redraw()  # Redraw for lighting changes
	
	# Smooth horizontal movement with A/D
	var horizontal_input = 0.0
	if Input.is_key_pressed(KEY_A):
		horizontal_input -= 1.0
	if Input.is_key_pressed(KEY_D):
		horizontal_input += 1.0
	
	if horizontal_input != 0.0:
		person.global_position.x += horizontal_input * movement_speed * delta
		# Update grid position based on current world position
		current_grid_pos = GridCoordinates.world_to_grid(person.global_position)

func get_sky_color_for_time(time: float) -> Color:
	# Normalize time to 0-1 range
	var normalized_time = time / day_length
	
	# Define key colors
	var midnight = Color(0.12, 0.10, 0.18)  # Dark grey-purple, darker than characters
	var dawn_dusk = Color(0.8, 0.45, 0.25)  # Current terracotta (dawn/dusk)
	var noon = Color(0.95, 0.85, 0.75)     # Whitewashed version
	
	# Calculate time of day
	# 0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk, 1.0 = midnight
	var result_color: Color
	
	if normalized_time < 0.25:
		# Midnight to dawn (0.0 to 0.25)
		var t = normalized_time / 0.25
		result_color = midnight.lerp(dawn_dusk, t)
	elif normalized_time < 0.5:
		# Dawn to noon (0.25 to 0.5)
		var t = (normalized_time - 0.25) / 0.25
		result_color = dawn_dusk.lerp(noon, t)
	elif normalized_time < 0.75:
		# Noon to dusk (0.5 to 0.75)
		var t = (normalized_time - 0.5) / 0.25
		result_color = noon.lerp(dawn_dusk, t)
	else:
		# Dusk to midnight (0.75 to 1.0)
		var t = (normalized_time - 0.75) / 0.25
		result_color = dawn_dusk.lerp(midnight, t)
	
	return result_color

func _input(event):
	# Remove R/F key handling to avoid conflicts with new player movement system
	pass

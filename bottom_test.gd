extends Node2D

var person: Player

var current_lane = 0

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
	# Ancient Greek pottery terracotta background
	var terracotta = Color(0.8, 0.45, 0.25)  # Classic terracotta pottery color
	draw_rect(Rect2(0, 0, 640, 480), terracotta)
	
	# Grid removed for cleaner 2.5D view
	
	# Coordinate display removed - using minimap instead
	
	# Let the Player draw itself - no manual drawing needed



var movement_speed = 150.0  # pixels per second for smooth horizontal movement
var current_grid_pos = Vector2i(16, 17)  # Start at grid (16, 17) 
var depth_lanes = [0, -2, 2, -4, 4]  # Depth offsets in grid units from current Y

func _process(delta):
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
		queue_redraw()

func _input(event):
	# Remove R/F key handling to avoid conflicts with new player movement system
	pass

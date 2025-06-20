extends Node
class_name TerrainSystem

# Terrain system for 2.5D side-view with cell-based heights
# Each grid cell has a height, slopes connect adjacent cells

@export var default_height: float = -10.0  # Default ground level, extended downward
@export var height_scale: float = 1.0    # Multiplier for height variations

# Dictionary to store height data: Vector2i(x,z) -> height
var terrain_heights: Dictionary = {}

# Cache for interpolated heights to avoid recalculation
var height_cache: Dictionary = {}

func _ready():
	# Generate some test terrain
	generate_test_terrain()

func generate_test_terrain():
	# Create some simple test terrain with hills and valleys
	# Extend terrain much further to prevent seeing sky when zoomed out
	for x in range(-200, 201):
		for z in range(-200, 201):
			var cell_pos = Vector2i(x, z)
			
			# Simple procedural terrain generation
			var height = default_height
			
			# Add some hills using sine waves
			height += sin(x * 0.1) * 3.0
			height += cos(z * 0.15) * 2.0
			
			# Add some random variation
			height += randf_range(-1.0, 1.0)
			
			# Create a few specific terrain features
			if x >= 10 and x <= 15 and z >= -5 and z <= 5:
				height += 5.0  # Hill
			if x >= -15 and x <= -10 and z >= -3 and z <= 3:
				height -= 3.0  # Valley
			
			set_terrain_height(cell_pos, height)
	
	print("Generated terrain with ", terrain_heights.size(), " cells")

func set_terrain_height(cell_pos: Vector2i, height: float):
	terrain_heights[cell_pos] = height
	# Clear height cache when terrain changes
	height_cache.clear()

func get_terrain_height(cell_pos: Vector2i) -> float:
	return terrain_heights.get(cell_pos, default_height)

func get_interpolated_height(world_pos_x: float, world_pos_z: float) -> float:
	# Convert world coordinates to grid coordinates
	var grid_x = world_pos_x / GridCoordinates.GRID_SIZE
	var grid_z = world_pos_z / GridCoordinates.GRID_SIZE
	
	# Get the four surrounding grid cells
	var x0 = int(floor(grid_x))
	var x1 = x0 + 1
	var z0 = int(floor(grid_z))
	var z1 = z0 + 1
	
	# Get heights of the four corners
	var h00 = get_terrain_height(Vector2i(x0, z0))  # Bottom-left
	var h10 = get_terrain_height(Vector2i(x1, z0))  # Bottom-right
	var h01 = get_terrain_height(Vector2i(x0, z1))  # Top-left
	var h11 = get_terrain_height(Vector2i(x1, z1))  # Top-right
	
	# Calculate interpolation factors
	var fx = grid_x - x0  # 0.0 to 1.0 within cell
	var fz = grid_z - z0  # 0.0 to 1.0 within cell
	
	# Bilinear interpolation
	var h_bottom = lerp(h00, h10, fx)  # Interpolate bottom edge
	var h_top = lerp(h01, h11, fx)     # Interpolate top edge
	var final_height = lerp(h_bottom, h_top, fz)  # Interpolate between edges
	
	return final_height

func get_height_at_grid_position(grid_pos: Vector3i) -> float:
	# Get terrain height at specific grid position
	var world_3d = GridCoordinates.grid_to_world_3d(grid_pos)
	return get_interpolated_height(world_3d.x, world_3d.z)

func is_valid_position(grid_pos: Vector3i) -> bool:
	# Check if a position is valid (not in a hole, reasonable height difference)
	var current_height = get_height_at_grid_position(grid_pos)
	var player_y = grid_pos.y * GridCoordinates.GRID_SIZE
	
	# Allow some tolerance for height differences
	var height_tolerance = GridCoordinates.GRID_SIZE * 2  # 2 grid units of jump height
	
	return abs(player_y - current_height) <= height_tolerance

func get_ground_level_at_position(grid_pos: Vector3i) -> float:
	# Get the ground level Y coordinate for a given X/Z position
	var terrain_height = get_height_at_grid_position(grid_pos)
	return terrain_height

func can_move_to_position(from_pos: Vector3i, to_pos: Vector3i) -> bool:
	# Check if movement from one position to another is valid
	var from_height = get_height_at_grid_position(from_pos)
	var to_height = get_height_at_grid_position(to_pos)
	
	var height_diff = abs(to_height - from_height)
	var max_step_height = GridCoordinates.GRID_SIZE * 1.5  # Max step without jumping
	
	return height_diff <= max_step_height

func get_terrain_slope(grid_pos: Vector3i, direction: Vector3i) -> float:
	# Get the slope in a given direction (for physics/movement)
	var current_height = get_height_at_grid_position(grid_pos)
	var next_pos = grid_pos + direction
	var next_height = get_height_at_grid_position(next_pos)
	
	var height_diff = next_height - current_height
	var horizontal_distance = GridCoordinates.GRID_SIZE
	
	return height_diff / horizontal_distance  # Slope as rise/run

func get_visible_terrain_cells(center_grid: Vector3i, radius: int) -> Array:
	# Get all terrain cells visible around a center position
	var visible_cells = []
	
	for x in range(center_grid.x - radius, center_grid.x + radius + 1):
		for z in range(center_grid.z - radius, center_grid.z + radius + 1):
			var cell_pos = Vector2i(x, z)
			if terrain_heights.has(cell_pos):
				visible_cells.append({
					"position": cell_pos,
					"height": terrain_heights[cell_pos]
				})
	
	return visible_cells
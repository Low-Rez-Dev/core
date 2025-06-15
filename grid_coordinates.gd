extends Node
class_name GridCoordinates

# Grid coordinate system: 1 meter = 20 units = 1 grid cell
const UNITS_PER_METER = 20
const GRID_SIZE = UNITS_PER_METER  # 20 units per grid cell

# Convert grid coordinates (meters) to world coordinates (units)
# X/Z are longitude/latitude, Y is altitude
static func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * GRID_SIZE, grid_pos.y * GRID_SIZE)

static func grid_to_world_3d(grid_pos: Vector3i) -> Vector3:
	return Vector3(grid_pos.x * GRID_SIZE, grid_pos.z * GRID_SIZE, grid_pos.y * GRID_SIZE)

# Convert world coordinates (units) to grid coordinates (meters)
static func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / GRID_SIZE), int(world_pos.y / GRID_SIZE))

static func world_to_grid_3d(world_pos: Vector3) -> Vector3i:
	return Vector3i(int(world_pos.x / GRID_SIZE), int(world_pos.z / GRID_SIZE), int(world_pos.y / GRID_SIZE))

# Snap world position to nearest grid cell center
static func snap_to_grid(world_pos: Vector2) -> Vector2:
	var grid_pos = world_to_grid(world_pos)
	return grid_to_world(grid_pos) + Vector2(GRID_SIZE / 2, GRID_SIZE / 2)

static func snap_to_grid_3d(world_pos: Vector3) -> Vector3:
	var grid_pos = world_to_grid_3d(world_pos)
	return grid_to_world_3d(grid_pos) + Vector3(GRID_SIZE / 2, GRID_SIZE / 2, GRID_SIZE / 2)

# Get grid cell boundaries
static func get_grid_cell_bounds(grid_pos: Vector2i) -> Rect2:
	var world_pos = grid_to_world(grid_pos)
	return Rect2(world_pos, Vector2(GRID_SIZE, GRID_SIZE))

# Check if two grid positions are adjacent (including diagonals)
static func are_adjacent(grid_a: Vector2i, grid_b: Vector2i) -> bool:
	var diff = grid_a - grid_b
	return abs(diff.x) <= 1 and abs(diff.y) <= 1 and (diff.x != 0 or diff.y != 0)

# Get all adjacent grid positions (8-directional)
static func get_adjacent_positions(grid_pos: Vector2i) -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			adjacent.append(grid_pos + Vector2i(x, y))
	return adjacent

# Get grid address as string (for easy building/plant tracking)
static func get_grid_address(grid_pos: Vector2i) -> String:
	return "(%d,%d)" % [grid_pos.x, grid_pos.y]

static func get_grid_address_3d(grid_pos: Vector3i) -> String:
	return "(%d,%d,%d)" % [grid_pos.x, grid_pos.y, grid_pos.z]

# Parse grid address back to position
static func parse_grid_address(address: String) -> Vector2i:
	var regex = RegEx.new()
	regex.compile(r"\((-?\d+),(-?\d+)\)")
	var result = regex.search(address)
	if result:
		return Vector2i(int(result.get_string(1)), int(result.get_string(2)))
	return Vector2i.ZERO

# Distance in grid cells
static func grid_distance(grid_a: Vector2i, grid_b: Vector2i) -> int:
	var diff = grid_a - grid_b
	return max(abs(diff.x), abs(diff.y))  # Chebyshev distance

# Manhattan distance in grid cells
static func grid_manhattan_distance(grid_a: Vector2i, grid_b: Vector2i) -> int:
	var diff = grid_a - grid_b
	return abs(diff.x) + abs(diff.y)
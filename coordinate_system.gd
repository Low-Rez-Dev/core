extends Node

enum Orientation {
	NORTH_SOUTH,  # X is movement axis, Z is depth lanes
	EAST_WEST     # Z is movement axis, X is depth lanes
}

signal orientation_changed(new_orientation)

var current_orientation = Orientation.NORTH_SOUTH
var grid_size: float = 1.0  # 1 meter per grid cell
var focus_lane_system: FocusLaneSystem
var terrain_system: TerrainSystem

func _ready():
	set_name("CoordinateSystem")
	
	# Create focus lane system
	focus_lane_system = FocusLaneSystem.new()
	add_child(focus_lane_system)
	
	# Create terrain system
	terrain_system = TerrainSystem.new()
	terrain_system.set_name("TerrainSystem")
	add_child(terrain_system)
	
	# For now, let dependent systems use direct access
	# CSLocator can be re-enabled once working properly
	print("CoordinateSystem ready with terrain and focus lane systems")

func get_movement_axis() -> String:
	match current_orientation:
		Orientation.NORTH_SOUTH:
			return "x"
		Orientation.EAST_WEST:
			return "z"
		_:
			return "x"

func get_depth_axis() -> String:
	match current_orientation:
		Orientation.NORTH_SOUTH:
			return "z"
		Orientation.EAST_WEST:
			return "x"
		_:
			return "z"

func snap_to_depth_grid(position: Vector3) -> Vector3:
	var snapped_pos = position
	match current_orientation:
		Orientation.NORTH_SOUTH:
			snapped_pos.z = round(position.z / grid_size) * grid_size
		Orientation.EAST_WEST:
			snapped_pos.x = round(position.x / grid_size) * grid_size
	return snapped_pos

func rotate_orientation_clockwise():
	match current_orientation:
		Orientation.NORTH_SOUTH:
			current_orientation = Orientation.EAST_WEST
		Orientation.EAST_WEST:
			current_orientation = Orientation.NORTH_SOUTH
	orientation_changed.emit(current_orientation)

func rotate_orientation_counterclockwise():
	rotate_orientation_clockwise()  # Only 2 orientations, so same result

func world_to_screen_direction(world_dir: Vector3) -> Vector2:
	match current_orientation:
		Orientation.NORTH_SOUTH:
			return Vector2(world_dir.x, -world_dir.y)  # Y becomes vertical on screen (flipped)
		Orientation.EAST_WEST:
			return Vector2(world_dir.z, -world_dir.y)  # Y becomes vertical on screen (flipped)
		_:
			return Vector2.ZERO

func get_forward_direction() -> Vector3:
	match current_orientation:
		Orientation.NORTH_SOUTH:
			return Vector3(1, 0, 0)  # Moving along X axis
		Orientation.EAST_WEST:
			return Vector3(0, 0, 1)  # Moving along Z axis
		_:
			return Vector3.ZERO

func get_depth_direction() -> Vector3:
	match current_orientation:
		Orientation.NORTH_SOUTH:
			return Vector3(0, 0, 1)  # Depth along Z axis
		Orientation.EAST_WEST:
			return Vector3(1, 0, 0)  # Depth along X axis
		_:
			return Vector3.ZERO

extends Node

# Singleton for coordinate system
var player_consciousness_pos: Vector2 = Vector2.ZERO
var player_z_layer: int = 0

# Side-stepping animation state
var is_side_stepping: bool = false
var side_step_elapsed: float = 0.0
var side_step_duration: float = 0.5
var side_step_start_pos: Vector2 = Vector2.ZERO
var side_step_target_pos: Vector2 = Vector2.ZERO

# Reality manifestation parameters
var perception_radius: float = 500.0
var perception_radius_squared: float = 250000.0  # Cached for performance
var render_entities: Array[VirtualEntity] = []
var all_entities: Array[VirtualEntity] = []

# The player's fixed position in subjective reality  
const CONSCIOUSNESS_CENTER: Vector2 = Vector2(320, 240)  # Screen center (640x480 viewport)

# Cardinal orientation system - how the observer perceives space
enum Orientation { EAST, SOUTH, WEST, NORTH }
var current_orientation: int = Orientation.EAST

# Coordinate transformation matrices for different orientations
var orientation_transforms = {
	Orientation.EAST:  { "move": Vector2(1, 0), "depth": Vector2(0, 1) },   # X=move, Z=depth
	Orientation.SOUTH: { "move": Vector2(0, -1), "depth": Vector2(1, 0) },  # Z=move, X=depth  
	Orientation.WEST:  { "move": Vector2(-1, 0), "depth": Vector2(0, -1) }, # -X=move, -Z=depth
	Orientation.NORTH: { "move": Vector2(0, 1), "depth": Vector2(-1, 0) }   # -Z=move, -X=depth
}

# Signals for reality shifts
signal consciousness_moved(new_position: Vector2)
signal orientation_changed(new_orientation: int)
signal entity_manifested(entity: VirtualEntity)
signal entity_dematerialized(entity: VirtualEntity)
signal side_step_started(direction: int)
signal side_step_completed()

# Helper functions for coordinate system
func get_current_lane_position() -> Vector2:
	"""Returns consciousness position with depth axis rounded to lane center"""
	var pos = player_consciousness_pos
	match current_orientation:
		Orientation.EAST, Orientation.WEST:
			# N-S is depth axis, round Y coordinate
			return Vector2(pos.x, round(pos.y))
		Orientation.NORTH, Orientation.SOUTH:
			# E-W is depth axis, round X coordinate
			return Vector2(round(pos.x), pos.y)
		_:
			return pos

func start_side_step(direction: int):
	"""Initiates a side-step animation in the given direction (+1 or -1)"""
	if is_side_stepping:
		return # Already side-stepping
	
	is_side_stepping = true
	side_step_elapsed = 0.0
	side_step_start_pos = player_consciousness_pos
	
	# Calculate target position based on current orientation
	var step_vector = Vector2.ZERO
	match current_orientation:
		Orientation.EAST, Orientation.WEST:
			# N-S is depth axis
			step_vector = Vector2(0, direction)
		Orientation.NORTH, Orientation.SOUTH:
			# E-W is depth axis  
			step_vector = Vector2(direction, 0)
	
	side_step_target_pos = get_current_lane_position() + step_vector
	side_step_started.emit(direction)

func update_side_step(delta: float):
	"""Updates side-step animation progress"""
	if not is_side_stepping:
		return
	
	side_step_elapsed += delta
	var progress = side_step_elapsed / side_step_duration
	
	if progress >= 1.0:
		# Animation complete
		progress = 1.0
		is_side_stepping = false
		side_step_completed.emit()
	
	# Update depth axis position with animation
	var animated_pos = side_step_start_pos.lerp(side_step_target_pos, progress)
	
	# Apply animated position to correct axis
	match current_orientation:
		Orientation.EAST, Orientation.WEST:
			# N-S is depth axis, update Y
			player_consciousness_pos.y = animated_pos.y
		Orientation.NORTH, Orientation.SOUTH:
			# E-W is depth axis, update X
			player_consciousness_pos.x = animated_pos.x

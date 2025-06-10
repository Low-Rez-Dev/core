extends Node
class_name SolipsisticCoordinates

# The observer's consciousness - the only fixed point in reality
static var player_consciousness_pos: Vector2 = Vector2.ZERO
static var player_z_layer: int = 0

# Reality manifestation parameters
static var perception_radius: float = 500.0
static var perception_radius_squared: float = 250000.0  # Cached for performance
static var render_entities: Array[VirtualEntity] = []
static var all_entities: Array[VirtualEntity] = []

# The player's fixed position in subjective reality
const CONSCIOUSNESS_CENTER: Vector2 = Vector2(640, 360)  # Screen center

# Cardinal orientation system - how the observer perceives space
enum Orientation { EAST, SOUTH, WEST, NORTH }
static var current_orientation: Orientation = Orientation.EAST

# Coordinate transformation matrices for different orientations
static var orientation_transforms = {
	Orientation.EAST:  { "move": Vector2(1, 0), "depth": Vector2(0, 1) },   # X=move, Z=depth
	Orientation.SOUTH: { "move": Vector2(0, -1), "depth": Vector2(1, 0) },  # Z=move, X=depth  
	Orientation.WEST:  { "move": Vector2(-1, 0), "depth": Vector2(0, -1) }, # -X=move, -Z=depth
	Orientation.NORTH: { "move": Vector2(0, 1), "depth": Vector2(-1, 0) }   # -Z=move, -X=depth
}

# Signals for reality shifts
signal consciousness_moved(new_position: Vector2)
signal orientation_changed(new_orientation: Orientation)
signal entity_manifested(entity: VirtualEntity)
signal entity_dematerialized(entity: VirtualEntity)
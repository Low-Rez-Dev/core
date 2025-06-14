extends Node2D
class_name VirtualEntity

# Virtual existence - the entity's "true" position independent of observer
var virtual_position: Vector2 = Vector2.ZERO
var virtual_z_layer: int = 0

# Manifestation state
var is_manifested: bool = false
var manifestation_distance: float = 0.0

# Visual properties affected by observation
var base_scale: Vector2 = Vector2.ONE
var base_modulate: Color = Color.WHITE

func _ready():
	# Register existence in the virtual world
	SolipsisticCoordinates.all_entities.append(self)
	
	# Start unmanifested
	visible = false
	is_manifested = false

func _exit_tree():
	# Remove from virtual world
	SolipsisticCoordinates.all_entities.erase(self)
	if is_manifested:
		SolipsisticCoordinates.render_entities.erase(self)

func update_manifestation():
	"""Updates whether this entity exists in the observer's reality"""
	# Calculate distance from player consciousness
	var coords = SolipsisticCoordinates
	var virtual_relative = virtual_position - coords.player_consciousness_pos
	var z_distance = abs(virtual_z_layer - coords.player_z_layer)
	
	# Fast distance check (avoid sqrt for performance)
	var distance_squared = virtual_relative.length_squared() + (z_distance * z_distance * 100)
	
	if distance_squared <= coords.perception_radius_squared:
		if not is_manifested:
			manifest_in_reality()
		update_subjective_position()
	else:
		if is_manifested:
			dematerialize_from_reality()

func manifest_in_reality():
	"""Brings entity into the observer's reality"""
	is_manifested = true
	visible = true
	SolipsisticCoordinates.render_entities.append(self)
	SolipsisticCoordinates.entity_manifested.emit(self)
	
	# Enable expensive components only when manifested
	enable_complex_behaviors()

func dematerialize_from_reality():
	"""Removes entity from observer's reality - it still exists, just not observed"""
	is_manifested = false
	visible = false
	SolipsisticCoordinates.render_entities.erase(self)
	SolipsisticCoordinates.entity_dematerialized.emit(self)
	
	# Disable expensive components when not observed
	disable_complex_behaviors()

func update_subjective_position():
	"""Updates the entity's position relative to the observer's fixed reality"""
	if not is_manifested:
		return
	
	# Get relative virtual position using the lane-aware consciousness position
	var coords = SolipsisticCoordinates
	var consciousness_lane_pos = coords.get_current_lane_position()
	var virtual_relative = virtual_position - consciousness_lane_pos
	
	# Transform to screen coordinates based on observer's orientation
	var screen_relative = virtual_to_screen_coords(virtual_relative)
	
	# Apply depth layer effects
	apply_depth_perception_effects()
	
	# Set final position relative to consciousness center
	position = coords.CONSCIOUSNESS_CENTER + screen_relative

func virtual_to_screen_coords(virtual_pos: Vector2) -> Vector2:
	"""Converts virtual world coordinates to observer's screen coordinates"""
	# virtual_pos.x = East/West world position
	# virtual_pos.y = North/South world position  
	var coords = SolipsisticCoordinates
	var scale = 20.0  # 20 pixels per meter
	match coords.current_orientation:
		coords.Orientation.EAST:   # Looking East: East/West is left/right, North/South is depth
			return Vector2(virtual_pos.x * scale, 0)  # East/West becomes horizontal movement
		coords.Orientation.SOUTH:  # Looking South: North/South is left/right, East/West is depth
			return Vector2(-virtual_pos.y * scale, 0)  # North/South becomes horizontal (flipped)
		coords.Orientation.WEST:   # Looking West: East/West is left/right (flipped), North/South is depth  
			return Vector2(-virtual_pos.x * scale, 0)  # East/West becomes horizontal (flipped)
		coords.Orientation.NORTH:  # Looking North: North/South is left/right, East/West is depth
			return Vector2(virtual_pos.y * scale, 0)   # North/South becomes horizontal
		_:
			return virtual_pos * scale

func apply_depth_perception_effects():
	"""Applies visual effects based on depth layer distance from observer"""
	var depth_offset = virtual_z_layer - SolipsisticCoordinates.player_z_layer
	var depth_distance = abs(depth_offset)
	
	# Depth scaling - further objects appear smaller
	var depth_scale = max(0.3, 1.0 - depth_distance * 0.15)
	scale = base_scale * depth_scale
	
	# Depth transparency - further objects fade
	var depth_alpha = max(0.2, 1.0 - depth_distance * 0.25)
	modulate = base_modulate
	modulate.a *= depth_alpha
	
	# Z-index for proper layering
	z_index = -virtual_z_layer

# Override these in subclasses for performance optimization
func enable_complex_behaviors():
	"""Called when entity manifests - enable VISUAL/AUDIO systems, particles, etc."""
	# Enable visual effects, detailed animations, sound effects
	# AI and logic ALWAYS run regardless of manifestation
	pass

func disable_complex_behaviors():
	"""Called when entity dematerializes - disable EXPENSIVE VISUAL operations"""
	# Disable particles, detailed animations, sound effects
	# AI and core logic continue running
	pass
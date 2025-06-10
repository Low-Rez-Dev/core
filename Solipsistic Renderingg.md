# ==============================================================================
# SOLIPSISTIC COORDINATES SYSTEM
# ==============================================================================
# A coordinate system where the player is the only fixed reality.
# All entities exist in virtual space but only manifest when observed.
# Perfect for tactical games with massive worlds but focused local gameplay.

# ==============================================================================
# CORE SYSTEM - The Player's Subjective Reality
# ==============================================================================

class_name SolipsisticCoordinates extends Node

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

# ==============================================================================
# VIRTUAL ENTITY - Exists in Potential Until Observed
# ==============================================================================

class_name VirtualEntity extends Node2D

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
    var virtual_relative = virtual_position - SolipsisticCoordinates.player_consciousness_pos
    var z_distance = abs(virtual_z_layer - SolipsisticCoordinates.player_z_layer)
    
    # Fast distance check (avoid sqrt for performance)
    var distance_squared = virtual_relative.length_squared() + (z_distance * z_distance * 100)
    
    if distance_squared <= SolipsisticCoordinates.perception_radius_squared:
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
    
    # Get relative virtual position
    var virtual_relative = virtual_position - SolipsisticCoordinates.player_consciousness_pos
    
    # Transform to screen coordinates based on observer's orientation
    var screen_relative = virtual_to_screen_coords(virtual_relative)
    
    # Apply depth layer effects
    apply_depth_perception_effects()
    
    # Set final position relative to consciousness center
    position = SolipsisticCoordinates.CONSCIOUSNESS_CENTER + screen_relative

func virtual_to_screen_coords(virtual_pos: Vector2) -> Vector2:
    """Converts virtual world coordinates to observer's screen coordinates"""
    match SolipsisticCoordinates.current_orientation:
        SolipsisticCoordinates.Orientation.EAST:   # X=horizontal, Z=vertical  
            return Vector2(virtual_pos.x, virtual_pos.y)
        SolipsisticCoordinates.Orientation.SOUTH:  # Z=horizontal, X=vertical
            return Vector2(-virtual_pos.y, virtual_pos.x)  
        SolipsisticCoordinates.Orientation.WEST:   # -X=horizontal, -Z=vertical
            return Vector2(-virtual_pos.x, -virtual_pos.y)
        SolipsisticCoordinates.Orientation.NORTH:  # -Z=horizontal, -X=vertical  
            return Vector2(virtual_pos.y, -virtual_pos.x)
        _:
            return virtual_pos

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

# ==============================================================================
# PLAYER CONTROLLER - The Observer's Interface to Reality
# ==============================================================================

class_name SolipsisticPlayer extends Node2D

@export var movement_speed: float = 200.0
@export var can_change_z_layers: bool = true

# Input state
var move_input: float = 0.0
var depth_input: float = 0.0

func _ready():
    # Player always exists at the center of their own reality
    position = SolipsisticCoordinates.CONSCIOUSNESS_CENTER

func _process(delta):
    handle_orientation_input()
    handle_movement_input(delta)
    handle_depth_input()
    
    # Update all entities' manifestation state
    update_reality_manifestation()

func handle_orientation_input():
    """Handle rotation of the observer's perspective"""
    if Input.is_action_just_pressed("rotate_clockwise"):    # Q key
        var new_orientation = (SolipsisticCoordinates.current_orientation + 1) % 4
        change_orientation(new_orientation)
    elif Input.is_action_just_pressed("rotate_counter"):    # E key
        var new_orientation = (SolipsisticCoordinates.current_orientation - 1) % 4
        if new_orientation < 0:
            new_orientation = 3
        change_orientation(new_orientation)

func change_orientation(new_orientation: int):
    """Changes how the observer perceives spatial relationships"""
    SolipsisticCoordinates.current_orientation = new_orientation
    SolipsisticCoordinates.orientation_changed.emit(new_orientation)
    
    var orientation_names = ["EAST", "SOUTH", "WEST", "NORTH"]
    print("Observer now perceives reality facing: %s" % orientation_names[new_orientation])

func handle_movement_input(delta):
    """Handle movement along the observer's current axis of perception"""
    move_input = 0.0
    
    # A/D moves along current facing axis
    if Input.is_action_pressed("move_backward"):  # A key
        move_input = -1.0
    elif Input.is_action_pressed("move_forward"): # D key  
        move_input = 1.0
    
    if move_input != 0.0:
        # Transform input to virtual world movement
        var transform = SolipsisticCoordinates.orientation_transforms[SolipsisticCoordinates.current_orientation]
        var world_movement = transform.move * move_input * movement_speed * delta
        
        # Update consciousness position in virtual space
        SolipsisticCoordinates.player_consciousness_pos += world_movement
        SolipsisticCoordinates.consciousness_moved.emit(SolipsisticCoordinates.player_consciousness_pos)

func handle_depth_input():
    """Handle movement between depth layers"""
    if not can_change_z_layers:
        return
    
    if Input.is_action_just_pressed("layer_forward"):   # R key
        SolipsisticCoordinates.player_z_layer += 1
        print("Observer shifted to depth layer: %d" % SolipsisticCoordinates.player_z_layer)
    elif Input.is_action_just_pressed("layer_backward"): # F key
        SolipsisticCoordinates.player_z_layer -= 1
        print("Observer shifted to depth layer: %d" % SolipsisticCoordinates.player_z_layer)

func update_reality_manifestation():
    """Updates which entities exist in the observer's current reality"""
    for entity in SolipsisticCoordinates.all_entities:
        entity.update_manifestation()

# ==============================================================================
# WORLD MANAGER - Manages the Virtual Reality
# ==============================================================================

class_name SolipsisticWorld extends Node

@export var enable_spatial_partitioning: bool = true
@export var grid_size: int = 128
@export var max_manifested_entities: int = 200

# Spatial partitioning for performance
var entity_grid: Dictionary = {}  # Vector2i -> Array[VirtualEntity]

func _ready():
    # Connect to consciousness events
    SolipsisticCoordinates.consciousness_moved.connect(_on_consciousness_moved)
    SolipsisticCoordinates.entity_manifested.connect(_on_entity_manifested)
    SolipsisticCoordinates.entity_dematerialized.connect(_on_entity_dematerialized)

func spawn_entity(entity_scene: PackedScene, virtual_pos: Vector2, z_layer: int = 0) -> VirtualEntity:
    """Spawns an entity in virtual space"""
    var entity = entity_scene.instantiate() as VirtualEntity
    entity.virtual_position = virtual_pos
    entity.virtual_z_layer = z_layer
    
    add_child(entity)
    
    if enable_spatial_partitioning:
        add_to_spatial_grid(entity)
    
    return entity

func add_to_spatial_grid(entity: VirtualEntity):
    """Adds entity to spatial partitioning grid for performance"""
    var grid_pos = Vector2i(entity.virtual_position / grid_size)
    if not entity_grid.has(grid_pos):
        entity_grid[grid_pos] = []
    entity_grid[grid_pos].append(entity)

func get_entities_near_consciousness(radius: float) -> Array[VirtualEntity]:
    """Gets entities near the observer's consciousness - useful for AI, physics, etc."""
    if not enable_spatial_partitioning:
        return SolipsisticCoordinates.all_entities
    
    var results: Array[VirtualEntity] = []
    var grid_radius = ceili(radius / grid_size)
    var center_grid = Vector2i(SolipsisticCoordinates.player_consciousness_pos / grid_size)
    
    for x in range(-grid_radius, grid_radius + 1):
        for y in range(-grid_radius, grid_radius + 1):
            var grid_pos = center_grid + Vector2i(x, y)
            if entity_grid.has(grid_pos):
                results.append_array(entity_grid[grid_pos])
    
    return results

func _on_consciousness_moved(new_position: Vector2):
    """Called when the observer's consciousness moves in virtual space"""
    # Manage entity manifestation based on new position
    # Could trigger streaming of new areas, AI activation, etc.
    pass

func _on_entity_manifested(entity: VirtualEntity):
    """Called when an entity enters the observer's reality"""
    print("Entity manifested: %s at %s" % [entity.name, entity.virtual_position])
    
    # Limit total manifested entities for performance
    if SolipsisticCoordinates.render_entities.size() > max_manifested_entities:
        # Find furthest entity and dematerialize it
        var furthest_entity = find_furthest_manifested_entity()
        if furthest_entity:
            furthest_entity.dematerialize_from_reality()

func _on_entity_dematerialized(entity: VirtualEntity):
    """Called when an entity leaves the observer's reality"""
    print("Entity dematerialized: %s (continues existing at %s)" % [entity.name, entity.virtual_position])
    # Entity still exists in virtual space and continues autonomous behavior!

func find_furthest_manifested_entity() -> VirtualEntity:
    """Finds the manifested entity furthest from consciousness"""
    var furthest: VirtualEntity = null
    var max_distance: float = 0.0
    
    for entity in SolipsisticCoordinates.render_entities:
        var distance = entity.virtual_position.distance_squared_to(SolipsisticCoordinates.player_consciousness_pos)
        if distance > max_distance:
            max_distance = distance
            furthest = entity
    
    return furthest

# ==============================================================================
# EXAMPLE USAGE - How to Implement Solipsistic Coordinates
# ==============================================================================

# Example scene setup:
# Main (Node2D)
# ├── SolipsisticWorld
# ├── SolipsisticPlayer
# └── UI (CanvasLayer)
#     └── OrientationDisplay (Label)

# Example entity with autonomous behavior:
class_name ExampleEnemy extends VirtualEntity

var patrol_points: Array[Vector2] = []
var current_target: int = 0
var move_speed: float = 50.0
var detailed_animations_enabled: bool = false

func _ready():
    super._ready()
    # Set up patrol route in virtual space
    patrol_points = [
        virtual_position + Vector2(100, 0),
        virtual_position + Vector2(100, 100), 
        virtual_position + Vector2(0, 100),
        virtual_position
    ]

func enable_complex_behaviors():
    # Enable expensive visual/audio systems when observed
    detailed_animations_enabled = true
    # Enable particles, detailed sprites, sound effects, etc.
    set_sprite_detail_level(DETAIL_HIGH)
    enable_particle_systems()

func disable_complex_behaviors():
    # Disable expensive visuals when not observed - but keep AI running!
    detailed_animations_enabled = false
    set_sprite_detail_level(DETAIL_LOW)
    disable_particle_systems()

func _process(delta):
    # AI ALWAYS runs - even when not manifested!
    update_ai(delta)
    
    # Expensive visuals only when observed
    if is_manifested and detailed_animations_enabled:
        update_detailed_animations(delta)
        update_sound_effects()

func update_ai(delta):
    """AI runs continuously regardless of manifestation"""
    # Move toward current patrol point
    var target_pos = patrol_points[current_target]
    var direction = (target_pos - virtual_position).normalized()
    virtual_position += direction * move_speed * delta
    
    # Check if reached target
    if virtual_position.distance_to(target_pos) < 10:
        current_target = (current_target + 1) % patrol_points.size()
    
    # AI can interact with other entities even when not manifested
    check_for_nearby_entities()
    update_combat_logic()

func update_detailed_animations(delta):
    """Expensive visual updates only when manifested"""
    # Complex sprite animations, particle trails, etc.
    pass

# ==============================================================================
# AUTONOMOUS WORLD SIMULATION
# ==============================================================================

class_name WorldSimulation extends Node

# All entities continue their logic here
var autonomous_entities: Array[VirtualEntity] = []
var simulation_timer: float = 0.0
var simulation_rate: float = 0.1  # Update 10 times per second

func _ready():
    # Register all autonomous entities
    for entity in SolipsisticCoordinates.all_entities:
        if entity.has_method("update_autonomous_behavior"):
            autonomous_entities.append(entity)

func _process(delta):
    simulation_timer += delta
    if simulation_timer >= simulation_rate:
        simulation_timer = 0.0
        update_world_simulation()

func update_world_simulation():
    """Updates all entity behaviors regardless of manifestation"""
    for entity in autonomous_entities:
        # Entities continue existing and acting in virtual space
        entity.update_autonomous_behavior()
        
        # Handle entity-to-entity interactions
        check_entity_interactions(entity)

func check_entity_interactions(entity: VirtualEntity):
    """Entities can interact even when not manifested"""
    # Check combat, trading, communication, etc.
    var nearby = get_nearby_autonomous_entities(entity, 100.0)
    for other in nearby:
        if entity != other:
            entity.interact_with(other)

# Example UI update:
func update_orientation_display():
    var orientation_names = ["EAST", "SOUTH", "WEST", "NORTH"]
    var move_axis = ["X-axis", "Z-axis", "X-axis", "Z-axis"]
    var depth_axis = ["Z-axis", "X-axis", "Z-axis", "X-axis"]
    
    orientation_label.text = """Observer Facing: %s
Movement Axis: %s  
Depth Axis: %s
Consciousness: %.0f, %.0f
Layer: %d
Manifested Entities: %d""" % [
        orientation_names[SolipsisticCoordinates.current_orientation],
        move_axis[SolipsisticCoordinates.current_orientation],
        depth_axis[SolipsisticCoordinates.current_orientation],
        SolipsisticCoordinates.player_consciousness_pos.x,
        SolipsisticCoordinates.player_consciousness_pos.y,
        SolipsisticCoordinates.player_z_layer,
        SolipsisticCoordinates.render_entities.size()
    ]# ==============================================================================
# SOLIPSISTIC COORDINATES SYSTEM
# ==============================================================================
# A coordinate system where the player is the only fixed reality.
# All entities exist in virtual space but only manifest when observed.
# Perfect for tactical games with massive worlds but focused local gameplay.

# ==============================================================================
# CORE SYSTEM - The Player's Subjective Reality
# ==============================================================================

class_name SolipsisticCoordinates extends Node

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

# ==============================================================================
# VIRTUAL ENTITY - Exists in Potential Until Observed
# ==============================================================================

class_name VirtualEntity extends Node2D

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
    var virtual_relative = virtual_position - SolipsisticCoordinates.player_consciousness_pos
    var z_distance = abs(virtual_z_layer - SolipsisticCoordinates.player_z_layer)
    
    # Fast distance check (avoid sqrt for performance)
    var distance_squared = virtual_relative.length_squared() + (z_distance * z_distance * 100)
    
    if distance_squared <= SolipsisticCoordinates.perception_radius_squared:
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
    
    # Get relative virtual position
    var virtual_relative = virtual_position - SolipsisticCoordinates.player_consciousness_pos
    
    # Transform to screen coordinates based on observer's orientation
    var screen_relative = virtual_to_screen_coords(virtual_relative)
    
    # Apply depth layer effects
    apply_depth_perception_effects()
    
    # Set final position relative to consciousness center
    position = SolipsisticCoordinates.CONSCIOUSNESS_CENTER + screen_relative

func virtual_to_screen_coords(virtual_pos: Vector2) -> Vector2:
    """Converts virtual world coordinates to observer's screen coordinates"""
    match SolipsisticCoordinates.current_orientation:
        SolipsisticCoordinates.Orientation.EAST:   # X=horizontal, Z=vertical  
            return Vector2(virtual_pos.x, virtual_pos.y)
        SolipsisticCoordinates.Orientation.SOUTH:  # Z=horizontal, X=vertical
            return Vector2(-virtual_pos.y, virtual_pos.x)  
        SolipsisticCoordinates.Orientation.WEST:   # -X=horizontal, -Z=vertical
            return Vector2(-virtual_pos.x, -virtual_pos.y)
        SolipsisticCoordinates.Orientation.NORTH:  # -Z=horizontal, -X=vertical  
            return Vector2(virtual_pos.y, -virtual_pos.x)
        _:
            return virtual_pos

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

# ==============================================================================
# PLAYER CONTROLLER - The Observer's Interface to Reality
# ==============================================================================

class_name SolipsisticPlayer extends Node2D

@export var movement_speed: float = 200.0
@export var can_change_z_layers: bool = true

# Input state
var move_input: float = 0.0
var depth_input: float = 0.0

func _ready():
    # Player always exists at the center of their own reality
    position = SolipsisticCoordinates.CONSCIOUSNESS_CENTER

func _process(delta):
    handle_orientation_input()
    handle_movement_input(delta)
    handle_depth_input()
    
    # Update all entities' manifestation state
    update_reality_manifestation()

func handle_orientation_input():
    """Handle rotation of the observer's perspective"""
    if Input.is_action_just_pressed("rotate_clockwise"):    # Q key
        var new_orientation = (SolipsisticCoordinates.current_orientation + 1) % 4
        change_orientation(new_orientation)
    elif Input.is_action_just_pressed("rotate_counter"):    # E key
        var new_orientation = (SolipsisticCoordinates.current_orientation - 1) % 4
        if new_orientation < 0:
            new_orientation = 3
        change_orientation(new_orientation)

func change_orientation(new_orientation: int):
    """Changes how the observer perceives spatial relationships"""
    SolipsisticCoordinates.current_orientation = new_orientation
    SolipsisticCoordinates.orientation_changed.emit(new_orientation)
    
    var orientation_names = ["EAST", "SOUTH", "WEST", "NORTH"]
    print("Observer now perceives reality facing: %s" % orientation_names[new_orientation])

func handle_movement_input(delta):
    """Handle movement along the observer's current axis of perception"""
    move_input = 0.0
    
    # A/D moves along current facing axis
    if Input.is_action_pressed("move_backward"):  # A key
        move_input = -1.0
    elif Input.is_action_pressed("move_forward"): # D key  
        move_input = 1.0
    
    if move_input != 0.0:
        # Transform input to virtual world movement
        var transform = SolipsisticCoordinates.orientation_transforms[SolipsisticCoordinates.current_orientation]
        var world_movement = transform.move * move_input * movement_speed * delta
        
        # Update consciousness position in virtual space
        SolipsisticCoordinates.player_consciousness_pos += world_movement
        SolipsisticCoordinates.consciousness_moved.emit(SolipsisticCoordinates.player_consciousness_pos)

func handle_depth_input():
    """Handle movement between depth layers"""
    if not can_change_z_layers:
        return
    
    if Input.is_action_just_pressed("layer_forward"):   # R key
        SolipsisticCoordinates.player_z_layer += 1
        print("Observer shifted to depth layer: %d" % SolipsisticCoordinates.player_z_layer)
    elif Input.is_action_just_pressed("layer_backward"): # F key
        SolipsisticCoordinates.player_z_layer -= 1
        print("Observer shifted to depth layer: %d" % SolipsisticCoordinates.player_z_layer)

func update_reality_manifestation():
    """Updates which entities exist in the observer's current reality"""
    for entity in SolipsisticCoordinates.all_entities:
        entity.update_manifestation()

# ==============================================================================
# WORLD MANAGER - Manages the Virtual Reality
# ==============================================================================

class_name SolipsisticWorld extends Node

@export var enable_spatial_partitioning: bool = true
@export var grid_size: int = 128
@export var max_manifested_entities: int = 200

# Spatial partitioning for performance
var entity_grid: Dictionary = {}  # Vector2i -> Array[VirtualEntity]

func _ready():
    # Connect to consciousness events
    SolipsisticCoordinates.consciousness_moved.connect(_on_consciousness_moved)
    SolipsisticCoordinates.entity_manifested.connect(_on_entity_manifested)
    SolipsisticCoordinates.entity_dematerialized.connect(_on_entity_dematerialized)

func spawn_entity(entity_scene: PackedScene, virtual_pos: Vector2, z_layer: int = 0) -> VirtualEntity:
    """Spawns an entity in virtual space"""
    var entity = entity_scene.instantiate() as VirtualEntity
    entity.virtual_position = virtual_pos
    entity.virtual_z_layer = z_layer
    
    add_child(entity)
    
    if enable_spatial_partitioning:
        add_to_spatial_grid(entity)
    
    return entity

func add_to_spatial_grid(entity: VirtualEntity):
    """Adds entity to spatial partitioning grid for performance"""
    var grid_pos = Vector2i(entity.virtual_position / grid_size)
    if not entity_grid.has(grid_pos):
        entity_grid[grid_pos] = []
    entity_grid[grid_pos].append(entity)

func get_entities_near_consciousness(radius: float) -> Array[VirtualEntity]:
    """Gets entities near the observer's consciousness - useful for AI, physics, etc."""
    if not enable_spatial_partitioning:
        return SolipsisticCoordinates.all_entities
    
    var results: Array[VirtualEntity] = []
    var grid_radius = ceili(radius / grid_size)
    var center_grid = Vector2i(SolipsisticCoordinates.player_consciousness_pos / grid_size)
    
    for x in range(-grid_radius, grid_radius + 1):
        for y in range(-grid_radius, grid_radius + 1):
            var grid_pos = center_grid + Vector2i(x, y)
            if entity_grid.has(grid_pos):
                results.append_array(entity_grid[grid_pos])
    
    return results

func _on_consciousness_moved(new_position: Vector2):
    """Called when the observer's consciousness moves in virtual space"""
    # Manage entity manifestation based on new position
    # Could trigger streaming of new areas, AI activation, etc.
    pass

func _on_entity_manifested(entity: VirtualEntity):
    """Called when an entity enters the observer's reality"""
    print("Entity manifested: %s at %s" % [entity.name, entity.virtual_position])
    
    # Limit total manifested entities for performance
    if SolipsisticCoordinates.render_entities.size() > max_manifested_entities:
        # Find furthest entity and dematerialize it
        var furthest_entity = find_furthest_manifested_entity()
        if furthest_entity:
            furthest_entity.dematerialize_from_reality()

func _on_entity_dematerialized(entity: VirtualEntity):
    """Called when an entity leaves the observer's reality"""
    print("Entity dematerialized: %s (continues existing at %s)" % [entity.name, entity.virtual_position])
    # Entity still exists in virtual space and continues autonomous behavior!

func find_furthest_manifested_entity() -> VirtualEntity:
    """Finds the manifested entity furthest from consciousness"""
    var furthest: VirtualEntity = null
    var max_distance: float = 0.0
    
    for entity in SolipsisticCoordinates.render_entities:
        var distance = entity.virtual_position.distance_squared_to(SolipsisticCoordinates.player_consciousness_pos)
        if distance > max_distance:
            max_distance = distance
            furthest = entity
    
    return furthest

# ==============================================================================
# EXAMPLE USAGE - How to Implement Solipsistic Coordinates
# ==============================================================================

# Example scene setup:
# Main (Node2D)
# ├── SolipsisticWorld
# ├── SolipsisticPlayer
# └── UI (CanvasLayer)
#     └── OrientationDisplay (Label)

# Example entity with autonomous behavior:
class_name ExampleEnemy extends VirtualEntity

var patrol_points: Array[Vector2] = []
var current_target: int = 0
var move_speed: float = 50.0
var detailed_animations_enabled: bool = false

func _ready():
    super._ready()
    # Set up patrol route in virtual space
    patrol_points = [
        virtual_position + Vector2(100, 0),
        virtual_position + Vector2(100, 100), 
        virtual_position + Vector2(0, 100),
        virtual_position
    ]

func enable_complex_behaviors():
    # Enable expensive visual/audio systems when observed
    detailed_animations_enabled = true
    # Enable particles, detailed sprites, sound effects, etc.
    set_sprite_detail_level(DETAIL_HIGH)
    enable_particle_systems()

func disable_complex_behaviors():
    # Disable expensive visuals when not observed - but keep AI running!
    detailed_animations_enabled = false
    set_sprite_detail_level(DETAIL_LOW)
    disable_particle_systems()

func _process(delta):
    # AI ALWAYS runs - even when not manifested!
    update_ai(delta)
    
    # Expensive visuals only when observed
    if is_manifested and detailed_animations_enabled:
        update_detailed_animations(delta)
        update_sound_effects()

func update_ai(delta):
    """AI runs continuously regardless of manifestation"""
    # Move toward current patrol point
    var target_pos = patrol_points[current_target]
    var direction = (target_pos - virtual_position).normalized()
    virtual_position += direction * move_speed * delta
    
    # Check if reached target
    if virtual_position.distance_to(target_pos) < 10:
        current_target = (current_target + 1) % patrol_points.size()
    
    # AI can interact with other entities even when not manifested
    check_for_nearby_entities()
    update_combat_logic()

func update_detailed_animations(delta):
    """Expensive visual updates only when manifested"""
    # Complex sprite animations, particle trails, etc.
    pass

# ==============================================================================
# AUTONOMOUS WORLD SIMULATION
# ==============================================================================

class_name WorldSimulation extends Node

# All entities continue their logic here
var autonomous_entities: Array[VirtualEntity] = []
var simulation_timer: float = 0.0
var simulation_rate: float = 0.1  # Update 10 times per second

func _ready():
    # Register all autonomous entities
    for entity in SolipsisticCoordinates.all_entities:
        if entity.has_method("update_autonomous_behavior"):
            autonomous_entities.append(entity)

func _process(delta):
    simulation_timer += delta
    if simulation_timer >= simulation_rate:
        simulation_timer = 0.0
        update_world_simulation()

func update_world_simulation():
    """Updates all entity behaviors regardless of manifestation"""
    for entity in autonomous_entities:
        # Entities continue existing and acting in virtual space
        entity.update_autonomous_behavior()
        
        # Handle entity-to-entity interactions
        check_entity_interactions(entity)

func check_entity_interactions(entity: VirtualEntity):
    """Entities can interact even when not manifested"""
    # Check combat, trading, communication, etc.
    var nearby = get_nearby_autonomous_entities(entity, 100.0)
    for other in nearby:
        if entity != other:
            entity.interact_with(other)

# Example UI update:
func update_orientation_display():
    var orientation_names = ["EAST", "SOUTH", "WEST", "NORTH"]
    var move_axis = ["X-axis", "Z-axis", "X-axis", "Z-axis"]
    var depth_axis = ["Z-axis", "X-axis", "Z-axis", "X-axis"]
    
    orientation_label.text = """Observer Facing: %s
Movement Axis: %s  
Depth Axis: %s
Consciousness: %.0f, %.0f
Layer: %d
Manifested Entities: %d""" % [
        orientation_names[SolipsisticCoordinates.current_orientation],
        move_axis[SolipsisticCoordinates.current_orientation],
        depth_axis[SolipsisticCoordinates.current_orientation],
        SolipsisticCoordinates.player_consciousness_pos.x,
        SolipsisticCoordinates.player_consciousness_pos.y,
        SolipsisticCoordinates.player_z_layer,
        SolipsisticCoordinates.render_entities.size()
    ]
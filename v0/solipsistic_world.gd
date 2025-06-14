extends Node
class_name SolipsisticWorld

@export var enable_spatial_partitioning: bool = true
@export var grid_size: int = 128
@export var max_manifested_entities: int = 200

# Spatial partitioning for performance
var entity_grid: Dictionary = {}  # Vector2i -> Array[VirtualEntity]

# Terrain system
var terrain_system: TerrainSystem
var terrain_renderer: TerrainRenderer

func _ready():
	# Add to group for easy access
	add_to_group("SolipsisticWorld")
	
	# Connect to consciousness events
	var coords = SolipsisticCoordinates
	coords.consciousness_moved.connect(_on_consciousness_moved)
	coords.entity_manifested.connect(_on_entity_manifested)
	coords.entity_dematerialized.connect(_on_entity_dematerialized)
	
	# Set up terrain system
	setup_terrain_system()
	
	# Set up test world after a frame to ensure everything is initialized
	call_deferred("setup_test_world")

func setup_terrain_system():
	print("🏔️ Setting up terrain system...")
	
	# Create terrain system
	terrain_system = TerrainSystem.new()
	add_child(terrain_system)
	
	# Create terrain renderer on background layer
	terrain_renderer = TerrainRenderer.new()
	terrain_renderer.setup(terrain_system)
	
	# Add to background layer so it renders behind entities
	var background_layer = get_node("BackgroundLayer")
	if background_layer:
		background_layer.add_child(terrain_renderer)
	else:
		add_child(terrain_renderer)
	
	print("✅ Terrain system ready!")

func setup_test_world():
	TestSceneSetup.setup_test_world(self)

func spawn_entity(entity_scene: PackedScene, virtual_pos: Vector2, z_layer: int = 0) -> VirtualEntity:
	"""Spawns an entity in virtual space"""
	var entity = entity_scene.instantiate() as VirtualEntity
	entity.virtual_position = virtual_pos
	entity.virtual_z_layer = z_layer
	
	add_child(entity)
	
	if enable_spatial_partitioning:
		add_to_spatial_grid(entity)
	
	return entity

func spawn_entity_direct(entity: VirtualEntity, virtual_pos: Vector2, z_layer: int = 0) -> VirtualEntity:
	"""Spawns an entity instance directly in virtual space"""
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
	var coords = SolipsisticCoordinates
	if not enable_spatial_partitioning:
		return coords.all_entities
	
	var results: Array[VirtualEntity] = []
	var grid_radius = ceili(radius / grid_size)
	var center_grid = Vector2i(coords.player_consciousness_pos / grid_size)
	
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
	var coords = SolipsisticCoordinates
	if coords.render_entities.size() > max_manifested_entities:
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
	var coords = SolipsisticCoordinates
	
	for entity in coords.render_entities:
		var distance = entity.virtual_position.distance_squared_to(coords.player_consciousness_pos)
		if distance > max_distance:
			max_distance = distance
			furthest = entity
	
	return furthest

# Terrain helper functions
func get_terrain_height_at(world_pos: Vector2) -> float:
	"""Get terrain height at world position"""
	if terrain_system:
		return terrain_system.get_height_at_world_pos(world_pos)
	return 0.0

func can_walk_between_positions(pos1: Vector2, pos2: Vector2) -> bool:
	"""Check if movement between positions is walkable"""
	if terrain_system:
		return terrain_system.can_walk_between(pos1, pos2)
	return true

func should_activate_edge_hang(pos: Vector2, direction: Vector2) -> bool:
	"""Check if edge hanging should activate"""
	if terrain_system:
		return terrain_system.should_activate_edge_hang(pos, direction)
	return false

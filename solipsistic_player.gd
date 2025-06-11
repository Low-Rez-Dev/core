extends ProceduralEntity
class_name SolipsisticPlayer

@export var movement_speed: float = 4.0  # 4 m/s walking speed (realistic human)
@export var can_change_z_layers: bool = true

# Physics constants (realistic for 1 unit = 1 meter)
@export var gravity_strength: float = 9.8   # 9.8 m/s² (Earth gravity)
@export var jump_force: float = 3.5        # 3.5 m/s upward (gives ~0.6m jump height)
@export var max_fall_speed: float = 15.0   # 15 m/s terminal velocity
@export var ground_snap_distance: float = 0.1  # 10cm snap distance

# Input state
var move_input: float = 0.0
var depth_input: float = 0.0

# Physics state
var vertical_velocity: float = 0.0  # Current Y velocity (positive = falling)
var current_height: float = 0.0  # Current Y position above terrain
var is_grounded: bool = false

# IK data from ported body controller
var left_arm_data: Dictionary = {}
var right_arm_data: Dictionary = {}
var facing_right: bool = true

# Input handling and body control
var input_handler: SolipsisticInput
var body_controller: SolipsisticBodyController

func _ready():
	super._ready()
	# Add to group for HUD access
	add_to_group("Player")
	
	# Player always exists at the center of their own reality
	position = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	
	# Set reasonable player visual properties
	entity_size = 40.0
	primary_color = Color.BLUE
	secondary_color = Color.LIGHT_BLUE
	outline_color = Color.DARK_BLUE
	outline_width = 2.0
	
	# Player is always manifested and visible (at consciousness center)
	is_manifested = true
	visible = true
	
	# Player exists at consciousness position in virtual space
	virtual_position = Vector2.ZERO  # Center of virtual world
	virtual_z_layer = 0
	
	# Set up body controller
	body_controller = SolipsisticBodyController.new()
	body_controller.setup(self)
	add_child(body_controller)
	
	# Set up input handler
	input_handler = SolipsisticInput.new()
	input_handler.setup(self, body_controller)
	add_child(input_handler)
	
	# Initialize physics state after terrain is available
	call_deferred("initialize_physics_state")
	
	# Also try immediate initialization as backup
	initialize_physics_state()

func _process(delta):
	handle_orientation_input()
	handle_movement_input(delta)
	handle_depth_input()
	handle_jump_input()
	apply_gravity_and_physics(delta)
	
	# Update side-step animation
	SolipsisticCoordinates.update_side_step(delta)
	
	# Update all entities' manifestation state
	update_reality_manifestation()

func set_input_handler(handler: SolipsisticInput):
	input_handler = handler

func handle_orientation_input():
	"""Handle rotation of the observer's perspective"""
	var coords = SolipsisticCoordinates
	if Input.is_action_just_pressed("rotate_clockwise"):    # Q key
		var new_orientation = (coords.current_orientation + 1) % 4
		change_orientation(new_orientation)
	elif Input.is_action_just_pressed("rotate_counter"):    # E key
		var new_orientation = (coords.current_orientation - 1) % 4
		if new_orientation < 0:
			new_orientation = 3
		change_orientation(new_orientation)

func change_orientation(new_orientation: int):
	"""Changes how the observer perceives spatial relationships"""
	var coords = SolipsisticCoordinates
	coords.current_orientation = new_orientation
	coords.orientation_changed.emit(new_orientation)
	
	var orientation_names = ["EAST", "SOUTH", "WEST", "NORTH"]
	print("Observer now perceives reality facing: %s" % orientation_names[new_orientation])

func handle_movement_input(delta):
	"""Handle movement along the observer's current axis of perception"""
	if not input_handler:
		return
	
	var movement_2d = input_handler.get_movement_direction()
	move_input = movement_2d.x
	
	if move_input != 0.0:
		# Transform input to virtual world movement on the movement axis only
		var coords = SolipsisticCoordinates
		var transform = coords.orientation_transforms[coords.current_orientation]
		var world_movement = transform.move * move_input * movement_speed * delta
		
		# Update consciousness position on movement axis only
		# The depth axis position is managed separately by side-stepping
		match coords.current_orientation:
			coords.Orientation.EAST, coords.Orientation.WEST:
				# E-W is movement axis, update X coordinate only
				coords.player_consciousness_pos.x += world_movement.x
			coords.Orientation.NORTH, coords.Orientation.SOUTH:
				# N-S is movement axis, update Y coordinate only  
				coords.player_consciousness_pos.y += world_movement.y
		
		coords.consciousness_moved.emit(coords.player_consciousness_pos)

func handle_depth_input():
	"""Handle side-stepping between depth lanes"""
	if not can_change_z_layers:
		return
	
	var coords = SolipsisticCoordinates
	if Input.is_action_just_pressed("layer_forward"):   # R key
		coords.start_side_step(1)  # Step forward in depth
		print("Observer side-stepping forward on depth axis")
	elif Input.is_action_just_pressed("layer_backward"): # F key
		coords.start_side_step(-1)  # Step backward in depth
		print("Observer side-stepping backward on depth axis")

func update_reality_manifestation():
	"""Updates which entities exist in the observer's current reality"""
	for entity in SolipsisticCoordinates.all_entities:
		if entity != self:  # Don't update own manifestation
			entity.update_manifestation()

# Override manifestation functions - player is always manifested
func update_manifestation():
	# Player never changes manifestation - always visible at consciousness center
	pass

# Override entity type for procedural drawing
func get_entity_type() -> String:
	return "player"

# Provide arm position data for procedural drawing
func get_arm_positions() -> Dictionary:
	return {
		"left_shoulder": Vector2(-12, -17),
		"left_elbow": left_arm_data.get("elbow", Vector2(-20, -10)),
		"left_hand": left_arm_data.get("hand", Vector2(-30, 0)),
		"right_shoulder": Vector2(12, -17),
		"right_elbow": right_arm_data.get("elbow", Vector2(20, -10)),
		"right_hand": right_arm_data.get("hand", Vector2(30, 0))
	}

func get_facing_direction() -> bool:
	return facing_right

func reset_to_ground():
	"""Emergency function to reset player to ground level"""
	var coords = SolipsisticCoordinates
	var world_pos = coords.player_consciousness_pos
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	if solipsistic_world:
		var terrain_height = solipsistic_world.get_terrain_height_at(world_pos)
		current_height = terrain_height  # Stand ON TOP of terrain
		vertical_velocity = 0.0
		is_grounded = true
		print("🏃 RESET TO GROUND! Height: %.1f, Terrain: %.1f" % [current_height, terrain_height])

func handle_jump_input():
	"""Handle spacebar jump input"""
	if Input.is_action_just_pressed("ui_accept") and is_grounded:  # Spacebar
		vertical_velocity = -jump_force  # Negative = going up
		is_grounded = false
		print("🚀 JUMP! Velocity: %.1f, Height: %.1f, Grounded: %s" % [vertical_velocity, current_height, is_grounded])
	
	# Also try direct spacebar check
	if Input.is_key_pressed(KEY_SPACE) and is_grounded:
		vertical_velocity = -jump_force
		is_grounded = false
		print("🚀 SPACE JUMP! Velocity: %.1f" % vertical_velocity)

func apply_gravity_and_physics(delta):
	"""Apply gravity and handle terrain collision"""
	var coords = SolipsisticCoordinates
	var world_pos = coords.player_consciousness_pos
	
	# Get terrain system to check height
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	if not solipsistic_world:
		return
	
	# Get terrain height at current horizontal position
	var terrain_height = solipsistic_world.get_terrain_height_at(world_pos)
	
	# Debug terrain height fetching
	if Engine.get_process_frames() % 60 == 0:  # Every second
		print("DEBUG: pos=%s, terrain_height=%.3f, current_height=%.3f" % [world_pos, terrain_height, current_height])
	
	# CRITICAL DEBUG: If terrain height is 0.0, something is wrong
	if terrain_height == 0.0 and world_pos.distance_to(Vector2.ZERO) < 0.1:
		print("🚨 TERRAIN HEIGHT IS 0.0! This is likely the bug!")
		print("   world_pos: %s" % world_pos)
		print("   solipsistic_world: %s" % solipsistic_world)
		print("   terrain_system exists: %s" % (solipsistic_world.terrain_system != null))
		if solipsistic_world.terrain_system:
			print("   terrain_system.height_grid size: %d" % solipsistic_world.terrain_system.height_grid.size())
			# Try direct calculation
			var direct_calc = solipsistic_world.terrain_system.calculate_terrain_height(world_pos)
			print("   direct calculate_terrain_height(world_pos): %.3f" % direct_calc)
	
	# Apply gravity if not grounded
	if not is_grounded:
		vertical_velocity += gravity_strength * delta
		vertical_velocity = min(vertical_velocity, max_fall_speed)  # Terminal velocity
		
	# Safety check to prevent infinite space travel
	if current_height > terrain_height + 1000.0:
		print("🚨 SPACE EMERGENCY! Teleporting back to terrain!")
		current_height = terrain_height + entity_size / 2
		vertical_velocity = 0.0
		is_grounded = true
	
	# Update height position  
	current_height -= vertical_velocity * delta  # Subtract velocity (negative velocity = going up, so subtracting negative = adding height)
	
	# Check ground collision - player should stand ON TOP of terrain
	var ground_level = terrain_height  # Player stands ON the terrain surface
	if current_height <= ground_level and vertical_velocity >= 0:  # Only snap when falling down
		# Land on ground - player stands ON the terrain surface
		print("SNAP TO GROUND: %.3f -> %.3f (terrain: %.3f)" % [current_height, ground_level, terrain_height])
		current_height = ground_level
		if vertical_velocity > 0:  # Was falling
			print("🏃 LANDING! Velocity: %.1f -> 0, Height: %.1f (terrain: %.1f)" % [vertical_velocity, current_height, terrain_height])
		vertical_velocity = 0.0
		is_grounded = true
	elif current_height > ground_level:
		is_grounded = false
	
	# Update visual position based on terrain height and current height
	# In the solipsistic system, the player stays at consciousness center
	# but their visual height can change to show they're above/on terrain
	var visual_offset = current_height - terrain_height
		
	# Debug every frame during jump/fall
	if abs(vertical_velocity) > 1.0 or not is_grounded:  # When moving or airborne
		print("Physics: Vel=%.1f, Height=%.1f, Terrain=%.1f, Ground=%.1f, Grounded=%s" % [
			vertical_velocity, current_height, terrain_height, ground_level, is_grounded
		])
	
	# Apply visual positioning using perspective system
	var viewport_size = get_viewport().get_visible_rect().size
	var horizon_y = viewport_size.y * 0.7  # Same as terrain renderer
	var player_eye_level = horizon_y - 50   # Same as terrain renderer
	
	# Player position: standing on terrain at their current height
	var vertical_scale = 2.0  # Same as terrain renderer
	position.y = player_eye_level - current_height * vertical_scale
	
	# Keep player horizontally centered (consciousness center)
	position.x = SolipsisticCoordinates.CONSCIOUSNESS_CENTER.x
	
	# Reduced debug info (now that we have HUD)
	if Engine.get_process_frames() % 300 == 0:  # Print every 5 seconds
		print("Physics Debug - Height: %.1f, Terrain: %.1f, Above: %.1f" % [
			current_height, terrain_height, visual_offset
		])

func get_current_height_above_terrain() -> float:
	"""Get how high above terrain the player currently is"""
	var coords = SolipsisticCoordinates
	var world_pos = coords.player_consciousness_pos
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	if not solipsistic_world:
		return 0.0
	var terrain_height = solipsistic_world.get_terrain_height_at(world_pos)
	return current_height - terrain_height

func initialize_physics_state():
	"""Initialize player height to be standing ON TOP of terrain at spawn"""
	var coords = SolipsisticCoordinates
	var world_pos = coords.player_consciousness_pos
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	if solipsistic_world:
		var terrain_height = solipsistic_world.get_terrain_height_at(world_pos)
		# Player should be standing ON the terrain surface
		current_height = terrain_height  # Exactly ON the terrain surface
		vertical_velocity = 0.0
		is_grounded = true  # Start grounded on terrain surface
		print("🌍 Player initialized ON terrain. Terrain: %.1f, Player height: %.1f" % [terrain_height, current_height])

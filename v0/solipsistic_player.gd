extends ProceduralEntity
class_name SolipsisticPlayer

@export var movement_speed: float = 4.0  # 4 m/s walking speed
@export var can_change_z_layers: bool = true

# Physics constants (1:1 scale - 1 unit = 1 meter)
@export var gravity_strength: float = 9.8    # 9.8 m/s² (Earth gravity)
@export var jump_force: float = 3.5         # 3.5 m/s upward (gives ~0.6m jump)
@export var max_fall_speed: float = 15.0    # 15 m/s terminal velocity
@export var ground_snap_distance: float = 0.1  # 0.1m snap distance

# Input state
var move_input: float = 0.0
var depth_input: float = 0.0

# Physics state
var vertical_velocity: float = 0.0  # Current Y velocity (positive = falling)
var current_height: float = 0.0  # Current Y position above terrain
var is_grounded: bool = false

# Rotation state
var rotation_cooldown: float = 0.0
var rotation_cooldown_time: float = 0.3  # 300ms between rotations

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
	
	# Player always stays at consciousness center on screen
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
	
	# Emergency drop to ground after a short delay
	call_deferred("drop_to_ground")

func _process(delta):
	# Update rotation cooldown
	if rotation_cooldown > 0:
		rotation_cooldown -= delta
	
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
	
	# Only allow rotation if cooldown has expired
	if rotation_cooldown > 0:
		return
		
	if Input.is_key_pressed(KEY_Q):    # Q key - rotate clockwise
		var new_orientation = (coords.current_orientation + 1) % 4
		change_orientation(new_orientation)
		rotation_cooldown = rotation_cooldown_time
	elif Input.is_key_pressed(KEY_E):    # E key - rotate counter-clockwise  
		var new_orientation = (coords.current_orientation - 1) % 4
		if new_orientation < 0:
			new_orientation = 3
		change_orientation(new_orientation)
		rotation_cooldown = rotation_cooldown_time

func change_orientation(new_orientation: int):
	"""Changes how the observer perceives spatial relationships"""
	var coords = SolipsisticCoordinates
	coords.current_orientation = new_orientation
	coords.orientation_changed.emit(new_orientation)
	
	var orientation_names = ["EAST", "SOUTH", "WEST", "NORTH"]
	print("Observer now perceives reality facing: %s" % orientation_names[new_orientation])

func handle_movement_input(delta):
	"""Handle cardinal movement - A/D moves along current facing direction"""
	if not input_handler:
		return
	
	var movement_2d = input_handler.get_movement_direction()
	move_input = movement_2d.x  # A/D keys for movement along facing direction
	
	if move_input != 0.0:
		# Calculate movement along current orientation's movement axis
		var coords = SolipsisticCoordinates
		var movement_delta = move_input * movement_speed * delta
		
		# Get movement direction based on current orientation
		var movement_vector = coords.orientation_transforms[coords.current_orientation]["move"]
		
		# Apply movement along the correct axis
		coords.player_consciousness_pos += movement_vector * movement_delta
		coords.consciousness_moved.emit(coords.player_consciousness_pos)

func handle_depth_input():
	"""Handle depth movement - W/S moves through terrain slices"""
	if not can_change_z_layers:
		return
	
	var coords = SolipsisticCoordinates
	var depth_movement = 0.0
	
	# DISABLED: W/S continuous depth movement - use R/F for discrete lane changes instead
	# W/S keys for continuous depth movement (forward/backward through terrain slices)
	#if Input.is_key_pressed(KEY_W):
	#	depth_movement = 1.0  # Move forward in depth
	#elif Input.is_key_pressed(KEY_S):
	#	depth_movement = -1.0  # Move backward in depth
	#
	## Apply depth movement
	#if depth_movement != 0.0:
	#	var depth_delta = depth_movement * movement_speed * get_process_delta_time()
	#	
	#	# Move along the depth axis (perpendicular to cross-section)
	#	match coords.current_orientation:
	#		coords.Orientation.EAST:
	#			# Looking EAST: depth is +Y direction
	#			coords.player_consciousness_pos.y += depth_delta
	#		coords.Orientation.WEST:
	#			# Looking WEST: depth is -Y direction
	#			coords.player_consciousness_pos.y -= depth_delta
	#		coords.Orientation.NORTH:
	#			# Looking NORTH: depth is -X direction
	#			coords.player_consciousness_pos.x -= depth_delta
	#		coords.Orientation.SOUTH:
	#			# Looking SOUTH: depth is +X direction
	#			coords.player_consciousness_pos.x += depth_delta
	#	
	#	coords.consciousness_moved.emit(coords.player_consciousness_pos)
	
	# R/F keys for discrete depth stepping (1 meter steps)
	if Input.is_action_just_pressed("layer_forward"):   # R key
		var depth_vector = coords.orientation_transforms[coords.current_orientation]["depth"]
		coords.player_consciousness_pos += depth_vector * 1.0  # 1 meter step
		coords.consciousness_moved.emit(coords.player_consciousness_pos)
		print("Stepped forward on depth axis: %s" % coords.player_consciousness_pos)
	elif Input.is_action_just_pressed("layer_backward"): # F key
		var depth_vector = coords.orientation_transforms[coords.current_orientation]["depth"]
		coords.player_consciousness_pos -= depth_vector * 1.0  # 1 meter step
		coords.consciousness_moved.emit(coords.player_consciousness_pos)
		print("Stepped backward on depth axis: %s" % coords.player_consciousness_pos)

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
	
	# Manual drop to ground for testing (G key)
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_G):
		drop_to_ground()

func apply_gravity_and_physics(delta):
	"""Apply gravity and handle terrain collision"""
	var coords = SolipsisticCoordinates
	
	# Get terrain system to check height
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	if not solipsistic_world:
		return
	
	# Get terrain height at player's world position (converted from screen position)
	var player_world_pos = coords.player_consciousness_pos
	var terrain_height = solipsistic_world.terrain_system.get_height_at_world_pos(player_world_pos)
	
	# Debug terrain height (controlled timing)
	if SolipsisticCoordinates.should_debug_now(delta):
		SolipsisticCoordinates.debug_print("terrain", "🏔️ PHYSICS DEBUG:")
		SolipsisticCoordinates.debug_print("terrain", "   world_pos: %s" % player_world_pos)
		SolipsisticCoordinates.debug_print("terrain", "   terrain_height: %.3fm" % terrain_height)
		SolipsisticCoordinates.debug_print("terrain", "   player_height: %.3fm" % current_height)
		SolipsisticCoordinates.debug_print("terrain", "   height_above_terrain: %.3fm" % (current_height - terrain_height))
	
	# CRITICAL DEBUG: If terrain height is 0.0, something is wrong
	if terrain_height == 0.0 and player_world_pos.distance_to(Vector2.ZERO) < 0.1:
		print("🚨 TERRAIN HEIGHT IS 0.0! This is likely the bug!")
		print("   player_world_pos: %s" % player_world_pos)
		print("   solipsistic_world: %s" % solipsistic_world)
		print("   terrain_system exists: %s" % (solipsistic_world.terrain_system != null))
		if solipsistic_world.terrain_system:
			print("   terrain_system.height_grid size: %d" % solipsistic_world.terrain_system.height_grid.size())
			# Try direct calculation
			var direct_calc = solipsistic_world.terrain_system.calculate_terrain_height(player_world_pos)
			print("   direct calculate_terrain_height(player_world_pos): %.3f" % direct_calc)
	
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
	
	# Safety check: prevent extreme terrain height changes from launching player
	var height_difference = abs(terrain_height - current_height)
	if height_difference > 10.0:  # If terrain changed by more than 10m, gradually adjust
		var adjustment_speed = 5.0  # meters per second
		var max_adjustment = adjustment_speed * delta
		if terrain_height > current_height:
			current_height = min(current_height + max_adjustment, terrain_height)
		else:
			current_height = max(current_height - max_adjustment, terrain_height)
		is_grounded = true
		vertical_velocity = 0.0
	elif current_height <= ground_level and vertical_velocity >= 0:  # Normal landing
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
	
	# Player stays horizontally centered, but Y adjusts for height
	var height_above_terrain = current_height - terrain_height
	var vertical_scale = 20.0  # 20 pixels per meter for height visualization
	
	# Ground reference level (where terrain appears on screen)
	var ground_reference_y = SolipsisticCoordinates.CONSCIOUSNESS_CENTER.y + 50.0  # 50px below center = ground level
	
	# Position player relative to terrain surface
	position.x = SolipsisticCoordinates.CONSCIOUSNESS_CENTER.x
	position.y = ground_reference_y - (terrain_height * vertical_scale) - (height_above_terrain * vertical_scale)
	
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

func drop_to_ground():
	"""Emergency function to ensure player is on ground"""
	print("🔧 DROP TO GROUND DEBUG:")
	var coords = SolipsisticCoordinates
	var world_pos = coords.player_consciousness_pos
	print("   world_pos: %s" % world_pos)
	
	var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
	print("   solipsistic_world: %s" % solipsistic_world)
	
	if solipsistic_world:
		print("   terrain_system: %s" % solipsistic_world.terrain_system)
		if solipsistic_world.terrain_system:
			var terrain_height = solipsistic_world.terrain_system.get_height_at_world_pos(world_pos)
			print("   terrain_height: %.3fm" % terrain_height)
			print("   old current_height: %.3fm" % current_height)
			current_height = terrain_height
			vertical_velocity = 0.0
			is_grounded = true
			print("   new current_height: %.3fm" % current_height)
			print("🎯 DROPPED TO GROUND! Success!")
		else:
			print("❌ No terrain_system found!")
			# Manual fallback - just set to ground level
			current_height = 0.0
			vertical_velocity = 0.0
			is_grounded = true
			print("🎯 MANUAL DROP TO ZERO!")
	else:
		print("❌ No SolipsisticWorld found!")
		current_height = 0.0
		vertical_velocity = 0.0
		is_grounded = true
		print("🎯 EMERGENCY DROP TO ZERO!")

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

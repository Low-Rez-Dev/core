extends Person
class_name Player

@export var move_speed: float = 4.0

var target_grid_position_3d: Vector3i
var camera_offset: Vector2
var is_moving: bool = false
var is_rotating: bool = false

# Accumulated movement for smooth grid traversal
var accumulated_movement_x: float = 0.0
var accumulated_movement_z: float = 0.0

# Terrain and physics
var velocity_y: float = 0.0
var is_grounded: bool = true
var gravity: float = 800.0  # Pixels per second squared
var jump_strength: float = 400.0  # Pixels per second
var terrain_system: TerrainSystem

signal rotation_complete()

func _ready():
	super._ready()
	add_to_group("entities")  # Add to entities group for focus lane system
	add_to_group("player")   # Add to player group for minimap
	print("Player added to groups: entities, player")
	setup_movement()
	setup_debug_minimap()

func setup_movement():
	# Direct access for now until CSLocator timing issues are resolved
	call_deferred("_setup_direct_access")
	
	# Initialize 3D grid position based on current world position
	var world_3d = Vector3(global_position.x, global_position.y, 0)
	set_grid_position(GridCoordinates.world_to_grid_3d(world_3d))
	target_grid_position_3d = grid_position_3d
	
	# Initialize camera offset to keep player centered
	camera_offset = Vector2.ZERO
	
	print("Player initialized at grid position: ", grid_position_3d)
	print("Player screen position: ", global_position)
	
	# Force redraw
	queue_redraw()

func _physics_process(delta):
	if is_rotating:
		return
	
	handle_movement_input(delta)
	handle_jumping_input()
	handle_rotation_input()
	apply_gravity_and_terrain_collision(delta)
	update_visual_position()
	
	# Force redraw every frame for debugging
	queue_redraw()

func handle_movement_input(delta):
	# Smooth cardinal movement (A/D keys) - continuous
	var horizontal_input = 0.0
	if Input.is_action_pressed("move_forward"):
		horizontal_input += 1.0
	if Input.is_action_pressed("move_backward"):
		horizontal_input -= 1.0
	
	if horizontal_input != 0.0:
		move_smoothly(horizontal_input, delta)
	
	# Discrete depth layer movement (R/F keys) - discrete steps
	if Input.is_action_just_pressed("layer_forward"):
		sidestep_depth_lane(1)
	if Input.is_action_just_pressed("layer_backward"):
		sidestep_depth_lane(-1)

func handle_jumping_input():
	# Jump with spacebar or W key
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("move_depth_positive"):
		if is_grounded:
			jump()

func jump():
	velocity_y = -jump_strength  # Negative Y is up
	is_grounded = false
	print("Player jumped! Velocity: ", velocity_y)

func apply_gravity_and_terrain_collision(delta):
	if not terrain_system:
		return
	
	# Apply gravity
	velocity_y += gravity * delta
	
	# Update Y position based on velocity
	var new_y = global_position.y + velocity_y * delta
	
	# Get terrain height at current position
	var terrain_height = get_terrain_height_at_current_position()
	var ground_screen_y = 240 - terrain_height  # Convert to screen coordinates
	
	# Adjust for character height - feet should touch ground, not center
	var character_foot_offset = 13  # Distance from center to bottom of feet
	var character_ground_y = ground_screen_y - character_foot_offset
	
	# Check ground collision
	if new_y >= character_ground_y:
		# Landed on ground
		global_position.y = character_ground_y
		velocity_y = 0.0
		is_grounded = true
	else:
		# In air
		global_position.y = new_y
		is_grounded = false

func get_terrain_height_at_current_position() -> float:
	if not terrain_system or not coordinate_system:
		return 0.0  # Return ground level if systems not available
	
	# Get terrain height based on current grid position
	var current_pos = grid_position_3d
	var lookup_pos: Vector2i
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			# Use X for movement, Z for depth lane
			lookup_pos = Vector2i(current_pos.x, current_pos.z)
		coordinate_system.Orientation.EAST_WEST:
			# Use Z for movement, X for depth lane
			lookup_pos = Vector2i(current_pos.x, current_pos.z)
		_:
			lookup_pos = Vector2i(current_pos.x, current_pos.z)
	
	var height = terrain_system.get_terrain_height(lookup_pos)
	return height

func move_smoothly(direction: float, delta: float):
	# Smooth movement in virtual grid coordinates with accumulation
	if not coordinate_system:
		return  # Wait for coordinate system to be available
	
	var movement_speed = 5.0  # grid units per second
	var movement_dir = coordinate_system.get_forward_direction()
	var movement_delta = direction * movement_speed * delta
	
	
	# Accumulate movement to handle fractional grid units
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			# X axis movement
			accumulated_movement_x += movement_dir.x * movement_delta
			var grid_steps = int(accumulated_movement_x)
			if grid_steps != 0:
				grid_position_3d.x += grid_steps
				accumulated_movement_x -= grid_steps
				# Update entity positions when player moves
				if coordinate_system and coordinate_system.focus_lane_system:
					coordinate_system.focus_lane_system.update_all_entity_positions()
		coordinate_system.Orientation.EAST_WEST:
			# Z axis movement
			accumulated_movement_z += movement_dir.z * movement_delta
			var grid_steps = int(accumulated_movement_z)
			if grid_steps != 0:
				grid_position_3d.z += grid_steps
				accumulated_movement_z -= grid_steps
				# Update entity positions when player moves
				if coordinate_system and coordinate_system.focus_lane_system:
					coordinate_system.focus_lane_system.update_all_entity_positions()
	
	# Keep player visually centered horizontally, but preserve Y for jumping
	global_position.x = 320

func sidestep_depth_lane(direction: int):
	# Discrete sidestepping between depth lanes
	if is_moving or not coordinate_system:
		return
	
	is_moving = true
	var depth_dir = coordinate_system.get_depth_direction() * direction
	var new_grid_pos = grid_position_3d + Vector3i(int(depth_dir.x), int(depth_dir.y), int(depth_dir.z))
	
	# Update focus lane when player sidesteps
	if coordinate_system.focus_lane_system:
		coordinate_system.focus_lane_system.set_focus_lane(new_grid_pos)
	
	set_grid_position(new_grid_pos)
	is_moving = false

func update_grid_from_screen_position_smooth():
	# Convert current screen position back to grid coordinates (but don't snap visually)
	if coordinate_system:
		var current_grid = grid_position_3d
		
		match coordinate_system.current_orientation:
			coordinate_system.Orientation.NORTH_SOUTH:
				# X axis is movement, preserve Y and Z
				var new_x = int(global_position.x / GridCoordinates.GRID_SIZE)
				current_grid.x = new_x
			coordinate_system.Orientation.EAST_WEST:
				# Z axis is movement, preserve X and Y  
				var new_z = int(global_position.x / GridCoordinates.GRID_SIZE)
				current_grid.z = new_z
		
		# Update grid position without snapping screen position
		grid_position_3d = current_grid



func update_grid_from_screen_position():
	# Convert current screen position back to grid coordinates
	if coordinate_system and coordinate_system.focus_lane_system:
		var current_grid = grid_position_3d
		
		match coordinate_system.current_orientation:
			coordinate_system.Orientation.NORTH_SOUTH:
				# X axis is movement, preserve Y and Z
				var new_x = int(global_position.x / GridCoordinates.GRID_SIZE)
				current_grid.x = new_x
			coordinate_system.Orientation.EAST_WEST:
				# Z axis is movement, preserve X and Y  
				var new_z = int(global_position.x / GridCoordinates.GRID_SIZE)
				current_grid.z = new_z
		
		set_grid_position(current_grid)

func move_on_grid(direction: Vector2):
	if is_moving:
		return
	
	# Cardinal movement or depth lane sidestepping
	var new_grid_pos = grid_position_3d
	
	if direction.x != 0:
		# Cardinal movement along current facing direction
		var movement_dir = coordinate_system.get_forward_direction() * direction.x
		new_grid_pos += Vector3i(int(movement_dir.x), int(movement_dir.y), int(movement_dir.z))
	
	if direction.y != 0:
		# Lane sidestepping (R/F keys) - move along depth axis (Z or X, not Y!)
		var depth_dir = coordinate_system.get_depth_direction() * direction.y
		new_grid_pos += Vector3i(int(depth_dir.x), int(depth_dir.y), int(depth_dir.z))
		
		# Update focus lane when player sidesteps
		if coordinate_system.focus_lane_system:
			coordinate_system.focus_lane_system.set_focus_lane(new_grid_pos)
	
	# Update target position
	target_grid_position_3d = new_grid_pos
	is_moving = true
	
	# Check if this is depth movement (R/F) or regular movement (A/D)
	if direction.y != 0:
		# Depth movement - no screen position animation, just instant focus change
		finish_movement()
	else:
		# Regular movement - animate screen position
		var tween = create_tween()
		var start_pos = coordinate_system.focus_lane_system.grid_to_screen_position(grid_position_3d)
		var end_pos = coordinate_system.focus_lane_system.grid_to_screen_position(target_grid_position_3d)
		
		tween.tween_method(update_position_during_movement, start_pos, end_pos, 0.2)
		tween.tween_callback(finish_movement)

func update_position_during_movement(pos: Vector2):
	global_position = pos

func finish_movement():
	set_grid_position(target_grid_position_3d)
	is_moving = false

func handle_rotation_input():
	if Input.is_action_just_pressed("rotate_clockwise"):
		perform_rotation(true)
	elif Input.is_action_just_pressed("rotate_counter"):
		perform_rotation(false)

func perform_rotation(clockwise: bool):
	if is_rotating or not coordinate_system:
		return
	
	is_rotating = true
	
	if clockwise:
		coordinate_system.rotate_orientation_clockwise()
	else:
		coordinate_system.rotate_orientation_counterclockwise()
	
	# Brief pause for rotation effect
	await get_tree().create_timer(0.1).timeout
	is_rotating = false
	rotation_complete.emit()

func update_visual_position():
	# Only snap to grid during discrete movements, not during smooth movement
	# Smooth movement handles its own positioning
	pass

func setup_debug_minimap():
	# Add debug minimap directly to the scene
	print("Creating minimap...")
	var minimap = preload("res://debug_minimap.gd").new()
	print("Minimap created: ", minimap)
	get_tree().current_scene.add_child(minimap)
	print("Minimap added to scene: ", get_tree().current_scene)


func set_render_properties(props: Dictionary):
	# Player stays at full visibility/scale since they're always on focus lane
	modulate = Color.WHITE
	scale = Vector2.ONE
	z_index = props.z_index

func _draw():
	# Draw a 3/4 view character facing the camera
	draw_three_quarter_character()

func draw_three_quarter_character():
	# Ancient Greek pottery colors
	var pottery_dark = Color(0.15, 0.1, 0.08)    # Dark pottery paint (almost black)
	var pottery_medium = Color(0.2, 0.15, 0.12)  # Medium pottery shade
	var eye_white = Color(0.95, 0.9, 0.85)       # Off-white for eyes
	var eye_blue = Color(0.2, 0.4, 0.7)          # Deep blue for eyes
	var accent_red = Color(0.6, 0.15, 0.1)       # Deep red accent
	
	# Scale factor for the character
	var scale = 1.0
	
	# 3/4 view facing the camera - no direction flipping
	
	# Head (slightly oval for 3/4 view)
	var head_pos = Vector2(0, -25 * scale)
	var head_points = PackedVector2Array()
	for i in range(16):
		var angle = i * 2 * PI / 16
		var x = head_pos.x + cos(angle) * 7 * scale
		var y = head_pos.y + sin(angle) * 8 * scale
		head_points.append(Vector2(x, y))
	draw_colored_polygon(head_points, pottery_dark)
	
	# Hair (covering top and back of head)
	var hair_points = PackedVector2Array([
		Vector2(-6 * scale, -30 * scale),
		Vector2(-4 * scale, -33 * scale),
		Vector2(0, -33 * scale),
		Vector2(4 * scale, -32 * scale),
		Vector2(6 * scale, -29 * scale),
		Vector2(5 * scale, -25 * scale)
	])
	draw_colored_polygon(hair_points, pottery_dark)
	
	# Eyes (both visible in 3/4 view)
	draw_circle(Vector2(-2 * scale, -27 * scale), 1.2 * scale, eye_white)  # Left eye
	draw_circle(Vector2(-2 * scale, -27 * scale), 0.8 * scale, eye_blue)   # Left pupil (blue)
	draw_circle(Vector2(2 * scale, -26 * scale), 1.0 * scale, eye_white)   # Right eye (slightly smaller for depth)
	draw_circle(Vector2(2 * scale, -26 * scale), 0.6 * scale, eye_blue)    # Right pupil (blue)
	
	# Nose (small triangle for 3/4 view)
	var nose_points = PackedVector2Array([
		Vector2(1 * scale, -24 * scale),
		Vector2(3 * scale, -23 * scale),
		Vector2(1 * scale, -22 * scale)
	])
	draw_colored_polygon(nose_points, pottery_medium)
	
	# Body (slightly angled rectangle for 3/4 view)
	var body_points = PackedVector2Array([
		Vector2(-5 * scale, -17 * scale),    # Top left
		Vector2(4 * scale, -17 * scale),     # Top right
		Vector2(5 * scale, -5 * scale),      # Bottom right
		Vector2(-4 * scale, -5 * scale)      # Bottom left
	])
	draw_colored_polygon(body_points, pottery_dark)
	
	# Back arm (partially visible)
	draw_line(Vector2(-4 * scale, -14 * scale), Vector2(-9 * scale, -10 * scale), pottery_dark, 2 * scale)
	draw_line(Vector2(-9 * scale, -10 * scale), Vector2(-7 * scale, -6 * scale), pottery_dark, 2 * scale)
	draw_circle(Vector2(-7 * scale, -6 * scale), 1.8 * scale, pottery_dark)  # Back hand
	
	# Front arm (fully visible)
	draw_line(Vector2(3 * scale, -14 * scale), Vector2(9 * scale, -9 * scale), pottery_dark, 3 * scale)
	draw_line(Vector2(9 * scale, -9 * scale), Vector2(7 * scale, -3 * scale), pottery_dark, 3 * scale)
	draw_circle(Vector2(7 * scale, -3 * scale), 2.2 * scale, pottery_dark)  # Front hand
	
	# Back leg (partially visible)
	var back_leg_points = PackedVector2Array([
		Vector2(-3 * scale, -5 * scale),     # Top left
		Vector2(-1 * scale, -5 * scale),     # Top right
		Vector2(-1 * scale, 10 * scale),     # Bottom right
		Vector2(-3 * scale, 10 * scale)      # Bottom left
	])
	draw_colored_polygon(back_leg_points, pottery_dark)
	
	# Front leg (fully visible)
	var front_leg_points = PackedVector2Array([
		Vector2(1 * scale, -5 * scale),      # Top left
		Vector2(4 * scale, -5 * scale),      # Top right
		Vector2(4 * scale, 10 * scale),      # Bottom right
		Vector2(1 * scale, 10 * scale)       # Bottom left
	])
	draw_colored_polygon(front_leg_points, pottery_dark)
	
	# Back foot (smaller, partially hidden)
	var back_foot_rect = Rect2(-4 * scale, 10 * scale, 4 * scale, 3 * scale)
	draw_rect(back_foot_rect, pottery_dark)
	
	# Front foot (larger, fully visible)
	var front_foot_rect = Rect2(1 * scale, 10 * scale, 6 * scale, 3 * scale)
	draw_rect(front_foot_rect, pottery_dark)

func _on_orientation_changed(new_orientation):
	print("Player orientation changed to: ", new_orientation)

# CSLocator callbacks for services
func _on_coordinate_system_ready(service):
	coordinate_system = service
	# Connect signals directly (CSConnector is for different use case)
	coordinate_system.orientation_changed.connect(_on_orientation_changed)

func _on_terrain_system_ready(service):
	terrain_system = service

# Direct access setup function
func _setup_direct_access():
	var coord_system = get_node("/root/CoordinateSystem")
	if coord_system:
		coordinate_system = coord_system
		terrain_system = coord_system.terrain_system
		coordinate_system.orientation_changed.connect(_on_orientation_changed)
		print("Player: Connected to coordinate system via direct access")

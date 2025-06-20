extends Person
class_name Player

@export var move_speed: float = 4.0

var target_grid_position_3d: Vector3i
var camera_offset: Vector2
var is_moving: bool = false
var is_rotating: bool = false

# Camera system
var camera: Camera2D
var zoom_level: float = 1.0
var min_zoom: float = 0.8
var max_zoom: float = 5.0
var zoom_speed: float = 0.1

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
	add_to_group("player")   # Add to player group
	print("Player added to groups: entities, player")
	setup_camera()
	setup_movement()

func setup_camera():
	# Create and configure the camera
	camera = Camera2D.new()
	camera.name = "PlayerCamera"
	camera.enabled = true
	camera.zoom = Vector2(zoom_level, zoom_level)
	
	# Add camera as child of player so it follows automatically
	add_child(camera)
	
	print("Camera setup complete, zoom level: ", zoom_level)

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
	handle_zoom_input()
	apply_gravity_and_terrain_collision(delta)
	update_visual_position()
	
	# Force redraw every frame for debugging
	queue_redraw()

func _input(event):
	# Handle mouse wheel zoom
	if event is InputEventMouseButton and camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_level = clamp(zoom_level + zoom_speed, min_zoom, max_zoom)
			camera.zoom = Vector2(zoom_level, zoom_level)
			print("Zoom in: ", zoom_level)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_level = clamp(zoom_level - zoom_speed, min_zoom, max_zoom)
			camera.zoom = Vector2(zoom_level, zoom_level)
			print("Zoom out: ", zoom_level)

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

func handle_zoom_input():
	if not camera:
		return
	
	var zoom_change = 0.0
	
	# Mouse wheel or + - keys for zoom
	if Input.is_action_just_pressed("ui_accept") and Input.is_key_pressed(KEY_SHIFT):
		zoom_change = zoom_speed  # Zoom in with Shift+Space
	elif Input.is_action_just_pressed("ui_cancel"):
		zoom_change = -zoom_speed  # Zoom out with Escape
	
	# Check for + and - keys
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		zoom_change = zoom_speed * 2  # Faster zoom in
	elif Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		zoom_change = -zoom_speed * 2  # Faster zoom out
	
	if zoom_change != 0.0:
		zoom_level = clamp(zoom_level + zoom_change, min_zoom, max_zoom)
		camera.zoom = Vector2(zoom_level, zoom_level)
		print("Zoom level: ", zoom_level)

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
	# Bridge physics Y position with grid system Y coordinate
	# Convert current screen Y position back to world altitude
	if terrain_system:
		# Calculate current altitude based on screen position
		var terrain_height_at_position = get_terrain_height_at_current_position()
		var ground_screen_y = 240 - terrain_height_at_position
		var character_foot_offset = 13
		var character_ground_y = ground_screen_y - character_foot_offset
		
		# Calculate how high above ground the player is (in screen pixels)
		var height_above_ground = character_ground_y - global_position.y
		
		# Convert to world units and then to grid units for Y coordinate
		var altitude_in_world_units = terrain_height_at_position + height_above_ground
		var grid_y = int(altitude_in_world_units / GridCoordinates.GRID_SIZE)
		
		# Update the grid position Y to reflect current altitude
		grid_position_3d.y = grid_y



func set_render_properties(props: Dictionary):
	# Player stays at full visibility/scale since they're always on focus lane
	modulate = Color.WHITE
	scale = Vector2.ONE
	z_index = props.z_index

func _draw():
	# Draw grid coordinates above the player
	draw_grid_coordinates()
	
	# Draw a 3/4 view character facing the camera
	draw_three_quarter_character()

func draw_grid_coordinates():
	# Display X Z Y coordinates above the player (Y is altitude)
	var coord_text = "X:%d Z:%d Y:%d" % [grid_position_3d.x, grid_position_3d.z, grid_position_3d.y]
	var text_pos = Vector2(0, -60)  # Above the player's head
	
	# Draw background for better readability
	var font = ThemeDB.fallback_font
	var font_size = 12
	var text_size = font.get_string_size(coord_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var bg_rect = Rect2(text_pos - Vector2(text_size.x/2, text_size.y), text_size + Vector2(4, 2))
	draw_rect(bg_rect, Color(0, 0, 0, 0.7))  # Semi-transparent black background
	
	# Draw the coordinate text in white
	draw_string(font, text_pos - Vector2(text_size.x/2, 0), coord_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func draw_three_quarter_character():
	# Ancient Greek pottery colors
	var pottery_dark = Color(0.15, 0.1, 0.08)    # Dark pottery paint (almost black)
	var pottery_medium = Color(0.2, 0.15, 0.12)  # Medium pottery shade
	var eye_white = Color(0.95, 0.9, 0.85)       # Off-white for eyes
	var accent_red = Color(0.6, 0.15, 0.1)       # Deep red accent
	
	# Scale factor for the character
	var scale = 1.0
	
	# Greek pottery figure style - right-facing profile like pottery references
	
	# Head (side profile facing right)
	var head_points = PackedVector2Array([
		Vector2(-4 * scale, -32 * scale),    # Back of head
		Vector2(2 * scale, -35 * scale),     # Top of head
		Vector2(6 * scale, -30 * scale),     # Forehead
		Vector2(7 * scale, -25 * scale),     # Nose tip
		Vector2(5 * scale, -22 * scale),     # Chin
		Vector2(0 * scale, -21 * scale),     # Jaw
		Vector2(-4 * scale, -24 * scale)     # Back of jaw
	])
	draw_colored_polygon(head_points, pottery_dark)
	
	# Hair/helmet (Greek warrior style, profile)
	var hair_points = PackedVector2Array([
		Vector2(-6 * scale, -33 * scale),
		Vector2(-2 * scale, -37 * scale),
		Vector2(4 * scale, -36 * scale),
		Vector2(6 * scale, -32 * scale),
		Vector2(2 * scale, -35 * scale),
		Vector2(-4 * scale, -32 * scale)
	])
	draw_colored_polygon(hair_points, pottery_dark)
	
	# Eye (single eye visible in profile)
	draw_circle(Vector2(2 * scale, -29 * scale), 1.5 * scale, eye_white)
	draw_circle(Vector2(2 * scale, -29 * scale), 1.0 * scale, pottery_dark)
	
	# Nose (Greek profile nose - pointing right)
	var nose_points = PackedVector2Array([
		Vector2(4 * scale, -27 * scale),
		Vector2(7 * scale, -25 * scale),
		Vector2(5 * scale, -24 * scale)
	])
	draw_colored_polygon(nose_points, pottery_medium)
	
	# Neck
	draw_rect(Rect2(-2 * scale, -21 * scale, 4 * scale, 4 * scale), pottery_dark)
	
	# Torso (buffer chest like Greek warrior)
	var torso_points = PackedVector2Array([
		Vector2(-7 * scale, -17 * scale),    # Top left (wider shoulders)
		Vector2(7 * scale, -17 * scale),     # Top right (wider shoulders)
		Vector2(8 * scale, -8 * scale),      # Bottom right (broader chest)
		Vector2(-8 * scale, -8 * scale)      # Bottom left (broader chest)
	])
	draw_colored_polygon(torso_points, pottery_dark)
	
	# Hip section (connects torso to legs)
	var hip_points = PackedVector2Array([
		Vector2(-8 * scale, -8 * scale),     # Top left
		Vector2(8 * scale, -8 * scale),      # Top right
		Vector2(6 * scale, -2 * scale),      # Bottom right (tapered waist)
		Vector2(-6 * scale, -2 * scale)      # Bottom left (tapered waist)
	])
	draw_colored_polygon(hip_points, pottery_dark)
	
	# BACK ARM (left side) - buffer/muscular
	var back_upper_arm = PackedVector2Array([
		Vector2(-7 * scale, -15 * scale),    # Shoulder connection (from wider shoulder)
		Vector2(-9 * scale, -14 * scale),    # Outer bicep
		Vector2(-12 * scale, -10 * scale),   # Elbow (pointing backward)
		Vector2(-10 * scale, -9 * scale),    # Inner bicep
		Vector2(-8 * scale, -11 * scale)     # Muscle definition
	])
	draw_colored_polygon(back_upper_arm, pottery_dark)
	
	var back_forearm = PackedVector2Array([
		Vector2(-12 * scale, -10 * scale),   # Elbow
		Vector2(-10 * scale, -9 * scale),
		Vector2(-7 * scale, -3 * scale),     # Wrist (forward from elbow)
		Vector2(-9 * scale, -4 * scale),     # Muscular forearm
		Vector2(-11 * scale, -7 * scale)     # Forearm bulk
	])
	draw_colored_polygon(back_forearm, pottery_dark)
	
	# Back hand (larger for heroic proportions)
	draw_circle(Vector2(-8 * scale, -3 * scale), 2.5 * scale, pottery_dark)
	
	# FRONT ARM (right side) - buffer/muscular
	var front_upper_arm = PackedVector2Array([
		Vector2(7 * scale, -15 * scale),     # Shoulder connection (from wider shoulder)
		Vector2(9 * scale, -14 * scale),     # Outer bicep
		Vector2(6 * scale, -10 * scale),     # Elbow (pointing backward)
		Vector2(8 * scale, -9 * scale),      # Inner bicep
		Vector2(10 * scale, -11 * scale)     # Muscle definition
	])
	draw_colored_polygon(front_upper_arm, pottery_dark)
	
	var front_forearm = PackedVector2Array([
		Vector2(6 * scale, -10 * scale),     # Elbow
		Vector2(8 * scale, -9 * scale),
		Vector2(10 * scale, -3 * scale),     # Wrist (forward from elbow)
		Vector2(8 * scale, -4 * scale),      # Muscular forearm
		Vector2(7 * scale, -7 * scale)       # Forearm bulk
	])
	draw_colored_polygon(front_forearm, pottery_dark)
	
	# Front hand (larger for heroic proportions)
	draw_circle(Vector2(9 * scale, -3 * scale), 2.5 * scale, pottery_dark)
	
	# BACK LEG (left) - knee pointing forward (right)
	var back_thigh = PackedVector2Array([
		Vector2(-5 * scale, -2 * scale),     # Hip connection
		Vector2(-2 * scale, -2 * scale),
		Vector2(0 * scale, 6 * scale),       # Knee (pointing forward/right)
		Vector2(-3 * scale, 6 * scale)
	])
	draw_colored_polygon(back_thigh, pottery_dark)
	
	# BACK LEG shin - angled forward from knee
	var back_shin = PackedVector2Array([
		Vector2(0 * scale, 6 * scale),       # Knee
		Vector2(-3 * scale, 6 * scale),
		Vector2(-2 * scale, 11 * scale),     # Ankle (raised up)
		Vector2(1 * scale, 11 * scale)
	])
	draw_colored_polygon(back_shin, pottery_dark)
	
	# FRONT LEG (right) - knee pointing forward (right)  
	var front_thigh = PackedVector2Array([
		Vector2(2 * scale, -2 * scale),      # Hip connection
		Vector2(5 * scale, -2 * scale),
		Vector2(7 * scale, 6 * scale),       # Knee (pointing forward/right)
		Vector2(4 * scale, 6 * scale)
	])
	draw_colored_polygon(front_thigh, pottery_dark)
	
	# FRONT LEG shin - angled forward from knee
	var front_shin = PackedVector2Array([
		Vector2(7 * scale, 6 * scale),       # Knee
		Vector2(4 * scale, 6 * scale),
		Vector2(5 * scale, 11 * scale),      # Ankle (raised up)
		Vector2(8 * scale, 11 * scale)
	])
	draw_colored_polygon(front_shin, pottery_dark)
	
	# FEET - both pointing right (facing direction), positioned on ground
	var back_foot = Rect2(-2 * scale, 11 * scale, 5 * scale, 2 * scale)
	draw_rect(back_foot, pottery_dark)
	
	var front_foot = Rect2(5 * scale, 11 * scale, 5 * scale, 2 * scale)
	draw_rect(front_foot, pottery_dark)

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

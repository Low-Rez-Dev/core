extends InputHandler
class_name MouseKeyboardInput

# Mouse chording state
var left_arm_was_active = false
var right_arm_was_active = false

# Reference to camera for 3D to 2D conversion
var camera_3d: Camera3D

func _ready():
	# Try to find camera immediately, but also set up a timer to retry
	find_camera()
	
	# If camera not found, try again in a few frames
	if not camera_3d:
		get_tree().process_frame.connect(_on_retry_find_camera, CONNECT_ONE_SHOT)

func _on_retry_find_camera():
	await get_tree().process_frame
	await get_tree().process_frame
	find_camera()
	
	# Try one more time if still not found
	if not camera_3d:
		await get_tree().process_frame
		find_camera()

func find_camera():
	# Look for Camera3D in the scene tree
	var scene_root = get_tree().current_scene
	if scene_root:
		camera_3d = find_camera_recursive(scene_root)
		if camera_3d:
			print("🎯 Mouse input found camera: %s" % camera_3d.name)
		else:
			print("⚠️ Mouse input could not find camera!")

func find_camera_recursive(node: Node) -> Camera3D:
	if node is Camera3D:
		return node as Camera3D
	
	for child in node.get_children():
		var result = find_camera_recursive(child)
		if result:
			return result
	
	return null

func update_input(delta: float, character_position: Vector2):
	# Try to find camera if we don't have it yet
	if not camera_3d:
		find_camera()
	
	# Update arm activation - using raw mouse input for reliability
	var left_mouse_active = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_mouse_active = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
	# Handle mouse chording
	handle_mouse_chording(left_mouse_active, right_mouse_active, character_position)
	
	# Convert 3D mouse position to 2D character-relative coordinates
	var mouse_2d_relative = get_mouse_position_relative_to_character()
	
	# Set arm targets
	if left_arm_locked:
		left_arm_target = locked_left_position
	elif left_mouse_active:
		left_arm_target = mouse_2d_relative
	else:
		left_arm_active = false
	
	if right_arm_locked:
		right_arm_target = locked_right_position
	elif right_mouse_active:
		right_arm_target = mouse_2d_relative
	else:
		right_arm_active = false
	
	# Update active states
	left_arm_active = left_mouse_active or left_arm_locked
	right_arm_active = right_mouse_active or right_arm_locked
	
	# Handle movement (A/D keys only - W/S reserved for Y-axis)
	movement_direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		movement_direction.x -= 1.0  # Move left along current axis
	if Input.is_key_pressed(KEY_D):
		movement_direction.x += 1.0  # Move right along current axis
	
	# Handle orientation rotation (Q/E keys)
	z_movement = 0.0
	if Input.is_key_pressed(KEY_Q):
		z_movement = 1.0   # Rotate clockwise
	elif Input.is_key_pressed(KEY_E):
		z_movement = -1.0  # Rotate counter-clockwise
	
# Handle focus direction (mouse when arms not active) - RESTORED
	if not (left_mouse_active or right_mouse_active):
		if mouse_2d_relative.length() > 10:  # Dead zone to prevent jitter
			focus_direction = mouse_2d_relative.normalized()
	
	# Handle zoom
	if Input.is_action_just_pressed("wheel_up"):
		request_zoom(0.2)
	elif Input.is_action_just_pressed("wheel_down"):
		request_zoom(-0.2)

func get_mouse_position_relative_to_character() -> Vector2:
	if not camera_3d:
		# Fallback to basic mouse position if no camera found
		var mouse_screen = get_viewport().get_mouse_position()
		var viewport_size = get_viewport().get_visible_rect().size
		var center = viewport_size / 2
		var mouse_2d = (mouse_screen - center) * 0.5
		return mouse_2d
	
	# ZOOM-INDEPENDENT APPROACH: Use viewport center instead of character projection
	# This completely eliminates zoom dependency by using screen center as reference
	
	var mouse_screen = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	var viewport_center = viewport_size / 2
	
	# Calculate relative mouse position from screen center
	var mouse_relative_screen = mouse_screen - viewport_center
	
	# Convert to character 2D coordinate space
	# SubViewport is 400x600 with character center at (200, 300)
	# Use fixed scale that matches character proportions independent of zoom
	var mouse_2d = mouse_relative_screen * 0.5  # Fixed scale for character coordinate space
	
	# COORDINATE SYSTEM ALIGNMENT:
	# The mouse_2d coordinates are relative to character center (0,0)
	# This matches body_controller coordinate system where shoulders are relative to center
	# No additional offset needed - the coordinate systems are already aligned
	
	# DEBUG: Print coordinate conversion chain (temporarily re-enabled for tuning)
	if Input.is_action_pressed("ui_accept"):  # Only when spacebar held
		print("[COORD_DEBUG] Mouse screen: %s | Viewport center: %s | Mouse 2D: %s | Scale: 0.5" % [
			mouse_screen, viewport_center, mouse_2d
		])
		
		# Also print what this will become as an arm target
		if get_parent() and get_parent().body_controller:
			var left_shoulder = get_parent().body_controller.get_shoulder_pos(true)
			var right_shoulder = get_parent().body_controller.get_shoulder_pos(false)
			print("[COORD_DEBUG] Left shoulder: %s | Right shoulder: %s" % [left_shoulder, right_shoulder])
			print("[COORD_DEBUG] Mouse target would be: %s (relative to character center)" % mouse_2d)
	
	return mouse_2d

func handle_mouse_chording(left_active: bool, right_active: bool, character_position: Vector2):
	# Get current mouse position for chording
	var mouse_2d_relative = get_mouse_position_relative_to_character()
	
	# Detect new activation while other arm is active
	if left_active and not left_arm_was_active and right_arm_was_active and not right_arm_locked:
		# Lock right arm when left is newly activated
		set_arm_lock(false, true, mouse_2d_relative)
	
	if right_active and not right_arm_was_active and left_arm_was_active and not left_arm_locked:
		# Lock left arm when right is newly activated  
		set_arm_lock(true, true, mouse_2d_relative)
	
	# Unlock arm when reactivated
	if left_active and not left_arm_was_active and left_arm_locked:
		set_arm_lock(true, false)
	
	if right_active and not right_arm_was_active and right_arm_locked:
		set_arm_lock(false, false)
	
	# Release all locks when both arms released
	if not left_active and not right_active:
		if left_arm_locked:
			set_arm_lock(true, false)
		if right_arm_locked:
			set_arm_lock(false, false)
	
	# Update previous state
	left_arm_was_active = left_active
	right_arm_was_active = right_active

func debug_mouse_coordinates():
	var mouse_2d = get_mouse_position_relative_to_character()
	var character_node = get_parent()
	
	print("=== MOUSE DEBUG ===")
	print("Raw mouse 2D: " + str(mouse_2d))
	if character_node and character_node.body_controller:
		print("Character facing: " + ("RIGHT" if character_node.body_controller.facing_right else "LEFT"))
		print("Left shoulder: " + str(character_node.body_controller.get_shoulder_pos(true)))
		print("Right shoulder: " + str(character_node.body_controller.get_shoulder_pos(false)))
	print("==================")

# Call debug when M key is pressed (handled in character_2d5d.gd)

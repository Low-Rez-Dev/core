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
	
	# Get mouse position in screen space
	var mouse_screen = get_viewport().get_mouse_position()
	
	# Get character's 3D position - find the character node
	var character_node = get_parent() # Should be Character2D5D
	if not character_node:
		return Vector2.ZERO
	
	# Use character center position for consistent tracking
	#var character_3d_pos = character_node.global_position + Vector3(0, 1, 0)  # Center of character
	var character_3d_pos = character_node.global_position 
	# Project character position to screen
	var character_screen = camera_3d.unproject_position(character_3d_pos)
	
	# Calculate relative mouse position in screen space
	var mouse_relative_screen = mouse_screen - character_screen
	
	# Convert screen space to character's 2D space with consistent scaling
	var scale_factor = 0.35  
	var mouse_2d = mouse_relative_screen * scale_factor
	
	# REMOVED: No coordinate flipping - let's see what happens naturally
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

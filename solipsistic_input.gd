extends Node
class_name SolipsisticInput

# Input state (ported from input_handler.gd patterns)
var left_arm_active: bool = false
var right_arm_active: bool = false
var left_arm_target: Vector2 = Vector2.ZERO
var right_arm_target: Vector2 = Vector2.ZERO
var movement_direction: Vector2 = Vector2.ZERO
var z_movement: float = 0.0
var focus_direction: Vector2 = Vector2(1, 0)

# Arm locking for chording (ported from mouse_keyboard_input.gd)
var left_arm_locked: bool = false
var right_arm_locked: bool = false
var locked_left_position: Vector2 = Vector2.ZERO
var locked_right_position: Vector2 = Vector2.ZERO

# Mouse chording state
var left_arm_was_active = false
var right_arm_was_active = false

# References
var player: SolipsisticPlayer
var body_controller: SolipsisticBodyController

func setup(player_ref: SolipsisticPlayer, body_ref: SolipsisticBodyController):
	player = player_ref
	body_controller = body_ref

func _process(delta):
	update_input(delta)

func update_input(delta: float):
	# Update arm activation - using raw mouse input for reliability
	var left_mouse_active = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_mouse_active = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
	# Handle mouse chording
	handle_mouse_chording(left_mouse_active, right_mouse_active)
	
	# Convert mouse position to 2D character-relative coordinates
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
	
	# Send arm targets to body controller
	if body_controller:
		if left_arm_active:
			body_controller.set_arm_target(true, left_arm_target)
		if right_arm_active:
			body_controller.set_arm_target(false, right_arm_target)
	
	# Handle movement (A/D keys only)
	movement_direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		movement_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		movement_direction.x += 1.0
	
	# Handle orientation rotation (Q/E keys) - handled by player directly
	z_movement = 0.0
	if Input.is_key_pressed(KEY_Q):
		z_movement = 1.0
	elif Input.is_key_pressed(KEY_E):
		z_movement = -1.0
	
	# Handle focus direction (mouse when arms not active)
	if not (left_mouse_active or right_mouse_active):
		if mouse_2d_relative.length() > 10:
			focus_direction = mouse_2d_relative.normalized()

func get_mouse_position_relative_to_character() -> Vector2:
	# Get mouse position relative to screen center (where player consciousness is)
	var mouse_screen = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	var viewport_center = viewport_size / 2
	
	# Calculate relative mouse position from screen center
	var mouse_relative_screen = mouse_screen - viewport_center
	
	# Convert to character 2D coordinate space with fixed scale
	var mouse_2d = mouse_relative_screen * 0.5
	
	return mouse_2d

func handle_mouse_chording(left_active: bool, right_active: bool):
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

func set_arm_lock(is_left_arm: bool, locked: bool, position: Vector2 = Vector2.ZERO):
	if is_left_arm:
		left_arm_locked = locked
		if locked:
			locked_left_position = position
			print("🔒 Left arm locked at: " + str(position))
		else:
			print("🔓 Left arm unlocked")
	else:
		right_arm_locked = locked
		if locked:
			locked_right_position = position
			print("🔒 Right arm locked at: " + str(position))
		else:
			print("🔓 Right arm unlocked")

func get_movement_direction() -> Vector2:
	return movement_direction

func get_z_movement() -> float:
	return z_movement
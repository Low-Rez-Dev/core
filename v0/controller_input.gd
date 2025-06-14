extends InputHandler
class_name ControllerInput

# Controller-specific settings
@export var controller_arm_range = 60.0  # How far controller sticks can reach

# Controller state
var left_trigger_held = false
var right_trigger_held = false

# Shoulder button chording and recording state
var left_shoulder_held = false
var right_shoulder_held = false
var left_shoulder_locked = false
var right_shoulder_locked = false
var shoulder_locked_left_position: Vector2
var shoulder_locked_right_position: Vector2

# Recording state
var left_shoulder_tap_time = 0.0
var right_shoulder_tap_time = 0.0
var left_shoulder_was_active = false
var right_shoulder_was_active = false
var double_tap_window = 0.3  # Time window for double-tap detection

func update_input(delta: float, character_position: Vector2):
	# Update controller state
	update_controller_state()
	
	# Handle movement (left stick when left trigger not held)
	if not left_trigger_held:
		movement_direction = Vector2(
			Input.get_axis("left_stick_left", "left_stick_right"),
			Input.get_axis("left_stick_up", "left_stick_down")
		)
		# DEBUG: Print controller movement (commented out to reduce spam)
		# if movement_direction != Vector2.ZERO:
		# 	print("🎮 Controller movement: %s" % movement_direction)
	else:
		movement_direction = Vector2.ZERO
	
	# Handle arm targets
	update_arm_targets()
	
	# Handle focus direction (right stick when triggers not held)
	update_focus_direction()
	
	# Handle zoom
	if Input.is_action_just_pressed("left_stick_click"):
		request_zoom(-0.2)  # Zoom out
	elif Input.is_action_just_pressed("right_stick_click"):
		request_zoom(0.2)   # Zoom in

func update_controller_state():
	var left_trigger = Input.get_action_strength("left_trigger")
	var right_trigger = Input.get_action_strength("right_trigger")
	
	left_trigger_held = left_trigger > 0.1
	right_trigger_held = right_trigger > 0.1
	
	# Handle shoulder button state
	var left_shoulder_active = Input.is_action_pressed("record_left")
	var right_shoulder_active = Input.is_action_pressed("record_right")
	
	handle_shoulder_system(left_shoulder_active, right_shoulder_active)
	
	left_shoulder_held = left_shoulder_active
	right_shoulder_held = right_shoulder_active

func handle_shoulder_system(left_active: bool, right_active: bool):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Handle left shoulder double-tap for recording start
	if left_active and not left_shoulder_was_active:
		if current_time - left_shoulder_tap_time < double_tap_window:
			# Double-tap detected - start recording
			if not recording_active:
				set_recording(true)
			else:
				print("⚠️ Already recording!")
		left_shoulder_tap_time = current_time
	
	# Handle right shoulder double-tap for recording stop
	if right_active and not right_shoulder_was_active:
		if current_time - right_shoulder_tap_time < double_tap_window:
			# Double-tap detected - stop recording
			if recording_active:
				set_recording(false)
			else:
				print("⚠️ Not currently recording!")
		right_shoulder_tap_time = current_time
	
	# Handle shoulder holds for arm locking (only when not double-tapping)
	if left_active and not (current_time - left_shoulder_tap_time < double_tap_window):
		if not left_shoulder_locked:
			# Lock left arm at current position
			left_shoulder_locked = true
			shoulder_locked_left_position = left_arm_target
			print("🔒 LEFT ARM LOCKED (shoulder hold)")
	else:
		if left_shoulder_locked:
			left_shoulder_locked = false
			print("🔓 LEFT ARM UNLOCKED")
	
	if right_active and not (current_time - right_shoulder_tap_time < double_tap_window):
		if not right_shoulder_locked:
			# Lock right arm at current position
			right_shoulder_locked = true
			shoulder_locked_right_position = right_arm_target
			print("🔒 RIGHT ARM LOCKED (shoulder hold)")
	else:
		if right_shoulder_locked:
			right_shoulder_locked = false
			print("🔓 RIGHT ARM UNLOCKED")
	
	left_shoulder_was_active = left_active
	right_shoulder_was_active = right_active

func update_arm_targets():
	# Left arm
	if left_shoulder_locked:
		left_arm_target = shoulder_locked_left_position
		left_arm_active = true
	elif left_trigger_held:
		var stick_input = Vector2(
			Input.get_axis("left_stick_left", "left_stick_right"),
			Input.get_axis("left_stick_up", "left_stick_down")
		)
		left_arm_target = stick_input * controller_arm_range
		left_arm_active = true
	else:
		left_arm_active = false
	
	# Right arm
	if right_shoulder_locked:
		right_arm_target = shoulder_locked_right_position
		right_arm_active = true
	elif right_trigger_held:
		var stick_input = Vector2(
			Input.get_axis("right_stick_left", "right_stick_right"),
			Input.get_axis("right_stick_up", "right_stick_down")
		)
		right_arm_target = stick_input * controller_arm_range
		right_arm_active = true
	else:
		right_arm_active = false

func update_focus_direction():
	# Use right stick for focus when triggers are not held
	if not (left_trigger_held or right_trigger_held):
		var right_stick = Vector2(
			Input.get_axis("right_stick_left", "right_stick_right"),
			Input.get_axis("right_stick_up", "right_stick_down")
		)
		if right_stick.length() > 0.1:
			focus_direction = right_stick.normalized()

# Override base class methods for shoulder locking
func is_left_arm_locked() -> bool:
	return left_arm_locked or left_shoulder_locked

func is_right_arm_locked() -> bool:
	return right_arm_locked or right_shoulder_locked

func get_locked_position(is_left_arm: bool) -> Vector2:
	if is_left_arm:
		return shoulder_locked_left_position if left_shoulder_locked else locked_left_position
	else:
		return shoulder_locked_right_position if right_shoulder_locked else locked_right_position

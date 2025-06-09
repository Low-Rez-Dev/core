extends Node
class_name InputHandler

# Base class for all input types (mouse/keyboard, controller, AI)

# Input state that all handlers should provide
var left_arm_active: bool = false
var right_arm_active: bool = false
var left_arm_target: Vector2 = Vector2.ZERO
var right_arm_target: Vector2 = Vector2.ZERO
var movement_direction: Vector2 = Vector2.ZERO
var z_movement: float = 0.0  # New: Z-axis movement
var focus_direction: Vector2 = Vector2.RIGHT

# Chording/locking state
var left_arm_locked: bool = false
var right_arm_locked: bool = false
var locked_left_position: Vector2 = Vector2.ZERO
var locked_right_position: Vector2 = Vector2.ZERO

# Recording state
var recording_active: bool = false

# Signals for important events
signal arm_lock_changed(is_left_arm: bool, is_locked: bool)
signal recording_started()
signal recording_stopped()
signal zoom_requested(zoom_delta: float)

# Virtual methods that specific input handlers must implement
func update_input(delta: float, character_position: Vector2):
	# Override in subclasses
	pass

func get_left_arm_active() -> bool:
	return left_arm_active

func get_right_arm_active() -> bool:
	return right_arm_active

func get_left_arm_target() -> Vector2:
	return left_arm_target

func get_right_arm_target() -> Vector2:
	return right_arm_target

func get_movement_direction() -> Vector2:
	return movement_direction

func get_z_movement() -> float:
	return z_movement

func get_focus_direction() -> Vector2:
	return focus_direction

func is_left_arm_locked() -> bool:
	return left_arm_locked

func is_right_arm_locked() -> bool:
	return right_arm_locked

func get_locked_position(is_left_arm: bool) -> Vector2:
	return locked_left_position if is_left_arm else locked_right_position

func is_recording() -> bool:
	return recording_active

# Helper functions for subclasses
func set_arm_lock(is_left_arm: bool, locked: bool, position: Vector2 = Vector2.ZERO):
	if is_left_arm:
		left_arm_locked = locked
		if locked:
			locked_left_position = position
	else:
		right_arm_locked = locked
		if locked:
			locked_right_position = position
	
	arm_lock_changed.emit(is_left_arm, locked)

func set_recording(active: bool):
	if active != recording_active:
		recording_active = active
		if active:
			recording_started.emit()
		else:
			recording_stopped.emit()

func request_zoom(delta: float):
	zoom_requested.emit(delta)

class_name RotationConstraint
extends Resource

@export var min_angle: float = -PI/2      # Minimum rotation angle (radians)
@export var max_angle: float = PI/2       # Maximum rotation angle (radians)
@export var rest_angle: float = 0.0       # Default/natural position
@export var stiffness: float = 1.0        # Resistance to movement (0.0 - 1.0)
@export var constraint_type: String = "hinge"  # "hinge", "ball_socket", "fixed", "twist"

func _init():
	pass

func is_angle_valid(angle: float) -> bool:
	return angle >= min_angle and angle <= max_angle

func clamp_angle(angle: float) -> float:
	return clamp(angle, min_angle, max_angle)

func get_angle_range() -> float:
	return max_angle - min_angle

func apply_stiffness(current_angle: float, target_angle: float, delta: float) -> float:
	var clamped_target = clamp_angle(target_angle)
	return lerp(current_angle, clamped_target, stiffness * delta)

func duplicate_constraint() -> RotationConstraint:
	var new_constraint = RotationConstraint.new()
	new_constraint.min_angle = min_angle
	new_constraint.max_angle = max_angle
	new_constraint.rest_angle = rest_angle
	new_constraint.stiffness = stiffness
	new_constraint.constraint_type = constraint_type
	return new_constraint

# Preset constraint types
static func create_hinge_constraint(min_deg: float = -90, max_deg: float = 90) -> RotationConstraint:
	var constraint = RotationConstraint.new()
	constraint.constraint_type = "hinge"
	constraint.min_angle = deg_to_rad(min_deg)
	constraint.max_angle = deg_to_rad(max_deg)
	constraint.rest_angle = 0.0
	constraint.stiffness = 0.8
	return constraint

static func create_ball_socket_constraint(range_deg: float = 180) -> RotationConstraint:
	var constraint = RotationConstraint.new()
	constraint.constraint_type = "ball_socket"
	constraint.min_angle = deg_to_rad(-range_deg/2)
	constraint.max_angle = deg_to_rad(range_deg/2)
	constraint.rest_angle = 0.0
	constraint.stiffness = 0.6
	return constraint

static func create_fixed_constraint() -> RotationConstraint:
	var constraint = RotationConstraint.new()
	constraint.constraint_type = "fixed"
	constraint.min_angle = 0.0
	constraint.max_angle = 0.0
	constraint.rest_angle = 0.0
	constraint.stiffness = 1.0
	return constraint

static func create_twist_constraint(range_deg: float = 360) -> RotationConstraint:
	var constraint = RotationConstraint.new()
	constraint.constraint_type = "twist"
	constraint.min_angle = deg_to_rad(-range_deg/2)
	constraint.max_angle = deg_to_rad(range_deg/2)
	constraint.rest_angle = 0.0
	constraint.stiffness = 0.4
	return constraint

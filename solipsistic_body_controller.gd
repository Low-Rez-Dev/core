extends Node
class_name SolipsisticBodyController

# Adjustable body proportions (ported from original body_controller.gd)
@export var body_scale = 1.0
@export var head_radius = 10.0
@export var neck_length = 6.0
@export var torso_width = 12.0
@export var torso_height = 38.0
@export var shoulder_height_ratio = 0.05
@export var hip_width_ratio = 0.9
@export var upper_arm_length = 22.0
@export var lower_arm_length = 20.0
@export var leg_length = 40.0
@export var foot_length = 8.0

# Animation settings
@export var arm_return_speed = 5.0

var facing_right = true
var debug_ik_active = false

# Calculated properties
var arm_reach: float
var shoulder_width: float
var hip_width: float
var shoulder_y: float

# Current arm positions for smooth transitions
var current_left_target: Vector2
var current_right_target: Vector2

# Reference to the player entity
var player_entity: SolipsisticPlayer

signal proportions_changed

func _ready():
	update_proportions()

func setup(player: SolipsisticPlayer):
	player_entity = player

func update_proportions():
	arm_reach = (upper_arm_length + lower_arm_length) * body_scale
	shoulder_width = torso_width * body_scale
	hip_width = (torso_width * hip_width_ratio) * body_scale
	shoulder_y = (-(torso_height * 0.5) + (torso_height * shoulder_height_ratio)) * body_scale
	proportions_changed.emit()

func get_ik_engagement_range() -> float:
	return arm_reach * 0.75

func get_shoulder_pos(is_left: bool) -> Vector2:
	var x = shoulder_width * (-1 if is_left else 1)
	return Vector2(x, shoulder_y)

func get_hip_rest_pos(is_left: bool) -> Vector2:
	var x = (hip_width * 0.7) * (-1 if is_left else 1)
	var y = (torso_height * 0.5) * body_scale
	return Vector2(x, y)

func get_head_center_pos() -> Vector2:
	var head_center_y = -(torso_height * 0.5 + neck_length + head_radius) * body_scale
	return Vector2(0, head_center_y)

func set_arm_target(is_left_arm: bool, target_position: Vector2, interpolation_speed: float = -1.0):
	if interpolation_speed < 0:
		interpolation_speed = arm_return_speed * get_process_delta_time() * 100
	
	if is_left_arm:
		current_left_target = current_left_target.move_toward(target_position, interpolation_speed)
	else:
		current_right_target = current_right_target.move_toward(target_position, interpolation_speed)

func calculate_ik_arm(shoulder_pos: Vector2, target_pos: Vector2, is_left_arm: bool) -> Dictionary:
	# Convert absolute target position to relative position from shoulder
	var relative_target = target_pos - shoulder_pos
	var distance = relative_target.length()
	var scaled_reach = arm_reach
	
	# Determine if target is within reach for precise IK or pointing mode
	var ik_threshold = scaled_reach
	var within_reach = distance <= ik_threshold
	
	if within_reach:
		# PRECISE IK MODE: Hand tracks cursor exactly, elbow bends naturally
		var clamped_target = relative_target
		
		# Prevent invalid triangle (when target too close)
		var min_distance = abs((upper_arm_length - lower_arm_length) * body_scale) + 1.0
		if distance < min_distance:
			clamped_target = relative_target.normalized() * min_distance
			distance = min_distance
		
		# Calculate elbow position using law of cosines
		var a = upper_arm_length * body_scale
		var b = lower_arm_length * body_scale
		var c = distance
		
		# Angle at shoulder using law of cosines
		var cos_angle_a = (a*a + c*c - b*b) / (2*a*c)
		cos_angle_a = clamp(cos_angle_a, -1.0, 1.0)
		var angle_a = acos(cos_angle_a)
		
		var target_angle = atan2(clamped_target.y, clamped_target.x)
		
		# Elbow bending direction based on facing
		var elbow_direction = 1.0 if facing_right else -1.0
		
		var elbow_angle = target_angle + (angle_a * elbow_direction)
		var elbow_pos_relative = Vector2(cos(elbow_angle), sin(elbow_angle)) * a
		
		return {
			"shoulder": shoulder_pos,
			"elbow": shoulder_pos + elbow_pos_relative,
			"hand": shoulder_pos + clamped_target,
			"mode": "precise"
		}
	else:
		# POINTING MODE: Arms fully extended toward cursor
		var pointing_direction = relative_target.normalized()
		var extended_reach = scaled_reach
		
		# Elbow positioned partway along the extended arm
		var elbow_distance = upper_arm_length * body_scale
		var elbow_pos_relative = pointing_direction * elbow_distance
		var hand_pos_relative = pointing_direction * extended_reach
		
		return {
			"shoulder": shoulder_pos,
			"elbow": shoulder_pos + elbow_pos_relative,
			"hand": shoulder_pos + hand_pos_relative,
			"mode": "pointing"
		}

func set_facing_direction(face_right: bool):
	if face_right == facing_right:
		return
	
	facing_right = face_right
	print("🎭 Body facing direction changed to: " + ("RIGHT" if facing_right else "LEFT"))

func get_arm_data(is_left_arm: bool) -> Dictionary:
	var shoulder_pos = get_shoulder_pos(is_left_arm)
	var target = current_left_target if is_left_arm else current_right_target
	return calculate_ik_arm(shoulder_pos, target, is_left_arm)

func update_player_arm_data():
	"""Updates the player entity's arm data for procedural drawing"""
	if not player_entity:
		return
	
	var left_data = get_arm_data(true)
	var right_data = get_arm_data(false)
	
	player_entity.left_arm_data = {
		"elbow": left_data.get("elbow", Vector2.ZERO),
		"hand": left_data.get("hand", Vector2.ZERO)
	}
	
	player_entity.right_arm_data = {
		"elbow": right_data.get("elbow", Vector2.ZERO),
		"hand": right_data.get("hand", Vector2.ZERO)
	}
	
	player_entity.facing_right = facing_right

func _process(delta):
	update_player_arm_data()
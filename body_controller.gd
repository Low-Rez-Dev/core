extends Node2D
class_name BodyController

# Adjustable body proportions
@export var body_scale = 1.0
@export var head_radius = 10.0
@export var neck_length = 6.0
@export var torso_width = 12.0
@export var torso_height = 38.0
@export var shoulder_height_ratio = 0.05  # How far down torso shoulders are (0.0 = top, 1.0 = bottom)
@export var hip_width_ratio = 0.9
@export var upper_arm_length = 22.0
@export var lower_arm_length = 20.0
@export var leg_length = 40.0
@export var foot_length = 8.0

# Animation settings
@export var arm_return_speed = 5.0  # How fast arms return to rest position

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

signal proportions_changed

func _ready():
	update_proportions()

func update_proportions():
	arm_reach = (upper_arm_length + lower_arm_length) * body_scale
	shoulder_width = torso_width * body_scale
	hip_width = (torso_width * hip_width_ratio) * body_scale
	shoulder_y = (-(torso_height * 0.5) + (torso_height * shoulder_height_ratio)) * body_scale
	proportions_changed.emit()

func get_ik_engagement_range() -> float:
	# IK mode should engage at about 75% of full arm reach for natural feel
	return arm_reach * 0.75

func get_shoulder_pos(is_left: bool) -> Vector2:
	# Arms stay on anatomically correct sides - no swapping
	var x = shoulder_width * (-1 if is_left else 1)
	return Vector2(x, shoulder_y)

func get_hip_rest_pos(is_left: bool) -> Vector2:
	# Hips stay on anatomically correct sides - no swapping
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
	
	# DEBUG: Print IK calculation inputs and intermediate values (commented out to reduce spam)
	# print("[BODY_CONTROLLER] IK for %s arm | Target pos: %s | Shoulder pos: %s | Relative target: %s | Distance: %.2f" % [
	# 	"LEFT" if is_left_arm else "RIGHT", target_pos, shoulder_pos, relative_target, distance
	# ])
	
	# Determine if target is within reach for precise IK or pointing mode
	var ik_threshold = scaled_reach
	var within_reach = distance <= ik_threshold
	
	# DEBUG: Print IK engagement data when arms are active
	if debug_ik_active:
		print("=== IK DEBUG ===")
		print("Distance to target: %.2f" % distance)
		print("Arm reach (threshold): %.2f" % ik_threshold) 
		print("Upper arm length: %.2f" % (upper_arm_length * body_scale))
		print("Lower arm length: %.2f" % (lower_arm_length * body_scale))
		print("Within reach: %s" % ("YES" if within_reach else "NO"))
		print("Mode: %s" % ("PRECISE IK" if within_reach else "POINTING"))
		print("==================")
	
	if within_reach:
		# PRECISE IK MODE: Hand tracks cursor exactly, elbow bends naturally
		var clamped_target = relative_target
		
		# Prevent invalid triangle (when target too close)
		var min_distance = abs((upper_arm_length - lower_arm_length) * body_scale) + 1.0
		if distance < min_distance:
			clamped_target = relative_target.normalized() * min_distance
			distance = min_distance
		
		# Calculate elbow position using law of cosines
		var a = upper_arm_length * body_scale  # Shoulder to elbow (original length)
		var b = lower_arm_length * body_scale  # Elbow to hand (original length)
		var c = distance  # Shoulder to hand
		
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
	

func rotate_position_with_facing(original_position: Vector2) -> Vector2:
	# REMOVED: This function was causing arm swapping - arms stay on correct sides
	return original_position

func set_facing_direction(face_right: bool):
	# FIXED: Prevent rapid toggling by only changing if different
	if face_right == facing_right:
		return  # No change needed
	
	facing_right = face_right
	print("🎭 Body facing direction changed to: " + ("RIGHT" if facing_right else "LEFT"))
	
	# Force redraw
	queue_redraw()
	
	# Signal parent to update texture
	var parent = get_parent()
	if parent and parent.has_method("force_texture_update"):
		parent.force_texture_update()

func get_facing_indicator_data() -> Array:
	# Triangle direction based on facing
	if facing_right:
		return [Vector2(15, -8), Vector2(25, 0), Vector2(15, 8)]  # Point right
	else:
		return [Vector2(-15, -8), Vector2(-25, 0), Vector2(-15, 8)]  # Point left

# Helper functions that return drawing data instead of drawing directly
func get_body_outline_data() -> Dictionary:
	var body_scale_local = body_scale
	var data = {}
	
	# Head
	var head_y = -(torso_height * 0.5 + neck_length + head_radius) * body_scale_local
	data.head_pos = Vector2(0, head_y)
	data.head_radius = head_radius * body_scale_local
	
	# Neck
	data.neck_top = Vector2(0, head_y + head_radius * body_scale_local)
	data.neck_bottom = Vector2(0, -(torso_height * 0.5) * body_scale_local)
	
	# Torso
	data.torso_rect = Rect2(
		-torso_width * body_scale_local, 
		-(torso_height * 0.5) * body_scale_local, 
		torso_width * 2 * body_scale_local, 
		torso_height * body_scale_local
	)
	
	# Shoulder line
	data.shoulder_left = Vector2(-shoulder_width * body_scale_local, shoulder_y)
	data.shoulder_right = Vector2(shoulder_width * body_scale_local, shoulder_y)
	
	# Hip line
	var hip_y = (torso_height * 0.5) * body_scale_local
	data.hip_left = Vector2(-hip_width * body_scale_local, hip_y)
	data.hip_right = Vector2(hip_width * body_scale_local, hip_y)
	
	# Legs
	var leg_separation = 6 * body_scale_local
	data.left_leg_top = Vector2(-leg_separation, hip_y)
	data.left_leg_bottom = Vector2(-leg_separation, hip_y + leg_length * body_scale_local)
	data.right_leg_top = Vector2(leg_separation, hip_y)
	data.right_leg_bottom = Vector2(leg_separation, hip_y + leg_length * body_scale_local)
	
	# Feet
	var foot_len = foot_length * body_scale_local
	data.left_foot_start = data.left_leg_bottom
	data.left_foot_end = Vector2(-leg_separation - foot_len, hip_y + leg_length * body_scale_local)
	data.right_foot_start = data.right_leg_bottom
	data.right_foot_end = Vector2(leg_separation + foot_len, hip_y + leg_length * body_scale_local)
	
	# Reference points
	data.left_shoulder_marker = get_shoulder_pos(true)
	data.right_shoulder_marker = get_shoulder_pos(false)
	data.left_hip_marker = get_hip_rest_pos(true)
	data.right_hip_marker = get_hip_rest_pos(false)
	
	return data

func get_arm_data(is_left_arm: bool) -> Dictionary:
	var shoulder_pos = get_shoulder_pos(is_left_arm)
	var target = current_left_target if is_left_arm else current_right_target
	return calculate_ik_arm(shoulder_pos, target, is_left_arm)

func force_triangle_debug():
	print("=== TRIANGLE DEBUG ===")
	print("facing_right: " + str(facing_right))
	print("Triangle points: " + str(get_facing_indicator_data()))
	print("Redrawing now...")
	queue_redraw()
	print("=====================")

func get_focus_cone_data(focus_direction: Vector2, cone_angle: float = 45.0, cone_length: float = 60.0) -> Dictionary:
	var head_pos = get_head_center_pos()
	
	# Calculate cone endpoints
	var cone_angle_rad = deg_to_rad(cone_angle)
	var focus_angle = atan2(focus_direction.y, focus_direction.x)
	
	# Main focus ray
	var focus_end = head_pos + focus_direction * cone_length
	
	# Cone edges
	var left_angle = focus_angle - cone_angle_rad / 2
	var right_angle = focus_angle + cone_angle_rad / 2
	
	var left_edge = head_pos + Vector2(cos(left_angle), sin(left_angle)) * cone_length
	var right_edge = head_pos + Vector2(cos(right_angle), sin(right_angle)) * cone_length
	
	return {
		"head_pos": head_pos,
		"focus_end": focus_end,
		"left_edge": left_edge,
		"right_edge": right_edge,
		"focus_direction": focus_direction
	}

func _draw():
	# BodyController no longer draws anything directly
	pass

func _process(delta):
	queue_redraw()

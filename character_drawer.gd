extends Node2D
class_name CharacterDrawer

# Draws the 2D character using the body controller data

var body_controller: BodyController
var input_handler: InputHandler

func _draw():
	if not body_controller or not input_handler:
		return
	
	# Center the drawing in the viewport
	var center = Vector2(200, 300)
	
	# Draw body outline
	var body_data = body_controller.get_body_outline_data()
	
	# Head
	draw_circle(center + body_data.head_pos, body_data.head_radius, Color.GRAY, false, 2)
	
	# Neck
	draw_line(center + body_data.neck_top, center + body_data.neck_bottom, Color.GRAY, 2)
	
	# Torso
	var torso_rect = body_data.torso_rect
	torso_rect.position += center
	draw_rect(torso_rect, Color.GRAY, false, 2)
	
	# Shoulder and hip lines
	draw_line(center + body_data.shoulder_left, center + body_data.shoulder_right, Color.GRAY, 2)
	draw_line(center + body_data.hip_left, center + body_data.hip_right, Color.GRAY, 2)
	
	# Legs and feet
	draw_line(center + body_data.left_leg_top, center + body_data.left_leg_bottom, Color.GRAY, 2)
	draw_line(center + body_data.right_leg_top, center + body_data.right_leg_bottom, Color.GRAY, 2)
	draw_line(center + body_data.left_foot_start, center + body_data.left_foot_end, Color.GRAY, 2)
	draw_line(center + body_data.right_foot_start, center + body_data.right_foot_end, Color.GRAY, 2)
	
	# Draw arms with activity colors - RED always on left, BLUE always on right
	var left_color = Color.RED if input_handler.get_left_arm_active() else Color.DARK_RED
	var right_color = Color.BLUE if input_handler.get_right_arm_active() else Color.DARK_BLUE
	
	var left_arm = body_controller.get_arm_data(true)
	var right_arm = body_controller.get_arm_data(false)
	
	# Draw arms
	draw_line(center + left_arm.shoulder, center + left_arm.elbow, left_color, 3)
	draw_line(center + left_arm.elbow, center + left_arm.hand, left_color * 0.7, 3)
	draw_circle(center + left_arm.elbow, 3, left_color)
	
	draw_line(center + right_arm.shoulder, center + right_arm.elbow, right_color, 3)
	draw_line(center + right_arm.elbow, center + right_arm.hand, right_color * 0.7, 3)
	draw_circle(center + right_arm.elbow, 3, right_color)
	
	# Draw facing indicator triangle
	var face_indicator = body_controller.get_facing_indicator_data()
	var face_points = PackedVector2Array()
	for point in face_indicator:
		face_points.append(center + point)
	
	# Draw filled triangle
	draw_colored_polygon(face_points, Color.YELLOW)
	
	# Draw triangle outline for extra visibility
	if face_points.size() >= 3:
		draw_line(face_points[0], face_points[1], Color.RED, 2)
		draw_line(face_points[1], face_points[2], Color.RED, 2)
		draw_line(face_points[2], face_points[0], Color.RED, 2)
	
	# Draw facing direction text
	var facing_text = "FACING: " + ("RIGHT" if body_controller.facing_right else "LEFT")
	draw_string(ThemeDB.fallback_font, center + Vector2(-50, -100), facing_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)
	
	# Draw reference markers
	draw_circle(center + body_data.left_shoulder_marker, 2, Color.WHITE)
	draw_circle(center + body_data.right_shoulder_marker, 2, Color.WHITE)
	draw_circle(center + body_data.left_hip_marker, 2, Color.GREEN)
	draw_circle(center + body_data.right_hip_marker, 2, Color.GREEN)

	if input_handler and not (input_handler.get_left_arm_active() or input_handler.get_right_arm_active()):
		var focus_dir = input_handler.get_focus_direction()
		if focus_dir.length() > 0.1:  # Only draw if focus is active
			var focus_data = body_controller.get_focus_cone_data(focus_dir)
			
			# Draw focus cone outline
			var cone_color = Color.CYAN
			cone_color.a = 0.3  # Semi-transparent
			
			# Draw cone edges
			draw_line(center + focus_data.head_pos, center + focus_data.left_edge, cone_color, 2)
			draw_line(center + focus_data.head_pos, center + focus_data.right_edge, cone_color, 2)
			draw_line(center + focus_data.left_edge, center + focus_data.right_edge, cone_color, 1)
			
			# Draw main focus ray (brighter)
			var focus_ray_color = Color.YELLOW
			focus_ray_color.a = 0.8
			draw_line(center + focus_data.head_pos, center + focus_data.focus_end, focus_ray_color, 2)
			
			# Draw focus point
			draw_circle(center + focus_data.focus_end, 3, Color.YELLOW)

func _process(delta):
	queue_redraw()

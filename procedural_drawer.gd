extends Node2D
class_name ProceduralDrawer

var entity: ProceduralEntity

func _draw():
	if not entity:
		return
	
	# Draw based on entity type and detail level
	match entity.get_entity_type():
		"player":
			draw_player()
		"enemy":
			draw_enemy()
		"building":
			draw_building()
		"tree":
			draw_tree()
		"pine_tree":
			draw_pine_tree()
		_:
			draw_generic_entity()

func draw_player():
	"""Draw the player character with dual arms"""
	var size = entity.entity_size
	
	# Body (rounded rectangle)
	var body_rect = Rect2(-size/4, -size/2, size/2, size * 0.8)
	draw_rect(body_rect, entity.primary_color, true, -1)
	draw_rect(body_rect, entity.outline_color, false, entity.outline_width)
	
	# Head (circle)
	var head_pos = Vector2(0, -size/2 - size/6)
	draw_circle(head_pos, size/6, entity.secondary_color)
	draw_arc(head_pos, size/6, 0, TAU, 32, entity.outline_color, entity.outline_width)
	
	# Arms (lines) - get from existing arm IK system
	if entity.has_method("get_arm_positions"):
		var arm_data = entity.get_arm_positions()
		
		# Left arm (red)
		if arm_data.has("left_shoulder") and arm_data.has("left_elbow") and arm_data.has("left_hand"):
			draw_line(arm_data.left_shoulder, arm_data.left_elbow, Color.RED, 4)
			draw_line(arm_data.left_elbow, arm_data.left_hand, Color.RED, 3)
			draw_circle(arm_data.left_elbow, 3, Color.DARK_RED)
			draw_circle(arm_data.left_hand, 4, Color.RED)
		
		# Right arm (blue)
		if arm_data.has("right_shoulder") and arm_data.has("right_elbow") and arm_data.has("right_hand"):
			draw_line(arm_data.right_shoulder, arm_data.right_elbow, Color.BLUE, 4)
			draw_line(arm_data.right_elbow, arm_data.right_hand, Color.BLUE, 3)
			draw_circle(arm_data.right_elbow, 3, Color.DARK_BLUE)
			draw_circle(arm_data.right_hand, 4, Color.BLUE)
	
	# Legs (simple lines)
	var leg_start = Vector2(0, size/2 - size/8)
	draw_line(Vector2(-size/8, leg_start.y), Vector2(-size/8, leg_start.y + size/3), entity.outline_color, 3)
	draw_line(Vector2(size/8, leg_start.y), Vector2(size/8, leg_start.y + size/3), entity.outline_color, 3)
	
	# Facing indicator (triangle)
	if entity.has_method("get_facing_direction"):
		var facing_right = entity.get_facing_direction()
		var triangle_points = PackedVector2Array()
		if facing_right:
			triangle_points = [Vector2(size/3, -size/8), Vector2(size/2, 0), Vector2(size/3, size/8)]
		else:
			triangle_points = [Vector2(-size/3, -size/8), Vector2(-size/2, 0), Vector2(-size/3, size/8)]
		draw_colored_polygon(triangle_points, Color.YELLOW)

func draw_enemy():
	"""Draw an enemy with animated features"""
	var size = entity.entity_size
	var time = entity.animation_time
	
	# Animated bobbing
	var bob_offset = sin(time * entity.bob_speed) * entity.bob_amplitude
	
	# Main body (hexagon for different look)
	var points = PackedVector2Array()
	for i in range(6):
		var angle = i * TAU / 6
		var point = Vector2(cos(angle), sin(angle)) * size/2
		point.y += bob_offset
		points.append(point)
	
	draw_colored_polygon(points, entity.primary_color)
	
	# Outline
	for i in range(points.size()):
		var start = points[i]
		var end = points[(i + 1) % points.size()]
		draw_line(start, end, entity.outline_color, entity.outline_width)
	
	# Eyes (animated)
	var eye_y = -size/4 + bob_offset
	draw_circle(Vector2(-size/4, eye_y), size/8, Color.RED)
	draw_circle(Vector2(size/4, eye_y), size/8, Color.RED)
	
	# Animated details based on detail level
	if entity.current_detail >= ProceduralEntity.DetailLevel.MEDIUM:
		# Breathing animation
		var breath_scale = 1.0 + sin(time * 2) * 0.1
		var breath_rect = Rect2(-size/6, -size/8, size/3, size/4)
		# Scale the rect by modifying position and size
		var scaled_pos = breath_rect.position * breath_scale
		var scaled_size = breath_rect.size * breath_scale
		breath_rect = Rect2(scaled_pos, scaled_size)
		draw_rect(breath_rect, entity.secondary_color, true)

func draw_building():
	"""Draw a building structure"""
	var size = entity.entity_size * 2  # Buildings are bigger
	
	# Main structure (rectangle)
	var building_rect = Rect2(-size/2, -size, size, size)
	draw_rect(building_rect, entity.primary_color, true)
	draw_rect(building_rect, entity.outline_color, false, entity.outline_width)
	
	# Roof (triangle)
	var roof_points = PackedVector2Array([
		Vector2(-size/2, -size),
		Vector2(0, -size - size/3),
		Vector2(size/2, -size)
	])
	draw_colored_polygon(roof_points, entity.secondary_color)
	
	# Details based on distance
	if entity.current_detail >= ProceduralEntity.DetailLevel.MEDIUM:
		# Windows
		var window_size = size/8
		for x in range(-1, 2, 2):
			for y in range(-3, 0):
				var window_pos = Vector2(x * size/4, y * size/4 - size/8)
				var window_rect = Rect2(window_pos - Vector2(window_size/2, window_size/2), 
									  Vector2(window_size, window_size))
				draw_rect(window_rect, Color.YELLOW, true)
				draw_rect(window_rect, entity.outline_color, false, 1)
		
		# Door
		var door_rect = Rect2(-size/8, -size/4, size/4, size/2)
		draw_rect(door_rect, Color.BROWN, true)
		draw_rect(door_rect, entity.outline_color, false, 2)

func draw_tree():
	"""Draw a tree with organic shapes"""
	var size = entity.entity_size
	var time = entity.animation_time
	
	# Trunk (tapered rectangle)
	var trunk_width = size/6
	var trunk_height = size/2
	var trunk_points = PackedVector2Array([
		Vector2(-trunk_width, 0),
		Vector2(trunk_width, 0),
		Vector2(trunk_width/2, -trunk_height),
		Vector2(-trunk_width/2, -trunk_height)
	])
	draw_colored_polygon(trunk_points, Color.SADDLE_BROWN)
	
	# Foliage (circles with slight animation)
	var wind_sway = sin(time * entity.bob_speed * 0.5) * 2
	
	# Multiple overlapping circles for organic look
	var foliage_centers = [
		Vector2(0, -trunk_height - size/3),
		Vector2(-size/4, -trunk_height - size/4),
		Vector2(size/4, -trunk_height - size/4),
		Vector2(0, -trunk_height - size/2)
	]
	
	for center in foliage_centers:
		center.x += wind_sway
		var radius = size/3 + randf_range(-size/8, size/8)
		draw_circle(center, radius, entity.primary_color)
		
		# Add some texture with smaller circles
		if entity.current_detail >= ProceduralEntity.DetailLevel.HIGH:
			for i in range(3):
				var small_center = center + Vector2(randf_range(-radius/2, radius/2), randf_range(-radius/2, radius/2))
				draw_circle(small_center, radius/4, entity.secondary_color)

func draw_generic_entity():
	"""Fallback drawing for unknown entity types"""
	var size = entity.entity_size
	
	# Simple diamond shape
	var points = PackedVector2Array([
		Vector2(0, -size/2),
		Vector2(size/2, 0),
		Vector2(0, size/2),
		Vector2(-size/2, 0)
	])
	
	draw_colored_polygon(points, entity.primary_color)
	
	# Outline
	for i in range(points.size()):
		var start = points[i]
		var end = points[(i + 1) % points.size()]
		draw_line(start, end, entity.outline_color, entity.outline_width)

func draw_pine_tree():
	"""Draw a pine tree with layered triangular canopy"""
	var size = entity.entity_size
	var time = entity.animation_time
	
	# Get tree properties from entity if it has them
	var tree_height = size
	var trunk_width = size / 8.0
	var canopy_layers = 4
	
	if entity.has_method("get_tree_properties"):
		var props = entity.get_tree_properties()
		tree_height = props.get("height", size)
		trunk_width = props.get("trunk_width", size / 8.0)
		canopy_layers = props.get("canopy_layers", 4)
	
	var half_size = tree_height / 2
	
	# Subtle wind sway
	var wind_sway = sin(time * 0.5) * 1.0
	
	# Draw trunk
	var trunk_color = Color(0.6, 0.3, 0.1)  # Brown
	var trunk_height = tree_height * 0.3
	var trunk_rect = Rect2(
		Vector2(-trunk_width/2 + wind_sway * 0.2, half_size - trunk_height),
		Vector2(trunk_width, trunk_height)
	)
	draw_rect(trunk_rect, trunk_color)
	
	# Draw canopy layers (triangular sections)
	var layer_height = (tree_height * 0.8) / canopy_layers
	
	for i in range(canopy_layers):
		var layer_y = half_size - trunk_height - (i * layer_height * 0.7)  # Overlap layers
		var layer_width = trunk_width + (canopy_layers - i) * 12.0
		
		# Add wind sway to each layer
		var layer_sway = wind_sway * (1.0 + i * 0.3)  # Upper layers sway more
		
		# Create triangle points for this canopy layer
		var triangle_points = PackedVector2Array([
			Vector2(layer_sway, layer_y - layer_height),        # Top point
			Vector2(-layer_width/2 + layer_sway, layer_y),      # Bottom left
			Vector2(layer_width/2 + layer_sway, layer_y)        # Bottom right
		])
		
		# Alternate colors for depth
		var layer_color = entity.primary_color if i % 2 == 0 else entity.secondary_color
		draw_colored_polygon(triangle_points, layer_color)
		
		# Add outline
		for j in range(triangle_points.size()):
			var next_j = (j + 1) % triangle_points.size()
			draw_line(triangle_points[j], triangle_points[next_j], entity.outline_color, 1.0)

func _process(delta):
	queue_redraw()

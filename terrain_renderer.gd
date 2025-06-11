extends Node2D
class_name TerrainRenderer

var terrain_system: TerrainSystem
var terrain_layers: Dictionary = {}  # Changed from PackedVector2Array to Dictionary

# Day/night cycle (24 minutes = 24 hours)
var day_cycle_duration: float = 24.0 * 60.0  # 24 minutes in seconds
var current_time: float = 6.0 * 60.0  # Start at 6 AM (6 minutes into cycle)

# Visual parameters
var terrain_color: Color = Color(0.6, 0.4, 0.2)  # Brown earth
var rock_color: Color = Color(0.5, 0.5, 0.5)     # Gray rock
var surface_color: Color = Color(0.4, 0.7, 0.3)  # Green grass
var line_width: float = 2.0
var vertical_scale: float = 2.0  # Exaggerate height for visibility


func setup(terrain_sys: TerrainSystem):
	terrain_system = terrain_sys
	add_to_group("TerrainRenderer")  # Add to group so trees can find us

func _process(delta):
	# Update day/night cycle
	current_time += delta
	if current_time >= day_cycle_duration:
		current_time -= day_cycle_duration  # Wrap to next day
	
	
	if terrain_system:
		update_cross_section()
	queue_redraw()

func update_cross_section():
	"""Update terrain cross-section based on current player position and orientation"""
	var coords = SolipsisticCoordinates
	var observer_pos = coords.player_consciousness_pos
	var orientation = coords.current_orientation
	
	# Calculate terrain width based on screen width
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	var horizontal_scale = 3.0  # Same scale used in draw function
	var terrain_width = (viewport_size.x / horizontal_scale) + 50.0  # Extra padding for smooth edges
	
	# Get multiple terrain layers for depth visualization
	terrain_layers = get_multi_layer_terrain(observer_pos, orientation, terrain_width)
	
	# Debug: Print some info about the cross-section
	if terrain_layers.has("interactive") and terrain_layers["interactive"].size() > 0:
		var interactive = terrain_layers["interactive"]
		print("Interactive terrain: %d points, first: %s, last: %s" % [
			interactive.size(), 
			interactive[0], 
			interactive[-1]
		])

func _draw():
	if terrain_layers.is_empty():
		return
	
	draw_multi_layer_terrain()


func calculate_perspective_scale(distance: float) -> float:
	"""Calculate perspective scaling - distant objects appear smaller"""
	var min_scale = 0.5  # Minimum scale for very distant objects (less extreme)
	var max_scale = 1.0  # Scale for nearby objects
	var perspective_distance = 2000.0  # 2000 units = 100 meters for half scale (much more gradual)
	
	# Less aggressive falloff for less fisheye effect
	var scale = max_scale * exp(-distance / perspective_distance)
	return max(min_scale, scale)

func get_multi_layer_terrain(observer_pos: Vector2, orientation: int, width: float) -> Dictionary:
	"""Get terrain for multiple depth layers with logarithmic LOD"""
	var layers = {}
	var coords = SolipsisticCoordinates
	var current_lane = coords.get_current_lane_position()
	
	# Interactive layer (exact player position) - highest detail
	var player_pos = coords.player_consciousness_pos  # Use exact position, not lane center
	layers["interactive"] = terrain_system.get_terrain_cross_section_at_depth(player_pos, orientation, width, 0.0, 0.5)
	
	# Background layers with logarithmic LOD grouping
	layers["background"] = []
	
	# LOD Level 1: Layers 1-10 (individual layers, high detail)
	for i in range(1, 11):
		var depth_offset = float(i)
		var bg_layer = terrain_system.get_terrain_cross_section_at_depth(player_pos, orientation, width, depth_offset, 0.5)
		if bg_layer.size() > 0:
			layers["background"].append({
				"points": bg_layer,
				"depth": depth_offset,
				"lod_level": 1
			})
	
	# LOD Level 2: Layers 11-50 (grouped into 8 composite layers, medium detail)
	for group in range(8):
		var start_depth = 11 + group * 5  # Groups of 5 layers
		var end_depth = start_depth + 4
		var composite_layer = create_peak_composite_layer(player_pos, orientation, width, start_depth, end_depth, 2.5)  # 5x lower detail
		if composite_layer.size() > 0:
			layers["background"].append({
				"points": composite_layer,
				"depth": (start_depth + end_depth) / 2.0,  # Average depth
				"lod_level": 2
			})
	
	# LOD Level 3: Layers 51-250 (grouped into 8 composite layers, low detail)
	for group in range(8):
		var start_depth = 51 + group * 25  # Groups of 25 layers
		var end_depth = start_depth + 24
		var composite_layer = create_peak_composite_layer(player_pos, orientation, width, start_depth, end_depth, 12.5)  # 25x lower detail
		if composite_layer.size() > 0:
			layers["background"].append({
				"points": composite_layer,
				"depth": (start_depth + end_depth) / 2.0,
				"lod_level": 3
			})
	
	# LOD Level 4: Far mountains (layers 251-1000, very low detail)
	var far_composite = create_peak_composite_layer(player_pos, orientation, width, 251, 1000, 62.5)  # Very low detail
	if far_composite.size() > 0:
		layers["background"].append({
			"points": far_composite,
			"depth": 625.0,  # Average depth
			"lod_level": 4
		})
	
	return layers

func create_composite_layer(current_lane: Vector2, orientation: int, width: float, start_depth: int, end_depth: int, step_size: float) -> PackedVector2Array:
	"""Create a composite layer by averaging multiple depth layers"""
	var composite_points = PackedVector2Array()
	
	# Calculate how many samples we need across the width
	var num_samples = int(width / step_size) + 1
	
	for i in range(num_samples):
		var horizontal_offset = (i - num_samples / 2) * step_size
		var height_sum = 0.0
		var valid_samples = 0
		
		# Average heights across all layers in this group
		for depth in range(start_depth, end_depth + 1):
			var sample_pos = calculate_sample_position(current_lane, orientation, horizontal_offset, float(depth))
			var height = terrain_system.get_height_at_world_pos(sample_pos)
			height_sum += height
			valid_samples += 1
		
		if valid_samples > 0:
			var average_height = height_sum / valid_samples
			composite_points.append(Vector2(horizontal_offset, average_height))
	
	return composite_points

func create_peak_composite_layer(current_lane: Vector2, orientation: int, width: float, start_depth: int, end_depth: int, step_size: float) -> PackedVector2Array:
	"""Create a composite layer by keeping peak heights (LOD 3-4)"""
	var composite_points = PackedVector2Array()
	
	# Calculate how many samples we need across the width
	var num_samples = int(width / step_size) + 1
	
	for i in range(num_samples):
		var horizontal_offset = (i - num_samples / 2) * step_size
		var max_height = -INF
		
		# Find peak height across all layers in this group
		for depth in range(start_depth, end_depth + 1):
			var sample_pos = calculate_sample_position(current_lane, orientation, horizontal_offset, float(depth))
			var height = terrain_system.get_height_at_world_pos(sample_pos)
			max_height = max(max_height, height)
		
		if max_height != -INF:
			composite_points.append(Vector2(horizontal_offset, max_height))
	
	return composite_points

func calculate_sample_position(current_lane: Vector2, orientation: int, horizontal_offset: float, depth_offset: float) -> Vector2:
	"""Calculate world position for a sample point"""
	var sample_pos = current_lane
	
	# Apply depth offset
	match orientation:
		SolipsisticCoordinates.Orientation.EAST:
			sample_pos.y += depth_offset
		SolipsisticCoordinates.Orientation.WEST:
			sample_pos.y -= depth_offset
		SolipsisticCoordinates.Orientation.NORTH:
			sample_pos.x -= depth_offset
		SolipsisticCoordinates.Orientation.SOUTH:
			sample_pos.x += depth_offset
	
	# Apply horizontal offset along cross-section
	match orientation:
		SolipsisticCoordinates.Orientation.EAST, SolipsisticCoordinates.Orientation.WEST:
			sample_pos.y += horizontal_offset
		SolipsisticCoordinates.Orientation.NORTH, SolipsisticCoordinates.Orientation.SOUTH:
			sample_pos.x += horizontal_offset
	
	return sample_pos

func calculate_dynamic_eye_level(viewport_size: Vector2) -> float:
	"""Calculate eye level to keep player FIXED at bottom of screen"""
	var fixed_player_screen_y = viewport_size.y * 0.85  # Player ALWAYS at 85% down from top
	
	# Get the terrain height that the player is actually standing on
	var coords = SolipsisticCoordinates  
	var player_world_pos = coords.player_consciousness_pos
	var terrain_height = 0.0
	
	if terrain_system:
		terrain_height = terrain_system.get_height_at_world_pos(player_world_pos)
	
	# Get player's actual height above their terrain
	var player_height_above_terrain = 0.0
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("get_current_height_above_terrain"):
		player_height_above_terrain = player.get_current_height_above_terrain()
	
	# DEBUG: Log the height calculations (controlled timing)
	if SolipsisticCoordinates.should_debug_now(0.0):  # Check if it's time for debug output
		SolipsisticCoordinates.debug_print("camera", "🎥 CAMERA DEBUG:")
		SolipsisticCoordinates.debug_print("camera", "   player_world_pos: %s" % player_world_pos)
		SolipsisticCoordinates.debug_print("camera", "   terrain_height (visual): %.3f" % terrain_height)
		SolipsisticCoordinates.debug_print("camera", "   player_height_above_terrain: %.3f" % player_height_above_terrain)
		SolipsisticCoordinates.debug_print("camera", "   fixed_player_screen_y: %.1f" % fixed_player_screen_y)
		SolipsisticCoordinates.debug_print("camera", "   viewport_size: %s" % viewport_size)
	
	# Calculate total player height in world space
	var player_total_height = terrain_height + player_height_above_terrain
	
	# Eye level = where player should be on screen - their total height in screen space
	var calculated_eye_level = fixed_player_screen_y - (player_total_height * vertical_scale)
	
	# FORCE camera bounds to keep player locked in bottom area
	var min_eye_level = viewport_size.y * 0.5   # Don't go above middle of screen
	var max_eye_level = viewport_size.y * 1.2   # Can go slightly below screen for very high terrain
	
	var unclamped_eye_level = calculated_eye_level
	calculated_eye_level = clamp(calculated_eye_level, min_eye_level, max_eye_level)
	
	# Only print this if we already decided to debug this frame  
	if SolipsisticCoordinates.debug_timer == 0.0:  # Just reset, so we're debugging this frame
		SolipsisticCoordinates.debug_print("camera", "   unclamped_eye_level: %.1f" % unclamped_eye_level)
		SolipsisticCoordinates.debug_print("camera", "   calculated_eye_level: %.1f (clamped between %.1f and %.1f)" % [calculated_eye_level, min_eye_level, max_eye_level])
		SolipsisticCoordinates.debug_print("camera", "   player_total_height: %.1f" % player_total_height)
	
	return calculated_eye_level

func cull_hidden_layers(background_layers: Array, player_eye_level: float) -> Array:
	"""Cull layers that are completely hidden by nearer layers"""
	var visible_layers = []
	var screen_center = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Sort layers by depth (nearest first for occlusion testing)
	var sorted_layers = background_layers.duplicate()
	sorted_layers.sort_custom(func(a, b): return a["depth"] < b["depth"])
	
	# Track occlusion using a simple height buffer across screen width
	var occlusion_buffer = {}  # x_position -> max_height_seen
	var sample_step = 20  # Sample every 20 pixels for performance
	
	for layer in sorted_layers:
		var is_visible = false
		var points = layer["points"]
		
		if points.size() < 2:
			continue
			
		# Convert layer points to screen space for occlusion testing
		for point in points:
			var distance_from_player = abs(point.x)
			var perspective_scale = calculate_perspective_scale(distance_from_player)
			
			# Skip points too close to player
			if distance_from_player < 40.0:
				continue
				
			var screen_x = int(screen_center.x + point.x * 3 * perspective_scale)
			var screen_y = player_eye_level - point.y * vertical_scale * perspective_scale
			
			# Sample at regular intervals for performance
			if screen_x % sample_step == 0:
				# Check if this point is occluded by previously drawn layers
				var max_height_at_x = occlusion_buffer.get(screen_x, INF)  # INF = no occlusion yet
				
				if screen_y < max_height_at_x:  # This point is visible (higher on screen = lower y)
					is_visible = true
					occlusion_buffer[screen_x] = screen_y  # Update occlusion buffer
		
		# Only include layer if at least some part is visible
		if is_visible:
			visible_layers.append(layer)
	
	return visible_layers

func draw_multi_layer_terrain():
	"""Draw multiple terrain layers with depth"""
	var viewport_size = get_viewport().get_visible_rect().size
	var horizon_y = viewport_size.y * 0.7
	
	# Calculate dynamic player eye level based on player height
	var player_eye_level = calculate_dynamic_eye_level(viewport_size)
	
	# Draw sky first
	draw_sky(viewport_size, horizon_y)
	
	# Draw background layers first (furthest to nearest) with culling
	if terrain_layers.has("background"):
		var visible_layers = cull_hidden_layers(terrain_layers["background"], player_eye_level)
		for i in range(visible_layers.size() - 1, -1, -1):  # Reverse order
			var layer = visible_layers[i]
			draw_terrain_layer(layer["points"], layer["depth"], false, player_eye_level, layer["lod_level"])
	
	# Draw interactive layer last (on top)
	if terrain_layers.has("interactive"):
		draw_terrain_layer(terrain_layers["interactive"], 0.0, true, player_eye_level, 1)
	
	# Draw player eye level reference
	draw_line(Vector2(0, player_eye_level), Vector2(viewport_size.x, player_eye_level), Color.RED, 2.0)
	

func draw_terrain_layer(points: PackedVector2Array, depth_offset: float, is_interactive: bool, player_eye_level: float, lod_level: int = 1):
	"""Draw a single terrain layer"""
	if points.size() < 2:
		return
	
	var screen_center = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_points = PackedVector2Array()
	
	# Calculate depth-based visual effects
	var depth_alpha = 1.0 - (depth_offset * 0.3)  # Further layers are more transparent
	var depth_scale = 1.0 - (depth_offset * 0.1)   # Further layers slightly smaller
	
	# Convert terrain points to screen coordinates
	for point in points:
		var distance_from_player = abs(point.x)
		var perspective_scale = calculate_perspective_scale(distance_from_player) * depth_scale
		
		# Skip points too close to player (blocked by foreground)
		if distance_from_player < 40.0:  # 40 units = 2 meters
			continue
			
		var screen_x = screen_center.x + point.x * 3 * perspective_scale
		var screen_y = player_eye_level - point.y * vertical_scale * perspective_scale
		screen_points.append(Vector2(screen_x, screen_y))
	
	if screen_points.size() < 2:
		return
	
	# Choose colors based on layer type
	var layer_terrain_color: Color
	var layer_surface_color: Color
	
	if is_interactive:
		# Interactive layer - normal colors
		layer_terrain_color = terrain_color
		layer_surface_color = surface_color
	else:
		# Background layer - darker, more muted colors
		layer_terrain_color = terrain_color.darkened(0.4)
		layer_surface_color = surface_color.darkened(0.3)
		
		# Apply distance fog for LOD 2-4 layers
		if lod_level >= 2:
			var fog_color = Color(0.7, 0.7, 0.8)  # Light blue-grey fog
			var fog_intensity: float
			match lod_level:
				2: fog_intensity = 0.15  # Light fog for LOD 2
				3: fog_intensity = 0.35  # Medium fog for LOD 3
				_: fog_intensity = 0.6   # Heavy fog for LOD 4+
			
			# Blend terrain colors with fog
			layer_terrain_color = layer_terrain_color.lerp(fog_color, fog_intensity)
			layer_surface_color = layer_surface_color.lerp(fog_color, fog_intensity)
	
	# Apply depth transparency
	layer_terrain_color.a = depth_alpha
	layer_surface_color.a = depth_alpha
	
	# Draw filled terrain polygon
	var filled_points = PackedVector2Array()
	var first_point = screen_points[0]
	var last_point = screen_points[-1]
	
	# Extend to screen edges if needed
	if first_point.x > 0:
		filled_points.append(Vector2(0, first_point.y))
	
	for point in screen_points:
		filled_points.append(point)
	
	if last_point.x < viewport_size.x:
		filled_points.append(Vector2(viewport_size.x, last_point.y))
	
	# Close polygon with bottom edge
	filled_points.append(Vector2(viewport_size.x, viewport_size.y))
	filled_points.append(Vector2(0, viewport_size.y))
	
	# Draw filled terrain
	if filled_points.size() >= 3:
		draw_colored_polygon(filled_points, layer_terrain_color)
	
	# Draw surface line
	if first_point.x > 0:
		draw_line(Vector2(0, first_point.y), screen_points[0], layer_surface_color, line_width)
	
	for i in range(screen_points.size() - 1):
		draw_line(screen_points[i], screen_points[i + 1], layer_surface_color, line_width)
	
	if last_point.x < viewport_size.x:
		draw_line(screen_points[-1], Vector2(viewport_size.x, last_point.y), layer_surface_color, line_width)

func draw_sky(viewport_size: Vector2, horizon_y: float):
	"""Draw a beautiful sky gradient with day/night cycle"""
	# Calculate time of day (0-24 hours)
	var time_of_day = (current_time / day_cycle_duration) * 24.0
	
	# Get sky colors based on time of day
	var sky_colors = get_sky_colors_for_time(time_of_day)
	var sky_top = sky_colors.top
	var sky_horizon = sky_colors.horizon
	var ground_color = sky_colors.ground
	
	# Create gradient from top to horizon
	for y in range(0, int(horizon_y), 2):  # Draw every 2 pixels for performance
		var progress = float(y) / horizon_y
		var current_color = sky_top.lerp(sky_horizon, progress)
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), current_color, 2.0)
	
	# Draw subtle ground atmosphere below horizon
	for y in range(int(horizon_y), int(viewport_size.y), 4):  # Sparser for ground area
		var progress = (float(y) - horizon_y) / (viewport_size.y - horizon_y)
		var current_color = sky_horizon.lerp(ground_color, progress * 0.3)  # Subtle fade
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), current_color, 4.0)

func get_sky_colors_for_time(time_of_day: float) -> Dictionary:
	"""Get sky colors based on time of day (0-24 hours)"""
	# Define key times and their colors
	var dawn = 6.0
	var noon = 12.0
	var dusk = 18.0
	var midnight = 0.0
	
	# Color palettes for different times
	var night_colors = {
		"top": Color(0.05, 0.05, 0.2),     # Dark blue
		"horizon": Color(0.1, 0.1, 0.3),   # Slightly lighter
		"ground": Color(0.05, 0.05, 0.15)  # Very dark
	}
	
	var dawn_colors = {
		"top": Color(0.3, 0.4, 0.8),       # Purple-blue
		"horizon": Color(1.0, 0.7, 0.4),   # Orange-pink
		"ground": Color(0.4, 0.3, 0.5)     # Purple-gray
	}
	
	var day_colors = {
		"top": Color(0.4, 0.7, 1.0),       # Bright blue
		"horizon": Color(0.8, 0.9, 1.0),   # Pale blue
		"ground": Color(0.6, 0.8, 0.9)     # Light blue-gray
	}
	
	var dusk_colors = {
		"top": Color(0.2, 0.3, 0.6),       # Deep blue
		"horizon": Color(1.0, 0.5, 0.2),   # Orange-red
		"ground": Color(0.3, 0.2, 0.4)     # Purple-brown
	}
	
	# Interpolate between color palettes based on time
	if time_of_day >= 0.0 and time_of_day < dawn:
		# Night to dawn
		var t = time_of_day / dawn
		return lerp_color_palette(night_colors, dawn_colors, t)
	elif time_of_day >= dawn and time_of_day < noon:
		# Dawn to day
		var t = (time_of_day - dawn) / (noon - dawn)
		return lerp_color_palette(dawn_colors, day_colors, t)
	elif time_of_day >= noon and time_of_day < dusk:
		# Day to dusk
		var t = (time_of_day - noon) / (dusk - noon)
		return lerp_color_palette(day_colors, dusk_colors, t)
	elif time_of_day >= dusk and time_of_day <= 24.0:
		# Dusk to night
		var t = (time_of_day - dusk) / (24.0 - dusk)
		return lerp_color_palette(dusk_colors, night_colors, t)
	
	return day_colors  # Fallback

func lerp_color_palette(palette1: Dictionary, palette2: Dictionary, t: float) -> Dictionary:
	"""Interpolate between two color palettes"""
	return {
		"top": palette1.top.lerp(palette2.top, t),
		"horizon": palette1.horizon.lerp(palette2.horizon, t),
		"ground": palette1.ground.lerp(palette2.ground, t)
	}

func draw_reference_grid():
	"""Draw subtle grid lines to show meter spacing"""
	var screen_center = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	var viewport_size = get_viewport().get_visible_rect().size
	var grid_color = Color(0.3, 0.3, 0.3, 0.3)  # Subtle gray
	
	# Vertical grid lines (every 10 pixels = 1 meter)
	for x in range(-20, 21):  # -20m to +20m around player
		var screen_x = screen_center.x + x * 10
		if screen_x >= 0 and screen_x <= viewport_size.x:
			draw_line(Vector2(screen_x, 0), Vector2(screen_x, viewport_size.y), grid_color, 1.0)
	
	# Horizontal grid lines (every meter in height)
	for y in range(-10, 11):  # -10m to +10m height
		var screen_y = screen_center.y - y * vertical_scale * 5  # Every 5m height
		if screen_y >= 0 and screen_y <= viewport_size.y:
			draw_line(Vector2(0, screen_y), Vector2(viewport_size.x, screen_y), grid_color, 1.0)

func draw_height_indicators():
	"""Draw height numbers at regular intervals"""
	# This would require a font resource - implement later if needed
	pass

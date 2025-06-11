extends Node
class_name TerrainSystem

# Terrain height grid with 0.25m resolution (4 points per 1m cell)
var height_grid: Dictionary = {}  # Vector2i -> float
var grid_resolution: float = 0.25

# Terrain generation parameters
var base_height: float = 0.0
var hill_scale: float = 20.0
var detail_scale: float = 5.0
var noise: FastNoiseLite

# Named locations that should always be the same
var named_locations: Dictionary = {
	"StartingTown": Vector2(0, 0),
	"RedRock": Vector2(50, 30),
	"BlueVale": Vector2(-30, 40)
}

func _ready():
	setup_noise()
	generate_initial_terrain()

func setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = 12345  # Fixed seed for consistent generation
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise.fractal_octaves = 3

func generate_initial_terrain():
	print("🗺️ Generating terrain grid...")
	
	# Generate terrain in a larger area to handle player movement
	for x in range(-1200, 1201):  # 2400x2400 grid around origin (600m x 600m)
		for z in range(-1200, 1201):
			var world_pos = Vector2(x * grid_resolution, z * grid_resolution)
			var height = calculate_terrain_height(world_pos)
			height_grid[Vector2i(x, z)] = height
			
			# Debug the origin and nearby points
			if x >= -2 and x <= 2 and z >= -2 and z <= 2:
				print("🏗️  INIT: grid(%d,%d) world_pos=%s height=%.3f" % [x, z, world_pos, height])
	
	# Smooth terrain around named locations
	for location_name in named_locations:
		var location_pos = named_locations[location_name]
		smooth_terrain_around_location(location_pos, 20.0)  # 20m radius
	
	print("✅ Terrain generation complete with %d grid points!" % height_grid.size())
	
	# Debug: Check if origin point was properly stored
	var origin_grid_key = Vector2i(0, 0)
	if height_grid.has(origin_grid_key):
		print("🎯 ORIGIN CHECK: Grid(0,0) has height %.3f" % height_grid[origin_grid_key])
	else:
		print("🚨 ORIGIN MISSING: Grid(0,0) not found in height_grid!")
	
	# Also check what height would be calculated directly
	var direct_height = calculate_terrain_height(Vector2.ZERO)
	print("🧮 DIRECT CALC: calculate_terrain_height(Vector2.ZERO) = %.3f" % direct_height)

func calculate_terrain_height(world_pos: Vector2) -> float:
	"""Calculate procedural terrain height at world position"""
	# Convert to proper scale for noise sampling (20 units = 1 meter)
	var sample_x = world_pos.x / 20.0  # Convert to meters for noise sampling
	var sample_y = world_pos.y / 20.0
	
	var height = base_height
	
	# Large mountains (very low frequency, high amplitude)
	height += noise.get_noise_2d(sample_x * 0.01, sample_y * 0.01) * 2000.0  # 100m mountains
	
	# Rolling hills (medium frequency, medium amplitude) 
	height += noise.get_noise_2d(sample_x * 0.05, sample_y * 0.05) * 800.0   # 40m hills
	
	# Smaller hills (higher frequency, lower amplitude)
	height += noise.get_noise_2d(sample_x * 0.1, sample_y * 0.1) * 400.0     # 20m hills
	
	# Fine detail (high frequency, small amplitude)
	height += noise.get_noise_2d(sample_x * 0.3, sample_y * 0.3) * 100.0     # 5m detail
	
	# Very fine surface detail
	height += noise.get_noise_2d(sample_x * 1.0, sample_y * 1.0) * 40.0      # 2m surface variation
	
	return height

func smooth_terrain_around_location(center: Vector2, radius: float):
	"""Smooth terrain around named locations to prevent building issues"""
	var target_height = get_height_at_world_pos(center)
	var grid_radius = int(radius / grid_resolution)
	var center_grid = Vector2i(center / grid_resolution)
	
	for x in range(-grid_radius, grid_radius + 1):
		for z in range(-grid_radius, grid_radius + 1):
			var grid_pos = center_grid + Vector2i(x, z)
			var world_pos = Vector2(grid_pos) * grid_resolution
			var distance = world_pos.distance_to(center)
			
			if distance <= radius:
				# Smoothly blend to target height
				var blend_factor = 1.0 - (distance / radius)
				var current_height = height_grid.get(grid_pos, 0.0)
				var smooth_height = lerp(current_height, target_height, blend_factor * 0.8)
				height_grid[grid_pos] = smooth_height

func get_height_at_world_pos(world_pos: Vector2) -> float:
	"""Get terrain height at any world position using interpolation"""
	var grid_pos = world_pos / grid_resolution
	var grid_x = int(floor(grid_pos.x))
	var grid_z = int(floor(grid_pos.y))
	
	# Debug terrain height lookups (controlled)
	if world_pos == Vector2.ZERO and SolipsisticCoordinates.should_debug_now(0.0):
		SolipsisticCoordinates.debug_print("terrain", "🏔️ HEIGHT LOOKUP: world_pos=%s, grid_pos=%s, grid_key=Vector2i(%d,%d)" % [world_pos, grid_pos, grid_x, grid_z])
	
	# Check if we're outside the generated grid
	var grid_key = Vector2i(grid_x, grid_z)
	if not height_grid.has(grid_key):
		# Generate height on-demand for positions outside our initial grid (no spam)
		var height = calculate_terrain_height(world_pos)
		height_grid[grid_key] = height
		# Also cache surrounding points to avoid repeated calculation
		height_grid[Vector2i(grid_x + 1, grid_z)] = calculate_terrain_height(Vector2((grid_x + 1) * grid_resolution, grid_z * grid_resolution))
		height_grid[Vector2i(grid_x, grid_z + 1)] = calculate_terrain_height(Vector2(grid_x * grid_resolution, (grid_z + 1) * grid_resolution))
		height_grid[Vector2i(grid_x + 1, grid_z + 1)] = calculate_terrain_height(Vector2((grid_x + 1) * grid_resolution, (grid_z + 1) * grid_resolution))
	
	# Ensure all 4 corner points are cached
	var corners = [
		Vector2i(grid_x, grid_z),
		Vector2i(grid_x + 1, grid_z),
		Vector2i(grid_x, grid_z + 1),
		Vector2i(grid_x + 1, grid_z + 1)
	]
	
	for corner in corners:
		if not height_grid.has(corner):
			var corner_world_pos = Vector2(corner.x * grid_resolution, corner.y * grid_resolution)
			var corner_height = calculate_terrain_height(corner_world_pos)
			height_grid[corner] = corner_height
			if world_pos == Vector2.ZERO:
				print("🔧 CACHED MISSING CORNER: %s -> %.3f" % [corner, corner_height])
	
	# Get heights of 4 surrounding grid points
	var h00 = height_grid.get(Vector2i(grid_x, grid_z), 0.0)
	var h10 = height_grid.get(Vector2i(grid_x + 1, grid_z), 0.0)
	var h01 = height_grid.get(Vector2i(grid_x, grid_z + 1), 0.0)
	var h11 = height_grid.get(Vector2i(grid_x + 1, grid_z + 1), 0.0)
	
	# Debug the height values we're interpolating (controlled)
	var debug_heights = world_pos == Vector2.ZERO and SolipsisticCoordinates.debug_timer == 0.0
	if debug_heights:
		SolipsisticCoordinates.debug_print("terrain", "🎯 GRID HEIGHTS: h00=%.3f, h10=%.3f, h01=%.3f, h11=%.3f" % [h00, h10, h01, h11])
	
	# Bilinear interpolation
	var fx = grid_pos.x - grid_x
	var fz = grid_pos.y - grid_z
	
	var h0 = lerp(h00, h10, fx)
	var h1 = lerp(h01, h11, fx)
	var final_height = lerp(h0, h1, fz)
	
	# Debug the final result (controlled)
	if debug_heights:
		SolipsisticCoordinates.debug_print("terrain", "✅ FINAL HEIGHT: %.3f (fx=%.3f, fz=%.3f, h0=%.3f, h1=%.3f)" % [final_height, fx, fz, h0, h1])
	
	return final_height

func get_terrain_cross_section(observer_pos: Vector2, orientation: int, width: float = 150.0) -> PackedVector2Array:
	"""Get terrain cross-section for current orientation view"""
	var points = PackedVector2Array()
	var step_size = 0.5  # Sample every half meter for smoother display
	
	print("Getting cross-section at observer_pos: %s, orientation: %d" % [observer_pos, orientation])
	
	match orientation:
		SolipsisticCoordinates.Orientation.EAST:
			# Looking EAST: Show N-S cross-section, left=North, right=South
			var x_pos = observer_pos.x
			print("EAST orientation: sampling N-S at X=%s" % x_pos)
			
			for z_offset in range(-int(width/2), int(width/2) + 1):
				var world_z = observer_pos.y + z_offset * step_size  # Positive = South
				var world_pos = Vector2(x_pos, world_z)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(z_offset * step_size, height))
		
		SolipsisticCoordinates.Orientation.WEST:
			# Looking WEST: Show N-S cross-section, left=South, right=North (REVERSED!)
			var x_pos = observer_pos.x
			print("WEST orientation: sampling S-N at X=%s" % x_pos)
			
			for z_offset in range(-int(width/2), int(width/2) + 1):
				var world_z = observer_pos.y - z_offset * step_size  # Negative = North (FLIPPED)
				var world_pos = Vector2(x_pos, world_z)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(z_offset * step_size, height))
		
		SolipsisticCoordinates.Orientation.SOUTH:
			# Looking SOUTH: Show E-W cross-section, left=East, right=West
			var z_pos = observer_pos.y
			print("SOUTH orientation: sampling E-W at Z=%s" % z_pos)
			
			for x_offset in range(-int(width/2), int(width/2) + 1):
				var world_x = observer_pos.x + x_offset * step_size  # Positive = East
				var world_pos = Vector2(world_x, z_pos)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(x_offset * step_size, height))
		
		SolipsisticCoordinates.Orientation.NORTH:
			# Looking NORTH: Show E-W cross-section, left=West, right=East (REVERSED!)
			var z_pos = observer_pos.y
			print("NORTH orientation: sampling W-E at Z=%s" % z_pos)
			
			for x_offset in range(-int(width/2), int(width/2) + 1):
				var world_x = observer_pos.x - x_offset * step_size  # Negative = West (FLIPPED)
				var world_pos = Vector2(world_x, z_pos)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(x_offset * step_size, height))
	
	print("Generated %d terrain points" % points.size())
	return points

func get_terrain_cross_section_at_depth(observer_pos: Vector2, orientation: int, width: float, depth_offset: float, step_size: float = 0.5) -> PackedVector2Array:
	"""Get terrain cross-section at a specific depth offset from observer position"""
	var points = PackedVector2Array()
	# Use provided step_size for LOD control
	
	# Calculate the actual position to sample based on depth offset
	var sample_pos = observer_pos
	match orientation:
		SolipsisticCoordinates.Orientation.EAST:
			# Looking east, depth is in +Y direction
			sample_pos.y += depth_offset
		SolipsisticCoordinates.Orientation.WEST:
			# Looking west, depth is in -Y direction  
			sample_pos.y -= depth_offset
		SolipsisticCoordinates.Orientation.NORTH:
			# Looking north, depth is in -X direction
			sample_pos.x -= depth_offset
		SolipsisticCoordinates.Orientation.SOUTH:
			# Looking south, depth is in +X direction
			sample_pos.x += depth_offset
	
	# Now get cross-section at this offset position with proper 4-way rotation
	match orientation:
		SolipsisticCoordinates.Orientation.EAST:
			# Looking EAST: Show N-S cross-section, left=North, right=South
			var x_pos = sample_pos.x
			for z_offset in range(-int(width/2), int(width/2) + 1):
				var world_z = sample_pos.y + z_offset * step_size  # Positive = South
				var world_pos = Vector2(x_pos, world_z)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(z_offset * step_size, height))
		
		SolipsisticCoordinates.Orientation.WEST:
			# Looking WEST: Show N-S cross-section, left=South, right=North (REVERSED!)
			var x_pos = sample_pos.x
			for z_offset in range(-int(width/2), int(width/2) + 1):
				var world_z = sample_pos.y - z_offset * step_size  # Negative = North (FLIPPED)
				var world_pos = Vector2(x_pos, world_z)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(z_offset * step_size, height))
		
		SolipsisticCoordinates.Orientation.SOUTH:
			# Looking SOUTH: Show E-W cross-section, left=East, right=West
			var z_pos = sample_pos.y
			for x_offset in range(-int(width/2), int(width/2) + 1):
				var world_x = sample_pos.x + x_offset * step_size  # Positive = East
				var world_pos = Vector2(world_x, z_pos)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(x_offset * step_size, height))
		
		SolipsisticCoordinates.Orientation.NORTH:
			# Looking NORTH: Show E-W cross-section, left=West, right=East (REVERSED!)
			var z_pos = sample_pos.y
			for x_offset in range(-int(width/2), int(width/2) + 1):
				var world_x = sample_pos.x - x_offset * step_size  # Negative = West (FLIPPED)
				var world_pos = Vector2(world_x, z_pos)
				var height = get_height_at_world_pos(world_pos)
				points.append(Vector2(x_offset * step_size, height))
	
	return points

func can_walk_between(pos1: Vector2, pos2: Vector2) -> bool:
	"""Check if the slope between two positions is walkable (<45 degrees)"""
	var height1 = get_height_at_world_pos(pos1)
	var height2 = get_height_at_world_pos(pos2)
	var horizontal_distance = pos1.distance_to(pos2)
	var vertical_distance = abs(height2 - height1)
	
	if horizontal_distance == 0:
		return vertical_distance < 3.0  # Prevent impossible vertical moves
	
	var slope_angle = atan(vertical_distance / horizontal_distance)
	return slope_angle < deg_to_rad(45)  # Less than 45 degrees

func get_edge_drop_distance(pos: Vector2, direction: Vector2) -> float:
	"""Get drop distance at edge in given direction"""
	var current_height = get_height_at_world_pos(pos)
	var edge_pos = pos + direction * 0.5  # Half meter ahead
	var edge_height = get_height_at_world_pos(edge_pos)
	return current_height - edge_height

func should_activate_edge_hang(pos: Vector2, direction: Vector2) -> bool:
	"""Check if edge hanging should activate (drop >3m)"""
	return get_edge_drop_distance(pos, direction) > 3.0
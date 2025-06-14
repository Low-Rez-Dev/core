class_name TestSceneSetup extends RefCounted

# Script to set up test entities in the new solipsistic world
static func setup_test_world(world: SolipsisticWorld):
	print("🌍 Setting up clean test world...")
	
	# Spawn pine trees for depth and rotation reference
	spawn_pine_trees(world)
	
	# Temporarily disabled test entities for clean physics testing
	# Uncomment these sections when you want to test entity spawning again
	
	# # Spawn some test enemies around the player
	# for i in range(10):
	# 	var enemy = ProceduralEnemy.new()
	# 	enemy.enemy_type = "guard" if i % 2 == 0 else "scout"
	# 	enemy.entity_size = 25.0
	# 	
	# 	# Spawn in a circle around player
	# 	var angle = i * TAU / 10
	# 	var distance = 200 + randf_range(-50, 50)
	# 	var spawn_pos = Vector2(cos(angle), sin(angle)) * distance
	# 	
	# 	world.spawn_entity_direct(enemy, spawn_pos, 0)
	# 	print("📍 Spawned %s enemy at %s" % [enemy.enemy_type, spawn_pos])
	
	# # Spawn some test buildings
	# for i in range(5):
	# 	var building = ProceduralBuilding.new()
	# 	building.building_type = "house"
	# 	building.entity_size = 40.0
	# 	building.primary_color = Color.SANDY_BROWN
	# 	building.secondary_color = Color.DARK_RED
	# 	
	# 	var spawn_pos = Vector2(randf_range(-400, 400), randf_range(-400, 400))
	# 	world.spawn_entity_direct(building, spawn_pos, 0)
	# 	print("🏠 Spawned building at %s" % spawn_pos)
	
	print("✅ Clean world setup complete!")

static func spawn_pine_trees(world: SolipsisticWorld):
	"""Spawn pine trees around the world for depth and rotation reference"""
	print("🌲 Spawning pine trees...")
	
	# Create a deterministic but varied pattern of trees
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistent tree placement
	
	# Spawn trees in clusters and scattered individually
	var tree_count = 0
	
	# Forest cluster to the north
	for i in range(15):
		var tree = PineTree.new()
		tree.tree_height = rng.randf_range(80.0, 120.0)  # 4-6 meters tall
		
		# Cluster around (-1000, -2000) with some spread (20 units = 1m scale)
		var cluster_center = Vector2(-1000, -2000)  # 50m, 100m in old scale
		var spread = 1200.0  # 60m spread
		var spawn_pos = cluster_center + Vector2(
			rng.randf_range(-spread, spread),
			rng.randf_range(-spread, spread)
		)
		
		world.spawn_entity_direct(tree, spawn_pos, 0)
		tree_count += 1
	
	# Scattered trees around the starting area (converted to 20 units = 1m scale)
	var scatter_positions = [
		Vector2(600, 500),    # NE of player (30m, 25m)
		Vector2(-800, 600),   # NW of player (-40m, 30m)
		Vector2(1200, -400),  # SE of player (60m, -20m)
		Vector2(-500, -300),  # SW of player (-25m, -15m)
		Vector2(1600, 800),   # Far east (80m, 40m)
		Vector2(-1400, -600), # Far west (-70m, -30m)
		Vector2(400, -1200),  # Far south (20m, -60m)
		Vector2(-200, 1400),  # Far north (-10m, 70m)
		Vector2(2400, 200),   # Very far east (120m, 10m)
		Vector2(-1800, 1000), # Very far west (-90m, 50m)
	]
	
	for pos in scatter_positions:
		var tree = PineTree.new()
		tree.tree_height = rng.randf_range(90.0, 110.0)  # 4.5-5.5 meters
		
		# Add some random offset for natural placement
		var final_pos = pos + Vector2(
			rng.randf_range(-200, 200),  # ±10m random offset
			rng.randf_range(-200, 200)
		)
		
		world.spawn_entity_direct(tree, final_pos, 0)
		tree_count += 1
	
	# Small grove to the east
	for i in range(8):
		var tree = PineTree.new()
		tree.tree_height = rng.randf_range(70.0, 130.0)  # 3.5-6.5 meters
		
		var grove_center = Vector2(3000, -800)  # 150m, -40m
		var grove_spread = 600.0  # 30m spread
		var spawn_pos = grove_center + Vector2(
			rng.randf_range(-grove_spread, grove_spread),
			rng.randf_range(-grove_spread, grove_spread)
		)
		
		world.spawn_entity_direct(tree, spawn_pos, 0)
		tree_count += 1
	
	print("🌲 Spawned %d pine trees for depth reference" % tree_count)
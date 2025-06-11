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
		tree.tree_height = rng.randf_range(40.0, 80.0)
		
		# Cluster around (-50, -100) with some spread
		var cluster_center = Vector2(-50, -100)
		var spread = 60.0
		var spawn_pos = cluster_center + Vector2(
			rng.randf_range(-spread, spread),
			rng.randf_range(-spread, spread)
		)
		
		world.spawn_entity_direct(tree, spawn_pos, 0)
		tree_count += 1
	
	# Scattered trees around the starting area
	var scatter_positions = [
		Vector2(30, 25),   # NE of player
		Vector2(-40, 30),  # NW of player  
		Vector2(60, -20),  # SE of player
		Vector2(-25, -15), # SW of player
		Vector2(80, 40),   # Far east
		Vector2(-70, -30), # Far west
		Vector2(20, -60),  # Far south
		Vector2(-10, 70),  # Far north
		Vector2(120, 10),  # Very far east
		Vector2(-90, 50),  # Very far west
	]
	
	for pos in scatter_positions:
		var tree = PineTree.new()
		tree.tree_height = rng.randf_range(45.0, 75.0)
		
		# Add some random offset for natural placement
		var final_pos = pos + Vector2(
			rng.randf_range(-10, 10),
			rng.randf_range(-10, 10)
		)
		
		world.spawn_entity_direct(tree, final_pos, 0)
		tree_count += 1
	
	# Small grove to the east
	for i in range(8):
		var tree = PineTree.new()
		tree.tree_height = rng.randf_range(35.0, 65.0)
		
		var grove_center = Vector2(150, -40)
		var grove_spread = 30.0
		var spawn_pos = grove_center + Vector2(
			rng.randf_range(-grove_spread, grove_spread),
			rng.randf_range(-grove_spread, grove_spread)
		)
		
		world.spawn_entity_direct(tree, spawn_pos, 0)
		tree_count += 1
	
	print("🌲 Spawned %d pine trees for depth reference" % tree_count)
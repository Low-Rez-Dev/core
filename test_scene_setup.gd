extends Node

# Script to set up test entities in the new solipsistic world
func setup_test_world(world: SolipsisticWorld):
	print("🌍 Setting up test world with entities...")
	
	# Spawn some test enemies around the player
	for i in range(10):
		var enemy = ProceduralEnemy.new()
		enemy.enemy_type = "guard" if i % 2 == 0 else "scout"
		enemy.entity_size = 25.0
		
		# Spawn in a circle around player
		var angle = i * TAU / 10
		var distance = 200 + randf_range(-50, 50)
		var spawn_pos = Vector2(cos(angle), sin(angle)) * distance
		
		world.spawn_entity_direct(enemy, spawn_pos, 0)
		print("📍 Spawned %s enemy at %s" % [enemy.enemy_type, spawn_pos])
	
	# Spawn some test buildings
	for i in range(5):
		var building = ProceduralBuilding.new()
		building.building_type = "house"
		building.entity_size = 40.0
		building.primary_color = Color.SANDY_BROWN
		building.secondary_color = Color.DARK_RED
		
		var spawn_pos = Vector2(randf_range(-400, 400), randf_range(-400, 400))
		world.spawn_entity_direct(building, spawn_pos, 0)
		print("🏠 Spawned building at %s" % spawn_pos)
	
	print("✅ Test world setup complete!")

class_name ProceduralBuilding extends ProceduralEntity:
	@export var building_type: String = "house"
	@export var building_height: int = 2
	
	func _ready():
		super._ready()
		entity_size = 40 * building_height
	
	func get_entity_type() -> String:
		return "building"
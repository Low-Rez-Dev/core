extends LivingEntity
class_name Plant

enum GrowthStage {
	SEED,
	SPROUT,
	JUVENILE,
	MATURE,
	FLOWERING,
	FRUITING
}

class PlantSegment:
	var segment_type: PlantPart
	var parent_segment_id: int
	var growth_progress: float = 0.0  # 0.0 to 1.0
	var health: float = 1.0
	var age_days: float = 0.0
	
	func _init(type: PlantPart, parent_id: int = -1):
		segment_type = type
		parent_segment_id = parent_id

var segments: Array[PlantSegment] = []
var growth_stage: GrowthStage = GrowthStage.SEED
var daily_growth_rate: float = 0.1
var water_level: float = 1.0
var sunlight_exposure: float = 1.0

@export var plant_species: String = "generic"
@export var max_height: float = 2.0  # meters
@export var leaf_color: Color = Color(0.2, 0.8, 0.3)
@export var flower_color: Color = Color(1.0, 0.8, 0.2)

func _ready():
	entity_type = EntityType.PLANT
	super._ready()

func define_entity_structure():
	define_plant_structure()

func define_plant_structure():
	match growth_stage:
		GrowthStage.SEED:
			create_seed()
		GrowthStage.SPROUT:
			create_sprout()
		GrowthStage.JUVENILE:
			create_juvenile_plant()
		GrowthStage.MATURE:
			create_mature_plant()
		GrowthStage.FLOWERING:
			create_flowering_plant()
		GrowthStage.FRUITING:
			create_fruiting_plant()

func create_seed():
	var seed_size = Vector2(0.02, 0.02)
	add_entity_shape(PlantPart.SEED, "circle", seed_size, Vector3.ZERO)
	entity_shapes[PlantPart.SEED].color = Color(0.6, 0.4, 0.2)

func create_sprout():
	var unit_scale = 0.1
	add_entity_shape(PlantPart.ROOT_SYSTEM, "line", Vector2(0.05, 0.05) * unit_scale, Vector3(0, -0.02, 0))
	add_entity_shape(PlantPart.MAIN_STEM, "rectangle", Vector2(0.01, 0.08) * unit_scale, Vector3.ZERO)
	add_entity_shape(PlantPart.LEAF, "circle", Vector2(0.03, 0.02) * unit_scale, Vector3(0, 0.04, 0))
	
	entity_shapes[PlantPart.ROOT_SYSTEM].color = Color(0.4, 0.2, 0.1)
	entity_shapes[PlantPart.MAIN_STEM].color = Color(0.3, 0.6, 0.2)
	entity_shapes[PlantPart.LEAF].color = leaf_color

func create_juvenile_plant():
	var unit_scale = 0.5
	add_entity_shape(PlantPart.ROOT_SYSTEM, "line", Vector2(0.2, 0.1) * unit_scale, Vector3(0, -0.1, 0))
	add_entity_shape(PlantPart.MAIN_STEM, "rectangle", Vector2(0.05, 0.4) * unit_scale, Vector3.ZERO)
	
	for i in range(3):
		var leaf_offset = Vector3(0.1 * (i % 2 * 2 - 1), 0.1 + i * 0.1, 0)
		add_entity_shape(PlantPart.LEAF + i, "circle", Vector2(0.08, 0.06) * unit_scale, leaf_offset)
		entity_shapes[PlantPart.LEAF + i].color = leaf_color
	
	entity_shapes[PlantPart.ROOT_SYSTEM].color = Color(0.4, 0.2, 0.1)
	entity_shapes[PlantPart.MAIN_STEM].color = Color(0.3, 0.6, 0.2)

func create_mature_plant():
	var unit_scale = max_height / 2.0
	add_entity_shape(PlantPart.ROOT_SYSTEM, "line", Vector2(0.3, 0.2) * unit_scale, Vector3(0, -0.2, 0))
	add_entity_shape(PlantPart.MAIN_STEM, "rectangle", Vector2(0.08, 0.8) * unit_scale, Vector3.ZERO)
	
	for i in range(6):
		var leaf_offset = Vector3(0.15 * (i % 2 * 2 - 1), 0.2 + i * 0.1, 0)
		add_entity_shape(PlantPart.LEAF + i, "circle", Vector2(0.12, 0.08) * unit_scale, leaf_offset)
		entity_shapes[PlantPart.LEAF + i].color = leaf_color
	
	entity_shapes[PlantPart.ROOT_SYSTEM].color = Color(0.4, 0.2, 0.1)
	entity_shapes[PlantPart.MAIN_STEM].color = Color(0.3, 0.6, 0.2)

func create_flowering_plant():
	create_mature_plant()
	var unit_scale = max_height / 2.0
	
	for i in range(3):
		var flower_offset = Vector3(0.1 * (i % 2 * 2 - 1), 0.6 + i * 0.05, 0)
		add_entity_shape(PlantPart.FLOWER + i, "circle", Vector2(0.06, 0.06) * unit_scale, flower_offset)
		entity_shapes[PlantPart.FLOWER + i].color = flower_color

func create_fruiting_plant():
	create_flowering_plant()
	var unit_scale = max_height / 2.0
	
	for i in range(2):
		var fruit_offset = Vector3(0.12 * (i % 2 * 2 - 1), 0.5 + i * 0.1, 0)
		add_entity_shape(PlantPart.FRUIT + i, "circle", Vector2(0.08, 0.08) * unit_scale, fruit_offset)
		entity_shapes[PlantPart.FRUIT + i].color = Color(0.8, 0.2, 0.2)

func add_plant_segment(type: PlantPart, parent_id: int = -1) -> PlantSegment:
	var segment = PlantSegment.new(type, parent_id)
	segments.append(segment)
	return segment

func grow_daily(delta_days: float):
	water_level = max(0.0, water_level - 0.1 * delta_days)
	
	if water_level > 0.2 and sunlight_exposure > 0.3:
		for segment in segments:
			segment.growth_progress = min(1.0, segment.growth_progress + daily_growth_rate * delta_days)
			segment.age_days += delta_days
		
		check_growth_stage_progression()

func check_growth_stage_progression():
	var avg_age = 0.0
	for segment in segments:
		avg_age += segment.age_days
	if segments.size() > 0:
		avg_age /= segments.size()
	
	var new_stage = growth_stage
	if avg_age > 30.0:
		new_stage = GrowthStage.FRUITING
	elif avg_age > 20.0:
		new_stage = GrowthStage.FLOWERING
	elif avg_age > 15.0:
		new_stage = GrowthStage.MATURE
	elif avg_age > 7.0:
		new_stage = GrowthStage.JUVENILE
	elif avg_age > 1.0:
		new_stage = GrowthStage.SPROUT
	
	if new_stage != growth_stage:
		growth_stage = new_stage
		entity_shapes.clear()
		define_plant_structure()

func water_plant(amount: float):
	water_level = min(1.0, water_level + amount)

func set_sunlight(exposure: float):
	sunlight_exposure = clamp(exposure, 0.0, 1.0)
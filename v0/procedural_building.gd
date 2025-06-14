extends ProceduralEntity
class_name ProceduralBuilding

@export var building_type: String = "house"
@export var building_height: int = 2

func _ready():
	super._ready()
	entity_size = 40 * building_height

func get_entity_type() -> String:
	return "building"
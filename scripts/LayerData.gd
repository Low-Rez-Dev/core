class_name LayerData
extends Resource

@export var material_type: String = ""       # "leather", "iron", "fur", etc.
@export var thickness: float = 1.0           # Physical depth of layer
@export var quality: float = 1.0             # Material grade (0.0 - 1.0)
@export var damage: float = 0.0              # Current damage level (0.0 - 1.0)
@export var volume: float = 0.0              # Calculated from polygon area × thickness
@export var condition_modifiers: Dictionary = {}  # Disease, enhancement, etc.

func _init():
	pass

func calculate_volume(polygon_area: float):
	volume = polygon_area * thickness

func get_effective_quality() -> float:
	return quality * (1.0 - damage)

func apply_damage(damage_amount: float):
	damage = min(1.0, damage + damage_amount)

func repair_damage(repair_amount: float):
	damage = max(0.0, damage - repair_amount)

func is_destroyed() -> bool:
	return damage >= 1.0

func get_material_value() -> float:
	return volume * get_effective_quality() * get_material_multiplier()

func get_material_multiplier() -> float:
	match material_type:
		"iron": return 5.0
		"steel": return 8.0
		"leather": return 2.0
		"fur": return 1.5
		"bone": return 3.0
		"meat": return 1.0
		_: return 1.0

func add_condition_modifier(condition: String, value: float):
	condition_modifiers[condition] = value

func remove_condition_modifier(condition: String):
	if condition in condition_modifiers:
		condition_modifiers.erase(condition)

func has_condition(condition: String) -> bool:
	return condition in condition_modifiers

func get_condition_value(condition: String) -> float:
	return condition_modifiers.get(condition, 0.0)

func duplicate_layer() -> LayerData:
	var new_layer = LayerData.new()
	new_layer.material_type = material_type
	new_layer.thickness = thickness
	new_layer.quality = quality
	new_layer.damage = damage
	new_layer.volume = volume
	new_layer.condition_modifiers = condition_modifiers.duplicate()
	return new_layer

# Material presets
static func create_iron_layer(thickness: float = 2.0) -> LayerData:
	var layer = LayerData.new()
	layer.material_type = "iron"
	layer.thickness = thickness
	layer.quality = 0.8
	layer.damage = 0.0
	return layer

static func create_leather_layer(thickness: float = 1.0) -> LayerData:
	var layer = LayerData.new()
	layer.material_type = "leather"
	layer.thickness = thickness
	layer.quality = 0.7
	layer.damage = 0.0
	return layer

static func create_fur_layer(thickness: float = 0.5) -> LayerData:
	var layer = LayerData.new()
	layer.material_type = "fur"
	layer.thickness = thickness
	layer.quality = 0.6
	layer.damage = 0.0
	return layer

static func create_meat_layer(thickness: float = 3.0) -> LayerData:
	var layer = LayerData.new()
	layer.material_type = "meat"
	layer.thickness = thickness
	layer.quality = 0.9
	layer.damage = 0.0
	return layer

static func create_bone_layer(thickness: float = 1.5) -> LayerData:
	var layer = LayerData.new()
	layer.material_type = "bone"
	layer.thickness = thickness
	layer.quality = 0.8
	layer.damage = 0.0
	return layer

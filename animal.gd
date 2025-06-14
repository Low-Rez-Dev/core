extends LivingEntity
class_name Animal

enum LimbType {
	ARM,
	LEG
}

class Limb:
	var limb_type: LimbType
	var is_left_side: bool
	var upper_part_id: int
	var lower_part_id: int
	var extremity_part_id: int  # hand/foot
	
	func _init(type: LimbType, left: bool, upper_id: int, lower_id: int, extremity_id: int):
		limb_type = type
		is_left_side = left
		upper_part_id = upper_id
		lower_part_id = lower_id
		extremity_part_id = extremity_id

var limbs: Array[Limb] = []

func _ready():
	entity_type = EntityType.ANIMAL
	super._ready()

func define_entity_structure():
	define_animal_structure()

func define_animal_structure():
	pass

func add_limb(type: LimbType, is_left: bool, upper_id: int, lower_id: int, extremity_id: int) -> Limb:
	var limb = Limb.new(type, is_left, upper_id, lower_id, extremity_id)
	limbs.append(limb)
	return limb

func get_limb(type: LimbType, is_left: bool) -> Limb:
	for limb in limbs:
		if limb.limb_type == type and limb.is_left_side == is_left:
			return limb
	return null

func set_limb_pose(type: LimbType, is_left: bool, shoulder_hip_angle: float, elbow_knee_angle: float):
	var limb = get_limb(type, is_left)
	if not limb:
		return
	
	var body_part_id = AnimalPart.BODY
	set_joint_angle(body_part_id, limb.upper_part_id, shoulder_hip_angle)
	set_joint_angle(limb.upper_part_id, limb.lower_part_id, elbow_knee_angle)

func has_head() -> bool:
	return entity_shapes.has(AnimalPart.HEAD)

func has_neck() -> bool:
	return entity_shapes.has(AnimalPart.NECK)

func get_arm_count() -> int:
	var count = 0
	for limb in limbs:
		if limb.limb_type == LimbType.ARM:
			count += 1
	return count

func get_leg_count() -> int:
	var count = 0
	for limb in limbs:
		if limb.limb_type == LimbType.LEG:
			count += 1
	return count
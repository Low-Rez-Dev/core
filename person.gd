extends Animal
class_name Person

@export var person_height: float = 1.8  # meters
@export var skin_tone: Color = Color(1.0, 0.6, 0.4)  # More visible orange skin
@export var clothing_color: Color = Color(0.3, 0.4, 0.8)

func define_animal_structure():
	# Defining person structure
	var unit_scale = person_height / 1.8  # Scale based on height
	# Scale calculated
	
	add_entity_shape(AnimalPart.HEAD, "circle", Vector2(0.25, 0.25) * unit_scale, Vector3(0, 0.85 * unit_scale, 0))
	add_entity_shape(AnimalPart.NECK, "rectangle", Vector2(0.12, 0.1) * unit_scale, Vector3(0, 0.7 * unit_scale, 0))
	add_entity_shape(AnimalPart.BODY, "rectangle", Vector2(0.35, 0.5) * unit_scale, Vector3(0, 0.3 * unit_scale, 0))
	
	add_entity_shape(AnimalPart.LEFT_ARM_UPPER, "rectangle", Vector2(0.08, 0.3) * unit_scale, Vector3(-0.25 * unit_scale, 0.45 * unit_scale, 0))
	add_entity_shape(AnimalPart.LEFT_ARM_LOWER, "rectangle", Vector2(0.06, 0.25) * unit_scale, Vector3(-0.25 * unit_scale, 0.1 * unit_scale, 0))
	add_entity_shape(AnimalPart.LEFT_HAND, "circle", Vector2(0.06, 0.06) * unit_scale, Vector3(-0.25 * unit_scale, -0.1 * unit_scale, 0))
	
	add_entity_shape(AnimalPart.RIGHT_ARM_UPPER, "rectangle", Vector2(0.08, 0.3) * unit_scale, Vector3(0.25 * unit_scale, 0.45 * unit_scale, 0))
	add_entity_shape(AnimalPart.RIGHT_ARM_LOWER, "rectangle", Vector2(0.06, 0.25) * unit_scale, Vector3(0.25 * unit_scale, 0.1 * unit_scale, 0))
	add_entity_shape(AnimalPart.RIGHT_HAND, "circle", Vector2(0.06, 0.06) * unit_scale, Vector3(0.25 * unit_scale, -0.1 * unit_scale, 0))
	
	add_entity_shape(AnimalPart.LEFT_LEG_UPPER, "rectangle", Vector2(0.12, 0.35) * unit_scale, Vector3(-0.08 * unit_scale, -0.15 * unit_scale, 0))
	add_entity_shape(AnimalPart.LEFT_LEG_LOWER, "rectangle", Vector2(0.1, 0.3) * unit_scale, Vector3(-0.08 * unit_scale, -0.55 * unit_scale, 0))
	add_entity_shape(AnimalPart.LEFT_FOOT, "rectangle", Vector2(0.2, 0.08) * unit_scale, Vector3(-0.08 * unit_scale, -0.85 * unit_scale, 0))
	
	add_entity_shape(AnimalPart.RIGHT_LEG_UPPER, "rectangle", Vector2(0.12, 0.35) * unit_scale, Vector3(0.08 * unit_scale, -0.15 * unit_scale, 0))
	add_entity_shape(AnimalPart.RIGHT_LEG_LOWER, "rectangle", Vector2(0.1, 0.3) * unit_scale, Vector3(0.08 * unit_scale, -0.55 * unit_scale, 0))
	add_entity_shape(AnimalPart.RIGHT_FOOT, "rectangle", Vector2(0.2, 0.08) * unit_scale, Vector3(0.08 * unit_scale, -0.85 * unit_scale, 0))
	
	add_limb(LimbType.ARM, true, AnimalPart.LEFT_ARM_UPPER, AnimalPart.LEFT_ARM_LOWER, AnimalPart.LEFT_HAND)
	add_limb(LimbType.ARM, false, AnimalPart.RIGHT_ARM_UPPER, AnimalPart.RIGHT_ARM_LOWER, AnimalPart.RIGHT_HAND)
	add_limb(LimbType.LEG, true, AnimalPart.LEFT_LEG_UPPER, AnimalPart.LEFT_LEG_LOWER, AnimalPart.LEFT_FOOT)
	add_limb(LimbType.LEG, false, AnimalPart.RIGHT_LEG_UPPER, AnimalPart.RIGHT_LEG_LOWER, AnimalPart.RIGHT_FOOT)
	
	apply_human_colors()
	setup_human_joints()

func apply_human_colors():
	# Applying human colors
	entity_shapes[AnimalPart.HEAD].color = skin_tone
	entity_shapes[AnimalPart.NECK].color = skin_tone
	entity_shapes[AnimalPart.LEFT_HAND].color = skin_tone
	entity_shapes[AnimalPart.RIGHT_HAND].color = skin_tone
	# Head color applied
	
	entity_shapes[AnimalPart.BODY].color = clothing_color
	entity_shapes[AnimalPart.LEFT_ARM_UPPER].color = skin_tone
	entity_shapes[AnimalPart.LEFT_ARM_LOWER].color = skin_tone
	entity_shapes[AnimalPart.RIGHT_ARM_UPPER].color = skin_tone
	entity_shapes[AnimalPart.RIGHT_ARM_LOWER].color = skin_tone
	
	entity_shapes[AnimalPart.LEFT_LEG_UPPER].color = skin_tone
	entity_shapes[AnimalPart.LEFT_LEG_LOWER].color = skin_tone
	entity_shapes[AnimalPart.LEFT_FOOT].color = Color(0.2, 0.1, 0.0)  # Brown shoes
	entity_shapes[AnimalPart.RIGHT_LEG_UPPER].color = skin_tone
	entity_shapes[AnimalPart.RIGHT_LEG_LOWER].color = skin_tone
	entity_shapes[AnimalPart.RIGHT_FOOT].color = Color(0.2, 0.1, 0.0)  # Brown shoes

func setup_human_joints():
	var unit_scale = person_height / 1.8
	
	add_joint(AnimalPart.BODY, AnimalPart.NECK, Vector3(0, 0.6 * unit_scale, 0))
	add_joint(AnimalPart.NECK, AnimalPart.HEAD, Vector3(0, 0.75 * unit_scale, 0))
	
	add_joint(AnimalPart.BODY, AnimalPart.LEFT_ARM_UPPER, Vector3(-0.2 * unit_scale, 0.5 * unit_scale, 0))
	add_joint(AnimalPart.LEFT_ARM_UPPER, AnimalPart.LEFT_ARM_LOWER, Vector3(-0.3 * unit_scale, 0.3 * unit_scale, 0))
	add_joint(AnimalPart.LEFT_ARM_LOWER, AnimalPart.LEFT_HAND, Vector3(-0.3 * unit_scale, 0.0, 0))
	
	add_joint(AnimalPart.BODY, AnimalPart.RIGHT_ARM_UPPER, Vector3(0.2 * unit_scale, 0.5 * unit_scale, 0))
	add_joint(AnimalPart.RIGHT_ARM_UPPER, AnimalPart.RIGHT_ARM_LOWER, Vector3(0.3 * unit_scale, 0.3 * unit_scale, 0))
	add_joint(AnimalPart.RIGHT_ARM_LOWER, AnimalPart.RIGHT_HAND, Vector3(0.3 * unit_scale, 0.0, 0))
	
	add_joint(AnimalPart.BODY, AnimalPart.LEFT_LEG_UPPER, Vector3(-0.1 * unit_scale, 0.0, 0))
	add_joint(AnimalPart.LEFT_LEG_UPPER, AnimalPart.LEFT_LEG_LOWER, Vector3(-0.1 * unit_scale, -0.4 * unit_scale, 0))
	add_joint(AnimalPart.LEFT_LEG_LOWER, AnimalPart.LEFT_FOOT, Vector3(-0.1 * unit_scale, -0.8 * unit_scale, 0))
	
	add_joint(AnimalPart.BODY, AnimalPart.RIGHT_LEG_UPPER, Vector3(0.1 * unit_scale, 0.0, 0))
	add_joint(AnimalPart.RIGHT_LEG_UPPER, AnimalPart.RIGHT_LEG_LOWER, Vector3(0.1 * unit_scale, -0.4 * unit_scale, 0))
	add_joint(AnimalPart.RIGHT_LEG_LOWER, AnimalPart.RIGHT_FOOT, Vector3(0.1 * unit_scale, -0.8 * unit_scale, 0))

func set_arm_pose(is_left_arm: bool, shoulder_angle: float, elbow_angle: float):
	set_limb_pose(LimbType.ARM, is_left_arm, shoulder_angle, elbow_angle)

func set_leg_pose(is_left_leg: bool, hip_angle: float, knee_angle: float):
	set_limb_pose(LimbType.LEG, is_left_leg, hip_angle, knee_angle)
extends ProceduralEntity
class_name SolipsisticPlayer

@export var movement_speed: float = 200.0
@export var can_change_z_layers: bool = true

# Input state
var move_input: float = 0.0
var depth_input: float = 0.0

# IK data from ported body controller
var left_arm_data: Dictionary = {}
var right_arm_data: Dictionary = {}
var facing_right: bool = true

# Input handling and body control
var input_handler: SolipsisticInput
var body_controller: SolipsisticBodyController

func _ready():
	super._ready()
	# Player always exists at the center of their own reality
	position = SolipsisticCoordinates.CONSCIOUSNESS_CENTER
	
	# Set up body controller
	body_controller = SolipsisticBodyController.new()
	body_controller.setup(self)
	add_child(body_controller)
	
	# Set up input handler
	input_handler = SolipsisticInput.new()
	input_handler.setup(self, body_controller)
	add_child(input_handler)

func _process(delta):
	handle_orientation_input()
	handle_movement_input(delta)
	handle_depth_input()
	
	# Update all entities' manifestation state
	update_reality_manifestation()

func set_input_handler(handler: SolipsisticInput):
	input_handler = handler

func handle_orientation_input():
	"""Handle rotation of the observer's perspective"""
	if Input.is_action_just_pressed("rotate_clockwise"):    # Q key
		var new_orientation = (SolipsisticCoordinates.current_orientation + 1) % 4
		change_orientation(new_orientation)
	elif Input.is_action_just_pressed("rotate_counter"):    # E key
		var new_orientation = (SolipsisticCoordinates.current_orientation - 1) % 4
		if new_orientation < 0:
			new_orientation = 3
		change_orientation(new_orientation)

func change_orientation(new_orientation: int):
	"""Changes how the observer perceives spatial relationships"""
	SolipsisticCoordinates.current_orientation = new_orientation
	SolipsisticCoordinates.orientation_changed.emit(new_orientation)
	
	var orientation_names = ["EAST", "SOUTH", "WEST", "NORTH"]
	print("Observer now perceives reality facing: %s" % orientation_names[new_orientation])

func handle_movement_input(delta):
	"""Handle movement along the observer's current axis of perception"""
	if not input_handler:
		return
	
	var movement_2d = input_handler.get_movement_direction()
	move_input = movement_2d.x
	
	if move_input != 0.0:
		# Transform input to virtual world movement
		var transform = SolipsisticCoordinates.orientation_transforms[SolipsisticCoordinates.current_orientation]
		var world_movement = transform.move * move_input * movement_speed * delta
		
		# Update consciousness position in virtual space
		SolipsisticCoordinates.player_consciousness_pos += world_movement
		SolipsisticCoordinates.consciousness_moved.emit(SolipsisticCoordinates.player_consciousness_pos)

func handle_depth_input():
	"""Handle movement between depth layers"""
	if not can_change_z_layers:
		return
	
	if Input.is_action_just_pressed("layer_forward"):   # R key
		SolipsisticCoordinates.player_z_layer += 1
		print("Observer shifted to depth layer: %d" % SolipsisticCoordinates.player_z_layer)
	elif Input.is_action_just_pressed("layer_backward"): # F key
		SolipsisticCoordinates.player_z_layer -= 1
		print("Observer shifted to depth layer: %d" % SolipsisticCoordinates.player_z_layer)

func update_reality_manifestation():
	"""Updates which entities exist in the observer's current reality"""
	for entity in SolipsisticCoordinates.all_entities:
		if entity != self:  # Don't update own manifestation
			entity.update_manifestation()

# Override entity type for procedural drawing
func get_entity_type() -> String:
	return "player"

# Provide arm position data for procedural drawing
func get_arm_positions() -> Dictionary:
	return {
		"left_shoulder": Vector2(-12, -17),
		"left_elbow": left_arm_data.get("elbow", Vector2(-20, -10)),
		"left_hand": left_arm_data.get("hand", Vector2(-30, 0)),
		"right_shoulder": Vector2(12, -17),
		"right_elbow": right_arm_data.get("elbow", Vector2(20, -10)),
		"right_hand": right_arm_data.get("hand", Vector2(30, 0))
	}

func get_facing_direction() -> bool:
	return facing_right
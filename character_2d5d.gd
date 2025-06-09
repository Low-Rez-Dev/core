extends Entity2D5D
class_name Character2D5D

# Character system using Sprite3D + rendered texture for arms
# Keeps the full arm IK system but renders to a single texture

var body_controller: BodyController
var input_handler: InputHandler
var movement_3d: Movement3DController

# Rendering system
var sub_viewport: SubViewport
var character_drawer: CharacterDrawer
var render_timer: float = 0.0
var render_interval: float = 1.0/60.0  # 60 FPS rendering

@export_enum("MouseKeyboard", "Controller", "AI") var input_type: String = "MouseKeyboard"

# Rest position settings (copied from old system)
@export_group("Rest Position Settings")
@export var rest_hand_offset_y: float = 15.0
@export var rest_hand_offset_x: float = 8.0
@export var use_hip_rest: bool = true
@export var custom_left_rest: Vector2 = Vector2(-15, 20)
@export var custom_right_rest: Vector2 = Vector2(15, 20)

func _ready():
	setup_character_components()
	setup_rendering_system()
	super._ready()  # Call Entity2D5D setup

func setup_character_components():
	print("🎮 Character2D5D _ready() called")
	
	# Create body controller
	body_controller = BodyController.new()
	add_child(body_controller)
	
	# Create input handler
	match input_type:
		"MouseKeyboard":
			input_handler = MouseKeyboardInput.new()
		"Controller":
			input_handler = ControllerInput.new()
		"AI":
			input_handler = MouseKeyboardInput.new()
	
	add_child(input_handler)
	
	# Connect signals
	if input_handler.has_signal("arm_lock_changed"):
		input_handler.arm_lock_changed.connect(_on_arm_lock_changed)
	
	# Create 3D movement controller
	movement_3d = Movement3DController.new()
	movement_3d.setup(self, input_handler)
	add_child(movement_3d)
	
	# Connect to movement orientation changes for sprite facing
	movement_3d.orientation_changed.connect(_on_orientation_changed)
	
	print("🔧 Character components setup complete")

func setup_rendering_system():
	print("🎨 Setting up rendering system...")
	
	# Create SubViewport for rendering character
	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(400, 600)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub_viewport)
	
	# Create 2D container
	var character_sprite = Node2D.new()
	character_sprite.name = "Character2D"
	sub_viewport.add_child(character_sprite)
	
	# Create character drawer
	character_drawer = CharacterDrawer.new()
	character_drawer.body_controller = body_controller
	character_drawer.input_handler = input_handler
	character_sprite.add_child(character_drawer)
	
	# Wait a frame for viewport to initialize
	await get_tree().process_frame
	
	# Set the SubViewport texture to the sprite
	texture = sub_viewport.get_texture()
	
	# IMPORTANT: Scale character to match 1-meter grid system
	# The character should be about 2 meters tall, so scale accordingly
	scale = Vector3(1, 1, 1)   # ← PROPER SIZE  # Much smaller - about 2m tall
	
	# IMPORTANT: Position sprite correctly (at feet level)
	position.y = 0.5#1.0  # Character center at 1m height (2m tall character)
	
	# IMPORTANT: Start facing camera (North for E-W movement)
	rotation.y = deg_to_rad(0)  # Face north initially
	
	print("🎨 Rendering system setup complete - Scale: %s, Position: %s" % [scale, position])

func update_entity(delta: float):
	# Update input system with proper 3D to 2D coordinate conversion
	update_input_system(delta)
	
	# Update body system
	update_body_system(delta)
	
	# Update movement and pass to base class
	if movement_3d:
		var velocity = Vector3(movement_3d.velocity_3d.x, 0, movement_3d.velocity_3d.z)
		update_movement(velocity)
	
	# Update sprite texture from SubViewport
	render_timer += delta
	if render_timer >= render_interval:
		render_timer = 0.0
		if sub_viewport and sub_viewport.get_texture():
			texture = sub_viewport.get_texture()

func update_input_system(delta: float):
	# Convert 3D world position to 2D for input handler
	var pos_2d = Vector2(global_position.x, global_position.z)
	input_handler.update_input(delta, pos_2d)

func update_body_system(delta):
	# FIXED: Only update facing based on movement, not focus direction
	# This prevents the rapid toggling caused by mouse focus changes
	
	if movement_3d and movement_3d.velocity_3d.length() > 0.1:
		var facing_direction = false  # Default to left/backward
		
		match movement_3d.current_orientation:
			0: # Facing East: check X velocity (positive = right/forward)
				facing_direction = movement_3d.velocity_3d.x > 0
			1: # Facing South: check Z velocity (negative = right/forward)  
				facing_direction = movement_3d.velocity_3d.z < 0
			2: # Facing West: check X velocity (negative = right/forward)
				facing_direction = movement_3d.velocity_3d.x < 0
			3: # Facing North: check Z velocity (positive = right/forward)
				facing_direction = movement_3d.velocity_3d.z > 0
		
		body_controller.set_facing_direction(facing_direction)
		set_facing_direction(facing_direction)
	
	# Also update facing based on focus direction when not moving
	if movement_3d.velocity_3d.length() <= 0.1:  # Only when not moving
		# Get focus direction from input handler
		var focus_direction = input_handler.get_focus_direction()
		if focus_direction.length() > 0.1:  # Only if focus is active
			var focus_facing_right = focus_direction.x > 0
			# ONLY update body controller facing, NOT the sprite facing
			body_controller.set_facing_direction(focus_facing_right)
			# REMOVED: set_facing_direction(focus_facing_right) - don't flip sprite

	
	# Get rest positions without causing flipping
	var left_rest: Vector2 = Vector2.ZERO
	var right_rest: Vector2 = Vector2.ZERO
	
	if use_hip_rest:
		# Get base hip positions (no flipping here)
		left_rest = body_controller.get_hip_rest_pos(true)
		right_rest = body_controller.get_hip_rest_pos(false)
		
		# Apply adjustable offsets
		left_rest.y += rest_hand_offset_y
		right_rest.y += rest_hand_offset_y
		
		# Simple offset - no facing-dependent flipping
		left_rest.x -= rest_hand_offset_x
		right_rest.x -= rest_hand_offset_x
	else:
		left_rest = custom_left_rest
		right_rest = custom_right_rest
	
	# Calculate arm targets
	var left_target: Vector2
	var right_target: Vector2
	
	if input_handler.is_left_arm_locked():
		left_target = input_handler.get_locked_position(true)
	elif input_handler.get_left_arm_active():
		left_target = convert_mouse_to_arm_target(input_handler.get_left_arm_target(), true)
	else:
		left_target = left_rest
	
	if input_handler.is_right_arm_locked():
		right_target = input_handler.get_locked_position(false)
	elif input_handler.get_right_arm_active():
		right_target = convert_mouse_to_arm_target(input_handler.get_right_arm_target(), false)
	else:
		right_target = right_rest
	
	# Update arm positions
	var interpolation_speed = body_controller.arm_return_speed * delta * 100
	body_controller.set_arm_target(true, left_target, interpolation_speed)
	body_controller.set_arm_target(false, right_target, interpolation_speed)

func convert_mouse_to_arm_target(mouse_pos: Vector2, is_left_arm: bool) -> Vector2:
	# Convert mouse position to arm target - arms should always point to cursor
	var shoulder_pos = body_controller.get_shoulder_pos(is_left_arm)
	
	# SIMPLE FIX: Always use direct calculation, no coordinate flipping
	# The mouse position and shoulder positions are already in the correct coordinate space
	var arm_target = mouse_pos - shoulder_pos
	
	# Debug output (keep this for testing)
	if Input.is_action_just_pressed("ui_accept") and is_left_arm:
		print("🎯 Mouse: %s, Shoulder: %s, Target: %s, Facing: %s" % [
			mouse_pos, shoulder_pos, arm_target, 
			"RIGHT" if body_controller.facing_right else "LEFT"
		])
	
	return arm_target

func force_texture_update():
	# Force the SubViewport to update its texture
	if sub_viewport:
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		
		# Update the sprite texture
		texture = sub_viewport.get_texture()
		print("🎨 Forced SubViewport texture update")

func debug_full_mouse_coordinates():
	if not input_handler:
		return
		
	var mouse_2d = input_handler.get_left_arm_target()  # This gets the mouse position
	
	print("=== FULL MOUSE DEBUG ===")
	print("Mouse 2D from input: " + str(mouse_2d))
	if body_controller:
		print("Character facing: " + ("RIGHT" if body_controller.facing_right else "LEFT"))
		print("Left shoulder: " + str(body_controller.get_shoulder_pos(true)))
		print("Right shoulder: " + str(body_controller.get_shoulder_pos(false)))
		
		# Calculate what the arm targets would be
		var left_target = convert_mouse_to_arm_target(mouse_2d, true)
		var right_target = convert_mouse_to_arm_target(mouse_2d, false)
		print("Left arm target: " + str(left_target))
		print("Right arm target: " + str(right_target))
	print("========================")

# ADD this comprehensive debug function:
func debug_coordinate_flow():
	if not input_handler:
		return
	
	print("=== COORDINATE FLOW DEBUG ===")
	
	# Get raw mouse screen position
	var raw_mouse = get_viewport().get_mouse_position()
	print("1. Raw mouse screen: " + str(raw_mouse))
	
	# Get processed mouse from input handler
	var processed_mouse = input_handler.get_mouse_position_relative_to_character()
	print("2. Processed mouse from input: " + str(processed_mouse))
	
	# Get current facing
	var facing = "RIGHT" if body_controller.facing_right else "LEFT"
	print("3. Character facing: " + facing)
	
	# Get shoulder positions
	var left_shoulder = body_controller.get_shoulder_pos(true)
	var right_shoulder = body_controller.get_shoulder_pos(false)
	print("4. Left shoulder: " + str(left_shoulder))
	print("5. Right shoulder: " + str(right_shoulder))
	
	# Calculate arm targets
	var left_target = convert_mouse_to_arm_target(processed_mouse, true)
	var right_target = convert_mouse_to_arm_target(processed_mouse, false)
	print("6. Left arm target: " + str(left_target))
	print("7. Right arm target: " + str(right_target))
	
	# Show which direction arms should point
	var left_dir = "LEFT" if left_target.x < 0 else "RIGHT"
	var right_dir = "LEFT" if right_target.x < 0 else "RIGHT"
	print("8. Left arm should point: " + left_dir)
	print("9. Right arm should point: " + right_dir)
	
	print("=============================")

# Signal handlers
func _on_arm_lock_changed(is_left_arm: bool, is_locked: bool):
	print("🔒 %s ARM %s" % ["LEFT" if is_left_arm else "RIGHT", "LOCKED" if is_locked else "UNLOCKED"])

func _on_orientation_changed(new_orientation: int):
	# Update sprite rotation to face camera based on movement orientation
	match new_orientation:
		0: # East: camera north of player, sprite faces north
			rotation.y = deg_to_rad(0)  # Face north (toward camera)
			print("🎭 Sprite facing North (East movement)")
		1: # South: camera east of player, sprite faces east  
			rotation.y = deg_to_rad(90)  # Face east (toward camera)
			print("🎭 Sprite facing East (South movement)")
		2: # West: camera south of player, sprite faces south
			rotation.y = deg_to_rad(180)  # Face south (toward camera)
			print("🎭 Sprite facing South (West movement)")
		3: # North: camera west of player, sprite faces west
			rotation.y = deg_to_rad(270)  # Face west (toward camera)
			print("🎭 Sprite facing West (North movement)")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:  # Press T to force triangle debug
				if body_controller:
					body_controller.force_triangle_debug()
			KEY_F:  # Press F to toggle facing manually
				if body_controller:
					body_controller.set_facing_direction(not body_controller.facing_right)
					print("🔄 Manually toggled facing to: " + ("RIGHT" if body_controller.facing_right else "LEFT"))
					force_texture_update()
			KEY_M:  # Press M for mouse coordinate debug
				debug_full_mouse_coordinates()
			KEY_C:  # Press C for comprehensive coordinate flow debug
				debug_coordinate_flow()
			KEY_R:  # Press R to force texture refresh
				print("🎨 Forcing texture refresh...")
				force_texture_update()
				
			KEY_F:  # Press F to toggle body facing manually (not sprite)
				if body_controller:
					body_controller.set_facing_direction(not body_controller.facing_right)
					print("🔄 Manually toggled BODY facing to: " + ("RIGHT" if body_controller.facing_right else "LEFT"))
					# Don't call force_texture_update() or flip sprite
					# Just let the body controller handle the facing change

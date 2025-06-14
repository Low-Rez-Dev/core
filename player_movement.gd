extends CharacterBody3D

@export var move_speed: float = 4.0
@export var rotation_dust_particles: PackedScene

var coordinate_system: Node
var current_position: Vector3
var target_depth_position: Vector3
var is_rotating: bool = false

signal rotation_complete()

func _ready():
	coordinate_system = get_node("/root/CoordinateSystem")
	if not coordinate_system:
		push_error("CoordinateSystem singleton not found!")
		return
	
	coordinate_system.orientation_changed.connect(_on_orientation_changed)
	current_position = global_position
	target_depth_position = current_position

func _physics_process(delta):
	if is_rotating:
		return
	
	handle_movement_input(delta)
	handle_rotation_input()

func handle_movement_input(delta):
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		input_vector.x += 1.0
	if Input.is_action_pressed("move_backward"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("move_depth_positive"):
		input_vector.y += 1.0
	if Input.is_action_pressed("move_depth_negative"):
		input_vector.y -= 1.0
	
	var movement_dir = coordinate_system.get_forward_direction() * input_vector.x
	var depth_dir = coordinate_system.get_depth_direction() * input_vector.y
	
	if input_vector.x != 0:
		current_position += movement_dir * move_speed * delta
	
	if abs(input_vector.y) > 0:
		target_depth_position += depth_dir * coordinate_system.grid_size
		target_depth_position = coordinate_system.snap_to_depth_grid(target_depth_position)
	
	var final_position = Vector3(current_position.x, current_position.y, current_position.z)
	final_position = coordinate_system.snap_to_depth_grid(final_position)
	
	if input_vector.y != 0:
		match coordinate_system.current_orientation:
			coordinate_system.Orientation.NORTH_SOUTH:
				final_position.z = target_depth_position.z
			coordinate_system.Orientation.EAST_WEST:
				final_position.x = target_depth_position.x
	
	velocity = (final_position - global_position) / delta if delta > 0 else Vector3.ZERO
	move_and_slide()

func handle_rotation_input():
	if Input.is_action_just_pressed("rotate_clockwise"):
		perform_rotation(true)
	elif Input.is_action_just_pressed("rotate_counterclockwise"):
		perform_rotation(false)

func perform_rotation(clockwise: bool):
	if is_rotating:
		return
	
	is_rotating = true
	
	var old_position = global_position
	
	if clockwise:
		coordinate_system.rotate_orientation_clockwise()
	else:
		coordinate_system.rotate_orientation_counterclockwise()
	
	spawn_dust_effect()
	
	var new_snapped_position = coordinate_system.snap_to_depth_grid(old_position)
	current_position = new_snapped_position
	target_depth_position = new_snapped_position
	global_position = new_snapped_position
	
	await get_tree().create_timer(0.1).timeout  # Brief pause for dust effect
	is_rotating = false
	rotation_complete.emit()

func spawn_dust_effect():
	if not rotation_dust_particles:
		return
	
	var dust = rotation_dust_particles.instantiate()
	get_parent().add_child(dust)
	dust.global_position = global_position

func _on_orientation_changed(new_orientation):
	print("Orientation changed to: ", new_orientation)

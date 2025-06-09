extends Node
class_name Movement3DController

@export var running_speed_ms = 4.0
@export var walking_speed_ms = 1.5
@export var snap_to_grid = true
@export var grid_size = 1.0

var target_node: Node3D
var input_handler: InputHandler
var velocity_3d: Vector3 = Vector3.ZERO

# FIXED: Track actual cardinal facing direction (0=E, 1=S, 2=W, 3=N)
var current_orientation = 0  # 0=East, 1=South, 2=West, 3=North
var orientation_cooldown = 0.3
var can_rotate = true
var rotate_timer = 0.0

# FIXED: Movement directions for each cardinal facing
# A = backwards along facing axis, D = forwards along facing axis
var movement_directions = [
	# Facing East: A moves West (-X), D moves East (+X)
	{ "backward": Vector3(-1, 0, 0), "forward": Vector3(1, 0, 0) },
	# Facing South: A moves North (+Z), D moves South (-Z) - FIXED: A/D corrected
	{ "backward": Vector3(0, 0, 1), "forward": Vector3(0, 0, -1) },
	# Facing West: A moves East (+X), D moves West (-X)
	{ "backward": Vector3(1, 0, 0), "forward": Vector3(-1, 0, 0) },
	# Facing North: A moves South (-Z), D moves North (+Z)
	{ "backward": Vector3(0, 0, -1), "forward": Vector3(0, 0, 1) }
]

signal position_changed(new_position: Vector3)
signal orientation_changed(new_orientation: int)

func setup(node_3d: Node3D, input: InputHandler):
	target_node = node_3d
	input_handler = input

func _ready():
	if not target_node or not input_handler:
		push_error("Movement3DController needs setup() called with target node and input handler")

func _process(delta):
	if not target_node or not input_handler:
		return
	
	handle_rotation_cooldown(delta)
	update_movement(delta)

func handle_rotation_cooldown(delta):
	if not can_rotate:
		rotate_timer += delta
		if rotate_timer >= orientation_cooldown:
			can_rotate = true
			rotate_timer = 0.0

func update_movement(delta):
	var movement_2d = input_handler.get_movement_direction()
	var rotation_input = input_handler.get_z_movement()
	
	# FIXED: Handle Q/E rotation - cycles through all 4 cardinal facing directions
	if rotation_input != 0.0 and can_rotate:
		if rotation_input > 0:  # Q key - clockwise rotation
			current_orientation = (current_orientation + 1) % 4  # 0→1→2→3→0
		else:  # E key - counter-clockwise rotation  
			current_orientation = (current_orientation - 1) % 4
			if current_orientation < 0:
				current_orientation = 3  # Wrap around
		
		can_rotate = false
		orientation_changed.emit(current_orientation)
		print("🧭 Now facing %s" % get_orientation_name())
	
	# Handle A/D movement along facing direction
	var is_running = Input.is_key_pressed(KEY_SHIFT)
	var current_speed_ms = running_speed_ms if is_running else walking_speed_ms
	
	if abs(movement_2d.x) > 0.1:  # A/D input
		var speed_per_frame = current_speed_ms * delta
		var movement_dirs = movement_directions[current_orientation]
		
		var movement_vector: Vector3
		if movement_2d.x < 0:  # A key - move backward along facing axis
			movement_vector = movement_dirs.backward * abs(movement_2d.x) * speed_per_frame
			print("🚶 Moving BACKWARD from %s" % get_orientation_name())
		else:  # D key - move forward along facing axis  
			movement_vector = movement_dirs.forward * movement_2d.x * speed_per_frame
			print("🚶 Moving FORWARD toward %s" % get_orientation_name())
		
		velocity_3d.x = movement_vector.x
		velocity_3d.z = movement_vector.z
	else:
		# Smooth stop when no A/D input
		var decel_speed = current_speed_ms * delta * 2
		velocity_3d.x = move_toward(velocity_3d.x, 0, decel_speed)
		velocity_3d.z = move_toward(velocity_3d.z, 0, decel_speed)
	
	# Apply movement
	target_node.position.x += velocity_3d.x
	target_node.position.z += velocity_3d.z
	target_node.position.y = 0.0
	
	if velocity_3d.length() > 0.01 or rotation_input != 0.0:
		position_changed.emit(target_node.position)

func get_orientation_name() -> String:
	match current_orientation:
		0: return "EAST"
		1: return "SOUTH"  
		2: return "WEST"
		3: return "NORTH"
		_: return "UNKNOWN"

func get_movement_axis_name() -> String:
	match current_orientation:
		0, 2: return "X-axis (East/West)"
		1, 3: return "Z-axis (North/South)"
		_: return "UNKNOWN"

func get_depth_axis_name() -> String:
	match current_orientation:
		0, 2: return "Z-axis (North/South lanes)"
		1, 3: return "X-axis (East/West lanes)"  
		_: return "UNKNOWN"

func get_camera_direction() -> int:
	# Return which cardinal direction camera should face
	match current_orientation:
		0: return 1  # E-W axis: camera faces North (looking South)
		1: return 0  # N-S axis: camera faces East (looking West)
		_: return 0

func get_grid_position() -> Vector3i:
	if not target_node:
		return Vector3i.ZERO
	
	var pos = target_node.position
	return Vector3i(
		int(round(pos.x / grid_size)),
		int(round(pos.y / grid_size)),
		int(round(pos.z / grid_size))
	)

func set_grid_position(grid_pos: Vector3i):
	if not target_node:
		return
	
	target_node.position = Vector3(
		grid_pos.x * grid_size,
		grid_pos.y * grid_size,
		grid_pos.z * grid_size
	)
	
	position_changed.emit(target_node.position)

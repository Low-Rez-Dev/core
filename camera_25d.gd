extends Node3D
class_name Camera25D

@export var follow_target: Node3D
@export var camera_distance = 5.0
@export var zoom_speed = 2.0
@export var min_distance = 2.0
@export var max_distance = 15.0

var camera: Camera3D
var current_direction = 1  # Start facing North (looking South) for E-W movement

# Cardinal directions - camera positions relative to player
var camera_positions = [
	Vector3(1, 0, 0),   # East: camera east of player (looking West)
	Vector3(0, 0, 1),   # North: camera north of player (looking South) - DEFAULT
	Vector3(-1, 0, 0),  # West: camera west of player (looking East)
	Vector3(0, 0, -1)   # South: camera south of player (looking North)
]

func _ready():
	setup_camera()
	if follow_target:
		connect_to_movement_system()
		position_camera()

func setup_camera():
	print("📷 Setting up rail camera system...")
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	add_child(camera)
	print("📷 Rail camera created - locked to cardinal directions")

func connect_to_movement_system():
	if follow_target and follow_target.has_method("get") and follow_target.movement_3d:
		follow_target.movement_3d.orientation_changed.connect(_on_orientation_changed)
		print("🔗 Camera connected to movement orientation system")
	else:
		print("⚠️ Could not connect to movement system - will retry")
		get_tree().process_frame.connect(_retry_connection, CONNECT_ONE_SHOT)

func _retry_connection():
	await get_tree().process_frame
	connect_to_movement_system()

func _process(delta):
	if follow_target:
		# FIXED: Hard rail following - no smooth interpolation
		update_rail_position()

func update_rail_position():
	var target_pos = follow_target.global_position
	target_pos.y += 1.0  # Character center mass
	
	# FIXED: Calculate exact rail position
	var direction_offset = camera_positions[current_direction] * camera_distance
	var rail_position = target_pos + direction_offset
	rail_position.y = target_pos.y  # Keep at character height
	
	# FIXED: SNAP to rail position - no lerping!
	global_position = rail_position
	
	# FIXED: Use look_at with proper up vector constraint
	var look_target = target_pos
	var up_vector = Vector3.UP
	
	# Ensure we're looking exactly along cardinal direction
	var look_direction = (look_target - global_position).normalized()
	
	# FIXED: Force exact cardinal alignment to prevent micro-rotations
	match current_direction:
		0: # East rail - looking exactly West
			look_direction = Vector3(-1, 0, 0)
			global_position.x = target_pos.x + camera_distance
			global_position.z = target_pos.z  # Lock Z exactly
		1: # North rail - looking exactly South  
			look_direction = Vector3(0, 0, -1)
			global_position.x = target_pos.x  # Lock X exactly
			global_position.z = target_pos.z + camera_distance
		2: # West rail - looking exactly East
			look_direction = Vector3(1, 0, 0)
			global_position.x = target_pos.x - camera_distance
			global_position.z = target_pos.z  # Lock Z exactly
		3: # South rail - looking exactly North
			look_direction = Vector3(0, 0, 1)
			global_position.x = target_pos.x  # Lock X exactly
			global_position.z = target_pos.z - camera_distance
	
	# Set exact rotation instead of look_at to avoid float precision issues
	var exact_target = global_position + look_direction
	look_at(exact_target, up_vector)

func _on_orientation_changed(new_orientation: int):
	# FIXED: Camera position based on player facing direction
	# When player faces right on screen, camera position is:
	match new_orientation:
		0: # Player facing East: camera faces North (looking South)
			current_direction = 1  # North position
			print("📷 Player facing EAST: Camera facing North")
		1: # Player facing South: camera faces East (looking West)
			current_direction = 0  # East position  
			print("📷 Player facing SOUTH: Camera facing East")
		2: # Player facing West: camera faces South (looking North)
			current_direction = 3  # South position
			print("📷 Player facing WEST: Camera facing South")
		3: # Player facing North: camera faces West (looking East)
			current_direction = 2  # West position
			print("📷 Player facing NORTH: Camera facing West")
	
	if follow_target:
		update_rail_position()
		
func position_camera():
	if not follow_target:
		return
	update_rail_position()
	print("📷 Camera positioned on %s rail" % get_direction_name())

func get_direction_name() -> String:
	match current_direction:
		0: return "EAST RAIL (looking West)"
		1: return "NORTH RAIL (looking South)"
		2: return "WEST RAIL (looking East)"
		3: return "SOUTH RAIL (looking North)"
		_: return "UNKNOWN"

func _input(event):
	# Handle zoom with mouse wheel only
	if event.is_action_pressed("wheel_up"):
		zoom_in()
	elif event.is_action_pressed("wheel_down"):
		zoom_out()

func zoom_in():
	camera_distance = max(min_distance, camera_distance - zoom_speed)
	if camera:
		camera.size = max(5, camera.size - 2)
	# FIXED: Immediate position update
	if follow_target:
		update_rail_position()
	print("📷 Zoomed in - Distance: %.1f, Size: %.1f" % [camera_distance, camera.size])

func zoom_out():
	camera_distance = min(max_distance, camera_distance + zoom_speed)
	if camera:
		camera.size = min(50, camera.size + 2)
	# FIXED: Immediate position update  
	if follow_target:
		update_rail_position()
	print("📷 Zoomed out - Distance: %.1f, Size: %.1f" % [camera_distance, camera.size])

# REMOVED: update_camera_position_immediate() - now handled by update_rail_position()

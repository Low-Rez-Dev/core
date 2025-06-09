extends Node3D
class_name GameWorld3D

@export var debug_mode = true

var debug_markers: DebugMarkers
var player_3d: Character2D5D  # Now using Character25D
var camera_3d: Camera25D    # Now using 2.5D camera

func _ready():
	print("🌍 GameWorld3D _ready() starting...")
	setup_world()
	print("🌍 GameWorld3D _ready() complete!")

func setup_world():
	if debug_mode:
		create_debug_environment()
	
	create_player()
	await get_tree().process_frame
	setup_camera_system()
	setup_coordinate_hud()  # Add coordinate display

func setup_coordinate_hud():
	# Create simple coordinate display without custom class
	var hud = Control.new()
	hud.name = "CoordinateHUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add a label for coordinate display
	var label = Label.new()
	label.name = "CoordinateLabel"
	label.position = Vector2(20, 20)
	label.size = Vector2(400, 200)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(label)
	
	add_child(hud)
	
	# Store reference for updating
	var coordinate_label = label
	
	# Connect to update coordinates
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_update_coordinates.bind(coordinate_label))
	timer.autostart = true
	add_child(timer)
	
	print("📍 Simple coordinate HUD created")

func _update_coordinates(label: Label):
	if not player_3d:
		return
	
	var pos = player_3d.global_position
	
	# Convert to cardinal coordinates
	var ns_dir = "N" if pos.z >= 0 else "S"  # Z-axis is N-S  
	var ns_meters = abs(pos.z)
	var ew_dir = "E" if pos.x >= 0 else "W"  # X-axis is E-W
	var ew_meters = abs(pos.x)

# Convert meters to coordinates  
	var ns_coord = meters_to_coordinate(ns_meters)
	var ew_coord = meters_to_coordinate(ew_meters)

	
	# Get actual player facing from movement system
	var player_facing = "E"  # Default
	var current_orientation = "E-W"  # Default
	
	if player_3d.movement_3d:
		var orientation = player_3d.movement_3d.current_orientation
		current_orientation = player_3d.movement_3d.get_orientation_name()
		
		# Determine facing based on body controller
		if player_3d.body_controller:
			if player_3d.body_controller.facing_right:
				player_facing = "E" if orientation == 0 else "N"
			else:
				player_facing = "W" if orientation == 0 else "S"
	
	# Get actual camera facing from camera system
	var camera_facing = "N"  # Default
	var camera_view = "looking S"
	
	if camera_3d:
		var cam_dir = camera_3d.current_direction
		match cam_dir:
			0: camera_facing = "E"; camera_view = "looking W"
			1: camera_facing = "N"; camera_view = "looking S"
			2: camera_facing = "W"; camera_view = "looking E"
			3: camera_facing = "S"; camera_view = "looking N"
	
	var text = """Position: %.1f, %.1f, %.1f
Cardinal: %s %s, %s %s
Player Axis: %s
Player Facing: %s
Camera Rail: %s (%s)
Grid: Z0=Prime Meridian, X0=Equator""" % [
		pos.x, pos.y, pos.z,
		ns_coord, ns_dir, ew_coord, ew_dir,
		current_orientation,
		player_facing, 
		camera_facing, camera_view
	]
	
	label.text = text

func meters_to_coordinate(meters: float) -> String:
	# Convert meters to degrees°minutes'seconds"milliseconds
	# 1 meter = 1 millisecond of arc
	# 1000 milliseconds = 1 second
	# 60 seconds = 1 minute  
	# 60 minutes = 1 degree
	
	var total_milliseconds = int(meters)
	
	var degrees = total_milliseconds / (60 * 60 * 1000)
	var remainder = total_milliseconds % (60 * 60 * 1000)
	
	var minutes = remainder / (60 * 1000)
	remainder = remainder % (60 * 1000)
	
	var seconds = remainder / 1000
	var milliseconds = remainder % 1000
	
	return "%02d°%02d'%02d\"%03d" % [degrees, minutes, seconds, milliseconds]

func create_debug_environment():
	debug_markers = DebugMarkers.new()
	debug_markers.name = "DebugMarkers"
	add_child(debug_markers)
	
	print("🌍 3D Debug environment created!")

func create_player():
	print("🎮 Creating player...")
	
	# Create the NEW 2.5D character using Entity2D5D system
	player_3d = Character2D5D.new()
	player_3d.name = "Player3D"
	player_3d.position = Vector3(0, 0, 0)  # Start at origin
	
	# Set input type here - change this line to switch input methods
	player_3d.input_type = "MouseKeyboard"  # Change to "Controller" for gamepad support
	
	add_child(player_3d)
	
	# Wait for character to initialize
	await get_tree().process_frame
	
	print("🎮 Player created as Character2D5D at position: %s" % player_3d.position)

func setup_camera_system():
	if not player_3d:
		print("❌ No player to follow!")
		return
		
	print("📷 Creating camera system...")
	camera_3d = Camera25D.new()
	camera_3d.name = "CameraController"
	camera_3d.follow_target = player_3d
	add_child(camera_3d)
	
	print("📷 Camera system created and added to scene!")
	
	# Force camera positioning
	await get_tree().process_frame
	if camera_3d.camera:
		print("📷 Camera exists: %s" % camera_3d.camera)
		print("📷 Camera position: %s" % camera_3d.global_position)
	else:
		print("❌ Camera is null!")

func get_player_grid_position() -> Vector3i:
	if player_3d:
		var pos = player_3d.position
		return Vector3i(roundi(pos.x), roundi(pos.y), roundi(pos.z))
	return Vector3i.ZERO

# Debug input for testing
# EMERGENCY DEBUG SCRIPT
# Add this directly to your world_3d_setup.gd file, replacing the existing _input function

# EMERGENCY DEBUG SCRIPT
# Add this directly to your world_3d_setup.gd file, replacing the existing _input function

func _input(event):
	if not debug_mode:
		return
	
	print("🎮 Raw input event: %s" % event)
	
	# Use raw key detection instead of actions
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER:
				print("🔍 ENTER pressed - debugging visibility")
				emergency_debug_visibility()
			KEY_ESCAPE:
				print("🔄 ESCAPE pressed - emergency reset")
				emergency_reset_everything()
			KEY_SPACE:
				print("🔴 SPACE pressed - creating marker")
				if player_3d:
					create_debug_marker_at_player()
				else:
					print("❌ No player found!")
					# Add this to your world_3d_setup.gd _input function for direct movement testing

# Add this case to your match statement in _input:
			KEY_T:  # Press T to test direct movement
				print("🧪 TESTING DIRECT MOVEMENT")
				if player_3d:
					var old_pos = player_3d.position
					player_3d.position.z += 0.5  # Move directly
					print("📍 Direct move: %s → %s" % [old_pos, player_3d.position])

			KEY_R:  # Press R to test movement system
				print("🧪 TESTING MOVEMENT SYSTEM")
				if player_3d and player_3d.movement_3d:
					print("✅ Movement3D exists: %s" % player_3d.movement_3d.name)
					print("🎮 Current orientation: %s" % player_3d.movement_3d.get_orientation_name())
					print("⚡ Current velocity: %s" % player_3d.movement_3d.velocity_3d)
				else:
					print("❌ Movement3D missing!")

			KEY_Y:  # Press Y to test input handler
				print("🧪 TESTING INPUT HANDLER")
				if player_3d and player_3d.input_handler:
					print("✅ Input handler exists: %s" % player_3d.input_handler.get_script().get_global_name())
					print("🎮 Movement direction: %s" % player_3d.input_handler.get_movement_direction())
					print("🔄 Z movement: %s" % player_3d.input_handler.get_z_movement())
				else:
					print("❌ Input handler missing!")

# Also add this simple direct key test:
			KEY_U:  # Press U for raw WASD test
				print("🧪 RAW KEY TEST")
				print("A pressed: %s" % Input.is_key_pressed(KEY_A))
				print("D pressed: %s" % Input.is_key_pressed(KEY_D))
				print("W pressed: %s" % Input.is_key_pressed(KEY_W))  
				print("S pressed: %s" % Input.is_key_pressed(KEY_S))
				print("Q pressed: %s" % Input.is_key_pressed(KEY_Q))
				print("E pressed: %s" % Input.is_key_pressed(KEY_E))

func emergency_debug_visibility():
	print("==================================================")
	print("🆘 EMERGENCY DEBUG VISIBILITY")
	print("==================================================")
	
	# Check player
	if player_3d:
		print("✅ Player exists: %s" % player_3d.name)
		print("📍 Position: %s" % player_3d.global_position)
		print("📏 Scale: %s" % player_3d.scale)
		print("🎭 Rotation: %s" % player_3d.rotation)
		print("👀 Visible: %s" % player_3d.visible)
		print("🖼️ Texture exists: %s" % (player_3d.texture != null))
		
		if player_3d.texture:
			print("🖼️ Texture size: %s" % player_3d.texture.get_size())
		
		# Check SubViewport
		if player_3d.has_method("get") and player_3d.sub_viewport:
			print("📺 SubViewport exists: %s" % player_3d.sub_viewport.name)
			print("📺 SubViewport size: %s" % player_3d.sub_viewport.size)
			var vp_tex = player_3d.sub_viewport.get_texture()
			print("📺 SubViewport texture: %s" % (vp_tex != null))
		else:
			print("❌ SubViewport missing!")
	else:
		print("❌ PLAYER IS NULL!")
	
	# Check camera
	if camera_3d:
		print("✅ Camera exists: %s" % camera_3d.name)
		print("📷 Position: %s" % camera_3d.global_position)
		print("📷 Distance: %s" % camera_3d.camera_distance)
		if camera_3d.camera:
			print("📷 Camera size: %s" % camera_3d.camera.size)
			print("📷 Projection: %s" % camera_3d.camera.projection)
		else:
			print("❌ Camera object missing!")
	else:
		print("❌ CAMERA IS NULL!")
	
	print("==================================================")

func emergency_reset_everything():
	print("🆘 EMERGENCY RESET - MAKING EVERYTHING HUGE AND VISIBLE")
	
	if player_3d:
		# Reset position
		player_3d.position = Vector3(0, 0, 0)
		print("📍 Player position reset to origin")
		
		# Make character MASSIVE for visibility
		player_3d.scale = Vector3(5.0, 5.0, 5.0)
		print("📏 Player scale set to HUGE: %s" % player_3d.scale)
		
		# Ensure visibility
		player_3d.visible = true
		print("👀 Player visibility forced to true")
		
		# Force texture refresh
		if player_3d.has_method("get") and player_3d.sub_viewport:
			await get_tree().process_frame
			player_3d.texture = player_3d.sub_viewport.get_texture()
			print("🖼️ Texture refreshed")
	
	if camera_3d:
		# Move camera very close
		camera_3d.camera_distance = 2.0
		camera_3d.update_camera_position_immediate()
		print("📷 Camera moved very close: %s" % camera_3d.global_position)
		
		# Make camera view smaller for close-up
		if camera_3d.camera:
			camera_3d.camera.size = 5.0
			print("📷 Camera size reduced to: %s" % camera_3d.camera.size)

# Keep the existing debug functions but rename them
func create_debug_marker_at_player():
	if not player_3d:
		return
	
	# Create a HUGE bright red cube
	var marker = MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	marker.mesh.size = Vector3(4, 8, 2)  # HUGE marker
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.emission_enabled = true
	material.emission = Color.RED
	
	marker.material_override = material
	marker.position = player_3d.global_position + Vector3(0, 4, 0)
	marker.name = "EMERGENCY_MARKER"
	
	add_child(marker)
	
	print("🔴 HUGE emergency marker created at: %s" % marker.position)
	
	# Remove after 10 seconds
	var tween = create_tween()
	tween.tween_delay(10.0)
	tween.tween_callback(marker.queue_free)

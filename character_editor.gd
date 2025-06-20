extends Control
class_name CharacterEditor

# References to UI elements
@onready var entity_name_edit: LineEdit = $VBoxContainer/EntitySelectorContainer/EntityNameEdit
@onready var full_character_preview: Control = $VBoxContainer/HBoxContainer/LeftPanel/FullCharacterPreview
@onready var part_preview: Control = $VBoxContainer/HBoxContainer/CenterPanel/PartPreview
@onready var part_label: Label = $VBoxContainer/HBoxContainer/CenterPanel/PartNavigationContainer/PartLabel
@onready var coordinates_list: VBoxContainer = $VBoxContainer/HBoxContainer/RightPanel/CoordinatesContainer/CoordinatesList
@onready var coordinates_container: ScrollContainer = $VBoxContainer/HBoxContainer/RightPanel/CoordinatesContainer
@onready var script_output: TextEdit = $VBoxContainer/HBoxContainer/RightPanel/ScriptOutput
@onready var zoom_label: Label = $VBoxContainer/HBoxContainer/LeftPanel/ZoomContainer/ZoomLabel
@onready var instance_label: Label = $VBoxContainer/HBoxContainer/CenterPanel/InstanceContainer/InstanceLabel
@onready var sync_instances_button: Button = $VBoxContainer/HBoxContainer/CenterPanel/SyncContainer/SyncInstancesButton
@onready var ground_value_label: Label = $VBoxContainer/HBoxContainer/LeftPanel/GroundContainer/GroundValueLabel

# Body part data structure
var body_parts = {}
var current_part_index = 0
var part_names = []

# Interactive editing variables
var is_dragging = false
var dragged_point_index = -1
var is_dragging_attachment = false
var is_dragging_child_attachment = false
var dragged_child_attachment_index = -1
var is_dragging_polygon = false
var last_mouse_pos = Vector2.ZERO
var point_radius = 8.0  # Size of draggable point circles
var drag_threshold = 5.0  # Minimum distance to start dragging
var attachment_point_radius = 6.0  # Size of attachment point circles

# Colors
var pottery_dark = Color(0.15, 0.1, 0.08)
var pottery_medium = Color(0.2, 0.15, 0.12)
var eye_white = Color(0.95, 0.9, 0.85)
var accent_red = Color(0.6, 0.15, 0.1)
var highlight_color = Color(1.0, 1.0, 0.0, 0.5)  # Yellow highlight for selected part

var character_scale = 6.0  # Much larger scale for easier editing (3x bigger)
var preview_zoom = 1.0  # Zoom level for the full character preview
var min_zoom = 0.5
var max_zoom = 3.0
# Instance management
var current_instance_index = 0  # 0 = right, 1 = left for shared parts

# Accordion state
var coordinates_section_collapsed = true  # Hidden by default
var script_section_collapsed = true  # Hidden by default

# Helper functions for instance-specific data
func get_current_instance_data(part_name: String) -> Dictionary:
	"""Get the data for the current instance of a part. Creates instance data if needed."""
	return get_instance_data(part_name, current_instance_index)

func get_instance_data(part_name: String, instance_index: int) -> Dictionary:
	"""Get the data for a specific instance of a part. Creates instance data if needed."""
	var part_data = body_parts[part_name]
	
	if not part_data.get("shared", false):
		# Non-shared parts return the data directly
		return part_data
	
	# Shared parts: ensure instance data exists
	if not part_data.has("instances"):
		part_data["instances"] = {}
	
	var instance_key = str(instance_index)
	if not part_data.instances.has(instance_key):
		# Create new instance data by copying from the base data
		part_data.instances[instance_key] = create_instance_data_from_base(part_data)
	
	return part_data.instances[instance_key]

func create_instance_data_from_base(base_data: Dictionary) -> Dictionary:
	"""Create instance-specific data from base part data."""
	var instance_data = {}
	
	# Copy geometry data that should be instance-specific
	if base_data.has("points"):
		instance_data["points"] = base_data.points.duplicate()
	if base_data.has("center"):
		instance_data["center"] = base_data.center
	if base_data.has("radius"):
		instance_data["radius"] = base_data.radius
	if base_data.has("rect"):
		instance_data["rect"] = base_data.rect
	if base_data.has("attachment_point"):
		instance_data["attachment_point"] = base_data.attachment_point
	if base_data.has("child_attachment_points"):
		instance_data["child_attachment_points"] = base_data.child_attachment_points.duplicate()
	if base_data.has("iris_center"):
		instance_data["iris_center"] = base_data.iris_center
	if base_data.has("iris_radius"):
		instance_data["iris_radius"] = base_data.iris_radius
	
	# Copy non-geometry properties that are shared across instances
	instance_data["type"] = base_data.get("type", "polygon")
	instance_data["color"] = base_data.get("color", Color.WHITE)
	if base_data.has("iris_color"):
		instance_data["iris_color"] = base_data.iris_color
	
	return instance_data

func sync_instances(part_name: String):
	"""Sync all instances of a shared part to match the current instance."""
	var part_data = body_parts[part_name]
	if not part_data.get("shared", false):
		return  # Nothing to sync for non-shared parts
	
	var source_data = get_current_instance_data(part_name)
	var num_instances = part_data.get("num_instances", 1)
	
	for i in range(num_instances):
		if i != current_instance_index:
			var instance_key = str(i)
			part_data.instances[instance_key] = create_instance_data_from_base(source_data)
	
	print("Synced all instances of %s to match instance %d" % [part_name, current_instance_index])
	full_character_preview.queue_redraw()
	part_preview.queue_redraw()

# Entity management
var available_entities = []
var current_entity_index = 0
var current_entity_name = "Human"
var entities_folder = "user://entities/"

# Ground level system
var ground_level = 0.0  # Y position where the ground is (positive is lower)
var is_dragging_ground = false
var terrain_sample_height = 20.0  # Height of the terrain sample area
var terrain_noise_scale = 0.1  # Scale for terrain noise variation

# Day-night cycle for background
var day_length: float = 60.0  # 60 seconds for a full day
var current_time: float = 30.0  # Start at midday
var time_speed: float = 1.0

func _ready():
	load_available_entities()
	# Try to load Human entity first, otherwise use defaults
	if not try_load_human_entity():
		initialize_body_parts()
	setup_accordion_ui()
	setup_previews()
	update_current_part_display()

	# Start the day-night cycle
	set_process(true)

func setup_accordion_ui():
	# Replace the static labels with clickable accordion headers
	var right_panel = $VBoxContainer/HBoxContainer/RightPanel
	
	# Setup coordinates section accordion
	var coordinates_label = right_panel.get_node("CoordinatesLabel")
	var coordinates_button = Button.new()
	coordinates_button.text = "▶ Polygon Coordinates"  # Collapsed state arrow
	coordinates_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	coordinates_button.pressed.connect(_on_coordinates_accordion_toggled)
	
	# Replace the label with our button
	var label_index = coordinates_label.get_index()
	coordinates_label.queue_free()
	right_panel.add_child(coordinates_button)
	right_panel.move_child(coordinates_button, label_index)
	
	# Setup script section accordion
	var script_label = right_panel.get_node("ScriptOutputLabel") 
	var script_button = Button.new()
	script_button.text = "▶ Generated Script"  # Collapsed state arrow
	script_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	script_button.pressed.connect(_on_script_accordion_toggled)
	
	# Replace the label with our button
	var script_label_index = script_label.get_index()
	script_label.queue_free()
	right_panel.add_child(script_button)
	right_panel.move_child(script_button, script_label_index)
	
	# Set initial collapsed state (hidden by default)
	coordinates_container.visible = not coordinates_section_collapsed
	script_output.visible = not script_section_collapsed

func _on_coordinates_accordion_toggled():
	coordinates_section_collapsed = not coordinates_section_collapsed
	coordinates_container.visible = not coordinates_section_collapsed
	
	# Update button text to show accordion state
	var button = $VBoxContainer/HBoxContainer/RightPanel.get_children().filter(func(child): return child is Button and "Polygon Coordinates" in child.text)[0]
	button.text = ("▼ Polygon Coordinates" if not coordinates_section_collapsed else "▶ Polygon Coordinates")

func _on_script_accordion_toggled():
	script_section_collapsed = not script_section_collapsed
	script_output.visible = not script_section_collapsed
	
	# Update button text to show accordion state
	var button = $VBoxContainer/HBoxContainer/RightPanel.get_children().filter(func(child): return child is Button and "Generated Script" in child.text)[0]
	button.text = ("▼ Generated Script" if not script_section_collapsed else "▶ Generated Script")

func try_load_human_entity() -> bool:
	var human_file_path = entities_folder + "Human.gd"
	if FileAccess.file_exists(human_file_path):
		print("Found Human entity file, loading...")
		if load_entity("Human"):
			print("Successfully loaded Human entity from file")
			return true
		else:
			print("Failed to load Human entity file, using defaults")
	else:
		print("No Human entity file found, using defaults")
	return false

func initialize_body_parts():
	# Extract all body part polygons from the character drawing code
	# Shared models for left/right limbs
	body_parts = {
		"head": {
			"type": "polygon",
			"points": [
				Vector2(-5.0, -30.9), Vector2(-0.9, -34.5), Vector2(5.0, -33.3), 
				Vector2(7.3, -29.2), Vector2(8.5, -25.2), Vector2(5.9, -21.8), 
				Vector2(-1.6, -19.9), Vector2(-5.7, -25.7)
			],
			"color": pottery_dark,
			"child_attachment_points": [
				Vector2(0, -21)  # 0: Neck attachment
			]
		},
		"hair": {
			"type": "polygon", 
			"points": [
				Vector2(-7.2, -31.5), Vector2(-1.7, -36.1), Vector2(4.3, -35.0),
				Vector2(6.0, -32.0), Vector2(-0.5, -32.3), Vector2(-5.8, -26.7)
			],
			"color": pottery_dark
		},
		"eye": {
			"type": "polygon",
			"points": [
				Vector2(0.5, -30.5), Vector2(3.5, -30.5), Vector2(3.5, -27.5), Vector2(0.5, -27.5)
			],
			"color": eye_white,
			"iris_center": Vector2(2, -29),
			"iris_radius": 0.8,
			"iris_color": pottery_dark
		},
		"nose": {
			"type": "polygon",
			"points": [
				Vector2(4, -27), Vector2(7, -25), Vector2(5, -24)
			],
			"color": pottery_medium
		},
		"neck": {
			"type": "polygon",
			"points": [
				Vector2(-2, -21), Vector2(2, -21), Vector2(2, -17), Vector2(-2, -17)
			],
			"color": pottery_dark,
			"attachment_point": Vector2(0, -21),  # Attaches to head
			"attachment_to": "head",
			"attachment_to_index": 0,  # Connects to head's child attachment point 0 (needs to be added)
			"child_attachment_points": [
				Vector2(0, -17)  # 0: Torso attachment
			]
		},
		"torso": {
			"type": "polygon",
			"points": [
				Vector2(-7.9, -13.8), Vector2(-7.3, -16.5), Vector2(-2.8, -17.7),
				Vector2(3.2, -17.8), Vector2(6.6, -16.8), Vector2(7.5, -14.0),
				Vector2(6.2, -7.5), Vector2(4.3, -1.7), Vector2(-3.9, -1.7), Vector2(-6.0, -7.3)
			],
			"color": pottery_dark,
			"attachment_point": Vector2(0, -17),  # Attaches to neck
			"attachment_to": "neck",
			"attachment_to_index": 0,  # Connects to neck's child attachment point 0
			"child_attachment_points": [
				Vector2(7.0, -16.0),   # 0: Right arm attachment (instance 0)
				Vector2(-7.0, -16.0),  # 1: Left arm attachment (instance 1)
				Vector2(0, -8)         # 2: Hips attachment
			]
		},
		"hips": {
			"type": "polygon",
			"points": [
				Vector2(-8, -8), Vector2(8, -8), Vector2(6, -2), Vector2(-6, -2)
			],
			"color": pottery_dark,
			"attachment_point": Vector2(0, -8),  # Attaches to torso
			"attachment_to": "torso",
			"attachment_to_index": 2,  # Connects to torso's child attachment point 2 (hips)
			"child_attachment_points": [
				Vector2(3.5, -2.0),   # 0: Right leg attachment (instance 0)
				Vector2(-3.5, -2.0)   # 1: Left leg attachment (instance 1)
			]
		},
		"upper_arm": {
			"type": "polygon",
			"points": [
				Vector2(7.0, -16.0), Vector2(8.0, -14.0), Vector2(6.0, -10.0),
				Vector2(4.0, -8.0), Vector2(5.0, -6.0), Vector2(6.5, -4.0), Vector2(8.0, -6.0)
			],
			"color": pottery_dark,
			"shared": true,  # This model is shared between left/right
			"num_instances": 2,  # Left and Right instances
			"attachment_point": Vector2(7.0, -16.0),  # Attaches to shoulder
			"attachment_to": "torso",
			# Shared parts use automatic sequential indexing: instance 0 → attachment 0, instance 1 → attachment 1
			"child_attachment_points": [
				Vector2(6.0, -10.0),  # 0: Right forearm attachment (instance 0)
				Vector2(6.0, -10.0)   # 1: Left forearm attachment (instance 1)
			]
		},
		"forearm": {
			"type": "polygon",
			"points": [
				Vector2(6.0, -10.0), Vector2(4.0, -8.0), Vector2(8.0, -4.0),
				Vector2(10.0, -2.0), Vector2(9.0, -1.0), Vector2(7.0, -2.0), Vector2(5.0, -5.0)
			],
			"color": pottery_dark,
			"shared": true,  # This model is shared between left/right
			"num_instances": 2,  # Left and Right instances
			"attachment_point": Vector2(6.0, -10.0),  # Attaches to elbow of upper arm
			"attachment_to": "upper_arm",
			"attachment_to_index": 0,  # Connects to upper arm's child attachment point 0
			"child_attachment_points": [
				Vector2(9.0, -2.0),   # 0: Right hand attachment (instance 0)
				Vector2(9.0, -2.0)    # 1: Left hand attachment (instance 1)
			]
		},
		"hand": {
			"type": "polygon",
			"points": [
				Vector2(9.0, -2.0), Vector2(12.0, -1.0), Vector2(12.5, 1.0),
				Vector2(11.0, 2.0), Vector2(8.5, 1.0), Vector2(8.0, -1.0)
			],
			"color": pottery_dark,
			"shared": true,  # This model is shared between left/right
			"num_instances": 2,  # Left and Right instances
			"attachment_point": Vector2(9.0, -2.0),  # Attaches to wrist of forearm
			"attachment_to": "forearm",
			"attachment_to_index": 0,  # Connects to forearm's child attachment point 0
			"child_attachment_points": []  # No children attach to hands
		},
		"thigh": {
			"type": "polygon",
			"points": [
				Vector2(2, -2), Vector2(5, -2), Vector2(7, 4), Vector2(6, 6),
				Vector2(4, 6), Vector2(3, 2)
			],
			"color": pottery_dark,
			"shared": true,  # This model is shared between left/right
			"num_instances": 2,  # Left and Right instances
			"attachment_point": Vector2(3.5, -2),  # Attaches to hip
			"attachment_to": "hips",
			# Shared parts use automatic sequential indexing: instance 0 → attachment 0, instance 1 → attachment 1
			"child_attachment_points": [
				Vector2(5.5, 6.0),   # 0: Right shin attachment (instance 0)
				Vector2(5.5, 6.0)    # 1: Left shin attachment (instance 1)
			]
		},
		"shin": {
			"type": "polygon",
			"points": [
				Vector2(7, 6), Vector2(4, 6), Vector2(5, 11), Vector2(8, 11)
			],
			"color": pottery_dark,
			"shared": true,  # This model is shared between left/right
			"num_instances": 2,  # Left and Right instances
			"attachment_point": Vector2(5.5, 6),  # Attaches to knee of thigh
			"attachment_to": "thigh",
			"attachment_to_index": 0,  # Connects to thigh's child attachment point 0
			"child_attachment_points": [
				Vector2(7.5, 11),    # 0: Right foot attachment (instance 0)
				Vector2(7.5, 11)     # 1: Left foot attachment (instance 1)
			]
		},
		"foot": {
			"type": "polygon",
			"points": [
				Vector2(5, 11), Vector2(10, 11), Vector2(10, 13), Vector2(5, 13)
			],
			"color": pottery_dark,
			"shared": true,  # This model is shared between left/right
			"num_instances": 2,  # Left and Right instances
			"attachment_point": Vector2(8, 11),  # Attaches to ankle of shin
			"attachment_to": "shin",
			"attachment_to_index": 0,  # Connects to shin's child attachment point 0
			"child_attachment_points": []  # No children attach to feet
		}
	}
	
	part_names = body_parts.keys()

func _process(delta):
	# Update day-night cycle
	current_time += delta * time_speed
	if current_time >= day_length:
		current_time = 0.0
	full_character_preview.queue_redraw()  # Redraw for sky color changes

func setup_previews():
	# Set up custom drawing for both preview panels
	full_character_preview.draw.connect(_draw_full_character)
	part_preview.draw.connect(_draw_current_part)
	
	# Set up mouse input for interactive editing on part preview
	part_preview.gui_input.connect(_on_part_preview_input)
	
	# Set up mouse input for ground level dragging on full character preview
	full_character_preview.gui_input.connect(_on_full_preview_input)

func update_current_part_display():
	if part_names.size() > 0:
		var current_part_name = part_names[current_part_index]
		part_label.text = current_part_name.capitalize()
		
		# Update instance selector visibility and state
		var part_data = body_parts[current_part_name]
		var num_instances = part_data.get("num_instances", 1)
		var has_multiple_instances = num_instances > 1
		
		print("Part: %s, num_instances: %d, has_multiple: %s" % [current_part_name, num_instances, has_multiple_instances])
		
		# Show/hide instance selector and sync button based on whether part has multiple instances
		var instance_container = instance_label.get_parent()
		instance_container.visible = has_multiple_instances
		
		var sync_container = sync_instances_button.get_parent()
		sync_container.visible = has_multiple_instances
		
		if has_multiple_instances:
			# Clamp current instance to valid range
			current_instance_index = clamp(current_instance_index, 0, num_instances - 1)
			# Update instance label (0 = Right, 1 = Left for typical bilateral parts)
			if num_instances == 2:
				instance_label.text = "Right" if current_instance_index == 0 else "Left"
			else:
				instance_label.text = "Instance %d" % current_instance_index
		else:
			current_instance_index = 0  # Reset for single-instance parts
		
		# Clear existing coordinate controls
		for child in coordinates_list.get_children():
			child.queue_free()
		
		await get_tree().process_frame
		create_coordinate_controls(current_part_name)
		
		# Update previews
		full_character_preview.queue_redraw()
		part_preview.queue_redraw()
		
		# Update script output
		update_script_output()

func create_coordinate_controls(part_name: String):
	var part_data = body_parts[part_name]
	
	if part_data.type == "polygon":
		# Add polygon controls header with +/- buttons
		create_polygon_header(part_name)
		
		for i in range(part_data.points.size()):
			create_point_control(part_name, i, part_data.points[i])
		
		# Add iris controls for eye
		if part_data.has("iris_center"):
			create_iris_controls(part_name, part_data)
			
	elif part_data.type == "circle":
		create_circle_controls(part_name, part_data)
	elif part_data.type == "rect":
		create_rect_controls(part_name, part_data)
	
	# Add attachment point controls if this part has attachment data
	if part_data.has("attachment_point"):
		create_attachment_controls(part_name, part_data)
	
	# Add child attachment point controls
	create_child_attachment_controls(part_name, part_data)

func create_polygon_header(part_name: String):
	var header_container = HBoxContainer.new()
	coordinates_list.add_child(header_container)
	
	var header_label = Label.new()
	header_label.text = "Polygon Points:"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(header_label)
	
	# Add point button
	var add_button = Button.new()
	add_button.text = "+"
	add_button.custom_minimum_size = Vector2(30, 30)
	add_button.tooltip_text = "Add new point"
	header_container.add_child(add_button)
	
	# Remove point button  
	var remove_button = Button.new()
	remove_button.text = "-"
	remove_button.custom_minimum_size = Vector2(30, 30)
	remove_button.tooltip_text = "Remove last point"
	header_container.add_child(remove_button)
	
	# Connect signals
	add_button.pressed.connect(_on_add_point.bind(part_name))
	remove_button.pressed.connect(_on_remove_point.bind(part_name))

func create_point_control(part_name: String, point_index: int, point: Vector2):
	var container = HBoxContainer.new()
	coordinates_list.add_child(container)
	
	# Point label
	var label = Label.new()
	label.text = "Point %d:" % (point_index + 1)
	label.custom_minimum_size.x = 60
	container.add_child(label)
	
	# X coordinate control
	var x_container = HBoxContainer.new()
	container.add_child(x_container)
	
	var x_decrease = Button.new()
	x_decrease.text = "◀"
	x_decrease.custom_minimum_size = Vector2(30, 30)
	x_container.add_child(x_decrease)
	
	var x_label = Label.new()
	x_label.text = "X: %.1f" % point.x
	x_label.custom_minimum_size.x = 50
	x_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_container.add_child(x_label)
	
	var x_increase = Button.new()
	x_increase.text = "▶"
	x_increase.custom_minimum_size = Vector2(30, 30)
	x_container.add_child(x_increase)
	
	# Y coordinate control
	var y_container = HBoxContainer.new()
	container.add_child(y_container)
	
	var y_decrease = Button.new()
	y_decrease.text = "◀"
	y_decrease.custom_minimum_size = Vector2(30, 30)
	y_container.add_child(y_decrease)
	
	var y_label = Label.new()
	y_label.text = "Y: %.1f" % point.y
	y_label.custom_minimum_size.x = 50
	y_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	y_container.add_child(y_label)
	
	var y_increase = Button.new()
	y_increase.text = "▶"
	y_increase.custom_minimum_size = Vector2(30, 30)
	y_container.add_child(y_increase)
	
	# Connect signals for real-time editing
	x_decrease.pressed.connect(_on_coordinate_changed.bind(part_name, "polygon", point_index, "x", -0.5))
	x_increase.pressed.connect(_on_coordinate_changed.bind(part_name, "polygon", point_index, "x", 0.5))
	y_decrease.pressed.connect(_on_coordinate_changed.bind(part_name, "polygon", point_index, "y", -0.5))
	y_increase.pressed.connect(_on_coordinate_changed.bind(part_name, "polygon", point_index, "y", 0.5))

func create_circle_controls(part_name: String, part_data: Dictionary):
	# Center X control
	var center_x_container = HBoxContainer.new()
	coordinates_list.add_child(center_x_container)
	
	var cx_label = Label.new()
	cx_label.text = "Center X:"
	cx_label.custom_minimum_size.x = 80
	center_x_container.add_child(cx_label)
	
	var cx_decrease = Button.new()
	cx_decrease.text = "◀"
	cx_decrease.custom_minimum_size = Vector2(30, 30)
	center_x_container.add_child(cx_decrease)
	
	var cx_value = Label.new()
	cx_value.text = "%.1f" % part_data.center.x
	cx_value.custom_minimum_size.x = 50
	cx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_x_container.add_child(cx_value)
	
	var cx_increase = Button.new()
	cx_increase.text = "▶"
	cx_increase.custom_minimum_size = Vector2(30, 30)
	center_x_container.add_child(cx_increase)
	
	# Center Y control
	var center_y_container = HBoxContainer.new()
	coordinates_list.add_child(center_y_container)
	
	var cy_label = Label.new()
	cy_label.text = "Center Y:"
	cy_label.custom_minimum_size.x = 80
	center_y_container.add_child(cy_label)
	
	var cy_decrease = Button.new()
	cy_decrease.text = "◀"
	cy_decrease.custom_minimum_size = Vector2(30, 30)
	center_y_container.add_child(cy_decrease)
	
	var cy_value = Label.new()
	cy_value.text = "%.1f" % part_data.center.y
	cy_value.custom_minimum_size.x = 50
	cy_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_y_container.add_child(cy_value)
	
	var cy_increase = Button.new()
	cy_increase.text = "▶"
	cy_increase.custom_minimum_size = Vector2(30, 30)
	center_y_container.add_child(cy_increase)
	
	# Radius control
	var radius_container = HBoxContainer.new()
	coordinates_list.add_child(radius_container)
	
	var r_label = Label.new()
	r_label.text = "Radius:"
	r_label.custom_minimum_size.x = 80
	radius_container.add_child(r_label)
	
	var r_decrease = Button.new()
	r_decrease.text = "◀"
	r_decrease.custom_minimum_size = Vector2(30, 30)
	radius_container.add_child(r_decrease)
	
	var r_value = Label.new()
	r_value.text = "%.1f" % part_data.radius
	r_value.custom_minimum_size.x = 50
	r_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radius_container.add_child(r_value)
	
	var r_increase = Button.new()
	r_increase.text = "▶"
	r_increase.custom_minimum_size = Vector2(30, 30)
	radius_container.add_child(r_increase)
	
	# Connect signals
	cx_decrease.pressed.connect(_on_coordinate_changed.bind(part_name, "circle", -1, "center_x", -0.5))
	cx_increase.pressed.connect(_on_coordinate_changed.bind(part_name, "circle", -1, "center_x", 0.5))
	cy_decrease.pressed.connect(_on_coordinate_changed.bind(part_name, "circle", -1, "center_y", -0.5))
	cy_increase.pressed.connect(_on_coordinate_changed.bind(part_name, "circle", -1, "center_y", 0.5))
	r_decrease.pressed.connect(_on_coordinate_changed.bind(part_name, "circle", -1, "radius", -0.1))
	r_increase.pressed.connect(_on_coordinate_changed.bind(part_name, "circle", -1, "radius", 0.1))

func create_rect_controls(part_name: String, part_data: Dictionary):
	# Similar to circle controls but for rectangle properties
	# Position X, Y and Size W, H
	pass  # Implement if needed

func create_iris_controls(part_name: String, part_data: Dictionary):
	# Add separator
	var separator = HSeparator.new()
	coordinates_list.add_child(separator)
	
	# Iris header
	var iris_header = Label.new()
	iris_header.text = "Iris (Eye):"
	iris_header.add_theme_color_override("font_color", Color(0.2, 0.6, 0.8))  # Blue color for iris
	coordinates_list.add_child(iris_header)
	
	# Iris Center X control
	var iris_x_container = HBoxContainer.new()
	coordinates_list.add_child(iris_x_container)
	
	var ix_label = Label.new()
	ix_label.text = "Iris X:"
	ix_label.custom_minimum_size.x = 80
	iris_x_container.add_child(ix_label)
	
	var ix_decrease = Button.new()
	ix_decrease.text = "◀"
	ix_decrease.custom_minimum_size = Vector2(30, 30)
	iris_x_container.add_child(ix_decrease)
	
	var ix_value = Label.new()
	ix_value.text = "%.1f" % part_data.iris_center.x
	ix_value.custom_minimum_size.x = 50
	ix_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iris_x_container.add_child(ix_value)
	
	var ix_increase = Button.new()
	ix_increase.text = "▶"
	ix_increase.custom_minimum_size = Vector2(30, 30)
	iris_x_container.add_child(ix_increase)
	
	# Iris Center Y control
	var iris_y_container = HBoxContainer.new()
	coordinates_list.add_child(iris_y_container)
	
	var iy_label = Label.new()
	iy_label.text = "Iris Y:"
	iy_label.custom_minimum_size.x = 80
	iris_y_container.add_child(iy_label)
	
	var iy_decrease = Button.new()
	iy_decrease.text = "◀"
	iy_decrease.custom_minimum_size = Vector2(30, 30)
	iris_y_container.add_child(iy_decrease)
	
	var iy_value = Label.new()
	iy_value.text = "%.1f" % part_data.iris_center.y
	iy_value.custom_minimum_size.x = 50
	iy_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iris_y_container.add_child(iy_value)
	
	var iy_increase = Button.new()
	iy_increase.text = "▶"
	iy_increase.custom_minimum_size = Vector2(30, 30)
	iris_y_container.add_child(iy_increase)
	
	# Iris Radius control
	var iris_r_container = HBoxContainer.new()
	coordinates_list.add_child(iris_r_container)
	
	var ir_label = Label.new()
	ir_label.text = "Iris Size:"
	ir_label.custom_minimum_size.x = 80
	iris_r_container.add_child(ir_label)
	
	var ir_decrease = Button.new()
	ir_decrease.text = "◀"
	ir_decrease.custom_minimum_size = Vector2(30, 30)
	iris_r_container.add_child(ir_decrease)
	
	var ir_value = Label.new()
	ir_value.text = "%.1f" % part_data.iris_radius
	ir_value.custom_minimum_size.x = 50
	ir_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iris_r_container.add_child(ir_value)
	
	var ir_increase = Button.new()
	ir_increase.text = "▶"
	ir_increase.custom_minimum_size = Vector2(30, 30)
	iris_r_container.add_child(ir_increase)
	
	# Connect signals for iris editing
	ix_decrease.pressed.connect(_on_iris_changed.bind(part_name, "center_x", -0.1))
	ix_increase.pressed.connect(_on_iris_changed.bind(part_name, "center_x", 0.1))
	iy_decrease.pressed.connect(_on_iris_changed.bind(part_name, "center_y", -0.1))
	iy_increase.pressed.connect(_on_iris_changed.bind(part_name, "center_y", 0.1))
	ir_decrease.pressed.connect(_on_iris_changed.bind(part_name, "radius", -0.1))
	ir_increase.pressed.connect(_on_iris_changed.bind(part_name, "radius", 0.1))

func _on_iris_changed(part_name: String, coord_type: String, delta: float):
	var part_data = get_current_instance_data(part_name)
	
	match coord_type:
		"center_x":
			part_data.iris_center.x += delta
		"center_y":
			part_data.iris_center.y += delta
		"radius":
			part_data.iris_radius = max(0.1, part_data.iris_radius + delta)
	
	# Update the display
	update_current_part_display()

func create_attachment_controls(part_name: String, part_data: Dictionary):
	# Add separator
	var separator = HSeparator.new()
	coordinates_list.add_child(separator)
	
	# Attachment header
	var attachment_header = Label.new()
	attachment_header.text = "Attachment Point:"
	attachment_header.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))  # Golden color for attachment
	coordinates_list.add_child(attachment_header)
	
	# Attachment target selector
	var attachment_container = HBoxContainer.new()
	coordinates_list.add_child(attachment_container)
	
	var attach_label = Label.new()
	attach_label.text = "Attaches to:"
	attach_label.custom_minimum_size.x = 80
	attachment_container.add_child(attach_label)
	
	var attach_prev = Button.new()
	attach_prev.text = "◀"
	attach_prev.custom_minimum_size = Vector2(30, 30)
	attachment_container.add_child(attach_prev)
	
	var attach_target_label = Label.new()
	attach_target_label.text = part_data.get("attachment_to", "none")
	attach_target_label.custom_minimum_size.x = 80
	attach_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attach_target_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	attachment_container.add_child(attach_target_label)
	
	var attach_next = Button.new()
	attach_next.text = "▶"
	attach_next.custom_minimum_size = Vector2(30, 30)
	attachment_container.add_child(attach_next)
	
	# Get valid attachment targets (exclude hair and eyes)
	var valid_targets = get_valid_attachment_targets()
	attach_prev.pressed.connect(_on_attachment_target_changed.bind(part_name, valid_targets, -1))
	attach_next.pressed.connect(_on_attachment_target_changed.bind(part_name, valid_targets, 1))
	
	# Attachment index selector (for shared limbs)
	create_attachment_index_selector(part_name, part_data)
	
	# Get attachment point (shared limbs use mirrored coordinates)
	var attachment_point = get_attachment_point_for_editing(part_name, part_data)
	
	# Attachment X control
	var attach_x_container = HBoxContainer.new()
	coordinates_list.add_child(attach_x_container)
	
	var ax_label = Label.new()
	ax_label.text = "Attach X:"
	ax_label.custom_minimum_size.x = 80
	attach_x_container.add_child(ax_label)
	
	var ax_decrease = Button.new()
	ax_decrease.text = "◀"
	ax_decrease.custom_minimum_size = Vector2(30, 30)
	attach_x_container.add_child(ax_decrease)
	
	var ax_value = Label.new()
	ax_value.text = "%.1f" % attachment_point.x
	ax_value.custom_minimum_size.x = 50
	ax_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attach_x_container.add_child(ax_value)
	
	var ax_increase = Button.new()
	ax_increase.text = "▶"
	ax_increase.custom_minimum_size = Vector2(30, 30)
	attach_x_container.add_child(ax_increase)
	
	# Attachment Y control
	var attach_y_container = HBoxContainer.new()
	coordinates_list.add_child(attach_y_container)
	
	var ay_label = Label.new()
	ay_label.text = "Attach Y:"
	ay_label.custom_minimum_size.x = 80
	attach_y_container.add_child(ay_label)
	
	var ay_decrease = Button.new()
	ay_decrease.text = "◀"
	ay_decrease.custom_minimum_size = Vector2(30, 30)
	attach_y_container.add_child(ay_decrease)
	
	var ay_value = Label.new()
	ay_value.text = "%.1f" % attachment_point.y
	ay_value.custom_minimum_size.x = 50
	ay_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attach_y_container.add_child(ay_value)
	
	var ay_increase = Button.new()
	ay_increase.text = "▶"
	ay_increase.custom_minimum_size = Vector2(30, 30)
	attach_y_container.add_child(ay_increase)
	
	# Connect signals for attachment point editing
	ax_decrease.pressed.connect(_on_attachment_changed.bind(part_name, "x", -0.5))
	ax_increase.pressed.connect(_on_attachment_changed.bind(part_name, "x", 0.5))
	ay_decrease.pressed.connect(_on_attachment_changed.bind(part_name, "y", -0.5))
	ay_increase.pressed.connect(_on_attachment_changed.bind(part_name, "y", 0.5))

func get_attachment_point_for_editing(part_name: String, part_data: Dictionary) -> Vector2:
	# For shared parts, we edit the right-side version and mirror applies automatically
	return part_data.attachment_point

func create_child_attachment_controls(part_name: String, part_data: Dictionary):
	# Ensure child_attachment_points exists
	if not part_data.has("child_attachment_points"):
		part_data["child_attachment_points"] = []
	
	var child_points = part_data.child_attachment_points
	
	# Add separator
	var separator = HSeparator.new()
	coordinates_list.add_child(separator)
	
	# Child attachment header with +/- buttons
	var header_container = HBoxContainer.new()
	coordinates_list.add_child(header_container)
	
	var header_label = Label.new()
	header_label.text = "Child Attachment Points:"
	header_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.8))  # Blue color for child attachments
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(header_label)
	
	# Add child attachment point button
	var add_child_button = Button.new()
	add_child_button.text = "+"
	add_child_button.custom_minimum_size = Vector2(30, 30)
	add_child_button.tooltip_text = "Add new child attachment point"
	header_container.add_child(add_child_button)
	
	# Remove child attachment point button  
	var remove_child_button = Button.new()
	remove_child_button.text = "-"
	remove_child_button.custom_minimum_size = Vector2(30, 30)
	remove_child_button.tooltip_text = "Remove last child attachment point"
	header_container.add_child(remove_child_button)
	
	# Connect signals
	add_child_button.pressed.connect(_on_add_child_attachment_point.bind(part_name))
	remove_child_button.pressed.connect(_on_remove_child_attachment_point.bind(part_name))
	
	# Create controls for each child attachment point
	for i in range(child_points.size()):
		create_child_attachment_point_control(part_name, i, child_points[i])

func create_child_attachment_point_control(part_name: String, index: int, point: Vector2):
	# Child attachment point number label
	var point_header = Label.new()
	point_header.text = "Child Point [%d]:" % index
	point_header.add_theme_color_override("font_color", Color(0.2, 0.6, 0.8))  # Blue color
	coordinates_list.add_child(point_header)
	
	# X coordinate control
	var x_container = HBoxContainer.new()
	coordinates_list.add_child(x_container)
	
	var x_label = Label.new()
	x_label.text = "X:"
	x_label.custom_minimum_size.x = 80
	x_container.add_child(x_label)
	
	var x_decrease = Button.new()
	x_decrease.text = "◀"
	x_decrease.custom_minimum_size = Vector2(30, 30)
	x_container.add_child(x_decrease)
	
	var x_value = Label.new()
	x_value.text = "%.1f" % point.x
	x_value.custom_minimum_size.x = 50
	x_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_container.add_child(x_value)
	
	var x_increase = Button.new()
	x_increase.text = "▶"
	x_increase.custom_minimum_size = Vector2(30, 30)
	x_container.add_child(x_increase)
	
	# Y coordinate control
	var y_container = HBoxContainer.new()
	coordinates_list.add_child(y_container)
	
	var y_label = Label.new()
	y_label.text = "Y:"
	y_label.custom_minimum_size.x = 80
	y_container.add_child(y_label)
	
	var y_decrease = Button.new()
	y_decrease.text = "◀"
	y_decrease.custom_minimum_size = Vector2(30, 30)
	y_container.add_child(y_decrease)
	
	var y_value = Label.new()
	y_value.text = "%.1f" % point.y
	y_value.custom_minimum_size.x = 50
	y_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	y_container.add_child(y_value)
	
	var y_increase = Button.new()
	y_increase.text = "▶"
	y_increase.custom_minimum_size = Vector2(30, 30)
	y_container.add_child(y_increase)
	
	# Connect signals
	x_decrease.pressed.connect(_on_child_attachment_changed.bind(part_name, index, "x", -0.5))
	x_increase.pressed.connect(_on_child_attachment_changed.bind(part_name, index, "x", 0.5))
	y_decrease.pressed.connect(_on_child_attachment_changed.bind(part_name, index, "y", -0.5))
	y_increase.pressed.connect(_on_child_attachment_changed.bind(part_name, index, "y", 0.5))

func create_attachment_index_selector(part_name: String, part_data: Dictionary):
	var attachment_to = part_data.get("attachment_to", "")
	if attachment_to == "":
		return  # No parent to attach to
	
	# Manual parent instance selector
	create_parent_instance_selector(part_name, part_data)
	
	# Manual child attachment index selector  
	create_child_attachment_index_selector(part_name, part_data)

func _on_attachment_changed(part_name: String, coord_type: String, delta: float):
	var part_data = get_current_instance_data(part_name)
	
	match coord_type:
		"x":
			part_data.attachment_point.x += delta
		"y":
			part_data.attachment_point.y += delta
	
	# For shared parts, the mirroring happens automatically in the drawing function
	# Update the display
	update_current_part_display()

func _on_coordinate_changed(part_name: String, part_type: String, point_index: int, coord_type: String, delta: float):
	var part_data = get_current_instance_data(part_name)
	
	match part_type:
		"polygon":
			match coord_type:
				"x":
					part_data.points[point_index].x += delta
				"y":
					part_data.points[point_index].y += delta
		"circle":
			match coord_type:
				"center_x":
					part_data.center.x += delta
				"center_y":
					part_data.center.y += delta
				"radius":
					part_data.radius = max(0.1, part_data.radius + delta)
	
	# Update the display
	update_current_part_display()

func _on_add_child_attachment_point(part_name: String):
	var part_data = get_current_instance_data(part_name)
	if not part_data.has("child_attachment_points"):
		part_data["child_attachment_points"] = []
	
	# Add new child attachment point at center of part
	var center = Vector2.ZERO
	if part_data.type == "polygon" and part_data.points.size() > 0:
		var sum = Vector2.ZERO
		for point in part_data.points:
			sum += point
		center = sum / part_data.points.size()
	elif part_data.type == "circle":
		center = part_data.center
	
	part_data.child_attachment_points.append(center)
	print("Added child attachment point %d to %s" % [part_data.child_attachment_points.size() - 1, part_name])
	update_current_part_display()

func _on_remove_child_attachment_point(part_name: String):
	var part_data = get_current_instance_data(part_name)
	if part_data.has("child_attachment_points") and part_data.child_attachment_points.size() > 0:
		var removed_index = part_data.child_attachment_points.size() - 1
		part_data.child_attachment_points.remove_at(removed_index)
		print("Removed child attachment point %d from %s" % [removed_index, part_name])
		update_current_part_display()
	else:
		print("No child attachment points to remove from %s" % part_name)

func _on_child_attachment_changed(part_name: String, index: int, coord_type: String, delta: float):
	var part_data = get_current_instance_data(part_name)
	if not part_data.has("child_attachment_points") or index >= part_data.child_attachment_points.size():
		return
	
	match coord_type:
		"x":
			part_data.child_attachment_points[index].x += delta
		"y":
			part_data.child_attachment_points[index].y += delta
	
	print("Changed child attachment point %d of %s: %s += %.1f" % [index, part_name, coord_type, delta])
	update_current_part_display()

func _on_attachment_index_changed(part_name: String, delta: int):
	var part_data = get_current_instance_data(part_name)
	var attachment_to = part_data.get("attachment_to", "")
	if attachment_to == "" or not body_parts.has(attachment_to):
		return
	
	# Parent data for child attachment points should come from base data
	# since child attachment points are typically defined at the part level
	var parent_data = body_parts[attachment_to]
	if not parent_data.has("child_attachment_points"):
		return
	
	var max_index = parent_data.child_attachment_points.size() - 1
	if max_index < 0:
		return
	
	if part_data.get("shared", false):
		# For shared parts, attachment index is automatic (instance index = attachment index)
		print("Shared parts use automatic sequential attachment indices")
		print("Instance %d automatically uses attachment index %d" % [current_instance_index, current_instance_index])
		return  # No manual adjustment needed
	else:
		# For non-shared parts, update single index
		var current_index = part_data.get("attachment_to_index", 0)
		current_index = clamp(current_index + delta, 0, max_index)
		part_data["attachment_to_index"] = current_index
		
		print("Changed attachment index for %s: %d" % [part_name, current_index])
	
	update_current_part_display()

func create_parent_instance_selector(part_name: String, part_data: Dictionary):
	var attachment_to = part_data.get("attachment_to", "")
	if attachment_to == "" or not body_parts.has(attachment_to):
		return
	
	var parent_base_data = body_parts[attachment_to]
	var num_parent_instances = parent_base_data.get("num_instances", 1)
	
	# Only show instance selector if parent has multiple instances
	if num_parent_instances <= 1:
		return
	
	var instance_container = HBoxContainer.new()
	coordinates_list.add_child(instance_container)
	
	var instance_label = Label.new()
	instance_label.text = "Parent Instance:"
	instance_label.custom_minimum_size.x = 80
	instance_container.add_child(instance_label)
	
	var instance_prev = Button.new()
	instance_prev.text = "◀"
	instance_prev.custom_minimum_size = Vector2(30, 30)
	instance_container.add_child(instance_prev)
	
	var current_parent_instance = part_data.get("attachment_to_instance", 0)
	var instance_value = Label.new()
	instance_value.text = "%d (%s)" % [current_parent_instance, "Right" if current_parent_instance == 0 else "Left"]
	instance_value.custom_minimum_size.x = 80
	instance_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instance_value.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	instance_container.add_child(instance_value)
	
	var instance_next = Button.new()
	instance_next.text = "▶"
	instance_next.custom_minimum_size = Vector2(30, 30)
	instance_container.add_child(instance_next)
	
	# Connect signals
	instance_prev.pressed.connect(_on_parent_instance_changed.bind(part_name, -1))
	instance_next.pressed.connect(_on_parent_instance_changed.bind(part_name, 1))

func create_child_attachment_index_selector(part_name: String, part_data: Dictionary):
	var attachment_to = part_data.get("attachment_to", "")
	if attachment_to == "" or not body_parts.has(attachment_to):
		return
	
	var child_container = HBoxContainer.new()
	coordinates_list.add_child(child_container)
	
	var child_label = Label.new()
	child_label.text = "Child Node:"
	child_label.custom_minimum_size.x = 80
	child_container.add_child(child_label)
	
	var child_prev = Button.new()
	child_prev.text = "◀"
	child_prev.custom_minimum_size = Vector2(30, 30)
	child_container.add_child(child_prev)
	
	var current_child_index = part_data.get("attachment_to_child_index", 0)
	var child_value = Label.new()
	child_value.text = str(current_child_index)
	child_value.custom_minimum_size.x = 50
	child_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	child_value.add_theme_color_override("font_color", Color(0.2, 0.6, 0.8))  # Blue to match child attachments
	child_container.add_child(child_value)
	
	var child_next = Button.new()
	child_next.text = "▶"
	child_next.custom_minimum_size = Vector2(30, 30)
	child_container.add_child(child_next)
	
	# Connect signals
	child_prev.pressed.connect(_on_child_attachment_index_changed.bind(part_name, -1))
	child_next.pressed.connect(_on_child_attachment_index_changed.bind(part_name, 1))

func _on_parent_instance_changed(part_name: String, delta: int):
	var base_part_data = body_parts[part_name]  # Use base data for attachment properties
	var attachment_to = base_part_data.get("attachment_to", "")
	if attachment_to == "" or not body_parts.has(attachment_to):
		return
	
	var parent_base_data = body_parts[attachment_to]
	var num_parent_instances = parent_base_data.get("num_instances", 1)
	
	var current_instance = base_part_data.get("attachment_to_instance", 0)
	var new_instance = (current_instance + delta) % num_parent_instances
	if new_instance < 0:
		new_instance = num_parent_instances - 1
	
	base_part_data["attachment_to_instance"] = new_instance
	print("Changed %s parent instance to %d" % [part_name, new_instance])
	
	update_current_part_display()
	full_character_preview.queue_redraw()

func _on_child_attachment_index_changed(part_name: String, delta: int):
	var base_part_data = body_parts[part_name]  # Use base data for attachment properties
	var attachment_to = base_part_data.get("attachment_to", "")
	if attachment_to == "" or not body_parts.has(attachment_to):
		return
	
	# Get the max child attachment index from the specified parent instance
	var parent_instance_index = base_part_data.get("attachment_to_instance", 0)
	var parent_base_data = body_parts[attachment_to]
	var max_child_index = 0
	
	if parent_base_data.get("shared", false) and parent_base_data.get("num_instances", 1) > 1:
		var parent_instance_data = get_instance_data(attachment_to, parent_instance_index)
		if parent_instance_data.has("child_attachment_points"):
			max_child_index = parent_instance_data.child_attachment_points.size() - 1
	else:
		if parent_base_data.has("child_attachment_points"):
			max_child_index = parent_base_data.child_attachment_points.size() - 1
	
	var current_index = base_part_data.get("attachment_to_child_index", 0)
	var new_index = clamp(current_index + delta, 0, max_child_index)
	
	base_part_data["attachment_to_child_index"] = new_index
	print("Changed %s child attachment index to %d" % [part_name, new_index])
	
	update_current_part_display()
	full_character_preview.queue_redraw()

func get_sky_color_for_time(time: float) -> Color:
	# Normalize time to 0-1 range
	var normalized_time = time / day_length
	
	# Define key colors from the day-night cycle system
	var midnight = Color(0.12, 0.10, 0.18)  # Dark grey-purple
	var dawn_dusk = Color(0.8, 0.45, 0.25)  # Terracotta (dawn/dusk)
	var noon = Color(0.95, 0.85, 0.75)     # Whitewashed version
	
	# Calculate time of day
	# 0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk, 1.0 = midnight
	var result_color: Color
	
	if normalized_time < 0.25:
		# Midnight to dawn (0.0 to 0.25)
		var t = normalized_time / 0.25
		result_color = midnight.lerp(dawn_dusk, t)
	elif normalized_time < 0.5:
		# Dawn to noon (0.25 to 0.5)
		var t = (normalized_time - 0.25) / 0.25
		result_color = dawn_dusk.lerp(noon, t)
	elif normalized_time < 0.75:
		# Noon to dusk (0.5 to 0.75)
		var t = (normalized_time - 0.5) / 0.25
		result_color = noon.lerp(dawn_dusk, t)
	else:
		# Dusk to midnight (0.75 to 1.0)
		var t = (normalized_time - 0.75) / 0.25
		result_color = dawn_dusk.lerp(midnight, t)
	
	return result_color

func _draw_full_character():
	var center = full_character_preview.size / 2
	
	# Draw sky background first
	var sky_color = get_sky_color_for_time(current_time)
	full_character_preview.draw_rect(Rect2(Vector2.ZERO, full_character_preview.size), sky_color)
	
	# Apply zoom by scaling all drawing operations
	var zoom_offset = center - (center * preview_zoom)
	
	# Calculate zoomed center position
	var zoomed_center = center * preview_zoom + zoom_offset
	
	# Draw terrain sample first (behind character)
	draw_terrain_sample(zoomed_center, preview_zoom)
	
	# Draw all body parts
	for part_name in part_names:
		var base_part_data = body_parts[part_name]
		var is_current = (part_name == part_names[current_part_index])
		var color = base_part_data.color
		
		# Highlight current part
		if is_current:
			color = color.lerp(highlight_color, 0.3)
		
		# If this is a shared part, draw all instances
		if base_part_data.get("shared", false):
			var num_instances = base_part_data.get("num_instances", 1)
			
			# Draw all instances of this shared part
			for i in range(num_instances):
				# Get instance data for this specific instance
				var instance_data = get_instance_data(part_name, i)
				
				# Determine if this instance should be drawn as left or right (mirrored)
				var is_left = (i % 2 == 1)  # Odd instances are left/mirrored
				
				# Draw this instance
				draw_body_part_mirrored_zoomed_with_name(part_name, instance_data, zoomed_center, color, is_left, preview_zoom)
				
				# Draw attachment points for this instance
				if instance_data.has("attachment_point"):
					draw_attachment_point_on_preview_with_name(part_name, instance_data, zoomed_center, is_left, preview_zoom)
				# Draw child attachment points for this instance
				if instance_data.has("child_attachment_points"):
					draw_child_attachment_points_on_preview_with_name(part_name, instance_data, zoomed_center, is_left, preview_zoom)
		else:
			# Draw single part normally using get_current_instance_data for consistency
			var part_data = get_current_instance_data(part_name)
			draw_body_part_zoomed(part_data, zoomed_center, color, preview_zoom)
			# Draw attachment point for single parts (red - parent attachment)
			if part_data.has("attachment_point"):
				draw_attachment_point_on_preview(part_data, zoomed_center, false, preview_zoom)
			# Draw child attachment points for single parts (blue - child attachments)
			if part_data.has("child_attachment_points"):
				draw_child_attachment_points_on_preview(part_data, zoomed_center, false, preview_zoom)

func _draw_current_part():
	if part_names.size() == 0:
		return
		
	var center = part_preview.size / 2
	var current_part_name = part_names[current_part_index]
	var part_data = get_current_instance_data(current_part_name)
	
	# Calculate the part's center point to offset properly
	var part_center = Vector2.ZERO
	
	match part_data.type:
		"polygon":
			# Calculate the center of the polygon
			if part_data.points.size() > 0:
				var sum = Vector2.ZERO
				for point in part_data.points:
					sum += point
				part_center = sum / part_data.points.size()
		"circle":
			part_center = part_data.center
		"rect":
			part_center = part_data.rect.position + part_data.rect.size / 2
	
	# Offset to center the part in the preview
	var centered_offset = center - part_center * character_scale * 4.0
	
	# Draw the current part larger and centered
	draw_body_part(part_data, centered_offset, highlight_color, 4.0)
	
	# Draw interactive point circles for polygons
	if part_data.type == "polygon":
		draw_interactive_points(part_data, centered_offset, 4.0)
	
	# Draw attachment point if it exists (red - where this part attaches to parent)
	if part_data.has("attachment_point"):
		draw_attachment_point(part_data, centered_offset, 4.0)
	
	# Draw child attachment points (blue - where children attach to this part)
	if part_data.has("child_attachment_points"):
		draw_child_attachment_points(part_data, centered_offset, 4.0)
	
	# Draw iris for eye
	if part_data.has("iris_center"):
		var iris_screen_pos = centered_offset + part_data.iris_center * character_scale * 4.0
		var iris_radius = part_data.iris_radius * character_scale * 4.0
		part_preview.draw_circle(iris_screen_pos, iris_radius, part_data.iris_color)

func draw_interactive_points(part_data: Dictionary, offset: Vector2, part_scale: float):
	if part_data.points.size() == 0:
		return
	
	for i in range(part_data.points.size()):
		var point = part_data.points[i]
		var screen_pos = offset + point * character_scale * part_scale
		
		# Draw point circle with different colors for different states
		var point_color = Color.CYAN
		if is_dragging and dragged_point_index == i:
			point_color = Color.YELLOW  # Highlight dragged point
		elif i == 0:
			point_color = Color.GREEN   # First point (start of polygon)
		else:
			point_color = Color.CYAN    # Regular points
		
		# Draw point circle
		part_preview.draw_circle(screen_pos, point_radius, point_color)
		part_preview.draw_circle(screen_pos, point_radius - 2, Color.WHITE)
		
		# Draw point index number
		var font = ThemeDB.fallback_font
		var text = str(i + 1)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		part_preview.draw_string(font, screen_pos - text_size / 2, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.BLACK)

func draw_attachment_point(part_data: Dictionary, offset: Vector2, part_scale: float):
	if not part_data.has("attachment_point"):
		return
		
	var attachment_pos = part_data.attachment_point
	var screen_pos = offset + attachment_pos * character_scale * part_scale
	
	# Draw attachment point as a distinctive circle
	var attachment_color = Color.RED
	if is_dragging_attachment:
		attachment_color = Color.ORANGE  # Highlight when dragging
	
	# Draw attachment point circle
	part_preview.draw_circle(screen_pos, attachment_point_radius + 2, attachment_color)
	part_preview.draw_circle(screen_pos, attachment_point_radius, Color.WHITE)
	
	# Draw "A" for attachment
	var font = ThemeDB.fallback_font
	var text = "A"
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	part_preview.draw_string(font, screen_pos - text_size / 2, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.BLACK)

func draw_child_attachment_points(part_data: Dictionary, offset: Vector2, part_scale: float):
	# For instance data, child attachment points are directly in part_data
	# For base data, we need to check if this is a shared part
	if not part_data.has("child_attachment_points"):
		return
	
	var child_points = part_data.child_attachment_points
	
	# For all parts (shared or not), just draw the child attachment points that exist in this part_data
	# Since we now store child attachment points in instance data for shared parts,
	# this will automatically show only the relevant points
	for i in range(child_points.size()):
		var point = child_points[i]
		var screen_pos = offset + point * character_scale * part_scale
		
		# Draw child attachment point as blue circle
		var child_color = Color(0.2, 0.6, 0.8)  # Blue color
		if is_dragging_child_attachment and dragged_child_attachment_index == i:
			child_color = Color(0.4, 0.8, 1.0)  # Lighter blue when dragging
		
		part_preview.draw_circle(screen_pos, attachment_point_radius + 2, child_color)
		part_preview.draw_circle(screen_pos, attachment_point_radius, Color.WHITE)
		
		# Draw number for the child attachment point
		var font = ThemeDB.fallback_font
		var text = str(i)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
		part_preview.draw_string(font, screen_pos - text_size / 2, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.BLACK)

func draw_body_part_mirrored(part_data: Dictionary, offset: Vector2, color: Color, is_left: bool):
	# Both sides should look identical - facing the same direction as the character
	# But positioned symmetrically based on mirrored attachment points
	var limb_x_flip = 1.0  # Always use same orientation for limbs
	var attachment_x_flip = 1.0  # For attachment point positioning
	
	if is_left:
		# Left side: same limb orientation but mirrored attachment positioning
		attachment_x_flip = -1.0
	
	match part_data.type:
		"polygon":
			# Validate polygon has enough points
			if part_data.points.size() < 3:
				print("Warning: Mirrored polygon has less than 3 points (%d), skipping draw" % part_data.points.size())
				return
				
			var points = PackedVector2Array()
			# Calculate position offset based on mirrored attachment point
			var attachment_offset = Vector2.ZERO
			if part_data.has("attachment_point"):
				# Use mirrored attachment point for positioning, but keep limb orientation same
				var mirrored_attachment = Vector2(part_data.attachment_point.x * attachment_x_flip, part_data.attachment_point.y)
				attachment_offset = mirrored_attachment - part_data.attachment_point
			
			for point in part_data.points:
				# Same orientation for both sides, positioned at mirrored attachment point
				var positioned_point = Vector2(point.x * limb_x_flip + attachment_offset.x, point.y + attachment_offset.y)
				var final_point = offset + positioned_point * character_scale
				# Validate point is finite
				if is_finite(final_point.x) and is_finite(final_point.y):
					points.append(final_point)
				else:
					print("Warning: Invalid mirrored point: %s" % final_point)
			
			if points.size() >= 3:
				full_character_preview.draw_colored_polygon(points, color)
			else:
				print("Warning: Not enough valid mirrored points: %d" % points.size())
		"circle":
			# Calculate position offset based on mirrored attachment point
			var attachment_offset = Vector2.ZERO
			if part_data.has("attachment_point"):
				var mirrored_attachment = Vector2(part_data.attachment_point.x * attachment_x_flip, part_data.attachment_point.y)
				attachment_offset = mirrored_attachment - part_data.attachment_point
			
			# Same orientation for both sides, positioned at mirrored attachment point
			var positioned_center = Vector2(part_data.center.x * limb_x_flip + attachment_offset.x, part_data.center.y + attachment_offset.y)
			var center = offset + positioned_center * character_scale
			var radius = part_data.radius * character_scale
			full_character_preview.draw_circle(center, radius, color)
			
			# Draw pupil if it's an eye
			if part_data.has("pupil_color"):
				var pupil_color = part_data.pupil_color
				var pupil_radius = radius * 0.6
				full_character_preview.draw_circle(center, pupil_radius, pupil_color)
		"rect":
			# Calculate position offset based on mirrored attachment point
			var attachment_offset = Vector2.ZERO
			if part_data.has("attachment_point"):
				var mirrored_attachment = Vector2(part_data.attachment_point.x * attachment_x_flip, part_data.attachment_point.y)
				attachment_offset = mirrored_attachment - part_data.attachment_point
			
			# Same orientation for both sides, positioned at mirrored attachment point
			var positioned_pos = Vector2(part_data.rect.position.x * limb_x_flip + attachment_offset.x, part_data.rect.position.y + attachment_offset.y)
			var rect = Rect2(offset + positioned_pos * character_scale, part_data.rect.size * character_scale)
			full_character_preview.draw_rect(rect, color)
	
	# Draw attachment point indicator
	if part_data.has("attachment_point"):
		# Attachment point should be mirrored for proper positioning
		var attach_pos = Vector2(part_data.attachment_point.x * attachment_x_flip, part_data.attachment_point.y)
		var attach_screen_pos = offset + attach_pos * character_scale
		# Draw a small circle to indicate attachment point
		full_character_preview.draw_circle(attach_screen_pos, 3, Color.RED)
		full_character_preview.draw_circle(attach_screen_pos, 2, Color.WHITE)

func draw_body_part(part_data: Dictionary, offset: Vector2, color: Color, part_scale: float = 1.0):
	match part_data.type:
		"polygon":
			# Validate polygon has enough points
			if part_data.points.size() < 3:
				print("Warning: Polygon has less than 3 points (%d), skipping draw" % part_data.points.size())
				return
				
			var points = PackedVector2Array()
			for point in part_data.points:
				var final_point = offset + point * character_scale * part_scale
				# Validate point is finite
				if is_finite(final_point.x) and is_finite(final_point.y):
					points.append(final_point)
				else:
					print("Warning: Invalid point in polygon: %s" % final_point)
			
			# Additional validation - check for duplicate or invalid points
			if points.size() >= 3:
				if part_scale == 1.0:
					full_character_preview.draw_colored_polygon(points, color)
				else:
					part_preview.draw_colored_polygon(points, color)
			else:
				print("Warning: Not enough valid points: %d" % points.size())
			
			# Draw iris if this is an eye
			if part_data.has("iris_center"):
				var iris_center = offset + part_data.iris_center * character_scale * part_scale
				var iris_radius = part_data.iris_radius * character_scale * part_scale
				if part_scale == 1.0:
					full_character_preview.draw_circle(iris_center, iris_radius, part_data.iris_color)
				else:
					part_preview.draw_circle(iris_center, iris_radius, part_data.iris_color)
		"circle":
			var center = offset + part_data.center * character_scale * part_scale
			var radius = part_data.radius * character_scale * part_scale
			full_character_preview.draw_circle(center, radius, color) if part_scale == 1.0 else part_preview.draw_circle(center, radius, color)
			
			# Draw pupil if it's an eye
			if part_data.has("pupil_color"):
				var pupil_color = part_data.pupil_color
				var pupil_radius = radius * 0.6
				full_character_preview.draw_circle(center, pupil_radius, pupil_color) if part_scale == 1.0 else part_preview.draw_circle(center, pupil_radius, pupil_color)
		"rect":
			var rect = Rect2(offset + part_data.rect.position * character_scale * part_scale, part_data.rect.size * character_scale * part_scale)
			full_character_preview.draw_rect(rect, color) if part_scale == 1.0 else part_preview.draw_rect(rect, color)
	
	# Draw attachment point indicator for non-shared parts or when showing individual part
	if part_data.has("attachment_point") and (part_scale > 1.0 or not part_data.get("shared", false)):
		var attach_screen_pos = offset + part_data.attachment_point * character_scale * part_scale
		var radius = 3 * part_scale
		if part_scale == 1.0:
			full_character_preview.draw_circle(attach_screen_pos, radius, Color.RED)
			full_character_preview.draw_circle(attach_screen_pos, radius - 1, Color.WHITE)
		else:
			part_preview.draw_circle(attach_screen_pos, radius, Color.RED)
			part_preview.draw_circle(attach_screen_pos, radius - 1, Color.WHITE)

func update_script_output():
	var current_part_name = part_names[current_part_index]
	var part_data = get_current_instance_data(current_part_name)
	
	var script_text = "# %s\n" % current_part_name.capitalize()
	
	# Add attachment point info as comment
	if part_data.has("attachment_point"):
		script_text += "# Attachment: Vector2(%.1f, %.1f) -> %s\n" % [part_data.attachment_point.x, part_data.attachment_point.y, part_data.get("attachment_to", "none")]
	
	match part_data.type:
		"polygon":
			script_text += "var %s_points = PackedVector2Array([\n" % current_part_name
			for point in part_data.points:
				script_text += "\tVector2(%.1f * scale, %.1f * scale),\n" % [point.x, point.y]
			script_text += "])\n"
			script_text += "draw_colored_polygon(%s_points, pottery_dark)\n" % current_part_name
			
			# Add iris code for eye
			if part_data.has("iris_center"):
				script_text += "\n# Iris\n"
				script_text += "draw_circle(Vector2(%.1f * scale, %.1f * scale), %.1f * scale, pottery_dark)\n" % [part_data.iris_center.x, part_data.iris_center.y, part_data.iris_radius]
				
		"circle":
			script_text += "draw_circle(Vector2(%.1f * scale, %.1f * scale), %.1f * scale, pottery_dark)\n" % [part_data.center.x, part_data.center.y, part_data.radius]
		"rect":
			script_text += "draw_rect(Rect2(%.1f * scale, %.1f * scale, %.1f * scale, %.1f * scale), pottery_dark)\n" % [part_data.rect.position.x, part_data.rect.position.y, part_data.rect.size.x, part_data.rect.size.y]
	
	script_output.text = script_text

func _on_prev_part_pressed():
	current_part_index = (current_part_index - 1) % part_names.size()
	update_current_part_display()

func _on_next_part_pressed():
	current_part_index = (current_part_index + 1) % part_names.size()
	update_current_part_display()

func _on_part_preview_input(event: InputEvent):
	if part_names.size() == 0:
		return
		
	var current_part_name = part_names[current_part_index]
	var part_data = get_current_instance_data(current_part_name)
	
	# Only handle polygon editing
	if part_data.type != "polygon":
		return
	
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Check for double-click (add point)
				if mouse_event.double_click:
					_handle_add_point_at_mouse(mouse_event.position, part_data)
				else:
					# Start dragging
					_handle_mouse_press(mouse_event.position, part_data)
			else:
				# Stop dragging
				_handle_mouse_release()
		
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			# Remove point
			_handle_remove_point_at_mouse(mouse_event.position, part_data)
	
	elif event is InputEventMouseMotion and (is_dragging or is_dragging_attachment or is_dragging_child_attachment or is_dragging_polygon):
		# Handle dragging
		_handle_mouse_drag(event.position, part_data)

func _handle_mouse_press(mouse_pos: Vector2, part_data: Dictionary):
	# Check for attachment point click first
	if part_data.has("attachment_point") and is_mouse_on_attachment_point(mouse_pos, part_data):
		is_dragging_attachment = true
		last_mouse_pos = mouse_pos
		part_preview.queue_redraw()
		return
	
	# Check for child attachment point click
	if part_data.has("child_attachment_points"):
		var child_index = get_child_attachment_at_mouse(mouse_pos, part_data)
		if child_index >= 0:
			is_dragging_child_attachment = true
			dragged_child_attachment_index = child_index
			last_mouse_pos = mouse_pos
			part_preview.queue_redraw()
			return
	
	# Check for individual point dragging
	var point_index = get_point_at_mouse(mouse_pos, part_data)
	if point_index >= 0:
		is_dragging = true
		dragged_point_index = point_index
		last_mouse_pos = mouse_pos
		part_preview.queue_redraw()
		return
	
	# Check if clicking inside polygon for whole polygon dragging
	if part_data.type == "polygon" and is_mouse_inside_polygon(mouse_pos, part_data):
		is_dragging_polygon = true
		last_mouse_pos = mouse_pos
		part_preview.queue_redraw()

func _handle_mouse_release():
	if is_dragging or is_dragging_attachment or is_dragging_child_attachment or is_dragging_polygon:
		is_dragging = false
		is_dragging_attachment = false
		is_dragging_child_attachment = false
		is_dragging_polygon = false
		dragged_point_index = -1
		dragged_child_attachment_index = -1
		part_preview.queue_redraw()
		full_character_preview.queue_redraw()
		# Update coordinate controls to reflect changes
		update_current_part_display()

func _handle_mouse_drag(mouse_pos: Vector2, part_data: Dictionary):
	var mouse_delta = mouse_pos - last_mouse_pos
	var coord_delta = mouse_delta / (character_scale * 4.0)
	
	if is_dragging and dragged_point_index >= 0:
		# Individual point dragging
		part_data.points[dragged_point_index] += coord_delta
		last_mouse_pos = mouse_pos
		part_preview.queue_redraw()
		full_character_preview.queue_redraw()
	
	elif is_dragging_attachment and part_data.has("attachment_point"):
		# Attachment point dragging
		part_data.attachment_point += coord_delta
		last_mouse_pos = mouse_pos
		part_preview.queue_redraw()
		full_character_preview.queue_redraw()
	
	elif is_dragging_child_attachment and dragged_child_attachment_index >= 0:
		# Child attachment point dragging
		if part_data.has("child_attachment_points") and dragged_child_attachment_index < part_data.child_attachment_points.size():
			part_data.child_attachment_points[dragged_child_attachment_index] += coord_delta
			last_mouse_pos = mouse_pos
			part_preview.queue_redraw()
			full_character_preview.queue_redraw()
	
	elif is_dragging_polygon:
		# Whole polygon dragging - move all points
		for i in range(part_data.points.size()):
			part_data.points[i] += coord_delta
		# Also move attachment point if it exists
		if part_data.has("attachment_point"):
			part_data.attachment_point += coord_delta
		# Also move child attachment points if they exist
		if part_data.has("child_attachment_points"):
			# For left instances of shared parts, mirror the X movement to maintain symmetry
			var current_part_name = part_names[current_part_index] if part_names.size() > 0 else ""
			var base_part_data = body_parts.get(current_part_name, {})
			var is_shared = base_part_data.get("shared", false)
			var is_left_instance = is_shared and current_instance_index == 1
			
			for i in range(part_data.child_attachment_points.size()):
				var adjusted_delta = coord_delta
				if is_left_instance:
					adjusted_delta.x = -coord_delta.x  # Mirror X movement for left instances
				part_data.child_attachment_points[i] += adjusted_delta
		last_mouse_pos = mouse_pos
		part_preview.queue_redraw()
		full_character_preview.queue_redraw()

func _handle_add_point_at_mouse(mouse_pos: Vector2, part_data: Dictionary):
	# Find the closest edge and insert point there
	var closest_edge_index = get_closest_edge_at_mouse(mouse_pos, part_data)
	if closest_edge_index >= 0:
		# Convert mouse position to coordinate
		var center = part_preview.size / 2
		var part_center = get_part_center(part_data)
		var centered_offset = center - part_center * character_scale * 4.0
		var coord_pos = (mouse_pos - centered_offset) / (character_scale * 4.0)
		
		# Insert new point after the closest edge
		part_data.points.insert(closest_edge_index + 1, coord_pos)
		update_current_part_display()

func _handle_remove_point_at_mouse(mouse_pos: Vector2, part_data: Dictionary):
	var point_index = get_point_at_mouse(mouse_pos, part_data)
	if point_index >= 0 and part_data.points.size() > 3:
		part_data.points.remove_at(point_index)
		update_current_part_display()

func get_point_at_mouse(mouse_pos: Vector2, part_data: Dictionary) -> int:
	var center = part_preview.size / 2
	var part_center = get_part_center(part_data)
	var centered_offset = center - part_center * character_scale * 4.0
	
	for i in range(part_data.points.size()):
		var point = part_data.points[i]
		var screen_pos = centered_offset + point * character_scale * 4.0
		var distance = mouse_pos.distance_to(screen_pos)
		
		if distance <= point_radius:
			return i
	
	return -1

func is_mouse_on_attachment_point(mouse_pos: Vector2, part_data: Dictionary) -> bool:
	if not part_data.has("attachment_point"):
		return false
		
	var center = part_preview.size / 2
	var part_center = get_part_center(part_data)
	var centered_offset = center - part_center * character_scale * 4.0
	var attachment_screen_pos = centered_offset + part_data.attachment_point * character_scale * 4.0
	var distance = mouse_pos.distance_to(attachment_screen_pos)
	
	return distance <= attachment_point_radius

func get_child_attachment_at_mouse(mouse_pos: Vector2, part_data: Dictionary) -> int:
	if not part_data.has("child_attachment_points"):
		return -1
	
	var center = part_preview.size / 2
	var part_center = get_part_center(part_data)
	var centered_offset = center - part_center * character_scale * 4.0
	
	var child_points = part_data.child_attachment_points
	
	# Since child attachment points are now stored in instance data for shared parts,
	# we can just check all points in the current part_data
	for i in range(child_points.size()):
		var child_screen_pos = centered_offset + child_points[i] * character_scale * 4.0
		var distance = mouse_pos.distance_to(child_screen_pos)
		
		if distance <= attachment_point_radius:
			return i
	
	return -1

func is_mouse_inside_polygon(mouse_pos: Vector2, part_data: Dictionary) -> bool:
	if part_data.type != "polygon" or part_data.points.size() < 3:
		return false
		
	var center = part_preview.size / 2
	var part_center = get_part_center(part_data)
	var centered_offset = center - part_center * character_scale * 4.0
	
	# Convert polygon points to screen coordinates
	var screen_points = PackedVector2Array()
	for point in part_data.points:
		screen_points.append(centered_offset + point * character_scale * 4.0)
	
	# Point-in-polygon test using ray casting
	var intersections = 0
	var j = screen_points.size() - 1
	
	for i in range(screen_points.size()):
		var p1 = screen_points[j]
		var p2 = screen_points[i]
		
		if ((p1.y > mouse_pos.y) != (p2.y > mouse_pos.y)) and \
		   (mouse_pos.x < (p2.x - p1.x) * (mouse_pos.y - p1.y) / (p2.y - p1.y) + p1.x):
			intersections += 1
		j = i
	
	return intersections % 2 == 1

func get_closest_edge_at_mouse(mouse_pos: Vector2, part_data: Dictionary) -> int:
	var center = part_preview.size / 2
	var part_center = get_part_center(part_data)
	var centered_offset = center - part_center * character_scale * 4.0
	
	var closest_distance = INF
	var closest_edge = -1
	
	for i in range(part_data.points.size()):
		var point1 = part_data.points[i]
		var point2 = part_data.points[(i + 1) % part_data.points.size()]
		
		var screen_pos1 = centered_offset + point1 * character_scale * 4.0
		var screen_pos2 = centered_offset + point2 * character_scale * 4.0
		
		# Calculate distance from mouse to line segment
		var distance = point_to_line_distance(mouse_pos, screen_pos1, screen_pos2)
		
		if distance < closest_distance and distance <= point_radius * 2:
			closest_distance = distance
			closest_edge = i
	
	return closest_edge

func get_part_center(part_data: Dictionary) -> Vector2:
	match part_data.type:
		"polygon":
			if part_data.points.size() > 0:
				var sum = Vector2.ZERO
				for point in part_data.points:
					sum += point
				return sum / part_data.points.size()
		"circle":
			return part_data.center
		"rect":
			return part_data.rect.position + part_data.rect.size / 2
	return Vector2.ZERO

func point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_len = line_vec.length()
	
	if line_len == 0:
		return point.distance_to(line_start)
	
	var t = max(0, min(1, point_vec.dot(line_vec) / (line_len * line_len)))
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

func _on_add_point(part_name: String):
	var part_data = get_current_instance_data(part_name)
	if part_data.type == "polygon":
		# Add a new point between the last and first point for better polygon continuity
		if part_data.points.size() >= 3:
			var last_point = part_data.points[-1]
			var first_point = part_data.points[0]
			# Insert new point as average of last and first point, slightly offset
			var new_point = (last_point + first_point) / 2.0 + Vector2(0.5, 0.5)
			part_data.points.append(new_point)
		else:
			# For small polygons, just add a simple offset
			var last_point = part_data.points[-1] if part_data.points.size() > 0 else Vector2.ZERO
			var new_point = last_point + Vector2(2, 2)
			part_data.points.append(new_point)
		
		print("Added point to %s. Total points: %d" % [part_name, part_data.points.size()])
		
		# Refresh the display
		update_current_part_display()

func _on_remove_point(part_name: String):
	var part_data = get_current_instance_data(part_name)
	if part_data.type == "polygon" and part_data.points.size() > 3:
		# Remove the last point (but keep at least 3 points for a valid polygon)
		part_data.points.remove_at(part_data.points.size() - 1)
		
		print("Removed point from %s. Total points: %d" % [part_name, part_data.points.size()])
		
		# Refresh the display
		update_current_part_display()
	else:
		print("Cannot remove point from %s. Minimum 3 points required. Current: %d" % [part_name, part_data.points.size()])

func get_valid_attachment_targets() -> Array:
	# Return list of valid body parts to attach to (exclude hair and eyes)
	var valid_parts = []
	for part_name in part_names:
		if part_name != "hair" and part_name != "eye":
			valid_parts.append(part_name)
	valid_parts.append("none")  # Allow no attachment
	return valid_parts

func _on_attachment_target_changed(part_name: String, valid_targets: Array, direction: int):
	var part_data = body_parts[part_name]
	var current_target = part_data.get("attachment_to", "none")
	
	# Find current index
	var current_index = valid_targets.find(current_target)
	if current_index == -1:
		current_index = valid_targets.size() - 1  # Default to "none"
	
	# Calculate new index
	var new_index = (current_index + direction) % valid_targets.size()
	if new_index < 0:
		new_index = valid_targets.size() - 1
	
	# Update attachment target
	var new_target = valid_targets[new_index]
	if new_target == "none":
		if part_data.has("attachment_to"):
			part_data.erase("attachment_to")
	else:
		part_data["attachment_to"] = new_target
	
	# Refresh display
	update_current_part_display()

func draw_body_part_zoomed(part_data: Dictionary, offset: Vector2, color: Color, zoom: float = 1.0):
	# Similar to draw_body_part but with zoom scaling
	match part_data.type:
		"polygon":
			if part_data.points.size() < 3:
				return
			var points = PackedVector2Array()
			for point in part_data.points:
				points.append(offset + point * character_scale * zoom)
			full_character_preview.draw_colored_polygon(points, color)
		"circle":
			var center = offset + part_data.center * character_scale * zoom
			var radius = part_data.radius * character_scale * zoom
			full_character_preview.draw_circle(center, radius, color)
		"rect":
			var rect = Rect2(offset + part_data.rect.position * character_scale * zoom, part_data.rect.size * character_scale * zoom)
			full_character_preview.draw_rect(rect, color)

func calculate_numbered_attachment_offset(part_name: String, is_left: bool, part_instance_data: Dictionary = {}) -> Vector2:
	# Manual attachment system using explicit parent part, instance, and child index
	if not body_parts.has(part_name):
		return Vector2.ZERO
		
	# Use provided instance data if available, otherwise get current instance data
	var part_data = part_instance_data if not part_instance_data.is_empty() else get_current_instance_data(part_name)
	
	# Get explicit attachment properties
	var parent_name = part_data.get("attachment_to", "")
	var parent_instance_index = part_data.get("attachment_to_instance", 0)
	var child_attachment_index = part_data.get("attachment_to_child_index", 0)
	
	if parent_name == "" or not body_parts.has(parent_name):
		return Vector2.ZERO  # No parent or invalid parent
	
	# Get the specific parent instance data
	var parent_base_data = body_parts[parent_name]
	var parent_child_points = []
	
	# If parent is shared, get child attachment points from the specific parent instance
	if parent_base_data.get("shared", false) and parent_base_data.get("num_instances", 1) > 1:
		var parent_instance_data = get_instance_data(parent_name, parent_instance_index)
		
		if parent_instance_data.has("child_attachment_points"):
			parent_child_points = parent_instance_data.child_attachment_points
		else:
			return Vector2.ZERO  # Parent instance has no child attachment points
	else:
		# Non-shared parent, check base data
		if parent_base_data.has("child_attachment_points"):
			parent_child_points = parent_base_data.child_attachment_points
		else:
			return Vector2.ZERO  # Parent has no child attachment points
	
	if parent_child_points.size() == 0:
		return Vector2.ZERO  # No child attachment points available
	
	# Use the explicitly specified child attachment index
	var attachment_index = clamp(child_attachment_index, 0, parent_child_points.size() - 1)
	
	# Get the specified child attachment point from the parent instance
	var child_attachment_point = parent_child_points[attachment_index]
	
	# The offset is the child attachment point position on the parent
	return child_attachment_point

func draw_body_part_mirrored_zoomed_with_name(part_name: String, part_data: Dictionary, offset: Vector2, color: Color, is_left: bool, zoom: float = 1.0):
	# Both sides should look identical - facing the same direction as the character
	# But positioned based on complete attachment hierarchy
	var limb_x_flip = 1.0  # Always use same orientation for limbs
	
	match part_data.type:
		"polygon":
			if part_data.points.size() < 3:
				return
			var points = PackedVector2Array()
			# Calculate numbered attachment offset for this part
			var attachment_offset = calculate_numbered_attachment_offset(part_name, is_left, part_data)
			
			for point in part_data.points:
				# Same orientation for both sides, positioned at attachment offset
				var positioned_point = Vector2(point.x * limb_x_flip + attachment_offset.x, point.y + attachment_offset.y)
				var final_point = offset + positioned_point * character_scale * zoom
				# Validate point is finite
				if is_finite(final_point.x) and is_finite(final_point.y):
					points.append(final_point)
				else:
					print("Warning: Invalid point in %s: %s" % [part_name, final_point])
			
			# Only draw if we have enough valid points
			if points.size() >= 3:
				full_character_preview.draw_colored_polygon(points, color)
			else:
				print("Warning: Not enough valid points for %s polygon: %d" % [part_name, points.size()])
		"circle":
			# Calculate numbered attachment offset for this part
			var attachment_offset = calculate_numbered_attachment_offset(part_name, is_left, part_data)
			
			# Same orientation for both sides, positioned at attachment offset
			var positioned_center = Vector2(part_data.center.x * limb_x_flip + attachment_offset.x, part_data.center.y + attachment_offset.y)
			var center = offset + positioned_center * character_scale * zoom
			var radius = part_data.radius * character_scale * zoom
			full_character_preview.draw_circle(center, radius, color)
		"rect":
			# Calculate numbered attachment offset for this part
			var attachment_offset = calculate_numbered_attachment_offset(part_name, is_left, part_data)
			
			# Same orientation for both sides, positioned at attachment offset
			var positioned_pos = Vector2(part_data.rect.position.x * limb_x_flip + attachment_offset.x, part_data.rect.position.y + attachment_offset.y)
			var rect = Rect2(offset + positioned_pos * character_scale * zoom, part_data.rect.size * character_scale * zoom)
			full_character_preview.draw_rect(rect, color)

func _on_zoom_in_pressed():
	preview_zoom = clamp(preview_zoom + 0.2, min_zoom, max_zoom)
	zoom_label.text = "Zoom: %d%%" % int(preview_zoom * 100)
	full_character_preview.queue_redraw()

func _on_zoom_out_pressed():
	preview_zoom = clamp(preview_zoom - 0.2, min_zoom, max_zoom)
	zoom_label.text = "Zoom: %d%%" % int(preview_zoom * 100)
	full_character_preview.queue_redraw()

func _on_ground_down_pressed():
	ground_level += 5.0  # Move ground down (positive Y)
	ground_value_label.text = "%.1f" % ground_level
	full_character_preview.queue_redraw()

func _on_ground_up_pressed():
	ground_level -= 5.0  # Move ground up (negative Y)
	ground_value_label.text = "%.1f" % ground_level
	full_character_preview.queue_redraw()

func _on_prev_instance_pressed():
	var current_part_name = part_names[current_part_index]
	var part_data = body_parts[current_part_name]
	var num_instances = part_data.get("num_instances", 1)
	
	if num_instances > 1:
		current_instance_index = (current_instance_index - 1) % num_instances
		if current_instance_index < 0:
			current_instance_index = num_instances - 1
		update_current_part_display()

func _on_next_instance_pressed():
	var current_part_name = part_names[current_part_index]
	var part_data = body_parts[current_part_name]
	var num_instances = part_data.get("num_instances", 1)
	
	if num_instances > 1:
		current_instance_index = (current_instance_index + 1) % num_instances
		update_current_part_display()

func _on_sync_instances_pressed():
	var current_part_name = part_names[current_part_index]
	sync_instances(current_part_name)
	update_current_part_display()

func draw_terrain_sample(center_pos: Vector2, zoom: float = 1.0):
	# Draw a sample terrain strip to show ground level
	var terrain_width = 300.0 * zoom
	var terrain_segments = 20
	var segment_width = terrain_width / terrain_segments
	
	# Calculate ground position
	var ground_y = center_pos.y + ground_level * character_scale * zoom
	
	# Create terrain points using simple noise
	var terrain_points = PackedVector2Array()
	var terrain_start_x = center_pos.x - terrain_width / 2
	
	for i in range(terrain_segments + 1):
		var x = terrain_start_x + i * segment_width
		var noise_value = sin(x * terrain_noise_scale) * 3.0 * zoom  # Simple wave for terrain variation
		var y = ground_y + noise_value
		terrain_points.append(Vector2(x, y))
	
	# Add bottom points to close the polygon
	terrain_points.append(Vector2(terrain_start_x + terrain_width, ground_y + terrain_sample_height * zoom))
	terrain_points.append(Vector2(terrain_start_x, ground_y + terrain_sample_height * zoom))
	
	# Draw terrain as a brown/earth colored polygon
	var terrain_color = Color(0.4, 0.3, 0.2, 0.8)  # Brown earth color
	full_character_preview.draw_colored_polygon(terrain_points, terrain_color)
	
	# Draw ground level line
	var line_start = Vector2(terrain_start_x, ground_y)
	var line_end = Vector2(terrain_start_x + terrain_width, ground_y)
	full_character_preview.draw_line(line_start, line_end, Color.GREEN, 2.0 * zoom)
	
	# Draw draggable ground level indicator
	var handle_pos = Vector2(center_pos.x, ground_y)
	var handle_radius = 6.0 * zoom
	full_character_preview.draw_circle(handle_pos, handle_radius, Color.YELLOW)
	full_character_preview.draw_circle(handle_pos, handle_radius - 2, Color.GREEN)
	
	# Draw feet positioning guides
	draw_feet_guides(center_pos, ground_y, zoom)

func draw_feet_guides(center_pos: Vector2, ground_y: float, zoom: float = 1.0):
	# Find the foot parts and draw guides to show their relationship with ground
	if not body_parts.has("foot"):
		return
	
	var foot_data = body_parts["foot"]
	if foot_data.type != "polygon" or foot_data.points.size() == 0:
		return
	
	# Calculate foot positions (both left and right)
	var foot_positions = []
	
	# Right foot position (normal)
	var right_foot_bottom = find_lowest_point(foot_data.points)
	var right_foot_world_pos = center_pos + right_foot_bottom * character_scale * zoom
	foot_positions.append(right_foot_world_pos)
	
	# Left foot position (mirrored)
	var left_foot_bottom = Vector2(-right_foot_bottom.x, right_foot_bottom.y)
	var left_foot_world_pos = center_pos + left_foot_bottom * character_scale * zoom
	foot_positions.append(left_foot_world_pos)
	
	# Draw guides from feet to ground level
	for foot_pos in foot_positions:
		var ground_contact_pos = Vector2(foot_pos.x, ground_y)
		
		# Draw vertical line from foot to ground
		var line_color = Color.CYAN
		if foot_pos.y > ground_y:
			line_color = Color.RED  # Feet below ground
		elif foot_pos.y < ground_y - 5 * zoom:
			line_color = Color.ORANGE  # Feet floating above ground
		
		full_character_preview.draw_line(foot_pos, ground_contact_pos, line_color, 1.5 * zoom)
		
		# Draw small circle at ground contact point
		full_character_preview.draw_circle(ground_contact_pos, 2.0 * zoom, line_color)

func find_lowest_point(points: Array) -> Vector2:
	# Find the point with the highest Y value (lowest on screen)
	var lowest_point = points[0]
	for point in points:
		if point.y > lowest_point.y:
			lowest_point = point
	return lowest_point

func draw_attachment_point_on_preview_with_name(part_name: String, part_data: Dictionary, offset: Vector2, is_left: bool, zoom: float = 1.0):
	if not part_data.has("attachment_point"):
		return
		
	# Show the raw attachment point position (same as part editor)
	var attachment_pos = part_data.attachment_point
	
	# For left side shared parts, only mirror the display position for root limbs
	var parent_name = part_data.get("attachment_to", "")
	var is_root_limb = parent_name in ["torso", "hips"]
	if is_left and is_root_limb and part_data.get("shared", false):
		attachment_pos.x = -attachment_pos.x
	
	var screen_pos = offset + attachment_pos * character_scale * zoom
	
	# Draw small attachment point indicator
	var attachment_radius = 3.0 * zoom
	full_character_preview.draw_circle(screen_pos, attachment_radius, Color.RED)
	full_character_preview.draw_circle(screen_pos, attachment_radius - 1, Color.WHITE)

func draw_attachment_point_on_preview(part_data: Dictionary, offset: Vector2, is_left: bool, zoom: float = 1.0):
	if not part_data.has("attachment_point"):
		return
		
	var attachment_pos = part_data.attachment_point
	var attachment_x_flip = 1.0  # For attachment point positioning
	
	# Only apply symmetrical mirroring to root limb parts (attach to torso/hips)
	var is_root_limb = part_data.get("attachment_to", "") in ["torso", "hips"]
	
	if is_left and is_root_limb:
		# Root limbs: mirror attachment point for symmetrical positioning
		attachment_x_flip = -1.0
	# Non-root limbs: use attachment point as-is (relative to parent)
	
	var positioned_attachment = Vector2(attachment_pos.x * attachment_x_flip, attachment_pos.y)
	var screen_pos = offset + positioned_attachment * character_scale * zoom
	
	# Draw small attachment point indicator
	var attachment_radius = 3.0 * zoom
	full_character_preview.draw_circle(screen_pos, attachment_radius, Color.RED)
	full_character_preview.draw_circle(screen_pos, attachment_radius - 1, Color.WHITE)

func draw_child_attachment_points_on_preview_with_name(part_name: String, part_data: Dictionary, offset: Vector2, is_left: bool, zoom: float = 1.0):
	if not part_data.has("child_attachment_points"):
		return
	
	var child_points = part_data.child_attachment_points
	
	# Since child attachment points are now stored in instance data,
	# we can just draw all points in the current part_data (which should only be relevant ones)
	for i in range(child_points.size()):
		var point = child_points[i]
		
		# Apply mirroring for left side only to root attachment points
		var mirrored_point = point
		var parent_name = part_data.get("attachment_to", "")
		var is_root_part = parent_name == "" or parent_name in ["head", "neck"]  # Root parts like torso/hips
		
		if is_left and is_root_part:
			mirrored_point.x = -mirrored_point.x
		
		var screen_pos = offset + mirrored_point * character_scale * zoom
		
		# Draw child attachment point as blue circle
		var attachment_radius = 3.0 * zoom
		var child_color = Color(0.2, 0.6, 0.8)  # Blue color
		full_character_preview.draw_circle(screen_pos, attachment_radius, child_color)
		full_character_preview.draw_circle(screen_pos, attachment_radius - 1, Color.WHITE)
		
		# Draw number label (should always be 0 for instance data)
		var font = ThemeDB.fallback_font
		var text = str(i)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(6 * zoom))
		full_character_preview.draw_string(font, screen_pos - text_size / 2, text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(6 * zoom), Color.BLACK)

func draw_child_attachment_points_on_preview(part_data: Dictionary, offset: Vector2, is_left: bool, zoom: float = 1.0):
	if not part_data.has("child_attachment_points"):
		return
	
	var child_points = part_data.child_attachment_points
	for i in range(child_points.size()):
		var point = child_points[i]
		var screen_pos = offset + point * character_scale * zoom
		
		# Draw child attachment point as blue circle
		var attachment_radius = 3.0 * zoom
		var child_color = Color(0.2, 0.6, 0.8)  # Blue color
		full_character_preview.draw_circle(screen_pos, attachment_radius, child_color)
		full_character_preview.draw_circle(screen_pos, attachment_radius - 1, Color.WHITE)
		
		# Draw number label
		var font = ThemeDB.fallback_font
		var text = str(i)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(6 * zoom))
		full_character_preview.draw_string(font, screen_pos - text_size / 2, text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(6 * zoom), Color.BLACK)

func load_available_entities():
	# Create entities folder if it doesn't exist
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("entities"):
		dir.make_dir("entities")
	
	# Scan the entities folder for .gd files
	available_entities.clear()
	
	var entities_dir = DirAccess.open(entities_folder)
	if entities_dir:
		entities_dir.list_dir_begin()
		var file_name = entities_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".gd"):
				var entity_name = file_name.get_basename()
				available_entities.append(entity_name)
			file_name = entities_dir.get_next()
		entities_dir.list_dir_end()
	
	# Add default "Human" if no entities exist
	if available_entities.is_empty():
		available_entities.append("Human")
		# Save a default Human entity
		save_entity_to_file("Human")
	
	# Try to automatically load Human entity if it exists, otherwise use first available
	var entity_to_load = "Human" if available_entities.has("Human") else available_entities[0]
	
	# Load the entity file if it exists, otherwise use hardcoded defaults
	if FileAccess.file_exists(entities_folder + entity_to_load + ".gd"):
		print("Loading entity from file: ", entity_to_load)
		if load_entity(entity_to_load):
			print("Successfully loaded entity: ", entity_to_load)
		else:
			print("Failed to load entity file, using hardcoded defaults")
			current_entity_name = entity_to_load
	else:
		print("No entity file found for: ", entity_to_load, ", using hardcoded defaults")
		current_entity_name = entity_to_load
	
	entity_name_edit.text = current_entity_name
	
	print("Available entities: ", available_entities)
	print("Entities folder: ", entities_folder)

func load_entity(entity_name: String):
	var file_path = entities_folder + entity_name + ".gd"
	
	if not FileAccess.file_exists(file_path):
		print("Entity file not found: ", file_path)
		return false
	
	# For now, we'll load the entity definition by parsing the file
	# In the future, this could be JSON or a more structured format
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		# Parse the body_parts dictionary from the file
		if parse_entity_from_content(content):
			current_entity_name = entity_name
			entity_name_edit.text = entity_name
			return true
	
	return false

func parse_entity_from_content(content: String) -> bool:
	# Parse the body_parts dictionary from the entity file
	print("Parsing entity content...")
	
	# Simple regex-based parsing to extract the body_parts dictionary
	var regex = RegEx.new()
	regex.compile("var body_parts = \\{([^}]+(?:\\}[^}]*)*?)\\}")
	var result = regex.search(content)
	
	if not result:
		print("Could not find body_parts dictionary in entity file")
		return false
	
	# Load ground level from content using regex
	var ground_regex = RegEx.new()
	ground_regex.compile("var ground_level = ([0-9.-]+)")
	var ground_result = ground_regex.search(content)
	if ground_result:
		ground_level = ground_result.get_string(1).to_float()
		ground_value_label.text = "%.1f" % ground_level
		print("Loaded ground level: ", ground_level)
	else:
		print("No ground level found in entity file - using default")
		ground_level = 0.0
		ground_value_label.text = "0.0"
	
	# Execute the content to get the data
	# This is safe since we control the file format
	var script = GDScript.new()
	# Only add get_body_parts function if it doesn't already exist
	if not content.contains("func get_body_parts"):
		script.source_code = content + "\nfunc get_body_parts(): return body_parts"
	else:
		script.source_code = content
	script.reload()
	var instance = script.new()
	
	if instance == null:
		print("Error parsing entity file - using defaults")
		return false
		
	var loaded_parts = instance.get_body_parts()
	
	if loaded_parts and typeof(loaded_parts) == TYPE_DICTIONARY and loaded_parts.size() > 0:
		print("Successfully loaded body_parts dictionary with %d parts" % loaded_parts.size())
		# Merge loaded parts with defaults, ensuring backward compatibility
		merge_entity_parts(loaded_parts)
		return true
	else:
		print("Invalid body_parts data structure - size: %d, type: %d" % [loaded_parts.size() if loaded_parts else 0, typeof(loaded_parts)])
		return false

func merge_entity_parts(loaded_parts: Dictionary):
	# Safely merge loaded parts with current defaults, preserving new fields
	print("Merging entity parts with backward compatibility...")
	print("Debug: Before merge, loaded_parts has %d parts" % loaded_parts.size())
	
	for part_name in loaded_parts.keys():
		if body_parts.has(part_name):
			var loaded_part = loaded_parts[part_name]
			var current_part = body_parts[part_name]
			
			# Merge properties, keeping loaded values but adding missing defaults
			for property in loaded_part.keys():
				current_part[property] = loaded_part[property]
			
			# Add any missing default properties for backward compatibility
			add_missing_defaults(current_part, part_name)
		else:
			# New part type - add it directly
			body_parts[part_name] = loaded_parts[part_name]
			add_missing_defaults(body_parts[part_name], part_name)
	
	# Update part names list
	part_names = body_parts.keys()

func add_missing_defaults(part_data: Dictionary, part_name: String):
	# Add missing default properties for backward compatibility
	
	# Ensure basic properties exist
	if not part_data.has("type"):
		part_data["type"] = "polygon"  # Default to polygon
	
	if not part_data.has("color"):
		part_data["color"] = pottery_dark  # Default color
	
	# Add missing polygon points if empty
	if part_data.type == "polygon" and not part_data.has("points"):
		part_data["points"] = [Vector2(0, 0), Vector2(5, 0), Vector2(5, 5), Vector2(0, 5)]  # Default square
	
	# Add missing shared property for limbs (not torso/hips)
	if part_name in ["upper_arm", "forearm", "hand", "thigh", "shin", "foot"]:
		if not part_data.has("shared"):
			part_data["shared"] = true
	
	# Ensure num_instances is properly set for shared parts
	if part_data.get("shared", false):
		if not part_data.has("num_instances"):
			part_data["num_instances"] = 2  # Default to bilateral for shared limbs
			print("Auto-set num_instances=2 for shared part: %s" % part_name)
		elif part_data.get("num_instances", 1) < 2:
			print("WARNING: Shared part '%s' has num_instances=%d, should be >= 2" % [part_name, part_data.get("num_instances")])
			part_data["num_instances"] = 2  # Force correction
	elif not part_data.has("num_instances"):
		# Non-shared parts default to 1 instance
		part_data["num_instances"] = 1
	
	# Add missing attachment points for certain parts
	if not part_data.has("attachment_point") and part_name in ["neck", "torso", "hips", "upper_arm", "forearm", "hand", "thigh", "shin", "foot"]:
		# Add reasonable default attachment points
		match part_name:
			"neck":
				part_data["attachment_point"] = Vector2(0, -21)
				part_data["attachment_to"] = "head"
			"torso":
				part_data["attachment_point"] = Vector2(0, -17)
				part_data["attachment_to"] = "neck"
			"hips":
				part_data["attachment_point"] = Vector2(0, -8)
				part_data["attachment_to"] = "torso"
				part_data["attachment_to_index"] = 2  # Hips now connects to torso index 2
			"upper_arm":
				part_data["attachment_point"] = Vector2(7.0, -16.0)
				part_data["attachment_to"] = "torso"
			"forearm":
				part_data["attachment_point"] = Vector2(7.5, -3.5)
				part_data["attachment_to"] = "upper_arm"
			"hand":
				part_data["attachment_point"] = Vector2(9, -3)
				part_data["attachment_to"] = "forearm"
			"thigh":
				part_data["attachment_point"] = Vector2(3.5, -2)
				part_data["attachment_to"] = "hips"
			"shin":
				part_data["attachment_point"] = Vector2(5.5, 6)
				part_data["attachment_to"] = "thigh"
			"foot":
				part_data["attachment_point"] = Vector2(7, 11)
				part_data["attachment_to"] = "shin"
	
	# Add missing child attachment points for parent parts
	match part_name:
		"head":
			if not part_data.has("child_attachment_points"):
				part_data["child_attachment_points"] = [Vector2(0, -21)]  # Neck attachment
		"neck":
			if not part_data.has("child_attachment_points"):
				part_data["child_attachment_points"] = [Vector2(0, -17)]  # Torso attachment
		"torso":
			if not part_data.has("child_attachment_points"):
				part_data["child_attachment_points"] = [
					Vector2(7.0, -16.0),   # 0: Right arm attachment (instance 0)
					Vector2(-7.0, -16.0),  # 1: Left arm attachment (instance 1)
					Vector2(0, -8)         # 2: Hips attachment
				]
				print("Debug: Added child attachment points to torso")
		"hips":
			if not part_data.has("child_attachment_points"):
				part_data["child_attachment_points"] = [
					Vector2(3.5, -2.0),   # 0: Right leg attachment (instance 0)
					Vector2(-3.5, -2.0)   # 1: Left leg attachment (instance 1)
				]
		"upper_arm":
			# For shared parts like upper_arm, child attachment points should be in instance data
			if part_data.get("shared", false) and part_data.get("num_instances", 1) > 1:
				# Ensure instances exist
				if not part_data.has("instances"):
					part_data["instances"] = {}
				
				# Add child attachment points to each instance
				for i in range(part_data.get("num_instances", 1)):
					var instance_key = str(i)
					if not part_data.instances.has(instance_key):
						part_data.instances[instance_key] = create_instance_data_from_base(part_data)
					
					var instance_data = part_data.instances[instance_key]
					if not instance_data.has("child_attachment_points"):
						# Each instance gets its own child attachment point
						instance_data["child_attachment_points"] = [Vector2(6.0, -10.0)]
			elif not part_data.has("child_attachment_points"):
				# Non-shared upper_arm gets single child attachment point
				part_data["child_attachment_points"] = [Vector2(6.0, -10.0)]
		"forearm":
			# For shared parts like forearm, child attachment points should be in instance data
			if part_data.get("shared", false) and part_data.get("num_instances", 1) > 1:
				# Ensure instances exist
				if not part_data.has("instances"):
					part_data["instances"] = {}
				
				# Add child attachment points to each instance
				for i in range(part_data.get("num_instances", 1)):
					var instance_key = str(i)
					if not part_data.instances.has(instance_key):
						part_data.instances[instance_key] = create_instance_data_from_base(part_data)
					
					var instance_data = part_data.instances[instance_key]
					if not instance_data.has("child_attachment_points"):
						# Each instance gets its own child attachment point
						instance_data["child_attachment_points"] = [Vector2(9.0, -2.0)]
			elif not part_data.has("child_attachment_points"):
				# Non-shared forearm gets single child attachment point
				part_data["child_attachment_points"] = [Vector2(9.0, -2.0)]
		"thigh":
			# For shared parts like thigh, child attachment points should be in instance data
			if part_data.get("shared", false) and part_data.get("num_instances", 1) > 1:
				# Ensure instances exist
				if not part_data.has("instances"):
					part_data["instances"] = {}
				
				# Add child attachment points to each instance
				for i in range(part_data.get("num_instances", 1)):
					var instance_key = str(i)
					if not part_data.instances.has(instance_key):
						part_data.instances[instance_key] = create_instance_data_from_base(part_data)
					
					var instance_data = part_data.instances[instance_key]
					if not instance_data.has("child_attachment_points"):
						# Each instance gets its own child attachment point
						instance_data["child_attachment_points"] = [Vector2(5.5, 6.0)]
			elif not part_data.has("child_attachment_points"):
				# Non-shared thigh gets single child attachment point
				part_data["child_attachment_points"] = [Vector2(5.5, 6.0)]
		"shin":
			# For shared parts like shin, child attachment points should be in instance data
			if part_data.get("shared", false) and part_data.get("num_instances", 1) > 1:
				# Ensure instances exist
				if not part_data.has("instances"):
					part_data["instances"] = {}
				
				# Add child attachment points to each instance
				for i in range(part_data.get("num_instances", 1)):
					var instance_key = str(i)
					if not part_data.instances.has(instance_key):
						part_data.instances[instance_key] = create_instance_data_from_base(part_data)
					
					var instance_data = part_data.instances[instance_key]
					if not instance_data.has("child_attachment_points"):
						# Each instance gets its own child attachment point
						instance_data["child_attachment_points"] = [Vector2(7.0, 11.0)]
			elif not part_data.has("child_attachment_points"):
				# Non-shared shin gets single child attachment point
				part_data["child_attachment_points"] = [Vector2(7.0, 11.0)]
	
	# Shared parts now use automatic sequential indexing (instance index = attachment index)
	# No separate attachment indices needed
	# Add missing iris properties for eyes
	if part_name == "eye":
		if not part_data.has("iris_center"):
			part_data["iris_center"] = Vector2(2, -29)
		if not part_data.has("iris_radius"):
			part_data["iris_radius"] = 0.8
		if not part_data.has("iris_color"):
			part_data["iris_color"] = pottery_dark
	
	print("Added missing defaults for part: %s" % part_name)

func _on_prev_entity_pressed():
	if available_entities.size() > 1:
		current_entity_index = (current_entity_index - 1) % available_entities.size()
		if current_entity_index < 0:
			current_entity_index = available_entities.size() - 1
		load_entity(available_entities[current_entity_index])
		update_current_part_display()

func _on_next_entity_pressed():
	if available_entities.size() > 1:
		current_entity_index = (current_entity_index + 1) % available_entities.size()
		load_entity(available_entities[current_entity_index])
		update_current_part_display()

func _on_entity_name_changed(new_text: String):
	current_entity_name = new_text

func _on_save_entity_pressed():
	if current_entity_name.strip_edges().is_empty():
		print("Cannot save entity with empty name")
		return
	
	save_entity_to_file(current_entity_name)

func save_entity_to_file(entity_name: String):
	var file_path = entities_folder + entity_name + ".gd"
	
	# Generate entity file content
	var entity_content = generate_entity_content(entity_name)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(entity_content)
		file.close()
		print("Entity saved: ", file_path)
		
		# Update available entities list
		if not available_entities.has(entity_name):
			available_entities.append(entity_name)
			current_entity_index = available_entities.find(entity_name)
		
		print("Entity '%s' saved successfully!" % entity_name)
	else:
		print("Error: Could not save entity to ", file_path)

func generate_entity_content(entity_name: String) -> String:
	var content = "# Entity: %s\n" % entity_name
	content += "# Generated by Character Editor\n"
	content += "# Date: " + Time.get_datetime_string_from_system() + "\n\n"
	
	content += "extends Resource\n"
	content += "class_name %sEntity\n\n" % entity_name.capitalize()
	
	content += "# Ground level for terrain interactions\n"
	content += "var ground_level = %.1f\n\n" % ground_level
	
	content += "var body_parts = {\n"
	
	for part_name in part_names:
		var part_data = body_parts[part_name]
		content += "\t\"%s\": {\n" % part_name
		content += "\t\t\"type\": \"%s\",\n" % part_data.type
		
		# Export points array for polygons
		if part_data.type == "polygon" and part_data.has("points"):
			content += "\t\t\"points\": [\n"
			for i in range(part_data.points.size()):
				var point = part_data.points[i]
				content += "\t\t\tVector2(%.1f, %.1f)" % [point.x, point.y]
				if i < part_data.points.size() - 1:
					content += ","
				content += "\n"
			content += "\t\t],\n"
		
		# Export other properties with safe fallbacks
		if part_data.has("center"):
			content += "\t\t\"center\": Vector2(%.1f, %.1f),\n" % [part_data.center.x, part_data.center.y]
		if part_data.has("radius"):
			content += "\t\t\"radius\": %.1f,\n" % part_data.radius
		if part_data.has("rect"):
			var rect = part_data.rect
			content += "\t\t\"rect\": Rect2(%.1f, %.1f, %.1f, %.1f),\n" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		if part_data.has("iris_center"):
			content += "\t\t\"iris_center\": Vector2(%.1f, %.1f),\n" % [part_data.iris_center.x, part_data.iris_center.y]
		if part_data.has("iris_radius"):
			content += "\t\t\"iris_radius\": %.1f,\n" % part_data.iris_radius
		if part_data.has("iris_color"):
			var iris_color = part_data.iris_color
			content += "\t\t\"iris_color\": Color(%.2f, %.2f, %.2f),\n" % [iris_color.r, iris_color.g, iris_color.b]
		if part_data.has("shared"):
			content += "\t\t\"shared\": %s,\n" % str(part_data.shared).to_lower()
		if part_data.has("attachment_point"):
			content += "\t\t\"attachment_point\": Vector2(%.1f, %.1f),\n" % [part_data.attachment_point.x, part_data.attachment_point.y]
		if part_data.has("attachment_to"):
			content += "\t\t\"attachment_to\": \"%s\",\n" % part_data.attachment_to
		
		# Color (always present)
		var color = part_data.color
		content += "\t\t\"color\": Color(%.2f, %.2f, %.2f)\n" % [color.r, color.g, color.b]
		
		content += "\t}"
		if part_name != part_names[-1]:
			content += ","
		content += "\n"
	
	content += "}\n"
	
	return content

func _on_full_preview_input(event: InputEvent):
	# Handle mouse input for ground level dragging
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Check if clicking on ground level handle
				if is_mouse_on_ground_handle(mouse_event.position):
					is_dragging_ground = true
					print("Started dragging ground level")
			else:
				# Stop dragging ground
				if is_dragging_ground:
					is_dragging_ground = false
					print("Stopped dragging ground level")
	
	elif event is InputEventMouseMotion and is_dragging_ground:
		# Drag ground level
		var center = full_character_preview.size / 2
		var zoom_offset = center - (center * preview_zoom)
		var zoomed_center = center * preview_zoom + zoom_offset
		
		# Convert mouse Y position to ground level
		var mouse_y_offset = event.position.y - zoomed_center.y
		ground_level = mouse_y_offset / (character_scale * preview_zoom)
		
		# Update UI and redraw
		ground_value_label.text = "%.1f" % ground_level
		full_character_preview.queue_redraw()

func is_mouse_on_ground_handle(mouse_pos: Vector2) -> bool:
	var center = full_character_preview.size / 2
	var zoom_offset = center - (center * preview_zoom)
	var zoomed_center = center * preview_zoom + zoom_offset
	
	# Calculate ground handle position
	var ground_y = zoomed_center.y + ground_level * character_scale * preview_zoom
	var handle_pos = Vector2(zoomed_center.x, ground_y)
	var handle_radius = 6.0 * preview_zoom
	
	# Check if mouse is within handle radius
	return mouse_pos.distance_to(handle_pos) <= handle_radius

func _on_reset_polygon_pressed():
	# Reset current body part to default shape
	if part_names.size() == 0:
		return
	
	var current_part_name = part_names[current_part_index]
	var base_part_data = body_parts[current_part_name]
	
	# Get default body part from initialize_body_parts
	var default_parts = get_default_body_parts()
	if default_parts.has(current_part_name):
		var default_data = default_parts[current_part_name].duplicate(true)
		
		if base_part_data.get("shared", false):
			# For shared parts, reset the current instance data
			if not base_part_data.has("instances"):
				base_part_data["instances"] = {}
			var instance_key = str(current_instance_index)
			base_part_data.instances[instance_key] = create_instance_data_from_base(default_data)
			print("Reset %s (instance %d) to default shape" % [current_part_name, current_instance_index])
		else:
			# For non-shared parts, reset the main data
			body_parts[current_part_name] = default_data
			print("Reset %s to default shape" % current_part_name)
		
		update_current_part_display()
	else:
		print("No default shape found for %s" % current_part_name)

func _on_reset_position_pressed():
	# Reset current body part position to sync with parent's child attachment point
	if part_names.size() == 0:
		return
	
	var current_part_name = part_names[current_part_index]
	var part_data = get_current_instance_data(current_part_name)
	var base_part_data = body_parts[current_part_name]
	
	# Check if this part has a parent to attach to
	var attachment_to = base_part_data.get("attachment_to", "")
	if attachment_to == "" or not body_parts.has(attachment_to):
		print("Cannot reset position for %s (no parent to attach to)" % current_part_name)
		return
	
	# Get explicit attachment properties from base part data
	var parent_instance_index = base_part_data.get("attachment_to_instance", 0)
	var child_attachment_index = base_part_data.get("attachment_to_child_index", 0)
	
	# Get parent's child attachment points using explicit properties
	var parent_base_data = body_parts[attachment_to]
	var parent_child_points = []
	
	# If parent is shared, get child attachment points from the specific parent instance
	if parent_base_data.get("shared", false) and parent_base_data.get("num_instances", 1) > 1:
		var parent_instance_data = get_instance_data(attachment_to, parent_instance_index)
		
		if parent_instance_data.has("child_attachment_points"):
			parent_child_points = parent_instance_data.child_attachment_points
		else:
			print("Cannot reset position for %s (parent instance %d has no child attachment points)" % [current_part_name, parent_instance_index])
			return
	else:
		# Non-shared parent, check base data
		if parent_base_data.has("child_attachment_points"):
			parent_child_points = parent_base_data.child_attachment_points
		else:
			print("Cannot reset position for %s (parent has no child attachment points)" % current_part_name)
			return
	
	if parent_child_points.size() == 0:
		print("Cannot reset position for %s (parent has no child attachment points)" % current_part_name)
		return
	
	# Use the explicitly specified child attachment index
	var attachment_index = clamp(child_attachment_index, 0, parent_child_points.size() - 1)
	var target_position = parent_child_points[attachment_index]
	
	# Calculate offset needed to position part's attachment point at target
	if part_data.type == "polygon" and part_data.has("attachment_point"):
		var current_attachment = part_data.attachment_point
		var offset_needed = target_position - current_attachment
		
		# Apply offset to all points and attachment point to move the entire part
		# This ensures the child's red attachment point overlaps the parent's blue child attachment point
		for i in range(part_data.points.size()):
			part_data.points[i] += offset_needed
		
		# Move attachment point by the same offset so it ends up exactly at target position
		part_data.attachment_point += offset_needed
		
		# Also update child attachment points if they exist
		if part_data.has("child_attachment_points"):
			for i in range(part_data.child_attachment_points.size()):
				part_data.child_attachment_points[i] += offset_needed
		
		print("Reset %s position to parent attachment point %d at %s" % [current_part_name, attachment_index, target_position])
		update_current_part_display()
		full_character_preview.queue_redraw()
		
	elif part_data.type == "circle" and part_data.has("attachment_point"):
		var current_attachment = part_data.attachment_point
		var offset_needed = target_position - current_attachment
		
		# Move circle center and attachment point
		part_data.center += offset_needed
		part_data.attachment_point += offset_needed
		
		print("Reset %s position to parent attachment point %d at %s" % [current_part_name, attachment_index, target_position])
		update_current_part_display()
		full_character_preview.queue_redraw()
		
	else:
		print("Cannot reset position for %s (no attachment point or unsupported type)" % current_part_name)

func get_default_body_parts() -> Dictionary:
	# Return the default body parts definition
	return {
		"head": {
			"type": "polygon",
			"points": [
				Vector2(-5.0, -30.9), Vector2(-0.9, -34.5), Vector2(5.0, -33.3), 
				Vector2(7.3, -29.2), Vector2(8.5, -25.2), Vector2(5.9, -21.8), 
				Vector2(-1.6, -19.9), Vector2(-5.7, -25.7)
			],
			"color": pottery_dark
		},
		"hair": {
			"type": "polygon", 
			"points": [
				Vector2(-7.2, -31.5), Vector2(-1.7, -36.1), Vector2(4.3, -35.0),
				Vector2(6.0, -32.0), Vector2(-0.5, -32.3), Vector2(-5.8, -26.7)
			],
			"color": pottery_dark
		},
		"eye": {
			"type": "polygon",
			"points": [
				Vector2(0.5, -30.5), Vector2(3.5, -30.5), Vector2(3.5, -27.5), Vector2(0.5, -27.5)
			],
			"color": eye_white,
			"iris_center": Vector2(2, -29),
			"iris_radius": 0.8,
			"iris_color": pottery_dark
		},
		"nose": {
			"type": "polygon",
			"points": [
				Vector2(4, -27), Vector2(7, -25), Vector2(5, -24)
			],
			"color": pottery_medium
		},
		"neck": {
			"type": "polygon",
			"points": [
				Vector2(-2, -21), Vector2(2, -21), Vector2(2, -17), Vector2(-2, -17)
			],
			"color": pottery_dark,
			"attachment_point": Vector2(0, -21),
			"attachment_to": "head"
		},
		"torso": {
			"type": "polygon",
			"points": [
				Vector2(-7.9, -13.8), Vector2(-7.3, -16.5), Vector2(-2.8, -17.7),
				Vector2(3.2, -17.8), Vector2(6.6, -16.8), Vector2(7.5, -14.0),
				Vector2(6.2, -7.5), Vector2(4.3, -1.7), Vector2(-3.9, -1.7), Vector2(-6.0, -7.3)
			],
			"color": pottery_dark,
			"attachment_point": Vector2(0, -17),
			"attachment_to": "neck"
		},
		"hips": {
			"type": "polygon",
			"points": [
				Vector2(-8, -8), Vector2(8, -8), Vector2(6, -2), Vector2(-6, -2)
			],
			"color": pottery_dark,
			"attachment_point": Vector2(0, -8),
			"attachment_to": "torso"
		},
		"upper_arm": {
			"type": "polygon",
			"points": [
				Vector2(7.0, -16.0), Vector2(8.0, -14.0), Vector2(6.0, -10.0),
				Vector2(4.0, -8.0), Vector2(5.0, -6.0), Vector2(6.5, -4.0), Vector2(8.0, -6.0)
			],
			"color": pottery_dark,
			"shared": true,
			"attachment_point": Vector2(7.0, -16.0),
			"attachment_to": "torso"
		},
		"forearm": {
			"type": "polygon",
			"points": [
				Vector2(6.0, -10.0), Vector2(4.0, -8.0), Vector2(8.0, -4.0),
				Vector2(10.0, -2.0), Vector2(9.0, -1.0), Vector2(7.0, -2.0), Vector2(5.0, -5.0)
			],
			"color": pottery_dark,
			"shared": true,
			"attachment_point": Vector2(6.0, -10.0),
			"attachment_to": "upper_arm"
		},
		"hand": {
			"type": "polygon",
			"points": [
				Vector2(9.0, -2.0), Vector2(12.0, -1.0), Vector2(12.5, 1.0),
				Vector2(11.0, 2.0), Vector2(8.5, 1.0), Vector2(8.0, -1.0)
			],
			"color": pottery_dark,
			"shared": true,
			"attachment_point": Vector2(9.0, -2.0),
			"attachment_to": "forearm"
		},
		"thigh": {
			"type": "polygon",
			"points": [
				Vector2(2, -2), Vector2(5, -2), Vector2(7, 4), Vector2(6, 6),
				Vector2(4, 6), Vector2(3, 2)
			],
			"color": pottery_dark,
			"shared": true,
			"attachment_point": Vector2(3.5, -2),
			"attachment_to": "hips"
		},
		"shin": {
			"type": "polygon",
			"points": [
				Vector2(7, 6), Vector2(4, 6), Vector2(5, 11), Vector2(8, 11)
			],
			"color": pottery_dark,
			"shared": true,
			"attachment_point": Vector2(5.5, 6),
			"attachment_to": "thigh"
		},
		"foot": {
			"type": "polygon",
			"points": [
				Vector2(5, 11), Vector2(10, 11), Vector2(10, 13), Vector2(5, 13)
			],
			"color": pottery_dark,
			"shared": true,
			"attachment_point": Vector2(7.5, 11),
			"attachment_to": "shin"
		}
	}

func _on_export_button_pressed():
	# Export entity using the new entity system
	save_entity_to_file(current_entity_name)
	
	# Also generate the export text for display in script output
	var export_text = generate_entity_content(current_entity_name)
	script_output.text = export_text
	print("Entity exported and displayed in script output.")

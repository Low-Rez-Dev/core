# ==============================================================================
# ENTITY EDITOR - 2D PROCEDURAL CHARACTER EDITOR FOR REDOT 4.3
# ==============================================================================
# This is a comprehensive entity composition system for creating hierarchical 
# characters using polygon-based body parts with biological layers and 
# attachment points for parent-child relationships.
#
# KEY FEATURES:
# - Polygon editing with smart point insertion between closest nodes
# - Biological layer system (equipment→armor→skin→meat→bone→organs)
# - Parent-child attachment system with visual connection lines
# - Whole-part movement by dragging inside shapes
# - Right-click point deletion with minimum 3-point constraint
# - Layer-based color coding and thickness visualization
# - Snap-to-parent functionality for proper joint connections
# ==============================================================================

extends Control

# ==============================================================================
# UI ELEMENT REFERENCES
# ==============================================================================
# Left panel UI elements for controlling the entity editor
@onready var body_parts_list = $HSplitContainer/ToolPanel/BodyPartsPanel/BodyPartsList  # List to select/switch between body parts
@onready var add_body_part_button = $HSplitContainer/ToolPanel/BodyPartsPanel/HBoxContainer/AddBodyPartButton  # Creates new body parts
@onready var clone_body_part_button = $HSplitContainer/ToolPanel/BodyPartsPanel/HBoxContainer/CloneButton  # Clones selected body part
@onready var part_name_edit = $HSplitContainer/ToolPanel/PropertiesPanel/PartNameEdit  # Edit selected part name
@onready var layer_options = $HSplitContainer/ToolPanel/PropertiesPanel/LayerOptions  # Dropdown to select biological layer
@onready var current_layer_label = $HSplitContainer/ToolPanel/PropertiesPanel/CurrentLayerLabel  # Shows current layer being edited
@onready var material_edit = $HSplitContainer/ToolPanel/PropertiesPanel/LayerPropertiesPanel/MaterialEdit  # Material type (iron, leather, etc)
@onready var thickness_slider = $HSplitContainer/ToolPanel/PropertiesPanel/LayerPropertiesPanel/ThicknessSlider  # Layer thickness (0.1-5.0)
@onready var thickness_label = $HSplitContainer/ToolPanel/PropertiesPanel/LayerPropertiesPanel/ThicknessLabel  # Shows thickness value
@onready var quality_slider = $HSplitContainer/ToolPanel/PropertiesPanel/LayerPropertiesPanel/QualitySlider  # Layer quality (0-100%)
@onready var quality_label = $HSplitContainer/ToolPanel/PropertiesPanel/LayerPropertiesPanel/QualityLabel  # Shows quality percentage
@onready var parent_option = $HSplitContainer/ToolPanel/RelationshipsPanel/ParentOption  # Dropdown to set parent part
@onready var children_list = $HSplitContainer/ToolPanel/RelationshipsPanel/ChildrenList  # Shows child parts list
@onready var snap_button = $HSplitContainer/ToolPanel/RelationshipsPanel/SnapButton  # Snaps child's yellow to parent's green attachment
@onready var canvas = $HSplitContainer/DrawingArea/Canvas  # Main drawing canvas for polygon editing

# UI elements not yet implemented in simplified scene
var damage_slider = null  # TODO: Layer damage (0-100%)
var damage_label = null   # TODO: Shows damage percentage  
var constraint_type = null  # TODO: Joint constraint types (hinge, ball_socket, etc)
var min_angle_slider = null  # TODO: Minimum rotation angle
var min_angle_label = null   # TODO: Shows min angle value
var max_angle_slider = null  # TODO: Maximum rotation angle  
var max_angle_label = null   # TODO: Shows max angle value
var rest_angle_slider = null # TODO: Rest/default angle
var rest_angle_label = null  # TODO: Shows rest angle value
var add_child_button = null  # TODO: Add child relationships

# Variability zone controls
var zone_paint_button = null  # TODO: Toggle zone painting mode
var zone_radius_slider = null  # TODO: Control zone radius
var zone_expansion_slider = null  # TODO: Control max expansion
var zone_list = null  # TODO: List of painted zones

# Template system controls
@onready var save_template_button = $HSplitContainer/ToolPanel/TemplatePanel/TemplateButtonsContainer/SaveTemplateButton  # Save current entity as template
@onready var load_template_button = $HSplitContainer/ToolPanel/TemplatePanel/TemplateButtonsContainer/LoadTemplateButton  # Load entity from template
@onready var delete_template_button = $HSplitContainer/ToolPanel/TemplatePanel/TemplateButtonsContainer/DeleteTemplateButton  # Delete selected template
@onready var template_name_edit = $HSplitContainer/ToolPanel/TemplatePanel/TemplateNameEdit    # Name for saving templates
@onready var template_list = $HSplitContainer/ToolPanel/TemplatePanel/TemplateList         # List of available templates

# ==============================================================================
# CORE DATA STRUCTURES
# ==============================================================================
var body_parts: Array[BodyPart] = []  # All created body parts in the editor
var selected_body_part: BodyPart = null  # Currently selected part for editing

# ==============================================================================
# INTERACTION STATE VARIABLES  
# ==============================================================================
var drawing_mode: String = "select"  # Current interaction mode: "select", "move_point", "move_attachment", "move_parent_attachment", "move_part"
var selected_point_index: int = -1   # Index of currently selected polygon point (-1 = none, -100 = attachment, -101 = parent_attachment)
var drag_offset: Vector2 = Vector2.ZERO  # Mouse offset for smooth dragging
var editing_attachment: bool = false  # Whether currently editing attachment points
var editing_constraint: bool = false  # Whether currently editing rotation constraints
var constraint_handle_type: String = ""  # Type of constraint handle being edited: "min", "max", "rest"
var dragging_part: bool = false      # Whether currently dragging entire part

# Drag state for accurate coordinate tracking
var drag_start_world_pos: Vector2 = Vector2.ZERO  # World position where drag started
var drag_original_point_pos: Vector2 = Vector2.ZERO  # Original position of dragged point
var drag_original_polygon: PackedVector2Array = PackedVector2Array()  # Original polygon for part movement
var drag_original_attachment: Vector2 = Vector2.ZERO  # Original attachment point for part movement
var drag_original_parent_attachment: Vector2 = Vector2.ZERO  # Original parent attachment for part movement

# Variability zone painting state
var zone_painting_mode: bool = false  # Whether in zone painting mode
var zone_radius: float = 30.0         # Radius for zone painting
var zone_expansion: float = 20.0      # Maximum expansion for new zones
var current_zone: VariabilityZone = null  # Zone being painted

# Grid system for scale reference (1 unit = 1 decimeter = 10cm)
var show_grid: bool = true            # Whether to show the grid
var grid_unit_size: float = 10.0      # Size of one grid unit in pixels (1 decimeter)
var grid_color_minor: Color = Color(0.3, 0.3, 0.3, 0.4)  # Decimeter lines
var grid_color_major: Color = Color(0.5, 0.5, 0.5, 0.7)  # Meter lines
var grid_color_origin: Color = Color(0.8, 0.8, 0.8, 0.8) # Origin axes
var grid_toggle_button_rect: Rect2 = Rect2()  # Button area for click detection

# Zoom and pan system
var zoom_level: float = 1.0           # Current zoom level (1.0 = 100%)
var min_zoom: float = 0.1             # Minimum zoom (10%)
var max_zoom: float = 5.0             # Maximum zoom (500%)
var zoom_step: float = 0.1            # How much to zoom per scroll step
var pan_offset: Vector2 = Vector2.ZERO # Camera pan offset
var is_panning: bool = false          # Whether currently panning with middle mouse
var pan_start_pos: Vector2 = Vector2.ZERO # Mouse position when panning started
var is_canvas_panning: bool = false   # Whether currently panning by dragging empty canvas
var canvas_pan_start: Vector2 = Vector2.ZERO # Canvas pan start position

# ==============================================================================
# BIOLOGICAL LAYER SYSTEM
# ==============================================================================
var current_layer: String = "skin"  # Currently selected layer for editing/viewing
var layer_names: Array[String] = ["equipment", "armor", "clothes", "outer", "skin", "meat", "bone", "organs"]  # Layer hierarchy (outside→inside)

func _ready():
	setup_ui()
	canvas.gui_input.connect(_on_canvas_input)
	canvas.draw.connect(_on_canvas_draw)

func setup_ui():
	# Setup layer options
	layer_options.add_item("Equipment")
	layer_options.add_item("Armor") 
	layer_options.add_item("Clothes")
	layer_options.add_item("Outer Layer")
	layer_options.add_item("Skin")
	layer_options.add_item("Meat")
	layer_options.add_item("Bone")
	layer_options.add_item("Organs")
	
	# Setup constraint type options (when UI exists)
	# constraint_type.add_item("Hinge")
	# constraint_type.add_item("Ball Socket")
	# constraint_type.add_item("Fixed")
	# constraint_type.add_item("Twist")
	
	# Connect signals for available UI elements
	add_body_part_button.pressed.connect(_on_add_body_part)
	clone_body_part_button.pressed.connect(_on_clone_body_part)
	body_parts_list.item_selected.connect(_on_body_part_selected)
	part_name_edit.text_changed.connect(_on_part_name_changed)
	
	# Connect layer signals
	layer_options.item_selected.connect(_on_layer_selected)
	material_edit.text_changed.connect(_on_material_changed)
	thickness_slider.value_changed.connect(_on_thickness_changed)
	quality_slider.value_changed.connect(_on_quality_changed)
	
	# Connect relationship signals
	parent_option.item_selected.connect(_on_parent_selected)
	snap_button.pressed.connect(_on_snap_to_parent)
	
	# Connect template signals
	save_template_button.pressed.connect(_on_save_template_button)
	load_template_button.pressed.connect(_on_load_template_button)
	delete_template_button.pressed.connect(_on_delete_template_button)
	template_list.item_selected.connect(_on_template_selected)
	
	# Populate template list on startup
	update_template_list()

func _on_add_body_part():
	var new_part = BodyPart.new()
	new_part.part_name = "New Part " + str(body_parts.size() + 1)
	
	# Create basic rectangle shape (scaled to grid: 30 units = 3 decimeters = 30cm wide)
	new_part.polygon_points = PackedVector2Array([
		Vector2(-30, -40),  # 6dm wide, 8dm tall (realistic torso proportions)
		Vector2(30, -40), 
		Vector2(30, 40),
		Vector2(-30, 40)
	])
	
	body_parts.append(new_part)
	body_parts_list.add_item(new_part.part_name)
	
	# Auto-select the new part
	body_parts_list.select(body_parts.size() - 1)
	_on_body_part_selected(body_parts.size() - 1)
	
	canvas.queue_redraw()

func _on_clone_body_part():
	# Clone the currently selected body part
	if not selected_body_part:
		print("No body part selected to clone!")
		return
	
	print("=== CLONE BODY PART DEBUG ===")
	print("Cloning part: ", selected_body_part.part_name)
	
	# Create a duplicate of the selected body part
	var cloned_part = selected_body_part.duplicate_part()
	
	# Offset the clone slightly so it doesn't overlap exactly
	var offset = Vector2(50, 50)  # 5dm to the right and down
	for i in range(cloned_part.polygon_points.size()):
		cloned_part.polygon_points[i] += offset
	cloned_part.attachment_point += offset
	cloned_part.parent_attachment += offset
	
	# Add to the body parts list
	body_parts.append(cloned_part)
	body_parts_list.add_item(cloned_part.part_name)
	
	# Auto-select the cloned part
	body_parts_list.select(body_parts.size() - 1)
	_on_body_part_selected(body_parts.size() - 1)
	
	canvas.queue_redraw()
	print("✅ Cloned part: ", cloned_part.part_name)
	print("=== END CLONE DEBUG ===")

func _on_body_part_selected(index: int):
	print("Part selected: ", index)
	if index >= 0 and index < body_parts.size():
		selected_body_part = body_parts[index]
		part_name_edit.text = selected_body_part.part_name
		print("Selected part: ", selected_body_part.part_name)
		update_relationships_ui()
		# update_constraints_ui()  # Disabled until joint limit UI is implemented
		update_layers_ui()
		canvas.queue_redraw()

func _on_part_name_changed(new_name: String):
	if selected_body_part:
		selected_body_part.part_name = new_name
		var selected_index = body_parts_list.get_selected_items()[0] if body_parts_list.get_selected_items().size() > 0 else -1
		if selected_index >= 0:
			body_parts_list.set_item_text(selected_index, new_name)

# ==============================================================================
# CANVAS INTERACTION SYSTEM
# ==============================================================================
# Handles all mouse interactions on the drawing canvas including:
# - Smart polygon point addition (only inside shapes or near edges)
# - Point selection and movement (white circles)
# - Attachment point movement (green/yellow circles)  
# - Whole part movement (drag inside polygon)
# - Point deletion (right-click on points)
func _on_canvas_input(event: InputEvent):
	# Handle mouse wheel zoom
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_at_position(event.position, zoom_step)
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at_position(event.position, -zoom_step)
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			is_panning = true
			pan_start_pos = event.position
		else:
			is_panning = false
		return
	
	if event is InputEventMouseButton:
		var mouse_pos = event.position
		
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if clicking on grid toggle button first (highest priority)
			if grid_toggle_button_rect.has_point(mouse_pos):
				toggle_grid()
				return
			
			# Check if we have a selected body part to interact with
			if selected_body_part:
				var world_pos = transform_screen_to_world(mouse_pos)
				
				# Handle zone painting mode
				if zone_painting_mode:
					paint_variability_zone(world_pos)
					canvas.queue_redraw()
					return
				
				# Check if clicking on attachment points first
				var attachment_screen_pos = transform_world_to_screen(selected_body_part.attachment_point)
				var parent_attachment_screen_pos = transform_world_to_screen(selected_body_part.parent_attachment)
				
				var attachment_radius = 12.0  # Fixed click radius regardless of zoom
				var parent_radius = 10.0   # Fixed click radius regardless of zoom
				
				if mouse_pos.distance_to(attachment_screen_pos) <= attachment_radius:
					drawing_mode = "move_attachment"
					drag_offset = mouse_pos
					drag_start_world_pos = world_pos
					drag_original_point_pos = selected_body_part.attachment_point
				elif mouse_pos.distance_to(parent_attachment_screen_pos) <= parent_radius:
					drawing_mode = "move_parent_attachment"
					drag_offset = mouse_pos
					drag_start_world_pos = world_pos
					drag_original_point_pos = selected_body_part.parent_attachment
				else:
					# Check if clicking on existing polygon point
					var point_index = find_point_at_position(mouse_pos)
					if point_index >= 0:
						selected_point_index = point_index
						drawing_mode = "move_point"
						drag_offset = mouse_pos
						drag_start_world_pos = world_pos
						drag_original_point_pos = selected_body_part.polygon_points[point_index]
					else:
						# Check if clicking near edge to add point (prioritize this over moving)
						if is_point_near_polygon_edge(world_pos, selected_body_part.polygon_points, 15.0):
							# Add new point between closest nodes
							add_point_between_closest(world_pos)
							canvas.queue_redraw()
						else:
							# Check if clicking inside polygon area for moving the whole part
							if is_point_inside_polygon(world_pos, selected_body_part.polygon_points):
								drawing_mode = "move_part"
								dragging_part = true
								drag_offset = mouse_pos
								drag_start_world_pos = world_pos
								# Store original positions for accurate movement
								drag_original_polygon = selected_body_part.polygon_points.duplicate()
								drag_original_attachment = selected_body_part.attachment_point
								drag_original_parent_attachment = selected_body_part.parent_attachment
							else:
								# Clicking on empty canvas - start canvas panning
								is_canvas_panning = true
								canvas_pan_start = mouse_pos
								drawing_mode = "canvas_pan"
			else:
				# No selected body part - clicking on empty canvas starts panning
				is_canvas_panning = true
				canvas_pan_start = mouse_pos
				drawing_mode = "canvas_pan"
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if selected_body_part:
				var canvas_center = get_canvas_center()
				var world_pos = mouse_pos - canvas_center
				
				# Check if in zone painting mode - right-click deletes zones
				if zone_painting_mode:
					delete_variability_zone_at_position(world_pos)
					canvas.queue_redraw()
					return
				
				# Normal mode - right-click to delete polygon points
				var clicked_point = find_point_at_position(mouse_pos)
				if clicked_point >= 0 and selected_body_part.polygon_points.size() > 3:
					selected_body_part.polygon_points.remove_at(clicked_point)
					selected_point_index = -1
					canvas.queue_redraw()
					print("Deleted polygon point")
		
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			drawing_mode = "select"
			selected_point_index = -1
			dragging_part = false
			is_canvas_panning = false
	
	elif event is InputEventMouseMotion:
		# Handle middle mouse panning
		if is_panning:
			var movement = event.position - pan_start_pos
			pan_offset += movement / zoom_level  # Adjust for zoom level
			pan_start_pos = event.position
			canvas.queue_redraw()
			return
		
		# Handle canvas panning (left-click drag on empty space)
		if is_canvas_panning:
			var movement = event.position - canvas_pan_start
			pan_offset += movement
			canvas_pan_start = event.position
			canvas.queue_redraw()
			return
		
		# Handle dragging with accurate coordinate tracking
		if drawing_mode == "move_point" and selected_point_index >= 0 and selected_body_part:
			# Get current world position and calculate offset from drag start
			var current_world_pos = transform_screen_to_world(event.position)
			var world_movement = current_world_pos - drag_start_world_pos
			
			# Set point to original position plus total movement
			selected_body_part.polygon_points[selected_point_index] = drag_original_point_pos + world_movement
			canvas.queue_redraw()
			
		elif drawing_mode == "move_attachment" and selected_body_part:
			var current_world_pos = transform_screen_to_world(event.position)
			var world_movement = current_world_pos - drag_start_world_pos
			
			selected_body_part.attachment_point = drag_original_point_pos + world_movement
			canvas.queue_redraw()
			
		elif drawing_mode == "move_parent_attachment" and selected_body_part:
			var current_world_pos = transform_screen_to_world(event.position)
			var world_movement = current_world_pos - drag_start_world_pos
			
			selected_body_part.parent_attachment = drag_original_point_pos + world_movement
			canvas.queue_redraw()
			
		elif drawing_mode == "move_part" and dragging_part and selected_body_part:
			var current_world_pos = transform_screen_to_world(event.position)
			var world_movement = current_world_pos - drag_start_world_pos
			
			# Apply movement to all points relative to their original positions
			for i in range(selected_body_part.polygon_points.size()):
				selected_body_part.polygon_points[i] = drag_original_polygon[i] + world_movement
			
			# Move attachment points relative to their original positions
			selected_body_part.attachment_point = drag_original_attachment + world_movement
			selected_body_part.parent_attachment = drag_original_parent_attachment + world_movement
			
			canvas.queue_redraw()

func find_point_at_position(pos: Vector2) -> int:
	if not selected_body_part:
		return -1
	
	var click_radius = 10.0  # Fixed click radius regardless of zoom
	
	for i in range(selected_body_part.polygon_points.size()):
		var point_screen_pos = transform_world_to_screen(selected_body_part.polygon_points[i])
		if pos.distance_to(point_screen_pos) <= click_radius:
			return i
	
	return -1

func get_canvas_center() -> Vector2:
	return canvas.size / 2

# ==============================================================================
# ZOOM AND PAN SYSTEM
# ==============================================================================
func zoom_at_position(screen_pos: Vector2, zoom_delta: float):
	# Zoom in/out while keeping the point under the mouse cursor stationary
	var old_zoom = zoom_level
	zoom_level = clamp(zoom_level + zoom_delta, min_zoom, max_zoom)
	
	if zoom_level == old_zoom:
		return  # No change in zoom
	
	# Calculate the world position under the mouse before zoom
	var world_pos_before = transform_screen_to_world(screen_pos)
	
	# After zoom, calculate where that world position would be on screen
	var screen_pos_after = transform_world_to_screen(world_pos_before)
	
	# Adjust pan offset to keep the world position under the cursor
	var screen_delta = screen_pos - screen_pos_after
	pan_offset += screen_delta / zoom_level
	
	canvas.queue_redraw()
	print("Zoom: ", int(zoom_level * 100), "%")

func transform_screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convert screen coordinates to world coordinates (accounting for zoom and pan)
	var canvas_center = get_canvas_center()
	return (screen_pos - canvas_center - pan_offset) / zoom_level

func transform_world_to_screen(world_pos: Vector2) -> Vector2:
	# Convert world coordinates to screen coordinates (accounting for zoom and pan)
	var canvas_center = get_canvas_center()
	return world_pos * zoom_level + canvas_center + pan_offset

func reset_view():
	# Reset zoom and pan to default
	zoom_level = 1.0
	pan_offset = Vector2.ZERO
	canvas.queue_redraw()
	print("View reset to 100%")

func _on_canvas_draw():
	print("Canvas drawing - parts count: ", body_parts.size())
	
	# Draw grid first (background)
	if show_grid:
		draw_measurement_grid()
	
	draw_all_body_parts()
	# draw_connection_lines()  # Temporarily disabled - needs coordinate transformation fix
	draw_variability_zones()
	
	# Draw zone painting preview
	if zone_painting_mode and selected_body_part:
		draw_zone_painting_preview()

func draw_all_body_parts():
	# Draw all body parts with transparency using zoom/pan transforms
	for i in range(body_parts.size()):
		var part = body_parts[i]
		var is_selected = (part == selected_body_part)
		var alpha = 0.8 if is_selected else 0.3
		
		draw_body_part(part, alpha, is_selected)

func draw_body_part(part: BodyPart, alpha: float, is_selected: bool):
	if part.polygon_points.size() < 3:
		return
	
	# Transform polygon points to screen space with zoom/pan
	var screen_points = PackedVector2Array()
	for point in part.polygon_points:
		screen_points.append(transform_world_to_screen(point))
	
	# Get layer-specific colors
	var layer_color = get_layer_color(current_layer)
	
	# Draw filled polygon
	var fill_color = layer_color
	fill_color.a = alpha * 0.3
	canvas.draw_colored_polygon(screen_points, fill_color)
	
	# Draw outline
	var outline_color = layer_color
	outline_color.a = alpha
	var line_width = 3.0 if is_selected else 1.0
	canvas.draw_polyline(screen_points + PackedVector2Array([screen_points[0]]), outline_color, line_width)
	
	# Draw layer thickness indicator if selected
	if is_selected and part.layers.has(current_layer):
		draw_layer_thickness(screen_points, part, Vector2.ZERO)
	
	if is_selected:
		# Draw polygon points with consistent size (independent of zoom)
		var point_radius = 6.0  # Fixed size regardless of zoom
		for i in range(part.polygon_points.size()):
			var screen_pos = transform_world_to_screen(part.polygon_points[i])
			var color = Color.RED if i == selected_point_index else Color.WHITE
			canvas.draw_circle(screen_pos, point_radius, color)
			canvas.draw_circle(screen_pos, point_radius, Color.BLACK, false, 1.0)
		
		# Draw attachment point with consistent size
		var attachment_screen_pos = transform_world_to_screen(part.attachment_point)
		var attachment_radius = 8.0  # Fixed size regardless of zoom
		canvas.draw_circle(attachment_screen_pos, attachment_radius, Color.GREEN)
		canvas.draw_circle(attachment_screen_pos, attachment_radius, Color.BLACK, false, 2.0)
		
		# Draw parent attachment point with consistent size
		var parent_attachment_screen_pos = transform_world_to_screen(part.parent_attachment)
		var parent_radius = 6.0  # Fixed size regardless of zoom
		canvas.draw_circle(parent_attachment_screen_pos, parent_radius, Color.YELLOW)
		canvas.draw_circle(parent_attachment_screen_pos, parent_radius, Color.BLACK, false, 1.0)
		
		# Draw rotation constraints (disabled until joint limit UI is implemented)
		# if part.parent_part:
		#	draw_rotation_constraints(part, Vector2.ZERO)

func update_relationships_ui():
	if not selected_body_part:
		return
	
	# Update parent dropdown (if exists)
	if parent_option:
		parent_option.clear()
		parent_option.add_item("None", -1)
		
		for i in range(body_parts.size()):
			if body_parts[i] != selected_body_part:
				parent_option.add_item(body_parts[i].part_name, i)
		
		# Select current parent
		if selected_body_part.parent_part:
			var parent_index = body_parts.find(selected_body_part.parent_part)
			if parent_index >= 0:
				for j in range(parent_option.get_item_count()):
					if parent_option.get_item_id(j) == parent_index:
						parent_option.selected = j
						break
		else:
			parent_option.selected = 0  # "None"
	
	# Update children list (if exists)
	if children_list:
		children_list.clear()
		for child in selected_body_part.child_parts:
			children_list.add_item(child.part_name)

func _on_parent_selected(index: int):
	if not selected_body_part:
		return
	
	var parent_id = parent_option.get_item_id(index)
	
	# Remove from current parent if any
	if selected_body_part.parent_part:
		selected_body_part.parent_part.remove_child_part(selected_body_part)
	
	# Set new parent
	if parent_id >= 0 and parent_id < body_parts.size():
		var new_parent = body_parts[parent_id]
		new_parent.add_child_part(selected_body_part)
	
	update_relationships_ui()
	canvas.queue_redraw()

func _on_add_child_relationship():
	if not selected_body_part or body_parts.size() <= 1:
		return
	
	# Find a body part that isn't already a child and isn't the selected part
	for part in body_parts:
		if part != selected_body_part and part.parent_part != selected_body_part:
			selected_body_part.add_child_part(part)
			update_relationships_ui()
			canvas.queue_redraw()
			break

func draw_rotation_constraints(part: BodyPart, offset: Vector2):
	if not part.parent_part:
		return
	
	var parent_attachment_pos = part.parent_attachment + offset
	var constraint = part.rotation_limits
	var radius = 50.0
	
	# Draw constraint arc
	var start_angle = constraint.min_angle
	var end_angle = constraint.max_angle
	var arc_color = Color.LIGHT_BLUE
	arc_color.a = 0.5
	
	# Draw arc using multiple line segments
	var segments = 20
	var angle_step = (end_angle - start_angle) / segments
	var prev_point = parent_attachment_pos + Vector2(cos(start_angle), sin(start_angle)) * radius
	
	for i in range(1, segments + 1):
		var angle = start_angle + angle_step * i
		var current_point = parent_attachment_pos + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(prev_point, current_point, arc_color, 3.0)
		prev_point = current_point
	
	# Draw constraint limit lines
	var min_end = parent_attachment_pos + Vector2(cos(start_angle), sin(start_angle)) * radius
	var max_end = parent_attachment_pos + Vector2(cos(end_angle), sin(end_angle)) * radius
	var rest_end = parent_attachment_pos + Vector2(cos(constraint.rest_angle), sin(constraint.rest_angle)) * radius
	
	canvas.draw_line(parent_attachment_pos, min_end, Color.RED, 2.0)
	canvas.draw_line(parent_attachment_pos, max_end, Color.RED, 2.0)
	canvas.draw_line(parent_attachment_pos, rest_end, Color.GREEN, 2.0)
	
	# Draw handle circles for interactive editing
	canvas.draw_circle(min_end, 5.0, Color.RED)
	canvas.draw_circle(max_end, 5.0, Color.RED)
	canvas.draw_circle(rest_end, 5.0, Color.GREEN)

func update_constraints_ui():
	if not selected_body_part:
		return
	
	var constraint = selected_body_part.rotation_limits
	
	# Update constraint type selection (if exists)
	if constraint_type:
		match constraint.constraint_type:
			"hinge": constraint_type.selected = 0
			"ball_socket": constraint_type.selected = 1
			"fixed": constraint_type.selected = 2
			"twist": constraint_type.selected = 3
	
	# Update angle sliders (if they exist)
	if min_angle_slider:
		min_angle_slider.value = rad_to_deg(constraint.min_angle)
	if max_angle_slider:
		max_angle_slider.value = rad_to_deg(constraint.max_angle)
	if rest_angle_slider:
		rest_angle_slider.value = rad_to_deg(constraint.rest_angle)
	
	# Update labels (if they exist)
	if min_angle_label:
		min_angle_label.text = "Min Angle: %.0f°" % rad_to_deg(constraint.min_angle)
	if max_angle_label:
		max_angle_label.text = "Max Angle: %.0f°" % rad_to_deg(constraint.max_angle)
	if rest_angle_label:
		rest_angle_label.text = "Rest Angle: %.0f°" % rad_to_deg(constraint.rest_angle)

func _on_constraint_type_changed(index: int):
	if not selected_body_part:
		return
	
	match index:
		0: # Hinge
			selected_body_part.rotation_limits = RotationConstraint.create_hinge_constraint()
		1: # Ball Socket
			selected_body_part.rotation_limits = RotationConstraint.create_ball_socket_constraint()
		2: # Fixed
			selected_body_part.rotation_limits = RotationConstraint.create_fixed_constraint()
		3: # Twist
			selected_body_part.rotation_limits = RotationConstraint.create_twist_constraint()
	
	update_constraints_ui()
	canvas.queue_redraw()

func _on_min_angle_changed(value: float):
	if selected_body_part:
		selected_body_part.rotation_limits.min_angle = deg_to_rad(value)
		if min_angle_label:
			min_angle_label.text = "Min Angle: %.0f°" % value
		canvas.queue_redraw()

func _on_max_angle_changed(value: float):
	if selected_body_part:
		selected_body_part.rotation_limits.max_angle = deg_to_rad(value)
		if max_angle_label:
			max_angle_label.text = "Max Angle: %.0f°" % value
		canvas.queue_redraw()

func _on_rest_angle_changed(value: float):
	if selected_body_part:
		selected_body_part.rotation_limits.rest_angle = deg_to_rad(value)
		if rest_angle_label:
			rest_angle_label.text = "Rest Angle: %.0f°" % value
		canvas.queue_redraw()

# Layer-related functions
func get_layer_color(layer_name: String) -> Color:
	match layer_name:
		"equipment": return Color.PURPLE
		"armor": return Color.GRAY
		"clothes": return Color.BROWN
		"outer": return Color.ORANGE  # Fur/feathers/scales
		"skin": return Color.PINK
		"meat": return Color.RED
		"bone": return Color.WHITE
		"organs": return Color.DARK_RED
		_: return Color.BLUE

func draw_layer_thickness(screen_points: PackedVector2Array, part: BodyPart, offset: Vector2):
	var layer_data = part.layers.get(current_layer)
	if not layer_data or not layer_data is LayerData:
		return
	
	var thickness = layer_data.thickness
	var quality = layer_data.get_effective_quality()
	
	# Draw thickness as outward expansion
	var expanded_points = PackedVector2Array()
	var centroid = Vector2.ZERO
	
	# Calculate centroid
	for point in screen_points:
		centroid += point
	centroid /= screen_points.size()
	
	# Expand points outward from centroid
	for point in screen_points:
		var direction = (point - centroid).normalized()
		var expanded_point = point + direction * thickness * 5.0  # Scale for visibility
		expanded_points.append(expanded_point)
	
	# Draw thickness outline
	var thickness_color = get_layer_color(current_layer)
	thickness_color.a = 0.2 * quality  # Transparency based on quality
	canvas.draw_polyline(expanded_points + PackedVector2Array([expanded_points[0]]), thickness_color, 2.0)

func update_layers_ui():
	if not selected_body_part:
		return
	
	# Update current layer label
	if current_layer_label:
		current_layer_label.text = "Current Layer: " + current_layer.capitalize()
	
	# Get or create layer data
	var layer_data = get_or_create_layer_data(current_layer)
	
	# Update UI controls (if they exist)
	if material_edit:
		material_edit.text = layer_data.material_type
	if thickness_slider:
		thickness_slider.value = layer_data.thickness
	if quality_slider:
		quality_slider.value = layer_data.quality
	if damage_slider:
		damage_slider.value = layer_data.damage
	
	# Update labels (if they exist)
	if thickness_label:
		thickness_label.text = "Thickness: %.1f" % layer_data.thickness
	if quality_label:
		quality_label.text = "Quality: %.0f%%" % (layer_data.quality * 100)
	if damage_label:
		damage_label.text = "Damage: %.0f%%" % (layer_data.damage * 100)

func get_or_create_layer_data(layer_name: String) -> LayerData:
	# CRITICAL BUG FIX: Check if selected_body_part exists before accessing its properties
	if not selected_body_part:
		# Return a dummy layer data to prevent null errors
		var dummy_layer = LayerData.new()
		dummy_layer.material_type = get_default_material(layer_name)
		dummy_layer.thickness = get_default_thickness(layer_name)
		return dummy_layer
	
	if not selected_body_part.layers.has(layer_name) or not selected_body_part.layers[layer_name]:
		# Create default layer data
		var new_layer = LayerData.new()
		new_layer.material_type = get_default_material(layer_name)
		new_layer.thickness = get_default_thickness(layer_name)
		selected_body_part.layers[layer_name] = new_layer
	
	return selected_body_part.layers[layer_name]

func get_default_material(layer_name: String) -> String:
	match layer_name:
		"equipment": return "leather"
		"armor": return "iron"
		"clothes": return "cloth"
		"outer": return "fur"
		"skin": return "skin"
		"meat": return "meat"
		"bone": return "bone"
		"organs": return "organ"
		_: return "unknown"

func get_default_thickness(layer_name: String) -> float:
	match layer_name:
		"equipment": return 0.5
		"armor": return 2.0
		"clothes": return 0.3
		"outer": return 0.5
		"skin": return 0.2
		"meat": return 3.0
		"bone": return 1.5
		"organs": return 1.0
		_: return 1.0

# Layer UI callbacks
func _on_layer_selected(index: int):
	current_layer = layer_names[index]
	update_layers_ui()
	canvas.queue_redraw()

func _on_material_changed(new_material: String):
	# BUG FIX: Only modify layer data if we have a selected body part
	if not selected_body_part:
		return
	var layer_data = get_or_create_layer_data(current_layer)
	layer_data.material_type = new_material

func _on_thickness_changed(value: float):
	# BUG FIX: Only modify layer data if we have a selected body part
	if not selected_body_part:
		return
	var layer_data = get_or_create_layer_data(current_layer)
	layer_data.thickness = value
	if thickness_label:
		thickness_label.text = "Thickness: %.1f" % value
	canvas.queue_redraw()

func _on_quality_changed(value: float):
	# BUG FIX: Only modify layer data if we have a selected body part
	if not selected_body_part:
		return
	var layer_data = get_or_create_layer_data(current_layer)
	layer_data.quality = value
	if quality_label:
		quality_label.text = "Quality: %.0f%%" % (value * 100)
	canvas.queue_redraw()

func _on_damage_changed(value: float):
	# BUG FIX: Only modify layer data if we have a selected body part
	if not selected_body_part:
		return
	var layer_data = get_or_create_layer_data(current_layer)
	layer_data.damage = value
	if damage_label:
		damage_label.text = "Damage: %.0f%%" % (value * 100)
	canvas.queue_redraw()

func _on_snap_to_parent():
	if not selected_body_part or not selected_body_part.parent_part:
		print("No parent to snap to!")
		return
	
	# Get the parent's attachment point (green circle - where children connect)
	var parent = selected_body_part.parent_part
	var parent_attachment_world = parent.attachment_point
	
	# Get this part's parent attachment point (yellow circle - where it connects to parent)
	var child_parent_attachment = selected_body_part.parent_attachment
	
	# Calculate how much to move this part so the yellow circle overlaps the parent's green circle
	var movement_needed = parent_attachment_world - child_parent_attachment
	
	# Move the entire polygon
	for i in range(selected_body_part.polygon_points.size()):
		selected_body_part.polygon_points[i] += movement_needed
	
	# Move attachment points
	selected_body_part.attachment_point += movement_needed
	selected_body_part.parent_attachment += movement_needed
	
	canvas.queue_redraw()
	print("Snapped ", selected_body_part.part_name, "'s yellow circle to ", parent.part_name, "'s green circle")

func auto_position_child_parts():
	# Automatically position all child parts when a parent moves
	if not selected_body_part:
		return
	
	for child in selected_body_part.child_parts:
		# Position child so its parent_attachment aligns with this part's attachment_point
		var parent_attachment_world = selected_body_part.get_world_position() + selected_body_part.attachment_point
		var new_child_position = parent_attachment_world - child.parent_attachment
		
		# Move child polygon
		var offset = new_child_position - child.get_world_position()
		for i in range(child.polygon_points.size()):
			child.polygon_points[i] += offset
		
		# Move child attachment points
		child.attachment_point += offset
		child.parent_attachment += offset

func draw_connection_lines():
	# Draw lines showing parent-child connections
	for part in body_parts:
		if part.parent_part:
			var parent_attachment_world = part.parent_part.get_world_position() + part.parent_part.attachment_point
			var child_attachment_world = part.get_world_position() + part.parent_attachment
			
			var canvas_center = get_canvas_center()
			var parent_screen = parent_attachment_world + canvas_center
			var child_screen = child_attachment_world + canvas_center
			
			# Draw connection line
			canvas.draw_line(parent_screen, child_screen, Color.CYAN, 2.0)
			
			# Draw arrow pointing from parent to child
			var direction = (child_screen - parent_screen).normalized()
			var arrow_length = 15.0
			var arrow_angle = PI / 6  # 30 degrees
			
			var arrow_point1 = child_screen - direction * arrow_length
			var arrow_point2 = arrow_point1 + Vector2(cos(direction.angle() + arrow_angle), sin(direction.angle() + arrow_angle)) * arrow_length * 0.5
			var arrow_point3 = arrow_point1 + Vector2(cos(direction.angle() - arrow_angle), sin(direction.angle() - arrow_angle)) * arrow_length * 0.5
			
			canvas.draw_line(child_screen, arrow_point2, Color.CYAN, 2.0)
			canvas.draw_line(child_screen, arrow_point3, Color.CYAN, 2.0)

func add_point_between_closest(world_pos: Vector2):
	if selected_body_part.polygon_points.size() < 3:
		# Not enough points to form edges, just append
		selected_body_part.polygon_points.append(world_pos)
		return
	
	var closest_edge_start = 0
	var closest_distance = INF
	
	# Find the closest edge
	for i in range(selected_body_part.polygon_points.size()):
		var start_point = selected_body_part.polygon_points[i]
		var end_point = selected_body_part.polygon_points[(i + 1) % selected_body_part.polygon_points.size()]
		
		var distance = distance_point_to_line_segment(world_pos, start_point, end_point)
		if distance < closest_distance:
			closest_distance = distance
			closest_edge_start = i
	
	# Insert the new point after the start of the closest edge
	var insert_index = (closest_edge_start + 1) % selected_body_part.polygon_points.size()
	if insert_index == 0:
		# Insert at the end instead of index 0 to maintain order
		selected_body_part.polygon_points.append(world_pos)
	else:
		selected_body_part.polygon_points.insert(insert_index, world_pos)
	
	print("Added point between nodes ", closest_edge_start, " and ", (closest_edge_start + 1) % (selected_body_part.polygon_points.size() - 1))

func distance_point_to_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var line_length_squared = line_vec.length_squared()
	
	if line_length_squared == 0.0:
		# Line is just a point
		return point.distance_to(line_start)
	
	# Project point onto line
	var t = (point - line_start).dot(line_vec) / line_length_squared
	t = clamp(t, 0.0, 1.0)  # Clamp to line segment
	
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

func is_point_inside_polygon(point: Vector2, polygon_points: PackedVector2Array) -> bool:
	if polygon_points.size() < 3:
		return false
	
	var inside = false
	var j = polygon_points.size() - 1
	
	for i in range(polygon_points.size()):
		var vi = polygon_points[i]
		var vj = polygon_points[j]
		
		if ((vi.y > point.y) != (vj.y > point.y)) and (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x):
			inside = !inside
		j = i
	
	return inside

func is_point_near_polygon_edge(point: Vector2, polygon_points: PackedVector2Array, threshold: float = 10.0) -> bool:
	if polygon_points.size() < 2:
		return false
	
	for i in range(polygon_points.size()):
		var start_point = polygon_points[i]
		var end_point = polygon_points[(i + 1) % polygon_points.size()]
		var distance = distance_point_to_line_segment(point, start_point, end_point)
		if distance <= threshold:
			return true
	
	return false

# ==============================================================================
# VARIABILITY ZONE SYSTEM
# ==============================================================================
func paint_variability_zone(world_pos: Vector2):
	if not selected_body_part:
		return
	
	# Check if we're inside the polygon
	if not is_point_inside_polygon(world_pos, selected_body_part.polygon_points):
		return
	
	# Find affected polygon points within radius
	var affected_points: Array[int] = []
	for i in range(selected_body_part.polygon_points.size()):
		var point = selected_body_part.polygon_points[i]
		if world_pos.distance_to(point) <= zone_radius:
			affected_points.append(i)
	
	if affected_points.size() == 0:
		return
	
	# Create new variability zone
	var new_zone = VariabilityZone.new()
	new_zone.center_position = world_pos
	new_zone.radius = zone_radius
	new_zone.max_expansion = zone_expansion
	new_zone.affected_points = affected_points
	new_zone.expansion_factor = 1.0  # Default, can be adjusted later
	
	selected_body_part.variability_zones.append(new_zone)
	print("Added variability zone at ", world_pos, " affecting ", affected_points.size(), " points")

func toggle_zone_painting_mode():
	zone_painting_mode = !zone_painting_mode
	print("Zone painting mode: ", "ON" if zone_painting_mode else "OFF")

func clear_variability_zones():
	if selected_body_part:
		selected_body_part.variability_zones.clear()
		canvas.queue_redraw()
		print("Cleared all variability zones")

func draw_variability_zones():
	if not selected_body_part:
		return
	
	var canvas_center = get_canvas_center()
	
	# Draw existing zones
	for zone in selected_body_part.variability_zones:
		var screen_pos = zone.center_position + canvas_center
		var zone_color = Color.CYAN
		zone_color.a = 0.3
		
		# Draw zone circle
		canvas.draw_circle(screen_pos, zone.radius, zone_color)
		canvas.draw_circle(screen_pos, zone.radius, Color.CYAN, false, 2.0)
		
		# Draw affected points
		for point_index in zone.affected_points:
			if point_index < selected_body_part.polygon_points.size():
				var point_screen = selected_body_part.polygon_points[point_index] + canvas_center
				canvas.draw_circle(point_screen, 4.0, Color.MAGENTA)
		
		# Draw expansion preview if zone has expansion > 1
		if zone.expansion_factor > 1.0:
			draw_zone_expansion_preview(zone, canvas_center)

func draw_zone_expansion_preview(zone: VariabilityZone, offset: Vector2):
	var centroid = selected_body_part.get_polygon_centroid()
	
	for point_index in zone.affected_points:
		if point_index < selected_body_part.polygon_points.size():
			var original_point = selected_body_part.polygon_points[point_index]
			var direction = (original_point - centroid).normalized()
			var expansion = (zone.expansion_factor - 1.0) * zone.max_expansion
			var expanded_point = original_point + direction * expansion
			
			var original_screen = original_point + offset
			var expanded_screen = expanded_point + offset
			
			# Draw expansion line
			canvas.draw_line(original_screen, expanded_screen, Color.ORANGE, 2.0)
			canvas.draw_circle(expanded_screen, 3.0, Color.ORANGE)

func draw_zone_painting_preview():
	# Draw a preview circle at mouse position when in zone painting mode
	var mouse_pos = canvas.get_local_mouse_position()
	var canvas_center = get_canvas_center()
	var world_pos = mouse_pos - canvas_center
	
	# Only show preview if inside polygon
	if is_point_inside_polygon(world_pos, selected_body_part.polygon_points):
		var preview_color = Color.YELLOW
		preview_color.a = 0.3
		canvas.draw_circle(mouse_pos, zone_radius, preview_color)
		canvas.draw_circle(mouse_pos, zone_radius, Color.YELLOW, false, 2.0)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_Z:
				if event.ctrl_pressed:
					toggle_zone_painting_mode()
					canvas.queue_redraw()
			KEY_C:
				if event.ctrl_pressed and zone_painting_mode:
					clear_variability_zones()
			KEY_S:
				if event.ctrl_pressed:
					_on_save_template_button()  # Use the UI handler for consistency
			KEY_L:
				if event.ctrl_pressed:
					show_load_template_dialog()
			KEY_G:
				if event.ctrl_pressed:
					toggle_grid()
			KEY_R:
				if event.ctrl_pressed:
					reset_view()
			KEY_D:
				if event.ctrl_pressed:
					_on_clone_body_part()
			KEY_ESCAPE:
				if zone_painting_mode:
					zone_painting_mode = false
					canvas.queue_redraw()

# ==============================================================================
# TEMPLATE SAVE/LOAD SYSTEM
# ==============================================================================
func save_current_template(template_name: String = ""):
	print("=== SAVE TEMPLATE DEBUG ===")
	print("Body parts count: ", body_parts.size())
	
	if body_parts.size() == 0:
		print("❌ No entity to save!")
		return
	
	var entity_data = {
		"name": template_name if template_name != "" else "Unnamed_Entity",
		"parts": [],
		"created_at": Time.get_datetime_string_from_system()
	}
	
	print("Template name: ", entity_data.name)
	
	# Save all body parts
	for part in body_parts:
		var part_data = serialize_body_part(part)
		entity_data.parts.append(part_data)
		print("Serialized part: ", part.part_name)
	
	# Save to templates directory
	var templates_dir = "user://templates/"
	print("Templates directory: ", templates_dir)
	
	if not DirAccess.dir_exists_absolute(templates_dir):
		print("Creating templates directory...")
		var result = DirAccess.open("user://").make_dir("templates")
		print("Directory creation result: ", result)
	
	var file_path = templates_dir + entity_data.name + ".json"
	print("Saving to: ", file_path)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(entity_data, "\t")
		file.store_string(json_string)
		file.close()
		print("✅ Saved template: ", entity_data.name)
		print("File size: ", FileAccess.get_file_as_bytes(file_path).size(), " bytes")
	else:
		print("❌ Failed to save template!")
	print("=== END SAVE DEBUG ===")

func serialize_body_part(part: BodyPart) -> Dictionary:
	var part_data = {
		"part_name": part.part_name,
		"polygon_points": [],
		"attachment_point": [part.attachment_point.x, part.attachment_point.y],
		"parent_attachment": [part.parent_attachment.x, part.parent_attachment.y],
		"layers": {},
		"variability_zones": [],
		"parent_name": part.parent_part.part_name if part.parent_part else "",
		"child_names": []
	}
	
	# Serialize polygon points
	for point in part.polygon_points:
		part_data.polygon_points.append([point.x, point.y])
	
	# Serialize child names
	for child in part.child_parts:
		part_data.child_names.append(child.part_name)
	
	# Serialize layers
	for layer_name in part.layers:
		var layer_data = part.layers[layer_name]
		if layer_data is LayerData:
			part_data.layers[layer_name] = {
				"material_type": layer_data.material_type,
				"thickness": layer_data.thickness,
				"quality": layer_data.quality,
				"damage": layer_data.damage,
				"volume": layer_data.volume
			}
	
	# Serialize variability zones
	for zone in part.variability_zones:
		var zone_data = {
			"zone_name": zone.zone_name,
			"center_position": [zone.center_position.x, zone.center_position.y],
			"radius": zone.radius,
			"affected_points": zone.affected_points,
			"expansion_factor": zone.expansion_factor,
			"max_expansion": zone.max_expansion,
			"growth_rate": zone.growth_rate,
			"zone_type": zone.zone_type
		}
		part_data.variability_zones.append(zone_data)
	
	return part_data

func load_template(template_name: String):
	print("=== LOAD TEMPLATE DEBUG ===")
	print("Loading template: ", template_name)
	
	var file_path = "user://templates/" + template_name + ".json"
	print("File path: ", file_path)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("❌ Template not found: ", template_name)
		return
	
	var json_string = file.get_as_text()
	file.close()
	print("JSON length: ", json_string.length(), " characters")
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("❌ Failed to parse template JSON!")
		return
	
	var entity_data = json.data
	print("Template data name: ", entity_data.get("name", "unknown"))
	print("Parts count: ", entity_data.get("parts", []).size())
	
	# Clear current entity
	clear_current_entity()
	print("Cleared current entity")
	
	# Load body parts
	var part_lookup = {}  # name -> BodyPart for setting up relationships
	
	for part_data in entity_data.parts:
		var new_part = deserialize_body_part(part_data)
		body_parts.append(new_part)
		part_lookup[new_part.part_name] = new_part
		body_parts_list.add_item(new_part.part_name)
		print("Loaded part: ", new_part.part_name)
	
	# Set up parent-child relationships
	for i in range(entity_data.parts.size()):
		var part_data = entity_data.parts[i]
		var part = body_parts[i]
		
		# Set parent
		if part_data.parent_name != "":
			var parent = part_lookup.get(part_data.parent_name)
			if parent:
				parent.add_child_part(part)
				print("Set parent: ", part.part_name, " -> ", parent.part_name)
		
		# Children are automatically set up by parent relationships
	
	# Select first part if any
	if body_parts.size() > 0:
		body_parts_list.select(0)
		_on_body_part_selected(0)
		print("Selected first part: ", body_parts[0].part_name)
	
	canvas.queue_redraw()
	print("✅ Loaded template: ", entity_data.name)
	print("=== END LOAD DEBUG ===")

func deserialize_body_part(part_data: Dictionary) -> BodyPart:
	var part = BodyPart.new()
	part.part_name = part_data.part_name
	
	# Deserialize polygon points
	for point_array in part_data.polygon_points:
		part.polygon_points.append(Vector2(point_array[0], point_array[1]))
	
	# Deserialize attachment points
	part.attachment_point = Vector2(part_data.attachment_point[0], part_data.attachment_point[1])
	part.parent_attachment = Vector2(part_data.parent_attachment[0], part_data.parent_attachment[1])
	
	# Deserialize layers
	for layer_name in part_data.layers:
		var layer_info = part_data.layers[layer_name]
		var layer_data = LayerData.new()
		layer_data.material_type = layer_info.material_type
		layer_data.thickness = layer_info.thickness
		layer_data.quality = layer_info.quality
		layer_data.damage = layer_info.damage
		layer_data.volume = layer_info.volume
		part.layers[layer_name] = layer_data
	
	# Deserialize variability zones
	for zone_info in part_data.variability_zones:
		var zone = VariabilityZone.new()
		zone.zone_name = zone_info.zone_name
		zone.center_position = Vector2(zone_info.center_position[0], zone_info.center_position[1])
		zone.radius = zone_info.radius
		zone.affected_points = zone_info.affected_points
		zone.expansion_factor = zone_info.expansion_factor
		zone.max_expansion = zone_info.max_expansion
		zone.growth_rate = zone_info.growth_rate
		zone.zone_type = zone_info.zone_type
		part.variability_zones.append(zone)
	
	return part

func clear_current_entity():
	body_parts.clear()
	selected_body_part = null
	body_parts_list.clear()
	canvas.queue_redraw()

func get_available_templates() -> Array[String]:
	var templates: Array[String] = []
	var dir = DirAccess.open("user://templates/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				templates.append(file_name.trim_suffix(".json"))
			file_name = dir.get_next()
	return templates

func show_load_template_dialog():
	var templates = get_available_templates()
	if templates.size() == 0:
		print("No templates found!")
		return
	
	print("Available templates:")
	for i in range(templates.size()):
		print(str(i + 1) + ". " + templates[i])
	print("Use load_template(name) to load a specific template")

# ==============================================================================
# TEMPLATE UI HANDLERS
# ==============================================================================
func _on_save_template_button():
	# Get template name from UI field, fallback to auto-generated name
	var template_name = template_name_edit.text.strip_edges()
	if template_name == "":
		template_name = "Entity_" + Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
		template_name_edit.text = template_name
	
	save_current_template(template_name)
	update_template_list()

func _on_load_template_button():
	# Load the selected template from the list
	var selected_items = template_list.get_selected_items()
	if selected_items.size() == 0:
		print("No template selected! Select a template from the list first.")
		return
	
	var selected_index = selected_items[0]
	var template_name = template_list.get_item_text(selected_index)
	load_template(template_name)

func _on_template_selected(index: int):
	# Auto-fill the template name field when selecting from list
	var template_name = template_list.get_item_text(index)
	template_name_edit.text = template_name

func update_template_list():
	# Refresh the template list UI with available templates
	template_list.clear()
	var templates = get_available_templates()
	for template in templates:
		template_list.add_item(template)
	
	print("Updated template list - found ", templates.size(), " templates")

func _on_delete_template_button():
	# Delete the selected template from the list
	var selected_items = template_list.get_selected_items()
	if selected_items.size() == 0:
		print("No template selected! Select a template from the list first.")
		return
	
	var selected_index = selected_items[0]
	var template_name = template_list.get_item_text(selected_index)
	
	# Confirm deletion (simple console confirmation for now)
	print("Deleting template: ", template_name)
	
	var file_path = "user://templates/" + template_name + ".json"
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("✅ Deleted template: ", template_name)
		template_name_edit.text = ""  # Clear the name field
		update_template_list()  # Refresh the list
	else:
		print("❌ Template file not found: ", file_path)

# ==============================================================================
# VARIABILITY ZONE DELETION SYSTEM
# ==============================================================================
func delete_variability_zone_at_position(world_pos: Vector2):
	# Delete variability zone at the specified world position
	if not selected_body_part:
		return
	
	# Find the zone that contains this position
	var zone_to_delete = null
	for i in range(selected_body_part.variability_zones.size()):
		var zone = selected_body_part.variability_zones[i]
		if zone.center_position.distance_to(world_pos) <= zone.radius:
			zone_to_delete = zone
			break
	
	if zone_to_delete:
		selected_body_part.variability_zones.erase(zone_to_delete)
		print("✅ Deleted variability zone at ", zone_to_delete.center_position)
	else:
		print("No variability zone found at position ", world_pos)

# ==============================================================================
# MEASUREMENT GRID SYSTEM
# ==============================================================================
func draw_measurement_grid():
	# Draw a measurement grid with decimeter marks and meter major lines
	# 1 grid unit = 1 decimeter = 10cm for realistic character scaling
	
	var canvas_size = canvas.size
	var scaled_grid_size = grid_unit_size * zoom_level
	
	# Calculate grid bounds based on zoom level
	var units_x = int(canvas_size.x / scaled_grid_size) + 4
	var units_y = int(canvas_size.y / scaled_grid_size) + 4
	
	# Calculate starting positions with pan offset
	var origin_screen = transform_world_to_screen(Vector2.ZERO)
	var start_x = origin_screen.x - (units_x * scaled_grid_size / 2)
	var start_y = origin_screen.y - (units_y * scaled_grid_size / 2)
	
	# Draw vertical lines (decimeters and meters)
	for i in range(units_x + 1):
		var x_pos = start_x + i * scaled_grid_size
		if x_pos < -scaled_grid_size or x_pos > canvas_size.x + scaled_grid_size:
			continue
		
		# Calculate world grid position to determine line type
		var world_x = (i - units_x / 2) * grid_unit_size
		var is_meter_line = (int(world_x) % 100) == 0  # Every meter (100 units)
		var is_origin = abs(world_x) < 0.5  # Origin line
		
		var line_color = grid_color_origin if is_origin else (grid_color_major if is_meter_line else grid_color_minor)
		var line_width = 2.0 if is_origin else (1.5 if is_meter_line else 1.0)  # Fixed width regardless of zoom
		
		canvas.draw_line(
			Vector2(x_pos, 0),
			Vector2(x_pos, canvas_size.y),
			line_color,
			line_width
		)
	
	# Draw horizontal lines (decimeters and meters)
	for i in range(units_y + 1):
		var y_pos = start_y + i * scaled_grid_size
		if y_pos < -scaled_grid_size or y_pos > canvas_size.y + scaled_grid_size:
			continue
		
		# Calculate world grid position to determine line type
		var world_y = (i - units_y / 2) * grid_unit_size
		var is_meter_line = (int(world_y) % 100) == 0  # Every meter (100 units)
		var is_origin = abs(world_y) < 0.5  # Origin line
		
		var line_color = grid_color_origin if is_origin else (grid_color_major if is_meter_line else grid_color_minor)
		var line_width = 2.0 if is_origin else (1.5 if is_meter_line else 1.0)  # Fixed width regardless of zoom
		
		canvas.draw_line(
			Vector2(0, y_pos),
			Vector2(canvas_size.x, y_pos),
			line_color,
			line_width
		)
	
	# Draw grid toggle button in the corner
	draw_grid_toggle_button()

func draw_grid_toggle_button():
	# Draw a grid toggle button in the bottom-left corner
	var button_size = Vector2(60, 30)
	var corner_margin = 15.0
	var button_pos = Vector2(corner_margin, canvas.size.y - corner_margin - button_size.y)
	
	# Button background color based on grid state
	var bg_color = Color(0.3, 0.3, 0.3, 0.8) if show_grid else Color(0.15, 0.15, 0.15, 0.8)
	var border_color = Color(0.6, 0.6, 0.6, 1.0) if show_grid else Color(0.4, 0.4, 0.4, 1.0)
	
	# Draw button background
	canvas.draw_rect(Rect2(button_pos, button_size), bg_color)
	
	# Draw button border
	var border_width = 2.0
	canvas.draw_rect(Rect2(button_pos, button_size), border_color, false, border_width)
	
	# Draw grid icon (simplified grid pattern)
	var icon_margin = 8.0
	var icon_pos = button_pos + Vector2(icon_margin, icon_margin)
	var icon_size = button_size - Vector2(icon_margin * 2, icon_margin * 2)
	var icon_color = Color.WHITE if show_grid else Color.GRAY
	
	# Draw a simple 3x3 grid icon
	var grid_step = icon_size / 3.0
	for i in range(4):  # 4 lines for 3x3 grid
		# Vertical lines
		var x = icon_pos.x + i * grid_step.x
		canvas.draw_line(Vector2(x, icon_pos.y), Vector2(x, icon_pos.y + icon_size.y), icon_color, 1.0)
		# Horizontal lines  
		var y = icon_pos.y + i * grid_step.y
		canvas.draw_line(Vector2(icon_pos.x, y), Vector2(icon_pos.x + icon_size.x, y), icon_color, 1.0)
	
	# Store button rect for click detection
	grid_toggle_button_rect = Rect2(button_pos, button_size)

func toggle_grid():
	# Toggle grid visibility
	show_grid = !show_grid
	canvas.queue_redraw()
	print("Grid ", "enabled" if show_grid else "disabled")

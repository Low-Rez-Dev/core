extends Control

@onready var add_part_button = $VBoxContainer/HSplitContainer/LeftPanel/Controls/AddPartButton
@onready var delete_part_button = $VBoxContainer/HSplitContainer/LeftPanel/Controls/DeletePartButton
@onready var body_parts_list = $VBoxContainer/HSplitContainer/LeftPanel/BodyPartsList
@onready var part_name_edit = $VBoxContainer/HSplitContainer/LeftPanel/PropertiesPanel/PartNameEdit
@onready var select_mode_button = $VBoxContainer/HSplitContainer/LeftPanel/PropertiesPanel/EditModeButtons/SelectModeButton
@onready var add_point_mode_button = $VBoxContainer/HSplitContainer/LeftPanel/PropertiesPanel/EditModeButtons/AddPointModeButton
@onready var attach_mode_button = $VBoxContainer/HSplitContainer/LeftPanel/PropertiesPanel/EditModeButtons/AttachModeButton
@onready var canvas = $VBoxContainer/HSplitContainer/RightPanel/Canvas

var body_parts: Array[BodyPart] = []
var selected_body_part: BodyPart = null
var selected_body_part_index: int = -1
var edit_mode: String = "select"  # "select", "add_point", "attachment"
var selected_point_index: int = -1
var dragging_point: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready():
	add_part_button.pressed.connect(_on_add_part)
	delete_part_button.pressed.connect(_on_delete_part)
	body_parts_list.item_selected.connect(_on_body_part_selected)
	part_name_edit.text_changed.connect(_on_part_name_changed)
	select_mode_button.pressed.connect(func(): _set_edit_mode("select"))
	add_point_mode_button.pressed.connect(func(): _set_edit_mode("add_point"))
	attach_mode_button.pressed.connect(func(): _set_edit_mode("attachment"))
	canvas.gui_input.connect(_on_canvas_input)

func _draw():
	if not body_parts.is_empty():
		draw_body_parts()

func draw_body_parts():
	var canvas_center = canvas.size / 2
	
	for i in range(body_parts.size()):
		var part = body_parts[i]
		var is_selected = (i == selected_body_part_index)
		
		if part.polygon_points.size() >= 3:
			var screen_points = PackedVector2Array()
			for point in part.polygon_points:
				screen_points.append(point + canvas_center)
			
			# Draw filled polygon
			var fill_color = Color.CYAN if is_selected else Color.BLUE
			fill_color.a = 0.3
			canvas.draw_colored_polygon(screen_points, fill_color)
			
			# Draw outline
			var outline_color = Color.CYAN if is_selected else Color.BLUE
			var line_width = 3.0 if is_selected else 1.0
			canvas.draw_polyline(screen_points + PackedVector2Array([screen_points[0]]), outline_color, line_width)
		
		# Draw points if selected
		if is_selected:
			for j in range(part.polygon_points.size()):
				var screen_pos = part.polygon_points[j] + canvas_center
				var point_color = Color.RED if j == selected_point_index else Color.WHITE
				canvas.draw_circle(screen_pos, 6.0, point_color)
				canvas.draw_circle(screen_pos, 6.0, Color.BLACK, false, 1.0)
			
		# Draw attachment points (always visible for selected part)
		if is_selected:
			var attachment_pos = part.attachment_point + canvas_center
			var parent_attachment_pos = part.parent_attachment + canvas_center
			
			# Draw attachment point (green - where children connect)
			var attach_color = Color.LIME if edit_mode == "attachment" else Color.GREEN
			canvas.draw_circle(attachment_pos, 8.0, attach_color)
			canvas.draw_circle(attachment_pos, 8.0, Color.BLACK, false, 2.0)
			
			# Draw parent attachment point (yellow - where this part connects to parent)
			var parent_attach_color = Color.YELLOW if edit_mode == "attachment" else Color.ORANGE
			canvas.draw_circle(parent_attachment_pos, 6.0, parent_attach_color)
			canvas.draw_circle(parent_attachment_pos, 6.0, Color.BLACK, false, 1.0)

func _on_add_part():
	var new_part = BodyPart.new()
	new_part.part_name = "Part " + str(body_parts.size() + 1)
	new_part.polygon_points = PackedVector2Array([
		Vector2(-50, -50),
		Vector2(50, -50),
		Vector2(50, 50),
		Vector2(-50, 50)
	])
	
	body_parts.append(new_part)
	body_parts_list.add_item(new_part.part_name)
	queue_redraw()
	print("Added part: ", new_part.part_name)

func _on_delete_part():
	if selected_body_part_index >= 0:
		body_parts.remove_at(selected_body_part_index)
		body_parts_list.remove_item(selected_body_part_index)
		selected_body_part_index = -1
		selected_body_part = null
		part_name_edit.text = ""
		queue_redraw()

func _on_body_part_selected(index: int):
	selected_body_part_index = index
	selected_body_part = body_parts[index]
	part_name_edit.text = selected_body_part.part_name
	queue_redraw()

func _on_part_name_changed(new_name: String):
	if selected_body_part:
		selected_body_part.part_name = new_name
		body_parts_list.set_item_text(selected_body_part_index, new_name)

func _set_edit_mode(mode: String):
	edit_mode = mode
	select_mode_button.button_pressed = (mode == "select")
	add_point_mode_button.button_pressed = (mode == "add_point")
	attach_mode_button.button_pressed = (mode == "attachment")
	selected_point_index = -1
	dragging_point = false
	queue_redraw()
	print("Edit mode: ", mode)

func _on_canvas_input(event: InputEvent):
	if not selected_body_part:
		return
	
	var canvas_center = canvas.size / 2
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if edit_mode == "add_point":
					# Add new point to polygon
					var world_pos = event.position - canvas_center
					selected_body_part.polygon_points.append(world_pos)
					queue_redraw()
					print("Added point at: ", world_pos)
				
				elif edit_mode == "select":
					# Check if clicking on existing point
					var clicked_point = find_point_at_position(event.position, canvas_center)
					if clicked_point >= 0:
						selected_point_index = clicked_point
						dragging_point = true
						drag_offset = event.position - (selected_body_part.polygon_points[clicked_point] + canvas_center)
						queue_redraw()
					else:
						selected_point_index = -1
						queue_redraw()
				
				elif edit_mode == "attachment":
					# Check if clicking on attachment points
					var attachment_pos = selected_body_part.attachment_point + canvas_center
					var parent_attachment_pos = selected_body_part.parent_attachment + canvas_center
					
					if event.position.distance_to(attachment_pos) <= 12.0:
						# Start dragging attachment point
						selected_point_index = -100  # Special value for attachment point
						dragging_point = true
						drag_offset = event.position - attachment_pos
						print("Dragging attachment point")
					elif event.position.distance_to(parent_attachment_pos) <= 10.0:
						# Start dragging parent attachment point
						selected_point_index = -101  # Special value for parent attachment
						dragging_point = true
						drag_offset = event.position - parent_attachment_pos
						print("Dragging parent attachment point")
			else:
				# Mouse button released
				dragging_point = false
	
	elif event is InputEventMouseMotion and dragging_point:
		if edit_mode == "select" and selected_point_index >= 0:
			selected_body_part.polygon_points[selected_point_index] = event.position - canvas_center - drag_offset
			queue_redraw()
		elif edit_mode == "attachment":
			if selected_point_index == -100:  # Attachment point
				selected_body_part.attachment_point = event.position - canvas_center - drag_offset
				queue_redraw()
			elif selected_point_index == -101:  # Parent attachment point
				selected_body_part.parent_attachment = event.position - canvas_center - drag_offset
				queue_redraw()

func find_point_at_position(pos: Vector2, canvas_center: Vector2) -> int:
	if not selected_body_part:
		return -1
	
	var click_radius = 10.0
	for i in range(selected_body_part.polygon_points.size()):
		var point_screen_pos = selected_body_part.polygon_points[i] + canvas_center
		if pos.distance_to(point_screen_pos) <= click_radius:
			return i
	
	return -1
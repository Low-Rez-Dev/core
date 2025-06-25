extends Control

@onready var add_button = $VBox/Controls/AddButton
@onready var clear_button = $VBox/Controls/ClearButton
@onready var canvas = $VBox/Canvas

# Simple data structure without Resource inheritance
var shapes: Array[Dictionary] = []
var selected_shape_index: int = -1

func _ready():
	add_button.pressed.connect(_on_add_shape)
	clear_button.pressed.connect(_on_clear_all)
	canvas.gui_input.connect(_on_canvas_input)

func _draw():
	if not shapes.is_empty():
		draw_shapes()

func draw_shapes():
	var center = canvas.size / 2
	
	for i in range(shapes.size()):
		var shape = shapes[i]
		var points = shape.get("points", [])
		
		if points.size() >= 3:
			var screen_points = PackedVector2Array()
			for point in points:
				screen_points.append(Vector2(point.x, point.y) + center)
			
			var color = Color.CYAN if i == selected_shape_index else Color.BLUE
			color.a = 0.3
			canvas.draw_colored_polygon(screen_points, color)
			
			var outline_color = Color.CYAN if i == selected_shape_index else Color.BLUE
			canvas.draw_polyline(screen_points + PackedVector2Array([screen_points[0]]), outline_color, 2.0)
			
			# Draw points if selected
			if i == selected_shape_index:
				for point in screen_points:
					canvas.draw_circle(point, 5.0, Color.WHITE)

func _on_add_shape():
	var new_shape = {
		"name": "Shape " + str(shapes.size() + 1),
		"points": [
			{"x": -50, "y": -50},
			{"x": 50, "y": -50},
			{"x": 50, "y": 50},
			{"x": -50, "y": 50}
		]
	}
	
	shapes.append(new_shape)
	selected_shape_index = shapes.size() - 1
	queue_redraw()
	print("Added shape: ", new_shape.name)

func _on_clear_all():
	shapes.clear()
	selected_shape_index = -1
	queue_redraw()
	print("Cleared all shapes")

func _on_canvas_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Simple click to add point to current shape
			if selected_shape_index >= 0:
				var center = canvas.size / 2
				var world_pos = event.position - center
				shapes[selected_shape_index]["points"].append({"x": world_pos.x, "y": world_pos.y})
				queue_redraw()
				print("Added point at: ", world_pos)
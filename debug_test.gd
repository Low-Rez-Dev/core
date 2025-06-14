extends Node2D

func _ready():
	print("Debug test starting...")

func _draw():
	print("_draw() called!")
	# Draw a simple red circle to test basic drawing
	draw_circle(Vector2(100, 100), 50, Color.RED)
	
	# Draw a blue rectangle
	draw_rect(Rect2(200, 200, 100, 150), Color.BLUE)
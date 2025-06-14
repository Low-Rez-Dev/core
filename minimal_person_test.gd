extends Node2D

func _ready():
	print("Minimal person test starting...")

func _draw():
	print("Drawing minimal person...")
	
	# Draw a simple stick figure manually
	var center = Vector2(300, 300)
	
	# Head
	draw_circle(center + Vector2(0, -60), 20, Color(0.9, 0.8, 0.7))
	
	# Body
	draw_rect(Rect2(center.x - 15, center.y - 30, 30, 60), Color(0.3, 0.4, 0.8))
	
	# Arms
	draw_rect(Rect2(center.x - 40, center.y - 20, 25, 10), Color(0.3, 0.4, 0.8))
	draw_rect(Rect2(center.x + 15, center.y - 20, 25, 10), Color(0.3, 0.4, 0.8))
	
	# Legs
	draw_rect(Rect2(center.x - 15, center.y + 30, 10, 40), Color(0.3, 0.4, 0.8))
	draw_rect(Rect2(center.x + 5, center.y + 30, 10, 40), Color(0.3, 0.4, 0.8))
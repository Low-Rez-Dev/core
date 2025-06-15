extends GridEntity
class_name TestTree

@export var tree_color: Color = Color(0.15, 0.1, 0.08)   # Dark pottery paint
@export var trunk_color: Color = Color(0.2, 0.15, 0.12)  # Medium pottery shade

func _ready():
	super._ready()

func _draw():
	# Draw a simple tree
	var render_props = {}
	if focus_lane_system:
		render_props = focus_lane_system.get_entity_render_properties(grid_position_3d)
	
	if render_props.get("visible", true):
		var alpha = render_props.get("alpha", 1.0)
		var scale_factor = render_props.get("scale", 1.0)
		
		# Tree trunk
		var trunk_rect = Rect2(-5 * scale_factor, -20 * scale_factor, 10 * scale_factor, 40 * scale_factor)
		draw_rect(trunk_rect, Color(trunk_color.r, trunk_color.g, trunk_color.b, alpha))
		
		# Tree leaves (circle)
		var leaf_radius = 15 * scale_factor
		draw_circle(Vector2(0, -20 * scale_factor), leaf_radius, Color(tree_color.r, tree_color.g, tree_color.b, alpha))

func set_render_properties(props: Dictionary):
	super.set_render_properties(props)
	queue_redraw()  # Redraw with new properties
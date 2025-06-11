extends Control
class_name SolipsisticHUD

# HUD elements
var coordinate_label: Label
var physics_label: Label
var orientation_label: Label
var controls_label: Label

func _ready():
	# Set up HUD layout
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	
	create_hud_elements()

func create_hud_elements():
	"""Create all HUD display elements"""
	
	# Main coordinates display (top-left)
	coordinate_label = Label.new()
	coordinate_label.position = Vector2(10, 10)
	coordinate_label.size = Vector2(300, 100)
	coordinate_label.add_theme_color_override("font_color", Color.WHITE)
	coordinate_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	coordinate_label.add_theme_constant_override("shadow_offset_x", 1)
	coordinate_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(coordinate_label)
	
	# Physics info display (top-left, below coordinates)
	physics_label = Label.new()
	physics_label.position = Vector2(10, 120)
	physics_label.size = Vector2(300, 80)
	physics_label.add_theme_color_override("font_color", Color.CYAN)
	physics_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	physics_label.add_theme_constant_override("shadow_offset_x", 1)
	physics_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(physics_label)
	
	# Orientation display (top-center)
	orientation_label = Label.new()
	orientation_label.position = Vector2(320, 10)
	orientation_label.size = Vector2(200, 60)
	orientation_label.add_theme_color_override("font_color", Color.YELLOW)
	orientation_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	orientation_label.add_theme_constant_override("shadow_offset_x", 1)
	orientation_label.add_theme_constant_override("shadow_offset_y", 1)
	orientation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(orientation_label)
	
	# Controls help (bottom-right)
	controls_label = Label.new()
	controls_label.position = Vector2(get_viewport().get_visible_rect().size.x - 300, get_viewport().get_visible_rect().size.y - 120)
	controls_label.size = Vector2(290, 110)
	controls_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	controls_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls_label.add_theme_constant_override("shadow_offset_x", 1)
	controls_label.add_theme_constant_override("shadow_offset_y", 1)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls_label.text = "CONTROLS:\nWASD - Move\nQ/E - Rotate View\nR/F - Depth Step\nSPACE - Jump"
	add_child(controls_label)

func _process(delta):
	update_hud_displays()

func update_hud_displays():
	"""Update all HUD elements with current game state"""
	var coords = SolipsisticCoordinates
	
	# Update coordinates display
	coordinate_label.text = "CONSCIOUSNESS POSITION:\nX: %.1f\nY: %.1f\nReality Center: %s" % [
		coords.player_consciousness_pos.x,
		coords.player_consciousness_pos.y,
		coords.CONSCIOUSNESS_CENTER
	]
	
	# Update physics display
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("get_current_height_above_terrain"):
		var height_above = player.get_current_height_above_terrain()
		var absolute_height = player.current_height
		var terrain_height = 0.0
		var solipsistic_world = get_tree().get_first_node_in_group("SolipsisticWorld")
		if solipsistic_world:
			terrain_height = solipsistic_world.get_terrain_height_at(SolipsisticCoordinates.player_consciousness_pos)
		
		physics_label.text = "PHYSICS:\nAbsolute Height: %.3f\nTerrain Height: %.3f\nAbove Terrain: %.3f\nVelocity: %.1f\nGrounded: %s" % [
			absolute_height,
			terrain_height,
			height_above,
			player.vertical_velocity,
			player.is_grounded
		]
	
	# Update orientation display
	var orientation_names = ["EAST →", "SOUTH ↓", "WEST ←", "NORTH ↑"]
	orientation_label.text = "PERSPECTIVE:\n%s" % orientation_names[coords.current_orientation]

func get_orientation_arrow(orientation: int) -> String:
	"""Get directional arrow for current orientation"""
	match orientation:
		SolipsisticCoordinates.Orientation.EAST:
			return "→"
		SolipsisticCoordinates.Orientation.SOUTH:
			return "↓"
		SolipsisticCoordinates.Orientation.WEST:
			return "←"
		SolipsisticCoordinates.Orientation.NORTH:
			return "↑"
		_:
			return "?"
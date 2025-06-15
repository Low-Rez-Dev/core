extends Control
class_name DebugMinimap

@export var grid_size: int = 20  # Size of each grid cell in pixels
@export var grid_range: int = 10  # Show +/- 10 cells from center
@export var player_color: Color = Color(0.6, 0.15, 0.1)  # Deep red pottery accent
@export var grid_color: Color = Color(0.15, 0.1, 0.08)   # Dark pottery paint
@export var axis_color: Color = Color(0.2, 0.4, 0.7)     # Blue accent

var player: Player
var coordinate_system: Node

func _ready():
	print("Minimap _ready() called")
	
	# Add to UI layer with higher z-index
	size = Vector2(200, 200)
	position = Vector2(640 - 220, 20)  # Absolute position: 20px from right edge, 20px from top
	z_index = 100  # Ensure it's on top
	
	print("Minimap positioned at: ", position, " size: ", size)
	
	# Find player and coordinate system
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Player not found in 'player' group, searching recursively...")
		# Try to find player by class name recursively
		player = find_player_recursive(get_tree().current_scene)
	
	if player:
		print("Minimap found player: ", player)
	else:
		print("Minimap could not find player!")
	
	# Direct access for now until CSLocator is working properly  
	call_deferred("_try_direct_access")

func find_player_recursive(node: Node) -> Player:
	if node is Player:
		return node
	for child in node.get_children():
		var result = find_player_recursive(child)
		if result:
			return result
	return null

func _draw():
	print("Minimap _draw() called")
	draw_background()
	draw_grid()
	draw_axes()
	draw_player_position()
	draw_orientation_indicator()

func draw_background():
	# Terracotta background with pottery border
	var terracotta = Color(0.8, 0.45, 0.25, 0.9)  # Semi-transparent terracotta
	var pottery_dark = Color(0.15, 0.1, 0.08)      # Dark pottery border
	draw_rect(Rect2(Vector2.ZERO, size), terracotta)
	
	# Pottery-style border
	draw_rect(Rect2(Vector2.ZERO, size), pottery_dark, false, 3)

func draw_grid():
	var center = size / 2
	
	# Draw grid lines
	for x in range(-grid_range, grid_range + 1):
		var pos_x = center.x + x * grid_size
		if pos_x >= 0 and pos_x <= size.x:
			draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), grid_color, 1)
	
	for y in range(-grid_range, grid_range + 1):
		var pos_y = center.y + y * grid_size
		if pos_y >= 0 and pos_y <= size.y:
			draw_line(Vector2(0, pos_y), Vector2(size.x, pos_y), grid_color, 1)

func draw_axes():
	var center = size / 2
	
	# Draw main axes (thicker lines)
	# North-South axis (vertical)
	draw_line(Vector2(center.x, 0), Vector2(center.x, size.y), axis_color, 3)
	
	# East-West axis (horizontal)
	draw_line(Vector2(0, center.y), Vector2(size.x, center.y), axis_color, 3)
	
	# Draw labels
	var font = ThemeDB.fallback_font
	var font_size = 12
	var pottery_dark = Color(0.15, 0.1, 0.08)
	
	# North
	draw_string(font, Vector2(center.x + 5, 15), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, pottery_dark)
	
	# South
	draw_string(font, Vector2(center.x + 5, size.y - 5), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, pottery_dark)
	
	# East
	draw_string(font, Vector2(size.x - 15, center.y - 5), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, pottery_dark)
	
	# West
	draw_string(font, Vector2(5, center.y - 5), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, pottery_dark)

func draw_player_position():
	if not player:
		print("Minimap: No player found")
		return
	
	var center = size / 2
	var grid_pos = player.get_grid_position()
	
	# Convert grid position to minimap pixel position (top-down view)
	# X = East-West, Z = North-South
	var pixel_pos = Vector2(
		center.x + grid_pos.x * grid_size / 4,  # Scale down for minimap
		center.y - grid_pos.z * grid_size / 4   # Flip Z for top-down (North = up)
	)
	
	# Draw player dot (only if within minimap bounds)
	if pixel_pos.x >= 0 and pixel_pos.x <= size.x and pixel_pos.y >= 0 and pixel_pos.y <= size.y:
		draw_circle(pixel_pos, 6, player_color)
		draw_circle(pixel_pos, 6, Color.WHITE, false, 2)
	
	# Draw coordinate text
	var font = ThemeDB.fallback_font
	var coord_text = "(%d,%d,%d)" % [grid_pos.x, grid_pos.y, grid_pos.z]
	var pottery_dark = Color(0.15, 0.1, 0.08)
	draw_string(font, pixel_pos + Vector2(10, -10), coord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, pottery_dark)

func draw_orientation_indicator():
	if not coordinate_system:
		return
	
	var center = size / 2
	var orientation_text = ""
	var movement_axis = ""
	var depth_axis = ""
	
	match coordinate_system.current_orientation:
		coordinate_system.Orientation.NORTH_SOUTH:
			orientation_text = "N-S Movement"
			movement_axis = "X axis (E-W)"
			depth_axis = "Z axis (N-S lanes)"
		coordinate_system.Orientation.EAST_WEST:
			orientation_text = "E-W Movement"
			movement_axis = "Z axis (N-S)"
			depth_axis = "X axis (E-W lanes)"
	
	var font = ThemeDB.fallback_font
	var font_size = 10
	var pottery_dark = Color(0.15, 0.1, 0.08)
	var blue_accent = Color(0.2, 0.4, 0.7)
	var red_accent = Color(0.6, 0.15, 0.1)
	
	# Draw orientation info at bottom
	draw_string(font, Vector2(5, size.y - 30), orientation_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, blue_accent)
	draw_string(font, Vector2(5, size.y - 20), "Move: A/D", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, pottery_dark)
	draw_string(font, Vector2(5, size.y - 10), "Lane: R/F", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, red_accent)

func _process(delta):
	# Redraw every frame to update player position
	queue_redraw()

func _on_orientation_changed(new_orientation):
	queue_redraw()

# CSLocator callback when coordinate system service is found
func _on_coordinate_system_found(service):
	coordinate_system = service
	# Connect signals directly
	coordinate_system.orientation_changed.connect(_on_orientation_changed)
	print("Minimap connected to coordinate system via CSLocator")

# Fallback to direct access if CSLocator doesn't work
func _try_direct_access():
	if not coordinate_system:
		coordinate_system = get_node("/root/CoordinateSystem")
		if coordinate_system:
			coordinate_system.orientation_changed.connect(_on_orientation_changed)
			print("Minimap connected to coordinate system via direct access")
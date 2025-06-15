extends Node2D
class_name GridEntity

# Base class for entities that exist in the 3D grid system

@export var grid_position_3d: Vector3i
var focus_lane_system: FocusLaneSystem

func _ready():
	add_to_group("entities")
	
	# Direct access for now until CSLocator timing issues are resolved
	call_deferred("_setup_direct_access")

func set_grid_position(new_pos: Vector3i):
	grid_position_3d = new_pos
	update_screen_position()
	update_render_properties()

func get_grid_position() -> Vector3i:
	return grid_position_3d

func update_screen_position():
	if focus_lane_system:
		global_position = focus_lane_system.grid_to_screen_position(grid_position_3d)

func update_render_properties():
	if focus_lane_system:
		var props = focus_lane_system.get_entity_render_properties(grid_position_3d)
		set_render_properties(props)

func set_render_properties(props: Dictionary):
	# Apply visual properties based on distance from focus lane
	visible = props.visible
	if visible:
		modulate = Color(1, 1, 1, props.alpha)
		scale = Vector2(props.scale, props.scale)
		z_index = props.z_index

func _on_focus_lane_changed(new_focus_lane: Vector3i):
	# Update rendering when focus lane changes
	update_render_properties()

# Override in child classes for specific entity behavior
func on_focus_lane_enter():
	pass

func on_focus_lane_exit():
	pass

# CSLocator callback when focus lane system service is found
func _on_focus_lane_system_found(service):
	focus_lane_system = service
	# Connect signals directly
	focus_lane_system.focus_lane_changed.connect(_on_focus_lane_changed)
	_initialize_if_ready()

# Initialize positioning once focus lane system is available
func _initialize_if_ready():
	if focus_lane_system:
		update_screen_position()
		update_render_properties()

# Direct access setup function  
func _setup_direct_access():
	var coord_system = get_node("/root/CoordinateSystem")
	if coord_system and coord_system.focus_lane_system:
		focus_lane_system = coord_system.focus_lane_system
		focus_lane_system.focus_lane_changed.connect(_on_focus_lane_changed)
		_initialize_if_ready()
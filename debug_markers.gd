extends Node3D
class_name DebugMarkers

# Settings
@export var grid_size = 10  # Smaller grid for better visibility
@export var z_layers = 6    # Fewer layers for testing
@export var grid_spacing = 1.0  # Meter spacing
@export var landmark_spacing = 3  # Landmark every 3 meters (more frequent)

# Materials
var grid_material: StandardMaterial3D
var landmark_materials: Array[StandardMaterial3D] = []
var text_material: StandardMaterial3D

func _ready():
	setup_materials()
	create_all_markers()

func setup_materials():
	# Grid line material
	grid_material = StandardMaterial3D.new()
	grid_material.albedo_color = Color.WHITE
	grid_material.emission_enabled = true
	grid_material.emission = Color.WHITE * 0.3
	grid_material.no_depth_test = false
	grid_material.vertex_color_use_as_albedo = true
	
	# Create different colored materials for each Z layer
	for i in range(z_layers):
		var mat = StandardMaterial3D.new()
		var hue = float(i) / float(z_layers)
		mat.albedo_color = Color.from_hsv(hue, 0.7, 0.9)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.5
		landmark_materials.append(mat)
	
	# Text material
	text_material = StandardMaterial3D.new()
	text_material.albedo_color = Color.YELLOW
	text_material.emission_enabled = true
	text_material.emission = Color.YELLOW * 0.8
	text_material.no_depth_test = true

func create_all_markers():
	create_floor_grids()
	create_landmark_cubes()
	create_coordinate_labels()

func create_floor_grids():
	var half_layers = z_layers / 2
	
	for z_layer in range(-half_layers, half_layers + 1):
		var z_pos = z_layer * grid_spacing
		create_grid_at_z(z_pos, z_layer + half_layers)

func create_grid_at_z(z_pos: float, layer_index: int):
	var grid_node = Node3D.new()
	grid_node.name = "Grid_Z_%d" % z_pos
	add_child(grid_node)
	
	# Choose color based on layer
	var layer_color = Color.from_hsv(float(layer_index) / float(z_layers), 0.5, 0.7)
	
	# Create grid lines
	for x in range(-grid_size, grid_size + 1):
		# Vertical lines (along Z)
		if x % 5 == 0:  # Major lines every 5 meters
			create_grid_line(
				Vector3(x, 0, -grid_size), 
				Vector3(x, 0, grid_size), 
				layer_color * 1.5,
				grid_node
			)
		else:  # Minor lines
			create_grid_line(
				Vector3(x, 0, -grid_size), 
				Vector3(x, 0, grid_size), 
				layer_color * 0.5,
				grid_node
			)
	
	for z in range(-grid_size, grid_size + 1):
		# Horizontal lines (along X)
		if z % 5 == 0:  # Major lines every 5 meters
			create_grid_line(
				Vector3(-grid_size, 0, z_pos + z - z_pos), 
				Vector3(grid_size, 0, z_pos + z - z_pos), 
				layer_color * 1.5,
				grid_node
			)
		else:  # Minor lines
			create_grid_line(
				Vector3(-grid_size, 0, z_pos + z - z_pos), 
				Vector3(grid_size, 0, z_pos + z - z_pos), 
				layer_color * 0.5,
				grid_node
			)

func create_grid_line(start: Vector3, end: Vector3, color: Color, parent: Node3D):
	var mesh_instance = MeshInstance3D.new()
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Create line geometry
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	
	vertices.append(start)
	vertices.append(end)
	colors.append(color)
	colors.append(color)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = grid_material
	
	parent.add_child(mesh_instance)

func create_landmark_cubes():
	var half_layers = z_layers / 2
	
	for x in range(-grid_size, grid_size + 1, landmark_spacing):
		for z_layer in range(-half_layers, half_layers + 1, 2):  # Every other layer
			var z_pos = z_layer * grid_spacing
			create_cube_at(Vector3(x, 0.5, z_pos), z_layer + half_layers)

func create_cube_at(position: Vector3, layer_index: int):
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	cube.mesh.size = Vector3(0.8, 1.0, 0.8)  # Slightly smaller than 1m
	
	# Use layer-specific material
	var material_index = clampi(layer_index, 0, landmark_materials.size() - 1)
	cube.material_override = landmark_materials[material_index]
	
	cube.position = position
	cube.name = "Landmark_%d_%d_%d" % [position.x, position.y, position.z]
	
	add_child(cube)

func create_coordinate_labels():
	# Create labels at major grid intersections
	for x in range(-grid_size, grid_size + 1, landmark_spacing):
		for z in range(-grid_size, grid_size + 1, landmark_spacing):
			create_coordinate_label(Vector3(x, 2.0, z))

func create_coordinate_label(position: Vector3):
	var label = Label3D.new()
	label.text = "%d,%d,%d" % [position.x, position.y, position.z]
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Style the label
	label.font_size = 32
	label.modulate = Color.YELLOW
	label.outline_size = 8
	label.outline_modulate = Color.BLACK
	
	label.name = "Label_%d_%d_%d" % [position.x, position.y, position.z]
	add_child(label)

# Utility function to highlight current player position
func highlight_position(world_pos: Vector3):
	# Create temporary highlight at player position
	var highlight = MeshInstance3D.new()
	highlight.mesh = SphereMesh.new()
	highlight.mesh.radius = 1.5
	highlight.mesh.height = 3.0
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.emission_enabled = true
	material.emission = Color.RED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.3
	
	highlight.material_override = material
	highlight.position = world_pos
	add_child(highlight)
	
	# Remove after a short time
	var tween = create_tween()
	tween.tween_property(highlight, "scale", Vector3.ZERO, 1.0)
	tween.tween_callback(highlight.queue_free)

extends Sprite3D
class_name Entity2D5D

# Base class for all 2D entities in 3D space
# Handles billboard behavior, orientation, and basic 2D-in-3D functionality

@export_group("Entity Settings")
@export var entity_scale: float = 2.0
@export var ground_height: float = 1.0
@export var always_face_camera: bool = false
@export var face_movement_direction: bool = false

@export_group("Sprite Settings") 
@export var sprite_texture: Texture2D
@export var sprite_size: Vector2 = Vector2(400, 600)

# Internal state
var facing_right: bool = true
var movement_velocity: Vector3 = Vector3.ZERO

func _ready():
	setup_sprite()
	
func setup_sprite():
	# Configure sprite properties
	scale = Vector3(entity_scale * 0.01, entity_scale * 0.01, entity_scale * 0.01)
	position.y = ground_height
	
	# Set billboard behavior
	if always_face_camera:
		billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		billboard = BaseMaterial3D.BILLBOARD_DISABLED
		rotation.y = deg_to_rad(90)  # Face camera initially
	
	# Set texture if provided
	if sprite_texture:
		texture = sprite_texture
	
	print("📍 Entity2D5D setup: scale=%s, billboard=%s" % [scale, billboard])

func set_sprite_texture(new_texture: Texture2D):
	texture = new_texture

func set_facing_direction(face_right: bool):
	if face_right != facing_right:
		facing_right = face_right
		if not always_face_camera:
			# Flip sprite by scaling X negatively
			scale.x = abs(scale.x) * (-1 if not face_right else 1)

func update_movement(velocity: Vector3):
	movement_velocity = velocity
	
	# Auto-face movement direction if enabled
	if face_movement_direction and velocity.length() > 0.1:
		var moving_right = velocity.z > 0  # Positive Z = East = Right
		set_facing_direction(moving_right)

# Virtual method for subclasses to override
func update_entity(delta: float):
	# Override in subclasses for custom behavior
	pass

func _process(delta):
	update_entity(delta)

extends VirtualEntity
class_name ProceduralEntity

# Visual properties
@export var primary_color: Color = Color.BLUE
@export var secondary_color: Color = Color.LIGHT_BLUE
@export var outline_color: Color = Color.DARK_BLUE
@export var outline_width: float = 2.0
@export var entity_size: float = 20.0

# Animation state
var animation_time: float = 0.0
var bob_amplitude: float = 2.0
var bob_speed: float = 3.0

# Detail level based on manifestation
enum DetailLevel { NONE, LOW, MEDIUM, HIGH }
var current_detail: DetailLevel = DetailLevel.HIGH

func _ready():
	super._ready()
	# Create a custom drawing node
	var drawer = ProceduralDrawer.new()
	drawer.entity = self
	add_child(drawer)

func enable_complex_behaviors():
	current_detail = DetailLevel.HIGH
	
func disable_complex_behaviors():
	# Still visible but simpler
	current_detail = DetailLevel.LOW

func _process(delta):
	animation_time += delta
	# Update any animated properties
	queue_redraw()

# Override these in specific entity types
func get_entity_type() -> String:
	return "generic"

func get_custom_data() -> Dictionary:
	return {}
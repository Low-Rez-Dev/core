extends ProceduralEntity
class_name ProceduralEnemy

@export var enemy_type: String = "guard"
@export var alertness: float = 0.0  # 0 = calm, 1 = alert

# Patrol behavior
var patrol_points: Array[Vector2] = []
var current_target: int = 0
var move_speed: float = 50.0

func _ready():
	super._ready()
	# Set colors based on type
	match enemy_type:
		"guard":
			primary_color = Color.DARK_GREEN
			secondary_color = Color.GREEN
		"archer":
			primary_color = Color.DARK_BLUE
			secondary_color = Color.BLUE
		"scout":
			primary_color = Color.ORANGE
			secondary_color = Color.YELLOW
	
	# Set up patrol route in virtual space
	patrol_points = [
		virtual_position + Vector2(100, 0),
		virtual_position + Vector2(100, 100), 
		virtual_position + Vector2(0, 100),
		virtual_position
	]

func _process(delta):
	super._process(delta)
	# AI runs continuously regardless of manifestation
	update_ai(delta)

func update_ai(delta):
	"""AI runs continuously regardless of manifestation"""
	if patrol_points.is_empty():
		return
	
	# Move toward current patrol point
	var target_pos = patrol_points[current_target]
	var direction = (target_pos - virtual_position).normalized()
	virtual_position += direction * move_speed * delta
	
	# Check if reached target
	if virtual_position.distance_to(target_pos) < 10:
		current_target = (current_target + 1) % patrol_points.size()

func get_entity_type() -> String:
	return "enemy"
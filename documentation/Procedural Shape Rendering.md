# ==============================================================================
# PROCEDURAL SHAPE RENDERING SYSTEM
# No sprites required - everything drawn with code!
# ==============================================================================

# Base class for all procedurally rendered entities
class_name ProceduralEntity extends VirtualEntity

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

# ==============================================================================
# PROCEDURAL DRAWER - Handles All Shape Drawing
# ==============================================================================

class_name ProceduralDrawer extends Node2D

var entity: ProceduralEntity

func _draw():
    if not entity:
        return
    
    # Draw based on entity type and detail level
    match entity.get_script().get_global_name():
        "ProceduralPlayer":
            draw_player()
        "ProceduralEnemy":
            draw_enemy()
        "ProceduralBuilding":
            draw_building()
        "ProceduralTree":
            draw_tree()
        _:
            draw_generic_entity()

func draw_player():
    """Draw the player character with dual arms"""
    var size = entity.entity_size
    
    # Body (rounded rectangle)
    var body_rect = Rect2(-size/4, -size/2, size/2, size * 0.8)
    draw_rect(body_rect, entity.primary_color, true, -1)
    draw_rect(body_rect, entity.outline_color, false, entity.outline_width)
    
    # Head (circle)
    var head_pos = Vector2(0, -size/2 - size/6)
    draw_circle(head_pos, size/6, entity.secondary_color)
    draw_arc(head_pos, size/6, 0, TAU, 32, entity.outline_color, entity.outline_width)
    
    # Arms (lines) - get from your existing arm IK system
    if entity.has_method("get_arm_positions"):
        var arm_data = entity.get_arm_positions()
        
        # Left arm (red)
        if arm_data.has("left_shoulder") and arm_data.has("left_elbow") and arm_data.has("left_hand"):
            draw_line(arm_data.left_shoulder, arm_data.left_elbow, Color.RED, 4)
            draw_line(arm_data.left_elbow, arm_data.left_hand, Color.RED, 3)
            draw_circle(arm_data.left_elbow, 3, Color.DARK_RED)
            draw_circle(arm_data.left_hand, 4, Color.RED)
        
        # Right arm (blue)
        if arm_data.has("right_shoulder") and arm_data.has("right_elbow") and arm_data.has("right_hand"):
            draw_line(arm_data.right_shoulder, arm_data.right_elbow, Color.BLUE, 4)
            draw_line(arm_data.right_elbow, arm_data.right_hand, Color.BLUE, 3)
            draw_circle(arm_data.right_elbow, 3, Color.DARK_BLUE)
            draw_circle(arm_data.right_hand, 4, Color.BLUE)
    
    # Legs (simple lines)
    var leg_start = Vector2(0, size/2 - size/8)
    draw_line(Vector2(-size/8, leg_start.y), Vector2(-size/8, leg_start.y + size/3), entity.outline_color, 3)
    draw_line(Vector2(size/8, leg_start.y), Vector2(size/8, leg_start.y + size/3), entity.outline_color, 3)
    
    # Facing indicator (triangle)
    if entity.has_method("get_facing_direction"):
        var facing_right = entity.get_facing_direction()
        var triangle_points = PackedVector2Array()
        if facing_right:
            triangle_points = [Vector2(size/3, -size/8), Vector2(size/2, 0), Vector2(size/3, size/8)]
        else:
            triangle_points = [Vector2(-size/3, -size/8), Vector2(-size/2, 0), Vector2(-size/3, size/8)]
        draw_colored_polygon(triangle_points, Color.YELLOW)

func draw_enemy():
    """Draw an enemy with animated features"""
    var size = entity.entity_size
    var time = entity.animation_time
    
    # Animated bobbing
    var bob_offset = sin(time * entity.bob_speed) * entity.bob_amplitude
    
    # Main body (hexagon for different look)
    var points = PackedVector2Array()
    for i in range(6):
        var angle = i * TAU / 6
        var point = Vector2(cos(angle), sin(angle)) * size/2
        point.y += bob_offset
        points.append(point)
    
    draw_colored_polygon(points, entity.primary_color)
    
    # Outline
    for i in range(points.size()):
        var start = points[i]
        var end = points[(i + 1) % points.size()]
        draw_line(start, end, entity.outline_color, entity.outline_width)
    
    # Eyes (animated)
    var eye_y = -size/4 + bob_offset
    draw_circle(Vector2(-size/4, eye_y), size/8, Color.RED)
    draw_circle(Vector2(size/4, eye_y), size/8, Color.RED)
    
    # Animated details based on detail level
    if entity.current_detail >= ProceduralEntity.DetailLevel.MEDIUM:
        # Breathing animation
        var breath_scale = 1.0 + sin(time * 2) * 0.1
        var breath_rect = Rect2(-size/6, -size/8, size/3, size/4)
        breath_rect = breath_rect * breath_scale
        draw_rect(breath_rect, entity.secondary_color, true)

func draw_building():
    """Draw a building structure"""
    var size = entity.entity_size * 2  # Buildings are bigger
    
    # Main structure (rectangle)
    var building_rect = Rect2(-size/2, -size, size, size)
    draw_rect(building_rect, entity.primary_color, true)
    draw_rect(building_rect, entity.outline_color, false, entity.outline_width)
    
    # Roof (triangle)
    var roof_points = PackedVector2Array([
        Vector2(-size/2, -size),
        Vector2(0, -size - size/3),
        Vector2(size/2, -size)
    ])
    draw_colored_polygon(roof_points, entity.secondary_color)
    
    # Details based on distance
    if entity.current_detail >= ProceduralEntity.DetailLevel.MEDIUM:
        # Windows
        var window_size = size/8
        for x in range(-1, 2, 2):
            for y in range(-3, 0):
                var window_pos = Vector2(x * size/4, y * size/4 - size/8)
                var window_rect = Rect2(window_pos - Vector2(window_size/2, window_size/2), 
                                      Vector2(window_size, window_size))
                draw_rect(window_rect, Color.YELLOW, true)
                draw_rect(window_rect, entity.outline_color, false, 1)
        
        # Door
        var door_rect = Rect2(-size/8, -size/4, size/4, size/2)
        draw_rect(door_rect, Color.BROWN, true)
        draw_rect(door_rect, entity.outline_color, false, 2)

func draw_tree():
    """Draw a tree with organic shapes"""
    var size = entity.entity_size
    var time = entity.animation_time
    
    # Trunk (tapered rectangle)
    var trunk_width = size/6
    var trunk_height = size/2
    var trunk_points = PackedVector2Array([
        Vector2(-trunk_width, 0),
        Vector2(trunk_width, 0),
        Vector2(trunk_width/2, -trunk_height),
        Vector2(-trunk_width/2, -trunk_height)
    ])
    draw_colored_polygon(trunk_points, Color.SADDLE_BROWN)
    
    # Foliage (circles with slight animation)
    var wind_sway = sin(time * entity.bob_speed * 0.5) * 2
    
    # Multiple overlapping circles for organic look
    var foliage_centers = [
        Vector2(0, -trunk_height - size/3),
        Vector2(-size/4, -trunk_height - size/4),
        Vector2(size/4, -trunk_height - size/4),
        Vector2(0, -trunk_height - size/2)
    ]
    
    for center in foliage_centers:
        center.x += wind_sway
        var radius = size/3 + randf_range(-size/8, size/8)
        draw_circle(center, radius, entity.primary_color)
        
        # Add some texture with smaller circles
        if entity.current_detail >= ProceduralEntity.DetailLevel.HIGH:
            for i in range(3):
                var small_center = center + Vector2(randf_range(-radius/2, radius/2), randf_range(-radius/2, radius/2))
                draw_circle(small_center, radius/4, entity.secondary_color)

func draw_generic_entity():
    """Fallback drawing for unknown entity types"""
    var size = entity.entity_size
    
    # Simple diamond shape
    var points = PackedVector2Array([
        Vector2(0, -size/2),
        Vector2(size/2, 0),
        Vector2(0, size/2),
        Vector2(-size/2, 0)
    ])
    
    draw_colored_polygon(points, entity.primary_color)
    
    # Outline
    for i in range(points.size()):
        var start = points[i]
        var end = points[(i + 1) % points.size()]
        draw_line(start, end, entity.outline_color, entity.outline_width)

func _process(delta):
    queue_redraw()

# ==============================================================================
# SPECIFIC ENTITY TYPES
# ==============================================================================

class_name ProceduralPlayer extends ProceduralEntity

# Your existing arm IK data
var left_arm_data: Dictionary = {}
var right_arm_data: Dictionary = {}
var facing_right: bool = true

func get_arm_positions() -> Dictionary:
    # Return data from your existing BodyController
    return {
        "left_shoulder": Vector2(-12, -17),
        "left_elbow": left_arm_data.get("elbow", Vector2(-20, -10)),
        "left_hand": left_arm_data.get("hand", Vector2(-30, 0)),
        "right_shoulder": Vector2(12, -17),
        "right_elbow": right_arm_data.get("elbow", Vector2(20, -10)),
        "right_hand": right_arm_data.get("hand", Vector2(30, 0))
    }

func get_facing_direction() -> bool:
    return facing_right

class_name ProceduralEnemy extends ProceduralEntity

@export var enemy_type: String = "guard"
@export var alertness: float = 0.0  # 0 = calm, 1 = alert

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

class_name ProceduralBuilding extends ProceduralEntity

@export var building_type: String = "house"
@export var building_height: int = 2

func _ready():
    super._ready()
    entity_size = 40 * building_height  # Taller buildings are bigger
    
    match building_type:
        "house":
            primary_color = Color.SANDY_BROWN
            secondary_color = Color.DARK_RED
        "tower":
            primary_color = Color.GRAY
            secondary_color = Color.DARK_GRAY
        "temple":
            primary_color = Color.WHITE
            secondary_color = Color.GOLD

class_name ProceduralTree extends ProceduralEntity

@export var tree_type: String = "oak"

func _ready():
    super._ready()
    bob_speed = randf_range(2.0, 4.0)  # Each tree sways differently
    
    match tree_type:
        "oak":
            primary_color = Color.FOREST_GREEN
            secondary_color = Color.DARK_GREEN
        "pine":
            primary_color = Color.DARK_GREEN
            secondary_color = Color.GREEN
        "dead":
            primary_color = Color.SADDLE_BROWN
            secondary_color = Color.DARK_GRAY

# ==============================================================================
# PROCEDURAL EFFECTS SYSTEM
# ==============================================================================

class_name ProceduralEffects extends Node2D

# Draw temporary effects like explosions, magic, etc.
static func draw_explosion(canvas: CanvasItem, center: Vector2, radius: float, time: float):
    var segments = 16
    var inner_radius = radius * 0.3
    
    # Outer ring
    for i in range(segments):
        var angle1 = i * TAU / segments
        var angle2 = (i + 1) * TAU / segments
        var point1 = center + Vector2(cos(angle1), sin(angle1)) * radius
        var point2 = center + Vector2(cos(angle2), sin(angle2)) * radius
        
        var color = Color.ORANGE.lerp(Color.RED, sin(time * 10))
        canvas.draw_line(point1, point2, color, 3)
    
    # Inner core
    canvas.draw_circle(center, inner_radius, Color.YELLOW)

static func draw_magic_circle(canvas: CanvasItem, center: Vector2, radius: float, time: float):
    var segments = 32
    
    # Rotating outer ring
    for i in range(segments):
        var angle = i * TAU / segments + time * 2
        var point = center + Vector2(cos(angle), sin(angle)) * radius
        var color = Color.CYAN
        color.a = 0.5 + sin(time * 5 + i) * 0.5
        canvas.draw_circle(point, 2, color)
    
    # Inner symbols (simple geometric shapes)
    var inner_segments = 6
    for i in range(inner_segments):
        var angle = i * TAU / inner_segments - time
        var point = center + Vector2(cos(angle), sin(angle)) * radius * 0.6
        canvas.draw_circle(point, 3, Color.WHITE)

# ==============================================================================
# EXAMPLE USAGE
# ==============================================================================

# Example: Spawn different entity types
func spawn_procedural_entities():
    var world = SolipsisticWorld.new()
    
    # Spawn a procedural enemy
    var enemy = ProceduralEnemy.new()
    enemy.virtual_position = Vector2(100, 100)
    enemy.enemy_type = "guard"
    enemy.primary_color = Color.RED
    world.add_child(enemy)
    
    # Spawn a building
    var building = ProceduralBuilding.new()
    building.virtual_position = Vector2(200, 50)
    building.building_type = "tower"
    building.building_height = 3
    world.add_child(building)
    
    # Spawn trees
    for i in range(10):
        var tree = ProceduralTree.new()
        tree.virtual_position = Vector2(randf_range(-500, 500), randf_range(-500, 500))
        tree.tree_type = "oak"
        world.add_child(tree)
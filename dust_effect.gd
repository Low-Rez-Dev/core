extends Node2D

@export var particle_count: int = 12
@export var dust_color: Color = Color(0.8, 0.7, 0.6, 0.8)
@export var effect_duration: float = 0.3

var particles: Array[DustParticle] = []

class DustParticle:
	var position: Vector2
	var velocity: Vector2
	var life: float
	var max_life: float
	var size: float
	
	func _init(pos: Vector2, vel: Vector2, lifetime: float):
		position = pos
		velocity = vel
		life = lifetime
		max_life = lifetime
		size = randf_range(2.0, 6.0)
	
	func update(delta: float) -> bool:
		life -= delta
		position += velocity * delta
		velocity *= 0.95  # Friction
		return life > 0

func _ready():
	spawn_particles()
	
	var tween = create_tween()
	tween.tween_callback(queue_free).set_delay(effect_duration)

func spawn_particles():
	for i in particle_count:
		var angle = (i / float(particle_count)) * PI * 2
		var speed = randf_range(50.0, 120.0)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		var lifetime = randf_range(0.2, effect_duration)
		
		var particle = DustParticle.new(Vector2.ZERO, velocity, lifetime)
		particles.append(particle)

func _draw():
	for particle in particles:
		var alpha = particle.life / particle.max_life
		var color = Color(dust_color.r, dust_color.g, dust_color.b, dust_color.a * alpha)
		draw_circle(particle.position, particle.size * alpha, color)

func _process(delta):
	var active_particles: Array[DustParticle] = []
	
	for particle in particles:
		if particle.update(delta):
			active_particles.append(particle)
	
	particles = active_particles
	queue_redraw()
	
	if particles.is_empty():
		queue_free()

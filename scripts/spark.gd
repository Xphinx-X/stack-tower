extends Node2D

## Tiny procedurally drawn debris particle used for impact feedback.

var _velocity := Vector2.ZERO
var _color := Color.WHITE
var _size := 10.0
var _life := 0.0
var _max_life := 0.6
var _gravity := 2400.0
var _spin := 0.0

func setup(p_color: Color, p_velocity: Vector2, p_size: float, p_life: float = 0.6) -> void:
	_color = p_color
	_velocity = p_velocity
	_size = p_size
	_max_life = maxf(0.12, p_life)
	_spin = randf_range(-8.0, 8.0)
	queue_redraw()

func _process(delta: float) -> void:
	_life += delta
	if _life >= _max_life:
		queue_free()
		return
	_velocity.y += _gravity * delta
	_velocity *= 1.0 - 1.4 * delta
	position += _velocity * delta
	rotation += _spin * delta
	queue_redraw()

func _draw() -> void:
	var t := clampf(_life / _max_life, 0.0, 1.0)
	var alpha := 1.0 - t
	var s := _size * (1.0 - 0.55 * t)
	var c := Color(_color.r, _color.g, _color.b, _color.a * alpha)
	draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), c)

class_name Block
extends Node2D

## A single tower block, drawn procedurally (no textures needed).

const CORNER_RATIO := 0.18
const GRAVITY := 3400.0
const LIFETIME := 2.6

var size: Vector2 = Vector2(100.0, 100.0)
var color: Color = Color.WHITE

var falling: bool = false
var velocity: Vector2 = Vector2.ZERO
var spin: float = 0.0

var _age: float = 0.0

func setup(p_size: Vector2, p_color: Color) -> void:
	size = p_size
	color = p_color
	queue_redraw()

func make_falling(p_velocity: Vector2, p_spin: float) -> void:
	falling = true
	velocity = p_velocity
	spin = p_spin

func _process(delta: float) -> void:
	if not falling:
		return
	_age += delta
	velocity.y += GRAVITY * delta
	position += velocity * delta
	rotation += spin * delta
	if _age > LIFETIME or global_position.y > 3600.0:
		queue_free()

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var radius := minf(size.y * CORNER_RATIO, size.x * 0.3)

	# Drop shadow.
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.0, 0.0, 0.0, 0.28)
	_set_radius(shadow, radius)
	draw_style_box(shadow, Rect2(rect.position + Vector2(0.0, 7.0), rect.size))

	# Body.
	var body := StyleBoxFlat.new()
	body.bg_color = color
	_set_radius(body, radius)
	draw_style_box(body, rect)

	# Gloss on the top edge.
	var inset := minf(8.0, size.x * 0.08)
	var gloss_h := size.y * 0.24
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = color.lightened(0.38)
	gloss.bg_color.a = 0.55
	_set_radius(gloss, maxf(2.0, radius * 0.6))
	draw_style_box(gloss, Rect2(
		rect.position + Vector2(inset, inset),
		Vector2(size.x - inset * 2.0, gloss_h)
	))

	# Subtle shade on the bottom edge.
	var shade := StyleBoxFlat.new()
	shade.bg_color = color.darkened(0.25)
	shade.bg_color.a = 0.45
	_set_radius(shade, maxf(2.0, radius * 0.6))
	draw_style_box(shade, Rect2(
		Vector2(rect.position.x + inset, rect.end.y - size.y * 0.16 - inset),
		Vector2(size.x - inset * 2.0, size.y * 0.16)
	))

static func _set_radius(style: StyleBoxFlat, radius: float) -> void:
	var r := int(maxf(0.0, radius))
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r

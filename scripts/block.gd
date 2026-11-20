class_name Block
extends Node2D

## A single tower block, drawn procedurally (no textures needed).

const CORNER_RATIO := 0.17
const GRAVITY := 3200.0
const LIFETIME := 2.4
const FADE_START := 0.9

var size: Vector2 = Vector2(100.0, 100.0)
var color: Color = Color.WHITE
var focus: bool = false

var falling: bool = false
var velocity: Vector2 = Vector2.ZERO
var spin: float = 0.0

var _age: float = 0.0

func setup(p_size: Vector2, p_color: Color, p_focus: bool = false) -> void:
	size = p_size
	color = p_color
	focus = p_focus
	queue_redraw()

## Little squash-and-stretch when a block settles into the tower.
func land() -> void:
	scale = Vector2(1.06, 0.94)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func make_falling(p_velocity: Vector2, p_spin: float) -> void:
	falling = true
	velocity = p_velocity
	spin = p_spin

func _process(delta: float) -> void:
	if not falling:
		return
	_age += delta
	velocity.y += GRAVITY * delta
	velocity.x *= 1.0 - 0.5 * delta
	position += velocity * delta
	rotation += spin * delta
	if _age > FADE_START:
		modulate.a = clampf(1.0 - (_age - FADE_START) / 1.1, 0.0, 1.0)
	if _age > LIFETIME or global_position.y > 4200.0:
		queue_free()

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var radius := minf(size.y * CORNER_RATIO, size.x * 0.3)
	var inset := minf(7.0, size.x * 0.07)

	# Soft halo around the block that is currently in play.
	if focus:
		var halo := Color(color.lightened(0.25), 0.16)
		draw_style_box(_style(halo, radius + 9.0),
			Rect2(rect.position - Vector2(9.0, 9.0), rect.size + Vector2(18.0, 18.0)))

	# Drop shadow onto the block below.
	draw_style_box(_style(Color(0.0, 0.0, 0.0, 0.32), radius),
		Rect2(rect.position + Vector2(0.0, 8.0), rect.size))

	# Body with a darker rim.
	var body := _style(color, radius)
	var rim := color.darkened(0.5)
	rim.a = 0.5
	body.border_color = rim
	body.border_width_left = 2
	body.border_width_right = 2
	body.border_width_top = 2
	body.border_width_bottom = 2
	draw_style_box(body, rect)

	# Glassy highlight across the top third.
	var gloss := _style(Color(color.lightened(0.45), 0.5), maxf(2.0, radius * 0.75))
	gloss.corner_radius_bottom_left = 0
	gloss.corner_radius_bottom_right = 0
	draw_style_box(gloss, Rect2(
		rect.position + Vector2(inset, inset),
		Vector2(size.x - inset * 2.0, size.y * 0.34)
	))

	# Heavier shade at the bottom for depth.
	var shade := _style(Color(color.darkened(0.35), 0.45), maxf(2.0, radius * 0.75))
	shade.corner_radius_top_left = 0
	shade.corner_radius_top_right = 0
	draw_style_box(shade, Rect2(
		Vector2(rect.position.x + inset, rect.end.y - size.y * 0.18 - inset),
		Vector2(size.x - inset * 2.0, size.y * 0.18)
	))

	# Bright lip on the very top edge.
	if size.x > 18.0:
		var lip := Color(color.lightened(0.7), 0.55 if focus else 0.32)
		draw_style_box(_style(lip, maxf(1.0, radius * 0.5)), Rect2(
			rect.position + Vector2(inset * 1.6, inset * 0.7),
			Vector2(size.x - inset * 3.2, maxf(2.0, size.y * 0.05))
		))

static func _style(bg: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	var r := int(maxf(0.0, radius))
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r
	return style

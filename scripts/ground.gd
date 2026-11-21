extends Node2D

## The platform the tower is built on. Lives inside the scrolling world node.

var width := 1080.0
var depth := 600.0
var top_color := Color(0.10, 0.085, 0.20)
var bottom_color := Color(0.012, 0.012, 0.04)

var _glow: GradientTexture2D

func setup(p_width: float, p_depth: float) -> void:
	width = p_width
	depth = p_depth
	_glow = _make_glow()
	queue_redraw()

func _draw() -> void:
	var half := width * 0.5

	# Vertical gradient slab: picked up by the tower light at the top and
	# melting into the background further down.
	var steps := 32
	var band := depth / float(steps)
	for i in steps:
		var t := float(i) / float(steps)
		var c := top_color.lerp(bottom_color, pow(t, 0.55))
		draw_rect(Rect2(-half, float(i) * band, width, band + 1.0), c)

	# Soft elliptical glow spilling out of the tower base. Drawn from a radial
	# gradient so there are no hard edges.
	if _glow != null:
		var cone_w := width * 1.1
		var cone_h := depth * 0.9
		draw_texture_rect(_glow, Rect2(-cone_w * 0.5, -8.0, cone_w, cone_h), false)

	# Glowing lip along the very top.
	draw_rect(Rect2(-half, 0.0, width, 4.0), Color(0.70, 0.62, 1.0, 0.16))
	draw_rect(Rect2(-half, 0.0, width, 1.5), Color(1.0, 1.0, 1.0, 0.16))

func _make_glow() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.66, 0.54, 1.0, 0.20))
	gradient.set_color(1, Color(0.66, 0.54, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 128
	tex.height = 128
	return tex

extends Node2D

## The platform the tower is built on. Lives inside the scrolling world node.

var width := 1080.0
var depth := 600.0
var body_color := Color(0.055, 0.05, 0.13)
var edge_color := Color(0.45, 0.35, 0.75)

func setup(p_width: float, p_depth: float) -> void:
	width = p_width
	depth = p_depth
	queue_redraw()

func _draw() -> void:
	var half := width * 0.5

	# Main slab.
	draw_rect(Rect2(-half, 0.0, width, depth), body_color)

	# Light spilling from the tower base into the slab.
	for i in 10:
		var t := float(i) / 10.0
		var a := 0.055 * (1.0 - t)
		draw_rect(Rect2(-half, t * depth * 0.9, width, depth * 0.1), Color(edge_color.r, edge_color.g, edge_color.b, a))

	# Glowing lip.
	draw_rect(Rect2(-half, 0.0, width, 4.0), Color(0.75, 0.66, 1.0, 0.22))
	draw_rect(Rect2(-half, 0.0, width, 2.0), Color(1.0, 0.98, 1.0, 0.13))

	# Fade the sides so the slab melts into the background.
	var fade_w := width * 0.12
	for i in 8:
		var a := 0.06 * (1.0 - float(i) / 8.0)
		draw_rect(Rect2(-half + float(i) * (fade_w / 8.0), 0.0, fade_w / 8.0, depth), Color(body_color.r, body_color.g, body_color.b, a))
		draw_rect(Rect2(half - float(i + 1) * (fade_w / 8.0), 0.0, fade_w / 8.0, depth), Color(body_color.r, body_color.g, body_color.b, a))

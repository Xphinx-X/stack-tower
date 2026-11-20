extends Node2D

## Soft parallax bokeh behind the tower. Moves with the camera scroll so the
## climb reads as vertical motion.

const COUNT := 24

var _vs := Vector2(1080.0, 1920.0)
var _x: Array[float] = []
var _y: Array[float] = []
var _r: Array[float] = []
var _a: Array[float] = []
var _depth: Array[float] = []
var _scroll := 0.0
var _t := 0.0

func setup(view_size: Vector2) -> void:
	_vs = view_size
	_x.clear()
	_y.clear()
	_r.clear()
	_a.clear()
	_depth.clear()
	var scale_ref := _vs.x / 1080.0
	for i in COUNT:
		_x.append(randf() * _vs.x)
		_y.append(randf() * _vs.y)
		_r.append(randf_range(7.0, 30.0) * scale_ref)
		_a.append(randf_range(0.035, 0.085))
		_depth.append(randf_range(0.25, 0.95))
	queue_redraw()

func sync(p_scroll: float, delta: float) -> void:
	var d := p_scroll - _scroll
	_scroll = p_scroll
	_t += delta
	for i in _x.size():
		_y[i] += d * _depth[i]
		_y[i] -= delta * (5.0 + 12.0 * _depth[i])
		if _y[i] < -60.0:
			_y[i] = _vs.y + 60.0
			_x[i] = randf() * _vs.x
		elif _y[i] > _vs.y + 60.0:
			_y[i] = -60.0
			_x[i] = randf() * _vs.x
	queue_redraw()

func _draw() -> void:
	for i in _x.size():
		var bob := sin(_t * 0.5 + float(i) * 1.7) * 5.0
		var p := Vector2(_x[i] + bob, _y[i])
		draw_circle(p, _r[i] * 2.1, Color(0.52, 0.46, 1.0, _a[i] * 0.3))
		draw_circle(p, _r[i], Color(0.82, 0.80, 1.0, _a[i]))

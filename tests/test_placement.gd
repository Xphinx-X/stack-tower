extends SceneTree

## Headless unit tests for the placement math.
## Run with: godot --headless --path . --script res://tests/test_placement.gd

const Game := preload("res://scripts/game.gd")
const W := 560.0

var _fails := 0

func _initialize() -> void:
	# Perfect drops keep the full width.
	_expect(Game.compute_placement(0.0, W, 0.0, W), "centered", true, W, 0.0, 0.0)
	_expect(Game.compute_placement(0.0, W, 9.0, W), "within tolerance", true, W, 0.0, 0.0)
	_expect(Game.compute_placement(0.0, W, -10.0, W), "within tolerance (left)", true, W, 0.0, 0.0)

	# Offset drops trim the overhang and narrow the tower.
	_expect(Game.compute_placement(0.0, W, 20.0, W), "offset +20", false, W - 20.0, 0.0, 20.0)
	_expect(Game.compute_placement(0.0, W, -20.0, W), "offset -20", false, W - 20.0, 20.0, 0.0)
	_expect(Game.compute_placement(0.0, W, 200.0, W), "offset +200", false, W - 200.0, 0.0, 200.0)

	# Just outside the tolerance is not perfect.
	_expect(Game.compute_placement(0.0, W, 12.0, W), "just outside tolerance", false, W - 12.0, 0.0, 12.0)

	# Edge touches and full misses have no overlap.
	_expect(Game.compute_placement(0.0, W, W, W), "edge touch", false, 0.0, 0.0, W)
	var miss: Dictionary = Game.compute_placement(0.0, W, W * 2.0, W)
	_ok(miss.overlap == 0.0 and not miss.perfect, "full miss has no overlap: %s" % str(miss))

	# A narrower block placed perfectly keeps its own width (no widening).
	_expect(Game.compute_placement(0.0, 300.0, 0.0, 300.0), "narrow perfect", true, 300.0, 0.0, 0.0)

	# Conservation: overlap + both trims always equals the previous width.
	for dx in [-250.0, -100.0, -13.0, 13.0, 100.0, 250.0]:
		var r: Dictionary = Game.compute_placement(0.0, W, dx, W)
		var total: float = r.overlap + r.trim_left + r.trim_right
		_ok(absf(total - W) < 0.001, "width conservation at dx=%s (got %s)" % [dx, total])

	if _fails > 0:
		printerr("placement tests: %d failure(s)" % _fails)
		quit(1)
	else:
		print("placement tests: all passed")
		quit(0)

func _expect(r: Dictionary, name: String, perfect: bool, overlap: float, trim_left: float, trim_right: float) -> void:
	var ok: bool = r.perfect == perfect \
		and absf(r.overlap - overlap) < 0.001 \
		and absf(r.trim_left - trim_left) < 0.001 \
		and absf(r.trim_right - trim_right) < 0.001
	_ok(ok, "%s: expected perfect=%s overlap=%.1f trims=(%.1f, %.1f), got %s" % [
		name, perfect, overlap, trim_left, trim_right, str(r)
	])

func _ok(cond: bool, message: String) -> void:
	if cond:
		print("  ok: ", message)
	else:
		_fails += 1
		printerr("  FAIL: ", message)

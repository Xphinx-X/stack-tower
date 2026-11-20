extends Node2D

## Stack Tower - a one-tap block stacking arcade game.
##
## Everything is laid out procedurally from the viewport size, so it adapts to
## any phone aspect ratio without assets.

const BlockScript := preload("res://scripts/block.gd")
const HudScript := preload("res://scripts/hud.gd")
const SparkScript := preload("res://scripts/spark.gd")
const BackdropScript := preload("res://scripts/backdrop.gd")
const GroundScript := preload("res://scripts/ground.gd")

enum State { READY, PLAYING, GAMEOVER }

const PERFECT_TOLERANCE := 11.0
const MIN_WIDTH := 26.0
const MIN_TRIM := 2.0
const BASE_SPEED := 420.0
const SPEED_PER_BLOCK := 15.0
const MAX_SPEED := 1220.0
const RESTART_DELAY_MS := 550
const DEMO_BLOCKS := 3
const SAVE_PATH := "user://stack_tower.cfg"

const PALETTE := [
	Color(0.99, 0.36, 0.42),
	Color(0.99, 0.62, 0.28),
	Color(0.98, 0.84, 0.36),
	Color(0.45, 0.90, 0.58),
	Color(0.30, 0.82, 0.92),
	Color(0.38, 0.58, 1.00),
	Color(0.65, 0.48, 1.00),
	Color(0.95, 0.46, 0.84),
]

var state := State.READY
var score := 0
var best := 0
var combo := 0
var blocks: Array = []
var moving = null
var _scroll_target := 0.0

var _vs := Vector2(1080.0, 1920.0)
var _world: Node2D
var _hud
var _backdrop
var _ground_node
var _sfx: AudioStreamPlayer

var _left := 0.0
var _right := 0.0
var _bh := 0.0
var _bw := 0.0
var _ground := 0.0

var _dir := 1.0
var _speed := BASE_SPEED
var _spawn_right := true
var _scroll := 0.0
var _over_at := 0
var _shake := 0.0
var _tap_frame := -1

# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	_vs = get_viewport_rect().size
	if _vs.x < 1.0 or _vs.y < 1.0:
		_vs = Vector2(1080.0, 1920.0)
	_compute_layout()

	_build_background()

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_ground_node = GroundScript.new()
	_ground_node.name = "Ground"
	_world.add_child(_ground_node)
	_place_ground()

	_hud = HudScript.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.relayout(_vs)

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = _make_tone(440.0, 0.13, 0.28)
	add_child(_sfx)

	get_viewport().size_changed.connect(_on_viewport_resized)

	_load_best()
	_reset_board(true)
	_hud.show_title(best)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_best()

func _process(delta: float) -> void:
	if moving != null and (state == State.PLAYING or state == State.READY):
		moving.position.x += _dir * _speed * delta
		var half: float = moving.size.x * 0.5
		var min_x := _left + half
		var max_x := _right - half
		if min_x > max_x:
			min_x = _vs.x * 0.5
			max_x = min_x
		if moving.position.x > max_x:
			moving.position.x = max_x
			_dir = -1.0
		elif moving.position.x < min_x:
			moving.position.x = min_x
			_dir = 1.0

	_scroll = lerpf(_scroll, _scroll_target, 1.0 - exp(-7.0 * delta))

	var offset := Vector2.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.6)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 14.0
	_world.position = Vector2(offset.x, _scroll + offset.y)

	if _backdrop != null:
		_backdrop.sync(_scroll, delta)

func _unhandled_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventScreenTouch:
		tapped = event.pressed
	elif event is InputEventMouseButton:
		tapped = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		tapped = event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)
	if not tapped:
		return
	get_viewport().set_input_as_handled()
	_on_tap()

# ---------------------------------------------------------------- public API

func begin_play() -> void:
	if state != State.READY:
		return
	state = State.PLAYING
	_hud.hide_title()

func drop_block() -> void:
	if moving == null or state != State.PLAYING:
		return

	var prev = blocks[blocks.size() - 1]
	var res := compute_placement(prev.position.x, prev.size.x, moving.position.x, moving.size.x)
	if res.overlap < MIN_WIDTH:
		_end_game()
		return

	var placed = _make_block((res.left + res.right) * 0.5, moving.position.y, res.overlap, moving.color)
	_world.add_child(placed)
	placed.land()
	blocks.append(placed)

	if res.trim_right > MIN_TRIM:
		var right_piece = _make_block(res.right + res.trim_right * 0.5, moving.position.y, res.trim_right, moving.color)
		right_piece.make_falling(Vector2(170.0, -110.0), randf_range(2.0, 4.0))
		_world.add_child(right_piece)
	if res.trim_left > MIN_TRIM:
		var left_piece = _make_block(res.left - res.trim_left * 0.5, moving.position.y, res.trim_left, moving.color)
		left_piece.make_falling(Vector2(-170.0, -110.0), randf_range(-4.0, -2.0))
		_world.add_child(left_piece)

	moving.queue_free()
	moving = null

	score += 1
	if res.perfect:
		combo += 1
		var label := "PERFECT" if combo < 2 else "PERFECT x%d" % combo
		_hud.popup(label, HudScript.ACCENT, placed.get_global_transform_with_canvas().origin)
		_hud.flash(Color(1.0, 1.0, 1.0), 0.07)
		_play_blip(660.0 + minf(combo, 8) * 45.0)
		_haptic(18)
	else:
		combo = 0
		_spawn_impact(placed, false)
		_add_shake(0.10)
		_play_blip(440.0)

	if res.perfect:
		_spawn_impact(placed, true)

	_hud.set_score(score)

	var top_local: float = placed.position.y - _bh * 0.5
	var want: float = _vs.y * 0.42 - top_local
	if want > _scroll_target:
		_scroll_target = want

	_spawn_moving()

func restart() -> void:
	_reset_board(false)
	state = State.PLAYING
	_hud.hide_game_over()
	_hud.hide_title()
	_hud.set_score(0, false)
	_hud.set_best(best)

## Pure placement math, kept static so it can be unit tested headlessly.
static func compute_placement(prev_x: float, prev_w: float, cur_x: float, cur_w: float) -> Dictionary:
	var perfect := absf(cur_x - prev_x) <= PERFECT_TOLERANCE
	var left := maxf(prev_x - prev_w * 0.5, cur_x - cur_w * 0.5)
	var right := minf(prev_x + prev_w * 0.5, cur_x + cur_w * 0.5)
	if perfect:
		left = prev_x - prev_w * 0.5
		right = prev_x + prev_w * 0.5
	var trim_left := 0.0
	var trim_right := 0.0
	if not perfect:
		trim_left = maxf(0.0, left - (cur_x - cur_w * 0.5))
		trim_right = maxf(0.0, (cur_x + cur_w * 0.5) - right)
	return {
		"left": left,
		"right": right,
		"overlap": maxf(0.0, right - left),
		"perfect": perfect,
		"trim_left": trim_left,
		"trim_right": trim_right,
	}

# ------------------------------------------------------------------ internals

func _on_tap() -> void:
	# A touch is delivered both as InputEventScreenTouch and (when mouse
	# emulation is on) as an emulated InputEventMouseButton. Ignore the twin.
	var frame := Engine.get_process_frames()
	if frame == _tap_frame:
		return
	_tap_frame = frame

	match state:
		State.READY:
			begin_play()
			drop_block()
		State.PLAYING:
			drop_block()
		State.GAMEOVER:
			if Time.get_ticks_msec() - _over_at > RESTART_DELAY_MS:
				restart()

func _compute_layout() -> void:
	_left = _vs.x * 0.11
	_right = _vs.x * 0.89
	_bh = _vs.x * 0.089
	_bw = _vs.x * 0.52
	_ground = _vs.y * 0.82
	_place_ground()

func _place_ground() -> void:
	if _ground_node == null:
		return
	_ground_node.position = Vector2(_vs.x * 0.5, _ground)
	_ground_node.setup(_vs.x, _vs.y * 0.5)

func _reset_board(demo: bool) -> void:
	for child in _world.get_children():
		if child != _ground_node:
			child.queue_free()
	blocks.clear()
	moving = null
	score = 0
	combo = 0
	_scroll = 0.0
	_scroll_target = 0.0
	_world.position = Vector2.ZERO
	_dir = 1.0
	_speed = BASE_SPEED
	_spawn_right = true

	var base = _make_block(_vs.x * 0.5, _ground - _bh * 0.5, _bw, _color_for(0))
	_world.add_child(base)
	blocks.append(base)

	if demo:
		for i in DEMO_BLOCKS:
			var prev = blocks[blocks.size() - 1]
			var offset: float = randf_range(-0.1, 0.1) * prev.size.x
			var width: float = prev.size.x * 0.93
			var block = _make_block(prev.position.x + offset, prev.position.y - _bh, width, _color_for(blocks.size()))
			_world.add_child(block)
			blocks.append(block)

	_spawn_moving()

	var top_local: float = blocks[blocks.size() - 1].position.y - _bh * 0.5
	_scroll_target = maxf(0.0, _vs.y * 0.42 - top_local)

func _spawn_moving() -> void:
	var prev = blocks[blocks.size() - 1]
	var width: float = prev.size.x
	var y: float = prev.position.y - _bh
	var half := width * 0.5
	var min_x := _left + half
	var max_x := _right - half
	if min_x > max_x:
		min_x = _vs.x * 0.5
		max_x = min_x

	var from_right := _spawn_right
	_spawn_right = not _spawn_right
	moving = _make_block(max_x if from_right else min_x, y, width, _color_for(blocks.size()), true)
	_dir = -1.0 if from_right else 1.0
	_speed = minf(BASE_SPEED + score * SPEED_PER_BLOCK, MAX_SPEED)
	_world.add_child(moving)

func _end_game() -> void:
	state = State.GAMEOVER
	_over_at = Time.get_ticks_msec()
	if moving != null:
		var away := 1.0 if moving.position.x > blocks[blocks.size() - 1].position.x else -1.0
		moving.make_falling(Vector2(away * 240.0, -80.0), away * 3.5)
		moving = null

	var new_best := score > best
	if new_best:
		best = score
		_save_best()
	_hud.set_score(score, false)
	_hud.show_game_over(score, best, new_best)
	_hud.flash(Color(1.0, 0.32, 0.38), 0.18)
	_add_shake(0.55)
	_play_blip(150.0)
	_haptic(60)

func _add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _spawn_impact(block, perfect: bool) -> void:
	var count := 9 if perfect else 4
	var origin: Vector2 = block.position + Vector2(0.0, -block.size.y * 0.4)
	for i in count:
		var spark = SparkScript.new()
		var angle := randf_range(-PI * 0.85, -PI * 0.15)
		var speed := randf_range(260.0, 700.0) if perfect else randf_range(120.0, 320.0)
		var tint: Color = Color(1.0, 0.98, 1.0, 0.95) if perfect else block.color.lightened(0.35)
		spark.setup(tint, Vector2(cos(angle), sin(angle)) * speed,
			randf_range(8.0, 17.0) if perfect else randf_range(6.0, 11.0),
			randf_range(0.4, 0.75))
		spark.position = origin + Vector2(randf_range(-block.size.x * 0.35, block.size.x * 0.35), 0.0)
		_world.add_child(spark)

func _make_block(x: float, y: float, width: float, color: Color, focus: bool = false):
	var b = BlockScript.new()
	b.setup(Vector2(width, _bh), color, focus)
	b.position = Vector2(x, y)
	return b

func _color_for(index: int) -> Color:
	return PALETTE[index % PALETTE.size()]

func _build_background() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)

	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/background.gdshader")
	rect.material = mat
	bg_layer.add_child(rect)

	var decor_layer := CanvasLayer.new()
	decor_layer.layer = -9
	add_child(decor_layer)
	_backdrop = BackdropScript.new()
	_backdrop.name = "Backdrop"
	decor_layer.add_child(_backdrop)
	_backdrop.setup(_vs)

func _on_viewport_resized() -> void:
	_vs = get_viewport_rect().size
	_compute_layout()
	if _hud != null:
		_hud.relayout(_vs)
	if _backdrop != null:
		_backdrop.setup(_vs)

# ---------------------------------------------------------------------- audio

func _make_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-6.5 * t / duration)
		var attack := minf(1.0, t / 0.004)
		var sample := sin(TAU * freq * t) * env * attack * volume
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _play_blip(freq: float) -> void:
	if _sfx == null or _sfx.stream == null:
		return
	_sfx.pitch_scale = clampf(freq / 440.0, 0.25, 3.5)
	_sfx.play()

func _haptic(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# ---------------------------------------------------------------------- saves

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("score", "best", 0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.save(SAVE_PATH)

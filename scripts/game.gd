extends Node2D

## Stack Tower - a one-tap block stacking arcade game.
##
## Everything is laid out procedurally from the viewport size, so it adapts to
## any phone aspect ratio without assets.

const BlockScript := preload("res://scripts/block.gd")
const HudScript := preload("res://scripts/hud.gd")

enum State { READY, PLAYING, GAMEOVER }

const PERFECT_TOLERANCE := 11.0
const MIN_WIDTH := 26.0
const MIN_TRIM := 2.0
const BASE_SPEED := 430.0
const SPEED_PER_BLOCK := 16.0
const MAX_SPEED := 1250.0
const RESTART_DELAY_MS := 550
const SAVE_PATH := "user://stack_tower.cfg"

var state := State.READY
var score := 0
var best := 0
var combo := 0
var blocks: Array = []
var moving = null

var _vs := Vector2(1080.0, 1920.0)
var _world: Node2D
var _hud
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
var _scroll_target := 0.0
var _over_at := 0

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

	_hud = HudScript.new()
	_hud.name = "Hud"
	add_child(_hud)
	_hud.relayout(_vs)

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = _make_tone(440.0, 0.14, 0.30)
	add_child(_sfx)

	get_viewport().size_changed.connect(_on_viewport_resized)

	_load_best()
	_reset_board()
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
	_world.position.y = _scroll

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
	blocks.append(placed)

	if res.trim_right > MIN_TRIM:
		var right_piece = _make_block(res.right + res.trim_right * 0.5, moving.position.y, res.trim_right, moving.color)
		right_piece.make_falling(Vector2(260.0, -340.0), randf_range(2.5, 5.0))
		_world.add_child(right_piece)
	if res.trim_left > MIN_TRIM:
		var left_piece = _make_block(res.left - res.trim_left * 0.5, moving.position.y, res.trim_left, moving.color)
		left_piece.make_falling(Vector2(-260.0, -340.0), randf_range(-5.0, -2.5))
		_world.add_child(left_piece)

	moving.queue_free()
	moving = null

	score += 1
	if res.perfect:
		combo += 1
		var label := "PERFECT" if combo < 2 else "PERFECT x%d" % combo
		_hud.popup(label, HudScript.ACCENT, placed.get_global_transform_with_canvas().origin)
		_play_blip(660.0 + minf(combo, 8) * 45.0)
		_haptic(18)
	else:
		combo = 0
		_play_blip(440.0)

	_hud.set_score(score)

	var top_local: float = placed.position.y - _bh * 0.5
	var want: float = _vs.y * 0.42 - top_local
	if want > _scroll_target:
		_scroll_target = want

	_spawn_moving()

func restart() -> void:
	_reset_board()
	state = State.PLAYING
	_hud.hide_game_over()
	_hud.hide_title()
	_hud.set_score(0)
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

func _reset_board() -> void:
	for child in _world.get_children():
		child.queue_free()
	blocks.clear()
	moving = null
	score = 0
	combo = 0
	_scroll = 0.0
	_scroll_target = 0.0
	_world.position.y = 0.0
	_dir = 1.0
	_speed = BASE_SPEED
	_spawn_right = true

	var base = _make_block(_vs.x * 0.5, _ground - _bh * 0.5, _bw, _color_for(0))
	_world.add_child(base)
	blocks.append(base)
	_spawn_moving()

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
	moving = _make_block(max_x if from_right else min_x, y, width, _color_for(blocks.size()))
	_dir = -1.0 if from_right else 1.0
	_speed = minf(BASE_SPEED + score * SPEED_PER_BLOCK, MAX_SPEED)
	_world.add_child(moving)

func _end_game() -> void:
	state = State.GAMEOVER
	_over_at = Time.get_ticks_msec()
	if moving != null:
		var away := 1.0 if moving.position.x > blocks[blocks.size() - 1].position.x else -1.0
		moving.make_falling(Vector2(away * 280.0, -260.0), away * 3.5)
		moving = null

	var new_best := score > best
	if new_best:
		best = score
		_save_best()
	_hud.set_score(score)
	_hud.show_game_over(score, best, new_best)
	_play_blip(170.0)
	_haptic(60)

func _make_block(x: float, y: float, width: float, color: Color):
	var b = BlockScript.new()
	b.setup(Vector2(width, _bh), color)
	b.position = Vector2(x, y)
	return b

func _color_for(index: int) -> Color:
	return Color.from_hsv(fposmod(0.53 + index * 0.037, 1.0), 0.62, 0.98)

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

func _on_viewport_resized() -> void:
	_vs = get_viewport_rect().size
	_compute_layout()
	if _hud != null:
		_hud.relayout(_vs)

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

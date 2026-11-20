class_name Hud
extends CanvasLayer

## Screen-space UI: score, title screen, game over panel, popups and flashes.

const TEXT := Color(0.97, 0.97, 1.0)
const OUTLINE := Color(0.04, 0.03, 0.10, 0.85)
const ACCENT := Color(0.42, 0.93, 0.76)
const DIM := Color(0.03, 0.02, 0.08, 0.68)

var _vs := Vector2(1080.0, 1920.0)
var _s := 1.0

var _score: Label
var _best: Label

var _title_root: Control
var _title_tap: Label

var _over_root: Control
var _over_score: Label
var _over_best: Label
var _over_tap: Label

var _flash: ColorRect

var _t := 0.0

func _ready() -> void:
	layer = 10
	_build()

func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.55 + 0.45 * sin(_t * 3.2)
	if is_instance_valid(_title_tap):
		_title_tap.modulate.a = pulse
	if is_instance_valid(_over_tap):
		_over_tap.modulate.a = pulse

# ---------------------------------------------------------------- public API

func relayout(view_size: Vector2) -> void:
	_vs = view_size
	_s = _vs.x / 1080.0
	_apply_layout()
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_root.offset_bottom = -_vs.y * 0.16

func set_score(value: int, pop: bool = true) -> void:
	_score.text = str(value)
	if not pop or _score.size.x <= 0.0:
		return
	_score.pivot_offset = _score.size * 0.5
	_score.scale = Vector2(1.16, 1.16)
	var tween := create_tween()
	tween.tween_property(_score, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_best(value: int) -> void:
	_best.text = "BEST %d" % value

func show_title(best: int) -> void:
	_best.text = "BEST %d" % best
	_score.text = "0"
	_score.scale = Vector2.ONE
	_title_root.visible = true
	_title_root.modulate.a = 1.0
	_over_root.visible = false

func hide_title() -> void:
	_title_root.visible = false

func show_game_over(final_score: int, best: int, is_new_best: bool) -> void:
	_best.text = "BEST %d" % best
	_over_score.text = "SCORE  %d" % final_score
	_over_best.text = "NEW BEST!" if is_new_best else "BEST  %d" % best
	_over_best.add_theme_color_override("font_color", ACCENT if is_new_best else TEXT)
	_over_root.visible = true
	_over_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_over_root, "modulate:a", 1.0, 0.22)

func hide_game_over() -> void:
	_over_root.visible = false

func flash(color: Color, peak: float) -> void:
	_flash.color = Color(color.r, color.g, color.b, peak)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)

func popup(text: String, color: Color, screen_pos: Vector2) -> void:
	var label := _make_label(text, 58, color)
	label.size = Vector2(_vs.x, 90.0)
	label.position = Vector2(0.0, screen_pos.y - 90.0)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 150.0 * _s, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75)
	tween.finished.connect(label.queue_free)

# ------------------------------------------------------------------ internals

func _build() -> void:
	_score = _make_label("0", 132, TEXT)
	_score.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_score)

	_best = _make_label("BEST 0", 40, Color(0.82, 0.83, 0.95))
	_best.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_best)

	# Title screen.
	_title_root = CenterContainer.new()
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title_root)

	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 14)
	_title_root.add_child(title_box)

	title_box.add_child(_make_label("STACK", 132, TEXT))
	title_box.add_child(_make_label("TOWER", 132, ACCENT))
	_title_tap = _make_label("TAP TO START", 52, Color(0.85, 0.86, 0.97))
	title_box.add_child(_title_tap)

	# Game over panel.
	_over_root = Control.new()
	_over_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_root.visible = false
	add_child(_over_root)

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_root.add_child(dim)

	var over_center := CenterContainer.new()
	over_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_root.add_child(over_center)

	var over_box := VBoxContainer.new()
	over_box.alignment = BoxContainer.ALIGNMENT_CENTER
	over_box.add_theme_constant_override("separation", 24)
	over_center.add_child(over_box)

	over_box.add_child(_make_label("GAME OVER", 104, TEXT))
	_over_score = _make_label("SCORE  0", 66, TEXT)
	over_box.add_child(_over_score)
	_over_best = _make_label("BEST  0", 48, Color(0.82, 0.83, 0.95))
	over_box.add_child(_over_best)
	_over_tap = _make_label("TAP TO RESTART", 50, Color(0.85, 0.86, 0.97))
	over_box.add_child(_over_tap)

	# Full-screen flash, always on top.
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _make_label(text: String, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(4, int(px * 0.12)))
	label.add_theme_font_size_override("font_size", px)
	label.set_meta("base_size", px)
	return label

func _apply_layout() -> void:
	var labels: Array[Label] = []
	_collect_labels(self, labels)
	for label in labels:
		var base := float(label.get_meta("base_size", 16))
		var px := int(base * _s)
		label.add_theme_font_size_override("font_size", px)
		label.add_theme_constant_override("outline_size", maxi(4, int(px * 0.12)))

	_score.offset_top = int(84 * _s)
	_score.offset_bottom = _score.offset_top + int(160 * _s)
	_best.offset_top = _score.offset_bottom - int(16 * _s)
	_best.offset_bottom = _best.offset_top + int(56 * _s)

func _collect_labels(node: Node, out: Array[Label]) -> void:
	for child in node.get_children():
		if child is Label:
			out.append(child)
		if child.get_child_count() > 0:
			_collect_labels(child, out)

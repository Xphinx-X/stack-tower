extends Node

## Dev helper: runs the real game under a display and saves PNG screenshots.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1920 \
##     res://tests/screenshot.tscn
##
## Output goes to $SHOT_DIR (default /tmp/opencode).

const OUT_DIR := "/tmp/opencode"

var _dir := OUT_DIR

func _ready() -> void:
	var env_dir := OS.get_environment("SHOT_DIR")
	if not env_dir.is_empty():
		_dir = env_dir

	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await _wait(8)
	await _shot("title")

	game.begin_play()
	# A mix of perfect drops and small slices so the tower keeps some width.
	for offset in [2.0, -22.0, 30.0, 2.0, -18.0, 24.0, 2.0, -20.0]:
		if game.moving == null:
			break
		var prev = game.blocks[game.blocks.size() - 1]
		game.moving.position.x = prev.position.x + offset
		game.drop_block()
		await _wait(5)
	await _wait(6)
	await _shot("playing")

	if game.moving != null:
		var prev = game.blocks[game.blocks.size() - 1]
		game.moving.position.x = prev.position.x + 2.0
		game.drop_block()
		await _wait(1)
		await _shot("perfect")

	if game.moving != null:
		var prev = game.blocks[game.blocks.size() - 1]
		game.moving.position.x = prev.position.x + 55.0
		await _wait(2)
		await _shot("aiming")
		game.drop_block()
		await _wait(3)
		await _shot("cut")

	if game.moving != null:
		game.moving.position.x = 9000.0
		game.drop_block()
		await _wait(24)
		await _shot("gameover")

	print("screenshots written to ", _dir)
	get_tree().quit(0)

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join("shot_%s.png" % tag)
	var err := img.save_png(path)
	print("saved %s (%s) err=%d" % [path, img.get_size(), err])

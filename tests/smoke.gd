extends Node

## Boots the real game scene headlessly, stacks a bunch of blocks and checks the
## state machine. Guards against regressions in game.gd.
## Run with: godot --headless --path . res://tests/smoke.tscn

const READY := 0
const PLAYING := 1
const GAMEOVER := 2
const DROPS := 30

var _fails := 0

func _ready() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(game.state == READY, "starts in READY (got %d)" % game.state)
	_ok(game.moving != null, "a moving block is spawned on the title screen")
	_ok(game.blocks.size() == 1, "title screen has one base block")

	game.begin_play()
	_ok(game.state == PLAYING, "begin_play() enters PLAYING")

	var placed := 0
	for i in DROPS:
		if game.state != PLAYING or game.moving == null:
			break
		var prev = game.blocks[game.blocks.size() - 1]
		game.moving.position.x = prev.position.x + 3.0
		game.drop_block()
		placed += 1
		await get_tree().process_frame

	_ok(placed == DROPS, "dropped %d of %d blocks" % [placed, DROPS])
	_ok(game.score == placed, "score == %d (got %d)" % [placed, game.score])
	_ok(game.blocks.size() == placed + 1, "block count == %d (got %d)" % [placed + 1, game.blocks.size()])
	_ok(game.combo == placed, "perfect combo tracked (%d)" % game.combo)

	# The tower must actually have scrolled upwards.
	_ok(game._scroll_target > 0.0, "camera scrolled as the tower grew")

	# Every placed block must sit within its parent's footprint.
	for i in range(1, game.blocks.size()):
		var a = game.blocks[i - 1]
		var b = game.blocks[i]
		_ok(absf(a.position.x - b.position.x) < 0.5, "block %d is aligned with its parent" % i)

	# A total miss must end the run.
	var last = game.blocks[game.blocks.size() - 1]
	game.moving.position.x = last.position.x + 100000.0
	game.drop_block()
	await get_tree().process_frame
	_ok(game.state == GAMEOVER, "a full miss ends the game (state %d)" % game.state)
	_ok(game.score == placed, "score frozen after game over")
	_ok(game.best >= placed - 0, "best score recorded (%d)" % game.best)

	# Restart must reset the board.
	game.restart()
	await get_tree().process_frame
	_ok(game.state == PLAYING, "restart() resumes play")
	_ok(game.score == 0, "restart() resets the score")
	_ok(game.blocks.size() == 1, "restart() rebuilds the base")

	if _fails > 0:
		printerr("smoke test: %d failure(s)" % _fails)
		get_tree().quit(1)
	else:
		print("smoke test: all passed")
		get_tree().quit(0)

func _ok(cond: bool, message: String) -> void:
	if cond:
		print("  ok: ", message)
	else:
		_fails += 1
		printerr("  FAIL: ", message)

extends SceneTree
## Second windowed tour: title -> new game, warps by walking, chests, save points,
## a battle fought to victory with rewards, and a defeat -> game over.
## godot --path . --script res://tests/screenshot_tour2.gd -- --out=DIR

var out_dir := "user://screenshots"
var gs
var stack

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.max_fps = 60
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	await process_frame
	gs = root.get_node("GameState")
	stack = root.get_node("SceneStack")
	root.theme = UITheme.theme()
	RenderingServer.set_default_clear_color(Color("0a0a1a"))
	await _tour()
	quit(0)

func _shot(name: String) -> void:
	await process_frame
	var drawn := [false]
	RenderingServer.frame_post_draw.connect(func(): drawn[0] = true, CONNECT_ONE_SHOT)
	for i in 60:
		await process_frame
		if drawn[0]:
			break
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	printerr("shot ", name)

func _press(action: String, frames: int = 2) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in frames:
		await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	for i in frames:
		await process_frame

func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await process_frame
	Input.action_release(action)
	await process_frame

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _until(cond: Callable, max_frames: int = 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	printerr("timeout waiting")
	return false

func _top_is(script_suffix: String) -> bool:
	var t = stack.top()
	return t != null and t.get_script() != null and t.get_script().resource_path.ends_with(script_suffix)

## Presses through a battle choosing Attack on the first target until it ends.
func _auto_battle(b) -> void:
	for round in 40:
		var ok: bool = await _until(func(): return b._done or b._command.active, 900)
		if not ok or b._done:
			return
		await _press("ui_accept")
		await _until(func(): return b._picking or b._done or b._command.active, 120)
		if b._picking:
			await _press("ui_accept")
	
func _tour() -> void:
	# Title -> New Game -> intro dialog
	stack.replace_all(load("res://src/ui/TitleScene.gd").new())
	await _wait(5)
	await _press("ui_accept")
	await _until(func(): return _top_is("FieldScene.gd"))
	await _wait(90)
	await _shot("30_new_game_intro")
	for i in 3:
		await _press("ui_accept")
		await _press("ui_accept")
		await _wait(30)
	# Walk south out of town through the warp tile
	var field = stack.top()
	await _hold("ui_down", 60)
	await _until(func(): return gs.map_id == "overworld", 300)
	await _wait(20)
	await _shot("31_warped_to_overworld")
	printerr("map after warp: ", gs.map_id, " ", gs.map_x, ",", gs.map_y)
	# Arena: open a chest, use the save point
	gs.set_location("debug_arena", 2, 9, "down")
	stack.replace_all(load("res://src/field/FieldScene.gd").new())
	await _wait(5)
	await _press("ui_accept")  # chest below
	await _wait(40)
	await _shot("32_chest_opened")
	await _press("ui_accept")
	await _press("ui_accept")
	await _wait(10)
	printerr("potions after chest: ", gs.inventory.count("potion"), " flag=", gs.flag("chest:debug_arena:2:10"))
	gs.set_location("debug_arena", 18, 2, "up")
	stack.replace_all(load("res://src/field/FieldScene.gd").new())
	await _wait(5)
	await _press("ui_accept")  # save point above
	await _until(func(): return _top_is("SaveMenu.gd") and stack.top()._slots.active)
	await _wait(5)
	await _shot("33_save_point_menu")
	await _press("ui_accept")  # slot 1
	await _wait(10)
	if _top_is("SaveMenu.gd") and stack.top()._msg.text == "":
		await _press("ui_accept")  # overwrite confirm if a save already exists
		await _wait(10)
	await _shot("34_saved")
	printerr("slot1 exists: ", root.get_node("SaveSystem").exists(1))
	await _press("ui_cancel")
	await _until(func(): return _top_is("FieldScene.gd"))
	# Battle to victory with the fresh party
	var b = load("res://src/battle/BattleScene.gd").new()
	b.setup("slimes")
	stack.push(b)
	await _auto_battle(b)
	await _until(func(): return b._message.text.begins_with("Gained"), 600)
	await _shot("35_battle_victory")
	printerr("ash xp after fight: ", gs.party[0].xp, " level ", gs.party[0].level)
	stack.pop()
	await _wait(5)
	# Defeat -> game over, through EventRunner.start_battle like the field does
	for a in gs.party:
		a.hp = 1
	var er = root.get_node("EventRunner")
	er.start_battle("boss_wyrm")
	await _until(func(): return _top_is("BattleScene.gd"), 300)
	var boss = stack.top()
	await _auto_battle(boss)
	await _until(func(): return _top_is("GameOverScene.gd"), 900)
	await _wait(5)
	await _shot("36_game_over_after_defeat")
	# Load the save from game over
	await _press("ui_accept")
	await _until(func(): return _top_is("SaveMenu.gd") and stack.top()._slots.active)
	await _press("ui_accept")
	await _until(func(): return _top_is("FieldScene.gd"), 300)
	await _wait(10)
	await _shot("37_loaded_from_game_over")
	printerr("after load: map=", gs.map_id, " hp=", gs.party[0].hp)

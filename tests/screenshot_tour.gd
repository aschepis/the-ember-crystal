extends SceneTree
## Drives the game with synthetic input and saves screenshots. Needs a window (not headless).
## godot --path . --script res://tests/screenshot_tour.gd -- --out=/path/to/dir

var out_dir := "user://screenshots"
var gs
var stack
var db

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.max_fps = 60
	# macOS skips drawing occluded windows, which would freeze every capture.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	await process_frame
	gs = root.get_node("GameState")
	stack = root.get_node("SceneStack")
	db = root.get_node("Database")
	root.theme = UITheme.theme()
	RenderingServer.set_default_clear_color(Color("0a0a1a"))
	await _tour()
	quit(0)

func _shot(name: String) -> void:
	await process_frame
	# Bounded wait for a real draw so the captured texture is current.
	var drawn := [false]
	RenderingServer.frame_post_draw.connect(func(): drawn[0] = true, CONNECT_ONE_SHOT)
	for i in 60:
		await process_frame
		if drawn[0]:
			break
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	printerr("shot ", name)

## Waits until cond() is true (or max_frames pass).
func _until(cond: Callable, max_frames: int = 600) -> void:
	for i in max_frames:
		if cond.call():
			return
		await process_frame
	printerr("timeout waiting: ", name_of(cond))

func name_of(c: Callable) -> String:
	return str(c)

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

func _tour() -> void:
	gs.debug_party(8)
	# Debug lab
	stack.replace_all(load("res://src/debug/DebugLab.gd").new())
	await _wait(5)
	await _shot("01_debug_lab")
	# Title
	stack.replace_all(load("res://src/ui/TitleScene.gd").new())
	await _wait(5)
	await _shot("02_title")
	# Town field
	gs.set_location("emberfall", 11, 15, "up")
	stack.replace_all(load("res://src/field/FieldScene.gd").new())
	await _wait(5)
	await _shot("03_town")
	await _hold("ui_up", 90)
	await _hold("ui_left", 60)
	await _shot("04_town_walked")
	# Arena: dialog with the tester NPC
	gs.set_location("debug_arena", 4, 4, "up")
	stack.replace_all(load("res://src/field/FieldScene.gd").new())
	await _wait(5)
	await _press("ui_accept")
	await _wait(50)
	await _shot("05_dialog_typing")
	await _press("ui_accept")  # skip typing
	await _press("ui_accept")  # advance
	await _wait(80)
	await _press("ui_accept")  # skip
	await _press("ui_accept")  # advance -> choice
	await _wait(10)
	await _shot("06_dialog_choice")
	await _press("ui_accept")  # pick first (set flag)
	await _wait(90)
	await _press("ui_accept")
	await _press("ui_accept")
	await _wait(10)
	await _shot("07_arena_after_unlock")
	# Overworld
	gs.set_location("overworld", 10, 11, "right")
	stack.replace_all(load("res://src/field/FieldScene.gd").new())
	await _wait(5)
	await _shot("08_overworld")
	# Battle
	var b = load("res://src/battle/BattleScene.gd").new()
	b.setup("spider_pack")
	stack.push(b)
	await _until(func(): return b._command.active)
	await _shot("09_battle_command")
	await _press("ui_accept")
	await _until(func(): return b._picking)
	await _shot("10_battle_target")
	await _press("ui_right")
	await _press("ui_accept")
	await _until(func(): return b._command.active)
	await _press("ui_down")  # Magic for Mira
	await _press("ui_accept")
	await _until(func(): return b._list.active)
	await _shot("11_battle_magic_list")
	await _press("ui_cancel")
	await _until(func(): return b._command.active)
	await _press("ui_up")
	await _press("ui_accept")  # attack
	await _until(func(): return b._picking)
	await _press("ui_accept")
	await _until(func(): return b._command.active)
	await _press("ui_accept")  # dorn attack
	await _until(func(): return b._picking)
	await _press("ui_accept")
	await _until(func(): return b._command.active)
	await _press("ui_down")  # vex magic
	await _press("ui_accept")
	await _until(func(): return b._list.active)
	await _press("ui_accept")  # fire
	await _until(func(): return b._picking)
	await _press("ui_accept")  # target
	await _wait(60)
	await _shot("12_battle_resolving")
	await _until(func(): return b._command.active, 1200)
	await _shot("13_battle_round2")
	stack.pop()
	await _wait(5)
	# Field menu
	var menu = load("res://src/ui/FieldMenu.gd").new()
	stack.push(menu)
	await _wait(5)
	await _shot("14_field_menu")
	await _press("ui_down")
	await _press("ui_down")
	await _press("ui_accept")  # Equip
	await _press("ui_accept")  # Ash
	await _wait(5)
	await _shot("15_equip_slots")
	await _press("ui_accept")  # weapon
	await _wait(5)
	await _shot("16_equip_pick")
	await _press("ui_cancel")
	await _press("ui_cancel")
	await _press("ui_down")
	await _press("ui_accept")  # Status
	await _press("ui_accept")
	await _wait(5)
	await _shot("17_status")
	await _press("ui_cancel")
	await _press("ui_cancel")
	await _press("ui_cancel")
	await _wait(5)
	# Shop
	var shop = load("res://src/ui/ShopScene.gd").new()
	shop.setup("debug_everything")
	stack.push(shop)
	await _wait(5)
	await _press("ui_accept")  # Buy
	for i in 12:
		await _press("ui_down")
	await _wait(5)
	await _shot("18_shop_buy_preview")
	await _press("ui_accept")
	await _press("ui_right")
	await _press("ui_right")
	await _wait(5)
	await _shot("19_shop_quantity")
	await _press("ui_cancel")
	await _press("ui_cancel")
	await _press("ui_down")
	await _press("ui_accept")  # Sell
	await _wait(5)
	await _shot("20_shop_sell")
	stack.pop()
	# Save menu
	var sm = load("res://src/ui/SaveMenu.gd").new()
	sm.setup("both")
	stack.push(sm)
	await _wait(5)
	await _shot("21_save_menu")
	stack.pop()
	# Debug tools
	stack.push(load("res://src/debug/FlagsInspector.gd").new())
	await _wait(5)
	await _shot("22_flags")
	stack.pop()
	stack.push(load("res://src/debug/DataBrowser.gd").new())
	await _wait(5)
	await _press("ui_down")
	await _press("ui_down")
	await _press("ui_down")
	await _press("ui_down")
	await _press("ui_accept")
	await _wait(5)
	await _shot("23_data_browser")
	stack.pop()
	stack.push(load("res://src/debug/LevelSim.gd").new())
	await _wait(5)
	await _shot("24_level_sim")
	stack.pop()
	stack.push(load("res://src/debug/TestRunnerScene.gd").new())
	await _wait(5)
	await _shot("25_tests")
	stack.pop()
	# Inn via event
	gs.set_location("emberfall_inn", 2, 3, "up")
	stack.replace_all(load("res://src/field/FieldScene.gd").new())
	await _wait(5)
	await _press("ui_accept")
	await _wait(10)
	await _shot("26_inn_prompt")
	await _press("ui_accept")
	await _wait(100)
	await _shot("27_inn_done")
	stack.replace_all(load("res://src/ui/GameOverScene.gd").new())
	await _wait(5)
	await _shot("28_game_over")
	stack.replace_all(load("res://src/ui/EndingScene.gd").new())
	await _wait(120)
	await _shot("29_ending")

extends Control
## Title screen: New Game / Load Game / Debug Lab / Quit.

signal _choice(index: int)

var _menu: MenuList

func _ready() -> void:
	UITheme.fullscreen(self)
	var bg := TextureRect.new()
	bg.texture = Placeholder.background("title", Color("1a0a2a"), Color("6a2a1a"), 640, 360)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)
	var title := UITheme.make_label(Database.cfg("game_title", "The Ember Crystal"), 36, UITheme.TEXT_HIGHLIGHT)
	title.position = Vector2(0, 70)
	title.size = Vector2(640, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := UITheme.make_label("A traditional RPG engine demo", UITheme.FONT_SIZE, UITheme.TEXT_DIM)
	sub.position = Vector2(0, 116)
	sub.size = Vector2(640, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var win := UITheme.make_window(Vector2(180, 100))
	win.position = Vector2(230, 190)
	add_child(win)
	_menu = MenuList.new()
	_menu.column_width = 150
	_menu.allow_cancel = false
	win.add_child(_menu)
	_menu.set_items(["New Game", "Load Game", "Debug Lab", "Quit"])
	_menu.selected.connect(func(i): _choice.emit(i))
	AudioManager.play_bgm("title")
	_run()

func _on_stack_active(active: bool) -> void:
	if active and _menu:
		_menu.activate()

func _run() -> void:
	await get_tree().process_frame
	while true:
		_menu.activate()
		var idx: int = await _choice
		_menu.deactivate()
		match idx:
			0:
				GameState.new_game()
				await SceneStack.fade_out(0.4)
				SceneStack.fade_in(0.4)
				# replace_all frees this scene, so it must be the last thing we do.
				SceneStack.replace_all(load("res://src/field/FieldScene.gd").new())
				return
			1:
				var sm = load("res://src/ui/SaveMenu.gd").new()
				sm.setup("load")
				SceneStack.push(sm)
			2:
				SceneStack.replace_all(load("res://src/debug/DebugLab.gd").new())
				return
			3:
				get_tree().quit()

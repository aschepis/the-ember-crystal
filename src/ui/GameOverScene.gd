extends Control
## Shown when the party is wiped. Offers load / title / lab.

signal _choice(index: int)

func _ready() -> void:
	UITheme.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("1a0000")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var l := UITheme.make_label("The party has fallen.", 30, UITheme.HP_CRIT)
	l.position = Vector2(0, 90)
	l.size = Vector2(640, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var win := UITheme.make_window(Vector2(180, 80))
	win.position = Vector2(230, 190)
	add_child(win)
	var menu := MenuList.new()
	menu.column_width = 150
	menu.allow_cancel = false
	win.add_child(menu)
	menu.set_items(["Load Game", "Title Screen", "Debug Lab"])
	menu.selected.connect(func(i): _choice.emit(i))
	AudioManager.stop_bgm()
	_run(menu)

func _run(menu: MenuList) -> void:
	await get_tree().process_frame
	while true:
		menu.activate()
		var idx: int = await _choice
		menu.deactivate()
		match idx:
			0:
				var sm = load("res://src/ui/SaveMenu.gd").new()
				sm.setup("load")
				SceneStack.push(sm)
			1:
				SceneStack.replace_all(load("res://src/ui/TitleScene.gd").new())
				return
			2:
				SceneStack.replace_all(load("res://src/debug/DebugLab.gd").new())
				return

func _on_stack_active(active: bool) -> void:
	pass

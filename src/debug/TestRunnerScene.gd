extends Control
## Runs the test suite in-process and shows the log.

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var win := UITheme.make_window(Vector2(616, 340))
	win.position = Vector2(12, 8)
	add_child(win)
	var text := RichTextLabel.new()
	text.theme = UITheme.theme()
	text.add_theme_font_size_override("normal_font_size", UITheme.FONT_SIZE_SMALL)
	text.custom_minimum_size = Vector2(596, 320)
	text.scroll_active = true
	win.add_child(text)
	var saved := GameState.to_dict()
	var runner := TestRunner.new()
	runner.run_all()
	GameState.load_dict(saved)
	var lines := runner.log.duplicate()
	for e in Database.load_errors:
		lines.append("DATA ERROR: " + e)
	lines.append("\n(cancel to return)")
	text.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		SceneStack.pop()

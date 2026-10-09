extends Control
## Scrolling ending text, then back to the title.

var _text: Label
var _done := false

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = Placeholder.background("ending", Color("2a1a0a"), Color("ff9a4a"), 640, 360)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)
	_text = UITheme.make_label("", UITheme.FONT_SIZE_LARGE)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.size = Vector2(640, 600)
	_text.position = Vector2(0, 360)
	var names: Array[String] = []
	for a in GameState.party:
		names.append("%s, %s, level %d" % [a.display_name, a.klass.name, a.level])
	_text.text = "The Ember Crystal returned to its shrine.\n\nThe hearth-fires of Emberfall burned again,\nand winter stayed on the far side of the mountains.\n\n\n%s\n\nPlay time %s\nSteps %d\nGold %d\n\n\nTHE END\n\n(a placeholder ending — the asset pipeline will do better)" % ["\n".join(names), GameState.format_play_time(), GameState.steps, GameState.gold]
	add_child(_text)
	AudioManager.play_bgm("ending")
	var tw := create_tween()
	tw.tween_property(_text, "position:y", -400.0, 24.0)
	tw.tween_callback(func(): _done = true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and (_done or _text.position.y < -200):
		SceneStack.replace_all(load("res://src/ui/TitleScene.gd").new())
	elif event.is_action_pressed("ui_accept"):
		_text.position.y -= 80

class_name DialogBox
extends CanvasLayer
## Bottom-of-screen message window with typewriter text, speaker name and choice prompts.
## Methods are coroutines: `await box.say("...")`, `var i = await box.choose([...])`.

const CHARS_PER_SECOND := 60.0

var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _prompt: Label
var _choice_panel: PanelContainer
var _choices: MenuList
var _waiting := false
var _advance := false
var _skip := false
var _choice_result := -1
var _generation := 0
## Test hooks: when auto_advance is on, say() returns at once and choose() picks auto_choice.
var auto_advance := false
var auto_choice := 0
var transcript: Array[String] = []

func _ready() -> void:
	layer = 50
	_panel = UITheme.make_window(Vector2(600, 90))
	_panel.position = Vector2(20, 262)
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_speaker = UITheme.make_label("", UITheme.FONT_SIZE, UITheme.TEXT_HIGHLIGHT)
	v.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 54)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.theme = UITheme.theme()
	v.add_child(_text)
	_prompt = UITheme.make_label("▼", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_HIGHLIGHT)
	_prompt.position = Vector2(580, 70)
	_prompt.visible = false
	_panel.add_child(_prompt)
	_choice_panel = UITheme.make_window()
	_choice_panel.visible = false
	add_child(_choice_panel)
	_choices = MenuList.new()
	_choices.column_width = 180
	_choices.allow_cancel = false
	_choice_panel.add_child(_choices)
	_choices.selected.connect(func(i): _choice_result = i)

## Closes the box and releases any coroutine waiting on input.
func abort() -> void:
	_generation += 1
	_waiting = false
	hide_box()

func say(text: String, speaker: String = "") -> void:
	transcript.append(text)
	if auto_advance:
		return
	var gen := _generation
	_panel.visible = true
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_text.text = text
	_text.visible_characters = 0
	_prompt.visible = false
	_skip = false
	_waiting = true
	var total := _text.get_total_character_count()
	var shown := 0.0
	while shown < total and not _skip and gen == _generation:
		await get_tree().process_frame
		shown += CHARS_PER_SECOND * get_process_delta_time()
		_text.visible_characters = int(shown)
	if gen != _generation:
		return
	_text.visible_characters = -1
	_prompt.visible = true
	_advance = false
	while not _advance and gen == _generation:
		await get_tree().process_frame
	_waiting = false
	_prompt.visible = false

func choose(options: Array, prompt: String = "", speaker: String = "") -> int:
	transcript.append(prompt)
	if auto_advance:
		return clampi(auto_choice, 0, options.size() - 1)
	_waiting = false
	if prompt != "":
		_panel.visible = true
		_speaker.text = speaker
		_speaker.visible = speaker != ""
		_text.text = prompt
		_text.visible_characters = -1
	_choices.set_items(options)
	_choice_panel.visible = true
	_choice_panel.reset_size()
	await get_tree().process_frame
	_choice_panel.position = Vector2(640 - _choice_panel.size.x - 24, 262 - _choice_panel.size.y - 4)
	_choice_result = -1
	var gen := _generation
	_choices.activate()
	while _choice_result < 0 and gen == _generation:
		await get_tree().process_frame
	_choices.deactivate()
	_choice_panel.visible = false
	return maxi(0, _choice_result)

func hide_box() -> void:
	_panel.visible = false
	_choice_panel.visible = false

func is_open() -> bool:
	return _panel.visible or _choice_panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if not _waiting:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _text.visible_characters >= 0 and _text.visible_characters < _text.get_total_character_count():
			_skip = true
		else:
			_advance = true
			AudioManager.play_sfx("cursor")

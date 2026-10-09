extends Node
## A stack of full-screen scenes. Only the top scene is visible and processing.
## Battle pushes over the field, menus push over battle/field, and pop() restores the scene below.

signal stack_changed

var _stack: Array[Node] = []
var _fader: ColorRect
var _layer: CanvasLayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fader)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_lab"):
		var t := top()
		if t and t.get_script() and t.get_script().resource_path.ends_with("DebugLab.gd"):
			return
		get_viewport().set_input_as_handled()
		EventRunner.dialog_box.hide_box()
		replace_all(load("res://src/debug/DebugLab.gd").new())

func top() -> Node:
	return _stack.back() if not _stack.is_empty() else null

func depth() -> int:
	return _stack.size()

func push(scene: Node) -> void:
	var prev := top()
	if prev:
		_set_active(prev, false)
	_stack.append(scene)
	add_child(scene)
	_set_active(scene, true)
	stack_changed.emit()

## Removes the top scene. The revealed scene receives _on_resume(result) if it defines it.
func pop(result = null) -> void:
	if _stack.is_empty():
		return
	var scene: Node = _stack.pop_back()
	remove_child(scene)
	scene.queue_free()
	var below := top()
	if below:
		_set_active(below, true)
		if below.has_method("_on_resume"):
			below.call("_on_resume", result)
	stack_changed.emit()

## Clears everything and shows a single scene (title, game over, lab).
func replace_all(scene: Node) -> void:
	while not _stack.is_empty():
		var s: Node = _stack.pop_back()
		remove_child(s)
		s.queue_free()
	push(scene)

func _set_active(scene: Node, active: bool) -> void:
	scene.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if scene is CanvasItem:
		scene.visible = active
	if scene.has_method("_on_stack_active"):
		scene.call("_on_stack_active", active)

func fade_out(duration: float = 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0, duration)
	await tw.finished

func fade_in(duration: float = 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 0.0, duration)
	await tw.finished

func flash(color: Color = Color.WHITE, duration: float = 0.15) -> void:
	_fader.color = Color(color.r, color.g, color.b, 0.8)
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 0.0, duration)
	await tw.finished
	_fader.color = Color(0, 0, 0, 0)

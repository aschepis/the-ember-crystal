class_name MenuList
extends Control
## Keyboard-driven list with a cursor, optional columns and scrolling.
## Emits selected(index) on confirm and cancelled() on cancel. Only reacts while `active`.

signal selected(index: int)
signal cancelled
signal cursor_moved(index: int)

@export var columns: int = 1
@export var visible_rows: int = 8
@export var row_height: int = 18
@export var column_width: int = 120
@export var wrap: bool = true
@export var allow_cancel: bool = true
@export var font_size: int = UITheme.FONT_SIZE
## Hidden menus that only drive a cursor elsewhere (party picker) still need input.
var input_only: bool = false

var items: Array = []           # Strings (or Dictionaries with "text", "right", "disabled", "color")
var index: int = 0
var active: bool = false
var scroll: int = 0              # first visible row
var _labels: Array[Label] = []
var _right_labels: Array[Label] = []
var _cursor: Label
var _hold_time := 0.0
var _hold_dir := Vector2i.ZERO

func _ready() -> void:
	_cursor = Label.new()
	_cursor.text = "▶"
	_cursor.add_theme_font_size_override("font_size", font_size)
	_cursor.add_theme_color_override("font_color", UITheme.TEXT_HIGHLIGHT)
	add_child(_cursor)
	_rebuild()

func set_items(new_items: Array, keep_index: bool = false) -> void:
	items = new_items
	if not keep_index:
		index = 0
		scroll = 0
	index = clampi(index, 0, maxi(0, items.size() - 1))
	_rebuild()

func item_text(i: int) -> String:
	var it = items[i]
	return it["text"] if it is Dictionary else String(it)

func is_disabled(i: int) -> bool:
	var it = items[i]
	return it is Dictionary and it.get("disabled", false)

func activate(at: int = -1) -> void:
	active = true
	if at >= 0:
		index = clampi(at, 0, maxi(0, items.size() - 1))
	_ensure_visible()
	_refresh()

func deactivate() -> void:
	active = false
	_refresh()

func _rows() -> int:
	return int(ceil(float(items.size()) / columns))

func _rebuild() -> void:
	for l in _labels:
		l.queue_free()
	for l in _right_labels:
		l.queue_free()
	_labels.clear()
	_right_labels.clear()
	var rows := mini(_rows(), visible_rows)
	for i in rows * columns:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", font_size)
		add_child(l)
		_labels.append(l)
		var r := Label.new()
		r.add_theme_font_size_override("font_size", font_size)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(r)
		_right_labels.append(r)
	custom_minimum_size = Vector2(columns * column_width + 16, rows * row_height)
	_refresh()

func _refresh() -> void:
	if _cursor == null:
		return
	var rows := mini(_rows(), visible_rows)
	for slot in _labels.size():
		var row := slot / columns
		var col := slot % columns
		var i := (scroll + row) * columns + col
		var l := _labels[slot]
		var r := _right_labels[slot]
		l.position = Vector2(16 + col * column_width, row * row_height)
		r.position = l.position
		r.size = Vector2(column_width - 8, row_height)
		if i < items.size():
			l.text = item_text(i)
			var it = items[i]
			r.text = it.get("right", "") if it is Dictionary else ""
			var color := UITheme.TEXT
			if it is Dictionary and it.has("color"):
				color = it["color"]
			if is_disabled(i):
				color = UITheme.TEXT_DIM
			l.add_theme_color_override("font_color", color)
			r.add_theme_color_override("font_color", color)
			l.visible = true
			r.visible = true
		else:
			l.visible = false
			r.visible = false
	var cur_row := index / columns - scroll
	var cur_col := index % columns
	_cursor.visible = active and not items.is_empty() and cur_row >= 0 and cur_row < rows
	_cursor.position = Vector2(cur_col * column_width, cur_row * row_height)

func _ensure_visible() -> void:
	var row := index / columns
	if row < scroll:
		scroll = row
	elif row >= scroll + visible_rows:
		scroll = row - visible_rows + 1
	scroll = clampi(scroll, 0, maxi(0, _rows() - visible_rows))

func _unhandled_input(event: InputEvent) -> void:
	if not active or (not input_only and not is_visible_in_tree()):
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if items.is_empty():
			return
		if is_disabled(index):
			AudioManager.play_sfx("error")
			return
		AudioManager.play_sfx("confirm")
		selected.emit(index)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if allow_cancel:
			AudioManager.play_sfx("cancel")
			cancelled.emit()
	elif event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(Vector2i(0, -1))
	elif event.is_action_pressed("ui_right", true):
		get_viewport().set_input_as_handled()
		_move(Vector2i(1, 0))
	elif event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_move(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_page_down"):
		_jump(visible_rows * columns)
	elif event.is_action_pressed("ui_page_up"):
		_jump(-visible_rows * columns)

func _jump(delta: int) -> void:
	if items.is_empty():
		return
	index = clampi(index + delta, 0, items.size() - 1)
	_ensure_visible()
	_refresh()
	AudioManager.play_sfx("cursor")
	cursor_moved.emit(index)

func _move(d: Vector2i) -> void:
	if items.is_empty():
		return
	var n := items.size()
	var new_index := index
	if columns == 1:
		if d.x != 0:
			return
		new_index = index + d.y
		if wrap:
			new_index = posmod(new_index, n)
		else:
			new_index = clampi(new_index, 0, n - 1)
	else:
		var row := index / columns
		var col := index % columns
		if d.y != 0:
			row += d.y
			var rows := _rows()
			row = posmod(row, rows) if wrap else clampi(row, 0, rows - 1)
		if d.x != 0:
			col += d.x
			col = posmod(col, columns) if wrap else clampi(col, 0, columns - 1)
		new_index = mini(row * columns + col, n - 1)
	if new_index != index:
		index = new_index
		_ensure_visible()
		_refresh()
		AudioManager.play_sfx("cursor")
		cursor_moved.emit(index)

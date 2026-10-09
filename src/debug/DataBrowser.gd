extends Control
## Browse every loaded data table and view the source JSON of any entry.

signal _choice(index: int)

var _cats: MenuList
var _ids: MenuList
var _detail: RichTextLabel
var _cat_names: Array = []
var _current_ids: Array = []

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var w1 := UITheme.make_window(Vector2(120, 340))
	w1.position = Vector2(8, 8)
	add_child(w1)
	_cats = MenuList.new()
	_cats.column_width = 90
	_cats.visible_rows = 12
	w1.add_child(_cats)
	_cat_names = Database.raw.keys()
	_cats.set_items(_cat_names)
	_cats.selected.connect(func(i): _choice.emit(i))
	_cats.cancelled.connect(func(): _choice.emit(-1))
	var w2 := UITheme.make_window(Vector2(160, 340))
	w2.position = Vector2(132, 8)
	add_child(w2)
	_ids = MenuList.new()
	_ids.column_width = 130
	_ids.visible_rows = 17
	_ids.row_height = 17
	w2.add_child(_ids)
	_ids.selected.connect(func(i): _choice.emit(i))
	_ids.cancelled.connect(func(): _choice.emit(-1))
	_ids.cursor_moved.connect(_show)
	var w3 := UITheme.make_window(Vector2(332, 340))
	w3.position = Vector2(300, 8)
	add_child(w3)
	_detail = RichTextLabel.new()
	_detail.theme = UITheme.theme()
	_detail.add_theme_font_size_override("normal_font_size", UITheme.FONT_SIZE_SMALL)
	_detail.custom_minimum_size = Vector2(310, 320)
	_detail.scroll_active = true
	w3.add_child(_detail)
	_run()

func _show(i: int) -> void:
	if i < 0 or i >= _current_ids.size():
		return
	var cat: String = _cat_names[_cats.index]
	var d = Database.raw[cat][_current_ids[i]]
	_detail.text = JSON.stringify(d, "  ")

func _run() -> void:
	await get_tree().process_frame
	while true:
		_cats.activate()
		var c: int = await _choice
		_cats.deactivate()
		if c < 0:
			SceneStack.pop()
			return
		var cat: String = _cat_names[c]
		_current_ids = Database.raw[cat].keys()
		_current_ids.sort()
		_ids.set_items(_current_ids)
		_show(0)
		_ids.activate()
		var i: int = await _choice
		_ids.deactivate()
		# Scroll with the cursor; any selection or cancel returns to categories.

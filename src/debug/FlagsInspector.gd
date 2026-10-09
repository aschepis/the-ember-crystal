extends Control
## Lists story flags, lets you toggle them, and shows what each flag gates (NPCs, triggers, branches).

signal _choice(index: int)

const KNOWN := ["met_elder", "got_cave_key", "cave_door_open", "golem_defeated", "wyrm_defeated", "has_crystal", "game_complete", "vex_declined", "child_stories", "debug_unlock", "debug_talks"]

var _list: MenuList
var _detail: Label
var _keys: Array = []

func _ready() -> void:
	UITheme.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var t := UITheme.make_label("Plot Flags — confirm toggles / increments, cancel returns", UITheme.FONT_SIZE, UITheme.TEXT_HIGHLIGHT)
	t.position = Vector2(12, 8)
	add_child(t)
	var win := UITheme.make_window(Vector2(300, 300))
	win.position = Vector2(12, 32)
	add_child(win)
	_list = MenuList.new()
	_list.column_width = 270
	_list.visible_rows = 15
	win.add_child(_list)
	_list.selected.connect(func(i): _choice.emit(i))
	_list.cancelled.connect(func(): _choice.emit(-1))
	_list.cursor_moved.connect(_show_detail)
	var right := UITheme.make_window(Vector2(310, 300))
	right.position = Vector2(318, 32)
	add_child(right)
	_detail = UITheme.make_label("", UITheme.FONT_SIZE_SMALL)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(290, 280)
	right.add_child(_detail)
	_run()

func _refresh() -> void:
	var keys := {}
	for k in KNOWN:
		keys[k] = true
	for k in GameState.flags:
		keys[k] = true
	_keys = keys.keys()
	_keys.sort()
	var items: Array = []
	for k in _keys:
		var v = GameState.flags.get(k, null)
		var shown := "unset" if v == null else str(v)
		items.append({"text": k, "right": shown, "color": UITheme.TEXT if v != null and v else UITheme.TEXT_DIM})
	_list.set_items(items, true)

func _show_detail(i: int) -> void:
	if i < 0 or i >= _keys.size():
		return
	var flag: String = _keys[i]
	var uses: Array[String] = []
	for m in Database.maps.values():
		for e in m.entities:
			var cond = e.get("condition", null)
			if cond != null and str(cond).find(flag) >= 0:
				uses.append("map %s: %s %s @(%d,%d) when %s" % [m.id, e.get("type"), e.get("id", e.get("dialog", "")), int(e.get("x", 0)), int(e.get("y", 0)), str(cond)])
	for d in Database.dialogs:
		for cmd in Database.dialogs[d]:
			if cmd is Dictionary:
				if cmd.has("if") and str(cmd["if"]).find(flag) >= 0:
					uses.append("dialog %s: branch if %s" % [d, str(cmd["if"])])
				if cmd.get("set_flag", "") == flag or cmd.get("add_flag", "") == flag:
					uses.append("dialog %s: sets it" % d)
	_detail.text = "%s = %s\n\n%s" % [flag, str(GameState.flags.get(flag, "unset")), "\n".join(uses) if not uses.is_empty() else "(not referenced by any map or dialog)"]

func _run() -> void:
	await get_tree().process_frame
	_refresh()
	_show_detail(0)
	while true:
		_list.activate()
		var idx: int = await _choice
		_list.deactivate()
		if idx < 0:
			SceneStack.pop()
			return
		var k: String = _keys[idx]
		var v = GameState.flags.get(k, null)
		if v is int and not v is bool:
			GameState.add_flag(k, 1)
		elif v == null or v == false:
			GameState.set_flag(k, true)
		else:
			GameState.flags.erase(k)
			GameState.flags_changed.emit(k)
		_refresh()
		_show_detail(idx)

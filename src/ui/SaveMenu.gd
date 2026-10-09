extends Control
## Save / load slot picker. mode: "save" | "load" | "both".

signal _choice(index: int)

var mode := "both"
var _menu: MenuList
var _slots: MenuList
var _title: Label
var _msg: Label

func setup(m: String) -> void:
	mode = m

func _ready() -> void:
	UITheme.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var win := UITheme.make_window(Vector2(520, 220))
	win.position = Vector2(60, 50)
	add_child(win)
	var v := VBoxContainer.new()
	win.add_child(v)
	_title = UITheme.make_label("", UITheme.FONT_SIZE, UITheme.TEXT_HIGHLIGHT)
	v.add_child(_title)
	_menu = MenuList.new()
	_menu.columns = 2
	_menu.column_width = 120
	_menu.visible_rows = 1
	_menu.visible = mode == "both"
	v.add_child(_menu)
	_menu.selected.connect(func(i): _choice.emit(i))
	_menu.cancelled.connect(func(): _choice.emit(-1))
	_slots = MenuList.new()
	_slots.column_width = 480
	_slots.visible_rows = 3
	_slots.row_height = 36
	v.add_child(_slots)
	_slots.selected.connect(func(i): _choice.emit(i))
	_slots.cancelled.connect(func(): _choice.emit(-1))
	_msg = UITheme.make_label("", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_DIM)
	_msg.position = Vector2(60, 280)
	add_child(_msg)
	_run()

func _refresh_slots() -> void:
	var items: Array = []
	for slot in range(1, SaveSystem.SLOTS + 1):
		var info := SaveSystem.slot_info(slot)
		if info.is_empty():
			items.append({"text": "Slot %d   — empty —" % slot, "color": UITheme.TEXT_DIM})
		else:
			items.append({"text": "Slot %d   %s Lv%d   %s   %s" % [slot, info.get("leader", "?"), int(info.get("level", 1)), info.get("map", ""), info.get("play_time", "")], "right": "%d G" % int(info.get("gold", 0))})
	_slots.set_items(items, true)

func _run() -> void:
	await get_tree().process_frame
	while true:
		var action := mode
		if mode == "both":
			_title.text = "Save / Load"
			_menu.set_items(["Save", "Load"], true)
			_refresh_slots()
			_menu.activate()
			var m: int = await _choice
			_menu.deactivate()
			if m < 0:
				SceneStack.pop()
				return
			action = "save" if m == 0 else "load"
		_title.text = "Choose a slot to %s" % action
		_refresh_slots()
		_slots.activate()
		var slot_idx: int = await _choice
		_slots.deactivate()
		if slot_idx < 0:
			if mode == "both":
				continue
			SceneStack.pop()
			return
		var slot := slot_idx + 1
		if action == "save":
			if SaveSystem.exists(slot):
				var ok: int = await EventRunner.dialog_box.choose(["Yes", "No"], "Overwrite slot %d?" % slot)
				EventRunner.dialog_box.hide_box()
				if ok != 0:
					continue
			if SaveSystem.save(slot):
				AudioManager.play_sfx("levelup")
				_msg.text = "Saved to slot %d (%s)." % [slot, SaveSystem.path_for(slot)]
			else:
				_msg.text = "Save failed."
		else:
			if not SaveSystem.exists(slot):
				AudioManager.play_sfx("error")
				_msg.text = "That slot is empty."
				continue
			if SaveSystem.load(slot):
				AudioManager.play_sfx("confirm")
				_msg.text = "Loaded slot %d." % slot
				if mode != "both":
					var field = load("res://src/field/FieldScene.gd").new()
					SceneStack.replace_all(field)
					return
			else:
				_msg.text = "Load failed."

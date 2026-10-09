class_name PartyStatusPanel
extends PanelContainer
## Rows of "Name  HP/Max  MP/Max  [status]". Used by the field menu and battle screen.

signal member_selected(index: int)
signal cancelled

var compact: bool = false
var _rows: Array[Control] = []
var _box: VBoxContainer
var _menu: MenuList
var highlight_index: int = -1

func _ready() -> void:
	theme = UITheme.theme()
	_box = VBoxContainer.new()
	add_child(_box)
	refresh()
	GameState.party_changed.connect(refresh)

func refresh() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for i in GameState.party.size():
		var a := GameState.party[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var cursor := UITheme.make_label("▶" if i == highlight_index else "", UITheme.FONT_SIZE, UITheme.TEXT_HIGHLIGHT)
		cursor.custom_minimum_size.x = 18
		h.add_child(cursor)
		if not compact:
			var icon := TextureRect.new()
			icon.texture = Placeholder.portrait(a.id, a.color(), a.glyph())
			icon.custom_minimum_size = Vector2(24, 24)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h.add_child(icon)
		var name := UITheme.make_label(a.display_name, UITheme.FONT_SIZE, UITheme.TEXT if a.is_alive() else UITheme.TEXT_DIM)
		name.custom_minimum_size.x = 90
		h.add_child(name)
		if not compact:
			var lv := UITheme.make_label("Lv %d" % a.level, UITheme.FONT_SIZE_SMALL, UITheme.TEXT_DIM)
			lv.custom_minimum_size.x = 40
			h.add_child(lv)
		var hp := UITheme.make_label("HP %3d/%3d" % [a.hp, a.max_hp()], UITheme.FONT_SIZE, UITheme.hp_color(a.hp, a.max_hp()))
		hp.custom_minimum_size.x = 100
		h.add_child(hp)
		var mp := UITheme.make_label("MP %3d/%3d" % [a.mp, a.max_mp()], UITheme.FONT_SIZE, UITheme.MP_COLOR)
		mp.custom_minimum_size.x = 100
		h.add_child(mp)
		var st := UITheme.make_label(UITheme.status_text(a), UITheme.FONT_SIZE_SMALL, UITheme.HP_LOW)
		h.add_child(st)
		_box.add_child(h)
		_rows.append(h)

## Lets the player pick a party member; resolves via member_selected / cancelled.
func pick(allow_dead: bool = true) -> void:
	if _menu == null:
		_menu = MenuList.new()
		_menu.visible = false
		_menu.input_only = true
		add_child(_menu)
		_menu.selected.connect(func(i): _menu.deactivate(); highlight_index = -1; refresh(); member_selected.emit(i))
		_menu.cancelled.connect(func(): _menu.deactivate(); highlight_index = -1; refresh(); cancelled.emit())
		_menu.cursor_moved.connect(func(i): highlight_index = i; refresh())
	var items: Array = []
	for a in GameState.party:
		items.append({"text": a.display_name, "disabled": not allow_dead and not a.is_alive()})
	_menu.set_items(items)
	highlight_index = 0
	refresh()
	_menu.activate()

func cancel_pick() -> void:
	if _menu:
		_menu.deactivate()
	highlight_index = -1
	refresh()

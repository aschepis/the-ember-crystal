extends Control
## Buy/sell screen. Equipment rows show, per party member, how ATK/DEF would change.

signal finished
signal _choice(index: int)

var shop: ShopData
var _title: Label
var _gold: Label
var _menu: MenuList
var _list_win: PanelContainer
var _list: MenuList
var _desc: Label
var _preview: Label
var _qty_win: PanelContainer
var _qty_label: Label
var _qty := 1
var _qty_active := false
var _qty_max := 1

func setup(shop_id: String) -> void:
	shop = Database.shop(shop_id)
	assert(shop != null, "Unknown shop " + shop_id)

func _ready() -> void:
	UITheme.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var top := UITheme.make_window(Vector2(616, 44))
	top.position = Vector2(12, 8)
	add_child(top)
	var h := HBoxContainer.new()
	top.add_child(h)
	_title = UITheme.make_label("%s   —   %s" % [shop.name, shop.greeting])
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_title)
	_gold = UITheme.make_label("", UITheme.FONT_SIZE, UITheme.TEXT_HIGHLIGHT)
	h.add_child(_gold)
	var menu_win := UITheme.make_window(Vector2(110, 90))
	menu_win.position = Vector2(12, 60)
	add_child(menu_win)
	_menu = MenuList.new()
	_menu.column_width = 80
	menu_win.add_child(_menu)
	_menu.set_items(["Buy", "Sell", "Leave"])
	_menu.selected.connect(func(i): _choice.emit(i))
	_menu.cancelled.connect(func(): _choice.emit(2))
	_list_win = UITheme.make_window(Vector2(496, 200))
	_list_win.position = Vector2(132, 60)
	add_child(_list_win)
	var v := VBoxContainer.new()
	_list_win.add_child(v)
	_list = MenuList.new()
	_list.column_width = 460
	_list.visible_rows = 9
	v.add_child(_list)
	_list.selected.connect(func(i): _choice.emit(i))
	_list.cancelled.connect(func(): _choice.emit(-1))
	_list.cursor_moved.connect(_on_hover)
	var bottom := UITheme.make_window(Vector2(616, 84))
	bottom.position = Vector2(12, 268)
	add_child(bottom)
	var bv := VBoxContainer.new()
	bottom.add_child(bv)
	_desc = UITheme.make_label("", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_HIGHLIGHT)
	bv.add_child(_desc)
	_preview = UITheme.make_label("", 11)
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size = Vector2(590, 40)
	bv.add_child(_preview)
	_qty_win = UITheme.make_window(Vector2(260, 50))
	_qty_win.position = Vector2(190, 140)
	_qty_win.visible = false
	add_child(_qty_win)
	_qty_label = UITheme.make_label("")
	_qty_win.add_child(_qty_label)
	_refresh_gold()
	_run()

var _hover_ids: Array[String] = []
var _hover_mode := "buy"

func _refresh_gold() -> void:
	_gold.text = "Gold: %d" % GameState.gold

func _on_hover(i: int) -> void:
	if i < 0 or i >= _hover_ids.size():
		_desc.text = ""
		_preview.text = ""
		return
	var it := Database.item(_hover_ids[i])
	_desc.text = "%s   (owned: %d)" % [it.description, GameState.inventory.count(it.id)]
	if it.is_equipment():
		var parts: Array[String] = []
		for a in GameState.party:
			if not a.can_equip(it):
				parts.append("%s: can't equip" % a.display_name)
				continue
			var saved: String = a.equipment[it.type]
			var before := [a.attack(), a.defense(), a.magic_defense(), a.evade()]
			a.equipment[it.type] = it.id
			var after := [a.attack(), a.defense(), a.magic_defense(), a.evade()]
			a.equipment[it.type] = saved
			var same := saved == it.id
			parts.append("%s: ATK %s DEF %s MDEF %s EVA %s%s" % [a.display_name, _delta(before[0], after[0]), _delta(before[1], after[1]), _delta(before[2], after[2]), _delta(before[3], after[3]), " (E)" if same else ""])
		_preview.text = "   ".join(parts)
	else:
		_preview.text = ""

func _delta(a: int, b: int) -> String:
	if a == b:
		return str(b)
	return "%d%s" % [b, "↑" if b > a else "↓"]

func _run() -> void:
	await get_tree().process_frame
	while true:
		_list.set_items([])
		_desc.text = ""
		_preview.text = ""
		_menu.activate()
		var idx: int = await _choice
		_menu.deactivate()
		match idx:
			0: await _buy()
			1: await _sell()
			_:
				finished.emit()
				return

func _buy() -> void:
	while true:
		_hover_mode = "buy"
		_hover_ids.clear()
		var items: Array = []
		for id in shop.items:
			var it := Database.item(id)
			_hover_ids.append(id)
			items.append({"text": it.name, "right": "%d G" % it.price, "disabled": GameState.gold < it.price})
		_list.set_items(items, true)
		_on_hover(_list.index)
		_list.activate()
		var idx: int = await _choice
		_list.deactivate()
		if idx < 0:
			return
		var it := Database.item(shop.items[idx])
		var room := Formulas.MAX_ITEM_STACK - GameState.inventory.count(it.id)
		var afford := int(GameState.gold / maxi(1, it.price)) if it.price > 0 else 99
		var max_qty := mini(room, afford)
		if max_qty <= 0:
			AudioManager.play_sfx("error")
			_desc.text = "You can't carry any more of those." if room <= 0 else "Not enough gold."
			continue
		var qty: int = await _ask_quantity(it, max_qty, it.price)
		if qty <= 0:
			continue
		GameState.spend_gold(it.price * qty)
		GameState.inventory.add(it.id, qty)
		AudioManager.play_sfx("buy")
		_refresh_gold()
		_desc.text = "Bought %d x %s." % [qty, it.name]

func _sell() -> void:
	while true:
		_hover_mode = "sell"
		var ids := GameState.inventory.filter(func(it): return it.sellable and it.price > 0)
		_hover_ids = ids
		if ids.is_empty():
			_desc.text = "You have nothing to sell."
			AudioManager.play_sfx("error")
			return
		var items: Array = []
		for id in ids:
			var it := Database.item(id)
			items.append({"text": "%s  x%d" % [it.name, GameState.inventory.count(id)], "right": "%d G" % _sell_price(it)})
		_list.set_items(items, true)
		_list.index = mini(_list.index, items.size() - 1)
		_on_hover(_list.index)
		_list.activate()
		var idx: int = await _choice
		_list.deactivate()
		if idx < 0:
			return
		var it := Database.item(ids[idx])
		var qty: int = await _ask_quantity(it, GameState.inventory.count(it.id), _sell_price(it))
		if qty <= 0:
			continue
		GameState.inventory.remove(it.id, qty)
		GameState.add_gold(_sell_price(it) * qty)
		AudioManager.play_sfx("buy")
		_refresh_gold()
		_desc.text = "Sold %d x %s." % [qty, it.name]

func _sell_price(it: ItemData) -> int:
	return maxi(1, int(it.price * Formulas.SELL_RATIO))

func _ask_quantity(it: ItemData, max_qty: int, unit_price: int) -> int:
	_qty = 1
	_qty_max = max_qty
	_qty_win.visible = true
	_qty_active = true
	_update_qty(it, unit_price)
	var result: int = await _choice
	_qty_active = false
	_qty_win.visible = false
	return _qty if result >= 0 else 0

func _update_qty(it: ItemData, unit_price: int) -> void:
	_qty_label.text = "%s  ◀ %2d ▶   total %d G" % [it.name, _qty, _qty * unit_price]

func _unhandled_input(event: InputEvent) -> void:
	if not _qty_active:
		return
	var it: ItemData = null
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_choice.emit(1)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("cancel")
		_choice.emit(-1)
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_qty = mini(_qty_max, _qty + (10 if event.is_action_pressed("ui_up", true) else 1))
		AudioManager.play_sfx("cursor")
		_refresh_qty_text()
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_qty = maxi(1, _qty - (10 if event.is_action_pressed("ui_down", true) else 1))
		AudioManager.play_sfx("cursor")
		_refresh_qty_text()

func _refresh_qty_text() -> void:
	# Re-derive the unit price from the label state: buy uses list price, sell uses the ratio.
	var it := Database.item(_hover_ids[_list.index])
	_update_qty(it, it.price if _hover_mode == "buy" else _sell_price(it))

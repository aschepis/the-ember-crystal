extends Control
## The pause menu: Items, Magic, Equip, Status, Order, Save, Quit.

signal _choice(index: int)
signal _member(index: int)

var can_save := true
var _main: MenuList
var _party_panel: PartyStatusPanel
var _info: Label
var _sub_win: PanelContainer
var _sub_title: Label
var _sub: MenuList
var _desc: Label
var _detail: RichTextLabel
var _msg: Label
var _logic: BattleLogic

const COMMANDS := ["Items", "Magic", "Equip", "Status", "Order", "Save", "Quit"]

func _ready() -> void:
	UITheme.fullscreen(self)
	_logic = BattleLogic.for_field()
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var left := UITheme.make_window(Vector2(120, 150))
	left.position = Vector2(12, 12)
	add_child(left)
	_main = MenuList.new()
	_main.column_width = 90
	_main.visible_rows = 7
	left.add_child(_main)
	_main.selected.connect(func(i): _choice.emit(i))
	_main.cancelled.connect(func(): _choice.emit(-1))
	var left2 := UITheme.make_window(Vector2(120, 80))
	left2.position = Vector2(12, 170)
	add_child(left2)
	_info = UITheme.make_label("", UITheme.FONT_SIZE_SMALL)
	left2.add_child(_info)
	_party_panel = PartyStatusPanel.new()
	_party_panel.position = Vector2(140, 12)
	_party_panel.custom_minimum_size = Vector2(488, 120)
	add_child(_party_panel)
	_party_panel.member_selected.connect(func(i): _member.emit(i))
	_party_panel.cancelled.connect(func(): _member.emit(-1))
	_sub_win = UITheme.make_window(Vector2(488, 210))
	_sub_win.position = Vector2(140, 138)
	add_child(_sub_win)
	var v := VBoxContainer.new()
	_sub_win.add_child(v)
	_sub_title = UITheme.make_label("", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_DIM)
	v.add_child(_sub_title)
	_sub = MenuList.new()
	_sub.columns = 2
	_sub.column_width = 230
	_sub.visible_rows = 6
	v.add_child(_sub)
	_sub.selected.connect(func(i): _choice.emit(i))
	_sub.cancelled.connect(func(): _choice.emit(-1))
	_sub.cursor_moved.connect(_on_sub_moved)
	_desc = UITheme.make_label("", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_HIGHLIGHT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(460, 40)
	v.add_child(_desc)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(460, 170)
	_detail.visible = false
	_detail.theme = UITheme.theme()
	_sub_win.add_child(_detail)
	_msg = UITheme.make_label("", UITheme.FONT_SIZE, UITheme.TEXT_HIGHLIGHT)
	_msg.position = Vector2(140, 336)
	add_child(_msg)
	_refresh_info()
	_run()

var _sub_hover: Callable = Callable()

func _on_sub_moved(i: int) -> void:
	if _sub_hover.is_valid():
		_sub_hover.call(i)

func _refresh_info() -> void:
	_info.text = "Gold  %d\nTime  %s\nSteps %d\n%s" % [GameState.gold, GameState.format_play_time(), GameState.steps, GameState.map_id]

func _show_msg(text: String) -> void:
	_msg.text = text
	_msg.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_msg, "modulate:a", 0.0, 0.4)

func _set_sub(title: String, items: Array, hover: Callable = Callable()) -> void:
	_sub_title.text = title
	_sub_hover = hover
	_sub.set_items(items)
	_desc.text = ""
	_detail.visible = false
	_sub.visible = true
	_desc.visible = true
	if hover.is_valid() and not items.is_empty():
		hover.call(0)

func _run() -> void:
	await get_tree().process_frame
	while true:
		_set_sub("", [])
		_main.set_items([
			"Items", "Magic", "Equip", "Status", "Order",
			{"text": "Save", "disabled": not can_save}, "Quit",
		], true)
		_main.activate()
		var idx: int = await _choice
		_main.deactivate()
		match idx:
			-1:
				SceneStack.pop()
				return
			0: await _items()
			1: await _magic()
			2: await _equip()
			3: await _status()
			4: await _order()
			5: SceneStack.push(_make_save_menu())
			6:
				if await _quit():
					return
		_refresh_info()

func _make_save_menu():
	var m = load("res://src/ui/SaveMenu.gd").new()
	m.setup("save")
	return m

func _pick_member(allow_dead: bool = true) -> int:
	_party_panel.pick(allow_dead)
	var i: int = await _member
	_party_panel.cancel_pick()
	return i

# ---------------------------------------------------------------- Items

func _items() -> void:
	while true:
		var ids := GameState.inventory.ids()
		var items: Array = [{"text": "(Sort)", "color": UITheme.TEXT_DIM}]
		for id in ids:
			var it := Database.item(id)
			items.append({"text": it.name, "right": "x%d" % GameState.inventory.count(id), "color": UITheme.TEXT if it.usable_field else UITheme.TEXT_DIM})
		_set_sub("Items", items, func(i): _desc.text = "" if i == 0 else Database.item(ids[i - 1]).description)
		_sub.activate()
		var idx: int = await _choice
		_sub.deactivate()
		if idx < 0:
			return
		if idx == 0:
			GameState.inventory.sort_by_type()
			continue
		var it := Database.item(ids[idx - 1])
		if not it.usable_field:
			_show_msg(it.description if it.description != "" else "Can't use that here.")
			continue
		await _use_field_effect(it.effect, true, it.name, null, func(): GameState.inventory.remove(it.id))

## Shared item/spell application: picks a target when needed and reports the result.
func _use_field_effect(effect: Dictionary, flat: bool, name: String, caster: Actor, on_consume: Callable) -> void:
	var kind: String = effect.get("kind", "")
	if kind == "full_heal":
		GameState.heal_party_fully()
		on_consume.call()
		AudioManager.play_sfx("heal")
		_show_msg("%s: the party is fully restored." % name)
		return
	var target_mode: String = "all_allies" if kind == "full_heal" else "one_ally"
	var targets: Array[Battler] = []
	if target_mode == "one_ally":
		var i: int = await _pick_member(true)
		if i < 0:
			return
		targets = [GameState.party[i]]
	else:
		for a in GameState.party:
			targets.append(a)
	var ev: Array[Dictionary] = []
	for t in targets:
		_logic.apply_effect(caster if caster else t, t, effect, ev, flat)
	var useful := false
	for e in ev:
		if e["type"] in ["heal", "mp", "revive", "cure"] and int(e.get("amount", 1)) > 0:
			useful = true
	if useful:
		on_consume.call()
		AudioManager.play_sfx("heal")
	else:
		AudioManager.play_sfx("error")
	_show_msg(ev.back()["text"] if not ev.is_empty() else "Nothing happened.")
	_party_panel.refresh()

# ---------------------------------------------------------------- Magic

func _magic() -> void:
	var who: int = await _pick_member(false)
	if who < 0:
		return
	var caster := GameState.party[who]
	while true:
		var skills := caster.known_skills()
		var items: Array = []
		for sid in skills:
			var sk := Database.skill(sid)
			items.append({"text": sk.name, "right": "%d MP" % sk.mp_cost, "disabled": not (sk.usable_field and caster.mp >= sk.mp_cost)})
		if items.is_empty():
			_show_msg("%s knows no magic." % caster.display_name)
			return
		_set_sub("%s's magic  (MP %d/%d)" % [caster.display_name, caster.mp, caster.max_mp()], items, func(i): _desc.text = Database.skill(skills[i]).description)
		_sub.activate()
		var idx: int = await _choice
		_sub.deactivate()
		if idx < 0:
			return
		var sk := Database.skill(skills[idx])
		if sk.target == "all_allies":
			var ev: Array[Dictionary] = []
			for a in GameState.party:
				_logic.apply_effect(caster, a, sk.effect, ev, false)
			caster.mp -= sk.mp_cost
			AudioManager.play_sfx("heal")
			_show_msg("%s casts %s on everyone." % [caster.display_name, sk.name])
			_party_panel.refresh()
		else:
			await _use_field_effect(sk.effect, false, sk.name, caster, func(): caster.mp -= sk.mp_cost)

# ---------------------------------------------------------------- Equip

func _equip() -> void:
	var who: int = await _pick_member(true)
	if who < 0:
		return
	var actor := GameState.party[who]
	while true:
		var slots := ItemData.EQUIP_SLOTS
		var items: Array = []
		for slot in slots:
			var it := actor.equipped_item(slot)
			items.append({"text": slot.capitalize(), "right": it.name if it else "-"})
		_set_sub("%s  ATK %d  DEF %d  MDEF %d  EVA %d" % [actor.display_name, actor.attack(), actor.defense(), actor.magic_defense(), actor.evade()], items,
			func(i): var it := actor.equipped_item(slots[i]); _desc.text = it.description if it else "")
		_sub.activate()
		var idx: int = await _choice
		_sub.deactivate()
		if idx < 0:
			return
		await _equip_slot(actor, slots[idx])

func _equip_slot(actor: Actor, slot: String) -> void:
	var candidates: Array[String] = GameState.inventory.filter(func(it): return it.type == slot and actor.can_equip(it))
	var items: Array = [{"text": "(Remove)", "color": UITheme.TEXT_DIM}]
	for id in candidates:
		items.append({"text": Database.item(id).name, "right": "x%d" % GameState.inventory.count(id)})
	var preview := func(i):
		var before := [actor.attack(), actor.defense(), actor.magic_defense(), actor.evade()]
		var saved: String = actor.equipment[slot]
		actor.equipment[slot] = "" if i == 0 else candidates[i - 1]
		var after := [actor.attack(), actor.defense(), actor.magic_defense(), actor.evade()]
		actor.equipment[slot] = saved
		var it: ItemData = null if i == 0 else Database.item(candidates[i - 1])
		_desc.text = "ATK %d→%d   DEF %d→%d   MDEF %d→%d   EVA %d→%d\n%s" % [before[0], after[0], before[1], after[1], before[2], after[2], before[3], after[3], it.description if it else ""]
	_set_sub("%s – %s" % [actor.display_name, slot.capitalize()], items, preview)
	_sub.activate()
	var idx: int = await _choice
	_sub.deactivate()
	if idx < 0:
		return
	var prev := ""
	if idx == 0:
		prev = actor.unequip(slot)
	else:
		var it := Database.item(candidates[idx - 1])
		GameState.inventory.remove(it.id)
		prev = actor.equip(it)
	if prev != "":
		GameState.inventory.add(prev)
	AudioManager.play_sfx("confirm")
	_party_panel.refresh()

# ---------------------------------------------------------------- Status

func _status() -> void:
	var who: int = await _pick_member(true)
	if who < 0:
		return
	var a := GameState.party[who]
	_set_sub("", [])
	_sub.visible = false
	_desc.visible = false
	_detail.visible = true
	var spells: Array[String] = []
	for sid in a.known_skills():
		spells.append(Database.skill(sid).name)
	var equip: Array[String] = []
	for slot in ItemData.EQUIP_SLOTS:
		var it := a.equipped_item(slot)
		equip.append("%s: %s" % [slot.capitalize(), it.name if it else "-"])
	_detail.text = ("[color=#ffe680]%s[/color]  %s  Lv %d\nHP %d/%d   MP %d/%d   XP %d (next in %d)\n" % [a.display_name, a.klass.name, a.level, a.hp, a.max_hp(), a.mp, a.max_mp(), a.xp, a.xp_to_next()]
		+ "STR %d  AGI %d  VIT %d  INT %d  SPI %d  LUCK %d\n" % [a.stat("str"), a.stat("agi"), a.stat("vit"), a.stat("int"), a.stat("spi"), a.stat("luck")]
		+ "ATK %d  DEF %d  MDEF %d  EVA %d  HIT%% %d\n" % [a.attack(), a.defense(), a.magic_defense(), a.evade(), Formulas.hit_chance(a.hit(), a.stat("agi"), 0, false)]
		+ "Status: %s\n" % (UITheme.status_text(a) if not a.statuses.is_empty() else "Normal")
		+ "  ".join(equip) + "\n"
		+ "Magic: %s\n" % (", ".join(spells) if not spells.is_empty() else "-")
		+ "[color=#8a8aa8]%s[/color]" % a.character.bio)
	# Wait for cancel/accept.
	_sub.set_items([""])
	_sub.visible = false
	_sub.activate()
	await _choice
	_sub.deactivate()
	_sub.visible = true

# ---------------------------------------------------------------- Order

func _order() -> void:
	_show_msg("Choose two members to swap.")
	var a: int = await _pick_member(true)
	if a < 0:
		return
	var b: int = await _pick_member(true)
	if b < 0:
		return
	GameState.swap_members(a, b)
	_party_panel.refresh()
	_show_msg("Swapped.")

# ---------------------------------------------------------------- Quit

func _quit() -> bool:
	_set_sub("Quit to...", ["Title Screen", "Debug Lab", "Cancel"])
	_sub.activate()
	var idx: int = await _choice
	_sub.deactivate()
	match idx:
		0:
			SceneStack.replace_all(load("res://src/ui/TitleScene.gd").new())
			return true
		1:
			SceneStack.replace_all(load("res://src/debug/DebugLab.gd").new())
			return true
	return false

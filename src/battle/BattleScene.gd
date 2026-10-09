extends Control
## Turn-based, round-input battle screen (FF1/DQ style): every party member picks a command,
## then all actions resolve in initiative order. Emits finished("victory"|"defeat"|"escape").

signal finished(result: String)
signal _choice(index: int)
signal _target_done(target)

const MESSAGE_TIME := 0.75
const ENEMY_BASELINE := 228.0

var logic := BattleLogic.new()
var group_id: String
var background_id: String
var _bg: TextureRect
var _message: Label
var _message_win: PanelContainer
var _command_win: PanelContainer
var _command: MenuList
var _party_panel: PartyStatusPanel
var _list_win: PanelContainer
var _list: MenuList
var _list_title: Label
var _enemy_nodes: Dictionary = {}   # Enemy -> Control
var _cursor: Label
var _picking := false
var _pick_pool: Array[Battler] = []
var _pick_index := 0
var _pick_all := false
var _done := false

func setup(group: String, background: String = "") -> void:
	group_id = group
	background_id = background

func _ready() -> void:
	UITheme.fullscreen(self)
	logic.setup(group_id, GameState.party, GameState.rng)
	_build_ui()
	_spawn_enemies()
	AudioManager.play_bgm("boss" if _is_boss() else "battle")
	_run()

func _is_boss() -> bool:
	for e in logic.enemies:
		if e.data.boss:
			return true
	return false

func _build_ui() -> void:
	var bg_id := background_id
	if bg_id == "" and logic.group.background != "":
		bg_id = logic.group.background
	var top := Color("3a5a8a")
	var bottom := Color("6a9a5a")
	match bg_id:
		"cave": top = Color("1a1420"); bottom = Color("4a3a40")
		"boss": top = Color("3a0a0a"); bottom = Color("8a3a1a")
		"forest": top = Color("1a3a2a"); bottom = Color("3a7a3a")
	_bg = TextureRect.new()
	_bg.texture = Placeholder.background("battle_" + (bg_id if bg_id != "" else "plains"), top, bottom, 640, 256)
	_bg.position = Vector2.ZERO
	_bg.size = Vector2(640, 256)
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_bg)
	var floor := ColorRect.new()
	floor.color = Color("0a0a1a")
	floor.position = Vector2(0, 256)
	floor.size = Vector2(640, 104)
	add_child(floor)

	_message_win = UITheme.make_window(Vector2(616, 34))
	_message_win.position = Vector2(12, 8)
	add_child(_message_win)
	_message = UITheme.make_label("")
	_message_win.add_child(_message)
	_message_win.visible = false

	_command_win = UITheme.make_window(Vector2(130, 92))
	_command_win.position = Vector2(12, 262)
	add_child(_command_win)
	_command = MenuList.new()
	_command.column_width = 100
	_command.visible_rows = 5
	_command.row_height = 16
	_command.allow_cancel = true
	_command_win.add_child(_command)
	_command.selected.connect(func(i): _choice.emit(i))
	_command.cancelled.connect(func(): _choice.emit(-1))

	_party_panel = PartyStatusPanel.new()
	_party_panel.compact = true
	_party_panel.position = Vector2(150, 262)
	_party_panel.custom_minimum_size = Vector2(478, 92)
	add_child(_party_panel)
	_party_panel.member_selected.connect(func(i): _target_done.emit(GameState.party[i]))
	_party_panel.cancelled.connect(func(): _target_done.emit(null))

	_list_win = UITheme.make_window(Vector2(616, 100))
	_list_win.position = Vector2(12, 258)
	_list_win.visible = false
	add_child(_list_win)
	var v := VBoxContainer.new()
	_list_win.add_child(v)
	_list_title = UITheme.make_label("", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_DIM)
	v.add_child(_list_title)
	_list = MenuList.new()
	_list.columns = 3
	_list.column_width = 196
	_list.visible_rows = 3
	_list.row_height = 18
	v.add_child(_list)
	_list.selected.connect(func(i): _choice.emit(i))
	_list.cancelled.connect(func(): _choice.emit(-1))

	_cursor = UITheme.make_label("▼", UITheme.FONT_SIZE_LARGE, UITheme.TEXT_HIGHLIGHT)
	_cursor.visible = false
	add_child(_cursor)

func _spawn_enemies() -> void:
	var n := logic.enemies.size()
	var spacing := minf(150.0, 560.0 / maxf(1.0, n))
	var total := spacing * (n - 1)
	var start_x := 320.0 - total / 2.0
	for i in n:
		var e := logic.enemies[i]
		var node := Control.new()
		var tex := Placeholder.enemy_sprite(e.data.id, Color(e.data.color), e.data.name, e.data.size)
		var spr := TextureRect.new()
		spr.texture = tex
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.size = Vector2(tex.get_width(), tex.get_height())
		spr.position = Vector2(-spr.size.x / 2, -spr.size.y)
		node.add_child(spr)
		var name := UITheme.make_label(e.display_name, UITheme.FONT_SIZE_SMALL)
		name.position = Vector2(-60, 2)
		name.size = Vector2(120, 14)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.add_child(name)
		node.position = Vector2(start_x + i * spacing, ENEMY_BASELINE)
		node.set_meta("sprite", spr)
		add_child(node)
		_enemy_nodes[e] = node

# ------------------------------------------------------------------ main loop

func _run() -> void:
	await get_tree().process_frame
	var names := {}
	for e in logic.enemies:
		names[e.data.name] = true
	await _say("%s appear%s!" % [", ".join(names.keys()), "s" if names.size() == 1 and logic.enemies.size() == 1 else ""])
	while not _done:
		logic.round_number += 1
		var actions: Array[BattleAction] = await _collect_party_commands()
		actions.append_array(logic.enemy_actions())
		logic.order(actions)
		for action in actions:
			if logic.outcome() != "":
				break
			var events := logic.execute(action)
			await _play_events(events)
			_party_panel.refresh()
			if logic.escaped:
				break
		if logic.outcome() == "":
			await _play_events(logic.end_of_round())
			_party_panel.refresh()
		var result := logic.outcome()
		if result != "":
			await _finish(result)

func _finish(result: String) -> void:
	_done = true
	match result:
		"victory":
			AudioManager.play_bgm("victory")
			var r := logic.rewards()
			await _say("Victory!", "victory")
			await _play_events(logic.apply_rewards(r))
			_party_panel.refresh()
		"defeat":
			AudioManager.stop_bgm()
			await _say("The party has fallen...", "ko")
		"escape":
			pass
	logic.cleanup()
	finished.emit(result)

## Lets each conscious member choose; cancel steps back to the previous member (FF style).
func _collect_party_commands() -> Array[BattleAction]:
	var choosers: Array[Actor] = []
	for a in logic.party:
		if a.can_act():
			choosers.append(a)
	var actions: Array[BattleAction] = []
	var i := 0
	while i < choosers.size():
		var actor := choosers[i]
		_party_panel.highlight_index = GameState.party.find(actor)
		_party_panel.refresh()
		var action: BattleAction = await _choose_for(actor, i > 0)
		if action == null:
			i = maxi(0, i - 1)
			actions.resize(i)
			continue
		actions.append(action)
		i += 1
	_party_panel.highlight_index = -1
	_party_panel.refresh()
	_command.deactivate()
	return actions

func _choose_for(actor: Actor, can_back: bool) -> BattleAction:
	_command_win.visible = true
	while true:
		var has_magic := not actor.known_skills().is_empty()
		var has_items := not GameState.inventory.filter(func(it): return it.usable_battle).is_empty()
		_command.set_items([
			"Attack",
			{"text": "Magic", "disabled": not has_magic},
			{"text": "Item", "disabled": not has_items},
			"Defend",
			{"text": "Run", "disabled": not logic.can_run()},
		], true)
		_command.allow_cancel = can_back
		_command.activate()
		await _say_prompt("%s: choose a command." % actor.display_name)
		var idx: int = await _choice
		_command.deactivate()
		if idx < 0:
			return null
		match idx:
			0:
				var t = await _pick_target("one_enemy")
				if t == null:
					continue
				var act := BattleAction.make(actor, "attack")
				act.target_mode = "one_enemy"
				act.targets = [t]
				return act
			1:
				var act = await _choose_skill(actor)
				if act:
					return act
			2:
				var act = await _choose_item(actor)
				if act:
					return act
			3:
				return BattleAction.make(actor, "defend")
			4:
				var act := BattleAction.make(actor, "run")
				return act
	return null

func _choose_skill(actor: Actor) -> BattleAction:
	var skills := actor.known_skills()
	var items: Array = []
	for sid in skills:
		var sk := Database.skill(sid)
		var usable := sk.usable_battle and actor.mp >= sk.mp_cost and not actor.has_status(StatusEffects.SILENCE)
		items.append({"text": sk.name, "right": "%d MP" % sk.mp_cost, "disabled": not usable})
	_list_title.text = "%s's magic   (MP %d/%d)" % [actor.display_name, actor.mp, actor.max_mp()]
	_list.set_items(items)
	_list_win.visible = true
	_command_win.visible = false
	_list.activate()
	var idx: int = await _choice
	_list.deactivate()
	_list_win.visible = false
	_command_win.visible = true
	if idx < 0:
		return null
	var sk := Database.skill(skills[idx])
	var targets: Array[Battler] = []
	if sk.target in ["one_enemy", "one_ally"]:
		var t = await _pick_target(sk.target, sk.effect.get("kind") == "revive")
		if t == null:
			return null
		targets = [t]
	elif sk.target in ["all_enemies", "all_allies"]:
		var ok = await _pick_target(sk.target)
		if ok == null:
			return null
		targets = logic.resolve_targets(actor, sk.target)
	else:
		targets = [actor]
	var act := BattleAction.make(actor, "skill")
	act.skill = sk
	act.target_mode = sk.target
	act.targets = targets
	return act

func _choose_item(actor: Actor) -> BattleAction:
	var ids := GameState.inventory.filter(func(it): return it.usable_battle)
	var items: Array = []
	for id in ids:
		items.append({"text": Database.item(id).name, "right": "x%d" % GameState.inventory.count(id)})
	_list_title.text = "Items"
	_list.set_items(items)
	_list_win.visible = true
	_command_win.visible = false
	_list.activate()
	var idx: int = await _choice
	_list.deactivate()
	_list_win.visible = false
	_command_win.visible = true
	if idx < 0:
		return null
	var it := Database.item(ids[idx])
	var targets: Array[Battler] = []
	if it.target in ["one_enemy", "one_ally"]:
		var t = await _pick_target(it.target, it.effect.get("kind") == "revive")
		if t == null:
			return null
		targets = [t]
	elif it.target in ["all_enemies", "all_allies"]:
		var ok = await _pick_target(it.target)
		if ok == null:
			return null
		targets = logic.resolve_targets(actor, it.target)
	else:
		targets = [actor]
	var act := BattleAction.make(actor, "item")
	act.item = it
	act.target_mode = it.target
	act.targets = targets
	return act

## Returns the chosen Battler (or `true` for group targets), or null on cancel.
func _pick_target(mode: String, dead_only: bool = false):
	match mode:
		"one_ally":
			await _say_prompt("Choose an ally.")
			_party_panel.pick(true)
			var t = await _target_done
			_party_panel.cancel_pick()
			if t != null and dead_only and t.is_alive():
				await _say("%s doesn't need that." % t.display_name)
				return null
			return t
		"all_allies":
			return true
		"one_enemy", "all_enemies":
			_pick_pool = logic.alive_enemies()
			if _pick_pool.is_empty():
				return null
			_pick_all = mode == "all_enemies"
			_pick_index = 0
			_picking = true
			_cursor.visible = true
			await _say_prompt("Choose a target." if not _pick_all else "Targets all enemies.")
			_update_cursor()
			var t = await _target_done
			_picking = false
			_cursor.visible = false
			for e in _enemy_nodes:
				_enemy_nodes[e].modulate = Color.WHITE if e.is_alive() else Color(1, 1, 1, 0)
			return t
	return true

func _update_cursor() -> void:
	for e in _pick_pool:
		_enemy_nodes[e].modulate = Color.WHITE if _pick_all else Color(0.7, 0.7, 0.7)
	if _pick_all:
		var first: Enemy = _pick_pool[0]
		_cursor.position = _enemy_nodes[first].position + Vector2(-8, -first.data.size - 24)
		_cursor.text = "▼ ALL"
	else:
		var e: Enemy = _pick_pool[_pick_index]
		_enemy_nodes[e].modulate = Color.WHITE
		_cursor.position = _enemy_nodes[e].position + Vector2(-8, -e.data.size - 24)
		_cursor.text = "▼"

func _unhandled_input(event: InputEvent) -> void:
	if not _picking:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("confirm")
		_target_done.emit(true if _pick_all else _pick_pool[_pick_index])
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("cancel")
		_target_done.emit(null)
	elif not _pick_all and (event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_down", true)):
		get_viewport().set_input_as_handled()
		_pick_index = (_pick_index + 1) % _pick_pool.size()
		AudioManager.play_sfx("cursor")
		_update_cursor()
	elif not _pick_all and (event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_up", true)):
		get_viewport().set_input_as_handled()
		_pick_index = posmod(_pick_index - 1, _pick_pool.size())
		AudioManager.play_sfx("cursor")
		_update_cursor()

# ------------------------------------------------------------------ presentation

func _say_prompt(text: String) -> void:
	_message_win.visible = true
	_message.text = text

func _say(text: String, sfx: String = "") -> void:
	_message_win.visible = true
	_message.text = text
	if sfx != "":
		AudioManager.play_sfx(sfx)
	var t := MESSAGE_TIME * (0.3 if Input.is_action_pressed("ui_accept") else 1.0)
	await get_tree().create_timer(t).timeout

func _play_events(events: Array[Dictionary]) -> void:
	for ev in events:
		var target: Battler = ev.get("target")
		match ev["type"]:
			"damage":
				AudioManager.play_sfx("crit" if ev.get("crit", false) else "hit")
				_popup(target, str(ev["amount"]), UITheme.TEXT if not ev.get("crit") else UITheme.TEXT_HIGHLIGHT)
				_flash(target)
			"heal":
				AudioManager.play_sfx("heal")
				_popup(target, "+%d" % ev["amount"], UITheme.HP_COLOR)
			"mp":
				AudioManager.play_sfx("heal")
				_popup(target, "+%d MP" % ev["amount"], UITheme.MP_COLOR)
			"miss":
				AudioManager.play_sfx("miss")
				_popup(target, "MISS", UITheme.TEXT_DIM)
			"ko":
				AudioManager.play_sfx("ko")
				if target.is_enemy:
					_die(target)
			"status":
				AudioManager.play_sfx("magic")
				_popup(target, StatusEffects.SHORT.get(ev["status"], ""), UITheme.HP_LOW)
			"revive":
				AudioManager.play_sfx("levelup")
			"escape":
				AudioManager.play_sfx("run" if ev["success"] else "error")
			_:
				if ev.has("sfx"):
					AudioManager.play_sfx(ev["sfx"])
		_party_panel.refresh()
		await _say(ev.get("text", ""))

func _target_screen_pos(target: Battler) -> Vector2:
	if target.is_enemy and _enemy_nodes.has(target):
		var e := target as Enemy
		return _enemy_nodes[target].position + Vector2(0, -e.data.size / 2)
	var idx := GameState.party.find(target)
	return _party_panel.position + Vector2(120, 14 + idx * 20)

func _popup(target: Battler, text: String, color: Color) -> void:
	if target == null:
		return
	var l := UITheme.make_label(text, UITheme.FONT_SIZE_LARGE, color)
	l.position = _target_screen_pos(target) + Vector2(-20, -10)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 24, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func _flash(target: Battler) -> void:
	if target.is_enemy and _enemy_nodes.has(target):
		var node: Control = _enemy_nodes[target]
		var tw := create_tween()
		tw.tween_property(node, "modulate", Color(3, 3, 3), 0.05)
		tw.tween_property(node, "modulate", Color.WHITE, 0.15)
		tw.parallel().tween_property(node, "position:x", node.position.x + 6, 0.05).from(node.position.x - 6)
	else:
		SceneStack.flash(Color(1, 0.3, 0.3), 0.15)

func _die(target: Battler) -> void:
	if _enemy_nodes.has(target):
		var node: Control = _enemy_nodes[target]
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 0.0, 0.4)

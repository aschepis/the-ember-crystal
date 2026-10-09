extends Control
## The subsystem test menu. Every entry sets up state and launches one system in isolation.

var _menu: MenuList
var _desc: Label
var _info: Label

const ENTRIES := [
	{"text": "Play: New Game (Title Screen)", "desc": "Title -> New Game -> full demo loop: town, elder quest, pass, cave, boss, ending.", "action": "title"},
	{"text": "Battle: Random Overworld Encounter", "desc": "Debug party (Lv 8) vs a random group from the overworld zone.", "action": "battle_random"},
	{"text": "Battle: Pick Encounter Group", "desc": "Choose any encounter group from data/encounters.json.", "action": "battle_pick"},
	{"text": "Battle: Boss (Ember Wyrm)", "desc": "Debug party (Lv 12) vs the boss. No running.", "action": "battle_boss"},
	{"text": "Battle: Low-Level Party", "desc": "Fresh Lv 1 party vs slimes. Exercises XP gain and level ups.", "action": "battle_lowlevel"},
	{"text": "Field: Overworld", "desc": "Tile movement, random encounters by terrain, warps, chests, signs, guard gate.", "action": "field_overworld"},
	{"text": "Field: Town (Emberfall)", "desc": "NPC wandering, dialogs, shops, inn, recruits, save point.", "action": "field_town"},
	{"text": "Field: Dungeon (Ember Cave)", "desc": "Cave encounters, sealed door + key, golem ambush, stairs, boss floor.", "action": "field_cave"},
	{"text": "Field: Debug Arena", "desc": "Tiny map with one of every interactable; flag-gated NPC.", "action": "field_arena"},
	{"text": "Menu: Field Menu (Items/Equip/Status...)", "desc": "The pause menu with a debug party and a full bag.", "action": "field_menu"},
	{"text": "Shop: Buy / Sell", "desc": "Debug Emporium with everything in the database; equip previews per member.", "action": "shop"},
	{"text": "Shop: Inn", "desc": "Inn flow: price, confirm, fade, full heal.", "action": "inn"},
	{"text": "Dialog: Script Runner", "desc": "Run any dialog script by id against the current flags.", "action": "dialog_pick"},
	{"text": "Dialog: Plot Flags Inspector", "desc": "View/toggle flags, see which NPCs/branches unlock.", "action": "flags"},
	{"text": "Save / Load", "desc": "Write and read the three JSON save slots.", "action": "save_load"},
	{"text": "Data Browser", "desc": "Inspect every loaded item, skill, class, enemy, map and shop.", "action": "data"},
	{"text": "Level-Up Simulator", "desc": "Grow each class 1..50 with the growth formula; check curves.", "action": "levelsim"},
	{"text": "Run Self-Tests", "desc": "Runs tests/ in-process and shows the report.", "action": "tests"},
	{"text": "Quit", "desc": "", "action": "quit"},
]

func _ready() -> void:
	UITheme.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var title := UITheme.make_label("THE EMBER CRYSTAL  —  Debug Lab", UITheme.FONT_SIZE_LARGE, UITheme.TEXT_HIGHLIGHT)
	title.position = Vector2(20, 10)
	add_child(title)
	var sub := UITheme.make_label("Godot %s  |  F1: back here  |  Z/Enter confirm, X/Esc cancel, arrows/WASD move, Shift run, F2 force fight" % Engine.get_version_info()["string"], 11, UITheme.TEXT_DIM)
	sub.position = Vector2(20, 36)
	add_child(sub)
	var win := UITheme.make_window(Vector2(380, 290))
	win.position = Vector2(16, 56)
	add_child(win)
	_menu = MenuList.new()
	_menu.visible_rows = 15
	_menu.column_width = 350
	_menu.allow_cancel = false
	win.add_child(_menu)
	var items: Array = []
	for e in ENTRIES:
		items.append(e["text"])
	_menu.set_items(items)
	_menu.selected.connect(_on_selected)
	_menu.cursor_moved.connect(_on_moved)
	var right := UITheme.make_window(Vector2(224, 290))
	right.position = Vector2(400, 56)
	add_child(right)
	var v := VBoxContainer.new()
	right.add_child(v)
	_desc = UITheme.make_label("", UITheme.FONT_SIZE_SMALL)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(200, 80)
	v.add_child(_desc)
	_info = UITheme.make_label("", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(200, 180)
	v.add_child(_info)
	_on_moved(0)
	_menu.activate()
	AudioManager.play_bgm("title")

func _on_stack_active(active: bool) -> void:
	if active and _menu:
		_menu.activate()
		_refresh_info()

func _refresh_info() -> void:
	var lines: Array[String] = []
	lines.append("Data: %d items, %d skills, %d classes, %d chars, %d enemies, %d groups, %d zones, %d shops, %d maps, %d dialogs" % [
		Database.items.size(), Database.skills.size(), Database.classes.size(), Database.characters.size(),
		Database.enemies.size(), Database.groups.size(), Database.zones.size(), Database.shops.size(),
		Database.maps.size(), Database.dialogs.size()])
	if not Database.load_errors.is_empty():
		lines.append("DATA ERRORS: %d (see console)" % Database.load_errors.size())
	if GameState.started:
		var names: Array[String] = []
		for a in GameState.party:
			names.append("%s L%d" % [a.display_name, a.level])
		lines.append("Party: " + ", ".join(names))
		lines.append("Gold: %d   Map: %s (%d,%d)" % [GameState.gold, GameState.map_id, GameState.map_x, GameState.map_y])
		lines.append("Flags: %d set" % GameState.flags.size())
	else:
		lines.append("No game in progress. Most tests create a debug party automatically.")
	_info.text = "\n".join(lines)

func _on_moved(i: int) -> void:
	_desc.text = ENTRIES[i]["desc"]
	_refresh_info()

func _ensure_party(level: int = 8) -> void:
	if not GameState.started or GameState.party.is_empty():
		GameState.debug_party(level)

func _on_selected(i: int) -> void:
	var action: String = ENTRIES[i]["action"]
	match action:
		"title":
			SceneStack.replace_all(load("res://src/ui/TitleScene.gd").new())
		"battle_random":
			_ensure_party(8)
			var zone := Database.zone("overworld")
			var gid := zone.pick("plains", GameState.rng)
			_run_battle(gid)
		"battle_pick":
			_ensure_party(8)
			_pick_from(Database.sorted_ids(Database.groups), func(id): _run_battle(id))
		"battle_boss":
			GameState.debug_party(12)
			_run_battle("boss_wyrm")
		"battle_lowlevel":
			GameState.new_game()
			GameState.pending_event = ""
			_run_battle("slimes")
		"field_overworld":
			_ensure_party(8)
			_open_field("overworld", 10, 11, "right")
		"field_town":
			_ensure_party(8)
			_open_field("emberfall", 11, 15, "up")
		"field_cave":
			_ensure_party(10)
			_open_field("ember_cave_1", 2, 17, "right")
		"field_arena":
			_ensure_party(8)
			_open_field("debug_arena", 10, 6, "up")
		"field_menu":
			_ensure_party(8)
			var menu = load("res://src/ui/FieldMenu.gd").new()
			SceneStack.push(menu)
		"shop":
			_ensure_party(8)
			_menu.deactivate()
			await EventRunner.open_shop("debug_everything")
			_menu.activate()
		"inn":
			_ensure_party(8)
			for a in GameState.party:
				a.hp = maxi(1, a.max_hp() / 3)
				a.mp = 0
			_menu.deactivate()
			await EventRunner.run("innkeeper")
			_menu.activate()
		"dialog_pick":
			_ensure_party(8)
			_pick_from(Database.sorted_ids(Database.dialogs), func(id):
				_menu.deactivate()
				await EventRunner.run(id)
				_menu.activate()
				_refresh_info())
		"flags":
			_ensure_party(8)
			SceneStack.push(load("res://src/debug/FlagsInspector.gd").new())
		"save_load":
			_ensure_party(8)
			SceneStack.push(load("res://src/ui/SaveMenu.gd").new())
		"data":
			SceneStack.push(load("res://src/debug/DataBrowser.gd").new())
		"levelsim":
			SceneStack.push(load("res://src/debug/LevelSim.gd").new())
		"tests":
			SceneStack.push(load("res://src/debug/TestRunnerScene.gd").new())
		"quit":
			get_tree().quit()

func _run_battle(group_id: String) -> void:
	_menu.deactivate()
	var result: String = await EventRunner.start_battle(group_id)
	if is_inside_tree():
		_menu.activate()
		_refresh_info()
		await EventRunner.say("Battle finished: %s. Party state is preserved for further tests." % result)

func _open_field(map_id: String, x: int, y: int, facing: String) -> void:
	GameState.set_location(map_id, x, y, facing)
	var field = load("res://src/field/FieldScene.gd").new()
	SceneStack.push(field)

## Shows a scrolling picker over the lab; calls `on_pick` with the chosen id.
func _pick_from(ids: Array, on_pick: Callable) -> void:
	_menu.deactivate()
	var win := UITheme.make_window(Vector2(300, 250))
	win.position = Vector2(170, 60)
	add_child(win)
	var list := MenuList.new()
	list.visible_rows = 12
	list.column_width = 270
	win.add_child(list)
	list.set_items(ids)
	list.activate()
	list.selected.connect(func(i):
		win.queue_free()
		on_pick.call(ids[i]))
	list.cancelled.connect(func():
		win.queue_free()
		_menu.activate())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_lab") and SceneStack.top() == self:
		_refresh_info()

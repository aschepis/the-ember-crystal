extends Node2D
## The exploration mode: renders a MapData, moves the player, resolves steps and interactions.
##
## Entity vocabulary (data/maps/*.json "entities"):
##   npc        {id,name,x,y,dialog,glyph,color,wander,facing,condition}
##   warp       {x,y,map,tx,ty,facing,condition}       step onto -> change map
##   stairs     same as warp, plays a different sound
##   chest      {x,y,item,count | gold, flag}          face + confirm, one-time (flag chest:map:x:y)
##   sign       {x,y,text}                             face + confirm
##   save_point {x,y}                                  face + confirm
##   trigger    {x,y,w,h,dialog,condition,once}        step into rect -> run dialog
##   region     {x,y,w,h,encounter_zone}               overrides the map's encounter zone inside the rect

const SAFE_TERRAIN := ["road", "indoor", "none", "water", "mountain"]

var map: MapData
var world: Node2D
var tiles: TileMapLayer
var entities_root: Node2D
var player: Player
var camera: Camera2D
var hud: CanvasLayer
var _toast: Label
var _debug_label: Label
var _npcs: Array[Npc] = []
var _props: Dictionary = {}          # Vector2i -> Node2D (chests, signs, save points)
var _busy := false
var _steps_until_encounter := 0
var _menu_open := false
var _pending_map := ""

func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	tiles = TileMapLayer.new()
	world.add_child(tiles)
	entities_root = Node2D.new()
	entities_root.y_sort_enabled = true
	world.add_child(entities_root)
	player = Player.new()
	player.field = self
	player.setup()
	player.step_finished.connect(_on_player_step)
	player.interact_requested.connect(_on_interact)
	entities_root.add_child(player)
	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)
	camera.make_current()
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_toast = UITheme.make_label("", UITheme.FONT_SIZE, UITheme.TEXT_HIGHLIGHT)
	_toast.position = Vector2(12, 8)
	_toast.modulate.a = 0.0
	hud.add_child(_toast)
	_debug_label = UITheme.make_label("", UITheme.FONT_SIZE_SMALL, UITheme.TEXT_DIM)
	_debug_label.position = Vector2(380, 8)
	hud.add_child(_debug_label)
	EventRunner.event_finished.connect(_refresh_entity_visibility)
	GameState.party_changed.connect(func(): if player: player.refresh_leader())
	load_map(GameState.map_id, GameState.map_x, GameState.map_y, GameState.facing)

func is_busy() -> bool:
	return _busy or EventRunner.running or _menu_open or SceneStack.top() != self

func _on_stack_active(active: bool) -> void:
	if active:
		_menu_open = false
		_refresh_entity_visibility()
		if map:
			AudioManager.play_bgm(map.bgm)

## Rebuilds the scene for a map. Called on first load and by warps.
func load_map(map_id: String, x: int, y: int, facing: String = "") -> void:
	map = Database.map(map_id)
	assert(map != null, "Unknown map " + map_id)
	GameState.set_location(map_id, x, y, facing)
	_build_tiles()
	for n in _npcs:
		n.queue_free()
	_npcs.clear()
	for p in _props.values():
		p.queue_free()
	_props.clear()
	for e in map.entities:
		match e.get("type", ""):
			"npc":
				var npc := Npc.new()
				npc.field = self
				npc.setup(e)
				entities_root.add_child(npc)
				_npcs.append(npc)
			"chest", "sign", "save_point":
				_add_prop(e)
	player.place(x, y, facing if facing != "" else GameState.facing)
	_refresh_entity_visibility()
	_reset_encounter_counter()
	_update_camera(true)
	_show_toast(map.name)
	AudioManager.play_bgm(map.bgm)
	if map.on_enter != "" and not GameState.flag("entered:" + map.id):
		GameState.set_flag("entered:" + map.id)
		_run_event(map.on_enter)

func _build_tiles() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Placeholder.TILE, Placeholder.TILE)
	var src := TileSetAtlasSource.new()
	src.texture = Placeholder.tile_atlas(TileDefs.DEFS)
	src.texture_region_size = Vector2i(Placeholder.TILE, Placeholder.TILE)
	for i in TileDefs.DEFS.size():
		src.create_tile(Vector2i(i, 0))
	var sid := ts.add_source(src)
	tiles.tile_set = ts
	tiles.clear()
	for y in map.height:
		for x in map.width:
			tiles.set_cell(Vector2i(x, y), sid, Vector2i(TileDefs.index_of(map.tiles[y][x]), 0))

func _add_prop(e: Dictionary) -> void:
	var node := Sprite2D.new()
	node.centered = false
	var pos := Vector2i(int(e["x"]), int(e["y"]))
	node.position = Vector2(pos * Placeholder.TILE)
	node.set_meta("entity", e)
	_props[pos] = node
	entities_root.add_child(node)
	_refresh_prop(node)

func _refresh_prop(node: Sprite2D) -> void:
	var e: Dictionary = node.get_meta("entity")
	match e["type"]:
		"chest":
			var opened: bool = GameState.flag(_chest_flag(e))
			node.texture = Placeholder.sprite("chest_open" if opened else "chest", Color("8a5a2a") if not opened else Color("5a3a1a"), "-" if opened else "$")
		"sign":
			node.texture = Placeholder.sprite("sign", Color("c0a070"), "!")
		"save_point":
			node.texture = Placeholder.sprite("save", Color("40d0d0"), "+")

func _chest_flag(e: Dictionary) -> String:
	return e.get("flag", "chest:%s:%d:%d" % [map.id, int(e["x"]), int(e["y"])])

func _refresh_entity_visibility() -> void:
	for n in _npcs:
		n.visible = GameState.check(n.data.get("condition", null))
		n.solid = n.visible
	for p in _props.values():
		_refresh_prop(p)

## Walls, water, solid props, NPCs and the player all block.
func is_blocked(x: int, y: int, who: Node = null) -> bool:
	if not map.is_walkable(x, y):
		return true
	var pos := Vector2i(x, y)
	if _props.has(pos):
		return true
	if who != player and player.tile == pos:
		return true
	for n in _npcs:
		if n != who and n.solid and n.visible and (n.tile == pos or (n.moving and n.tile == pos)):
			return true
	for e in map.entities:
		if e.get("type") == "trigger" and e.get("block", false) and _in_rect(e, pos) and GameState.check(e.get("condition", null)):
			return true
	return false

func _in_rect(e: Dictionary, pos: Vector2i) -> bool:
	var ex := int(e.get("x", 0)); var ey := int(e.get("y", 0))
	return pos.x >= ex and pos.y >= ey and pos.x < ex + int(e.get("w", 1)) and pos.y < ey + int(e.get("h", 1))

func _process(_delta: float) -> void:
	_update_camera(false)
	_debug_label.text = "%s (%d,%d) %s | zone %s | next fight %d" % [map.id, player.tile.x, player.tile.y, map.tile_at(player.tile.x, player.tile.y), _current_zone(), _steps_until_encounter] if map else ""

func _update_camera(snap: bool) -> void:
	if map == null:
		return
	var view := get_viewport_rect().size
	var map_px := Vector2(map.width, map.height) * Placeholder.TILE
	var target := player.position + Vector2(Placeholder.TILE / 2, Placeholder.TILE / 2)
	for axis in 2:
		if map_px[axis] <= view[axis]:
			target[axis] = map_px[axis] / 2
		else:
			target[axis] = clampf(target[axis], view[axis] / 2, map_px[axis] - view[axis] / 2)
	camera.position = target if snap else camera.position.lerp(target, 0.5)

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)

# -------------------------------------------------------------------- steps

func _on_player_step(x: int, y: int) -> void:
	GameState.map_x = x
	GameState.map_y = y
	GameState.facing = player.facing
	GameState.steps += 1
	_tick_poison()
	var pos := Vector2i(x, y)
	for e in map.entities:
		if is_busy():
			return
		var t: String = e.get("type", "")
		if not _in_rect(e, pos):
			continue
		if not GameState.check(e.get("condition", null)):
			continue
		match t:
			"warp", "stairs":
				_busy = true
				await EventRunner.warp(e["map"], int(e["tx"]), int(e["ty"]), e.get("facing", ""))
				_busy = false
				return
			"trigger":
				var once_flag := "trigger:%s:%d:%d" % [map.id, int(e["x"]), int(e["y"])]
				if e.get("once", false) and GameState.flag(once_flag):
					continue
				if e.get("once", false):
					GameState.set_flag(once_flag)
				_run_event(e["dialog"])
				return
	_check_encounter(pos)

func _tick_poison() -> void:
	var interval := int(Database.cfg("poison_field_step_interval", 4))
	if GameState.steps % interval != 0:
		return
	var hurt := false
	for a in GameState.party:
		if a.has_status(StatusEffects.POISON) and a.hp > 1:
			a.hp = maxi(1, a.hp - maxi(1, int(a.max_hp() * Formulas.POISON_TICK_RATIO / 2)))
			hurt = true
	if hurt:
		SceneStack.flash(Color("8040a0"), 0.2)

func _current_zone() -> String:
	if map == null:
		return ""
	for e in map.entities:
		if e.get("type") == "region" and _in_rect(e, player.tile):
			return e.get("encounter_zone", map.encounter_zone)
	return map.encounter_zone

func _reset_encounter_counter() -> void:
	var zone := Database.zone(_current_zone())
	if zone == null:
		_steps_until_encounter = -1
		return
	var variance := float(Database.cfg("encounter_step_variance", 0.5))
	var base := zone.steps_per_encounter
	_steps_until_encounter = GameState.rng.randi_range(int(base * (1.0 - variance)), int(base * (1.0 + variance)))

func _check_encounter(pos: Vector2i) -> void:
	var zone_id := _current_zone()
	if zone_id == "":
		return
	var terrain := TileDefs.terrain(map.tile_at(pos.x, pos.y))
	if terrain in SAFE_TERRAIN:
		return
	if _steps_until_encounter < 0:
		_reset_encounter_counter()
	_steps_until_encounter -= 1
	if _steps_until_encounter > 0:
		return
	var zone := Database.zone(zone_id)
	var gid := zone.pick(terrain, GameState.rng)
	_reset_encounter_counter()
	if gid == "":
		return
	start_encounter(gid)

func start_encounter(group_id: String) -> void:
	_busy = true
	var bg := map.background
	var zone := Database.zone(_current_zone())
	if bg == "" and zone:
		bg = zone.background
	await EventRunner.start_battle(group_id, bg)
	_busy = false

func _run_event(script) -> void:
	_busy = true
	await EventRunner.run(script)
	_busy = false
	_refresh_entity_visibility()

# -------------------------------------------------------------------- interaction

func _on_interact() -> void:
	var target := player.facing_tile()
	# Shopkeepers stand behind counters: look one tile further through a counter.
	if map.tile_at(target.x, target.y) == "counter":
		target += FieldEntity.DIRS[player.facing]
	for n in _npcs:
		if n.visible and n.tile == target and not n.moving:
			n.face_towards(player.tile)
			if n.data.has("dialog"):
				_run_event(n.data["dialog"])
			return
	if _props.has(target):
		var e: Dictionary = _props[target].get_meta("entity")
		match e["type"]:
			"chest": _open_chest(e)
			"sign": _run_event([{"say": e.get("text", "")}])
			"save_point": _open_save_point()
		return
	for e in map.entities:
		if e.get("type") == "trigger" and e.get("interact", false) and _in_rect(e, target) and GameState.check(e.get("condition", null)):
			_run_event(e["dialog"])
			return

func _open_chest(e: Dictionary) -> void:
	var flag := _chest_flag(e)
	if GameState.flag(flag):
		_run_event([{"say": "The chest is empty."}])
		return
	GameState.set_flag(flag)
	_refresh_entity_visibility()
	var script: Array = []
	if e.has("item"):
		script.append({"give_item": e["item"], "count": int(e.get("count", 1))})
	if int(e.get("gold", 0)) > 0:
		script.append({"give_gold": int(e["gold"])})
	if script.is_empty():
		script.append({"say": "The chest is empty."})
	_run_event(script)

func _open_save_point() -> void:
	_menu_open = true
	var menu = load("res://src/ui/SaveMenu.gd").new()
	menu.setup("save")
	SceneStack.push(menu)

func _unhandled_input(event: InputEvent) -> void:
	if is_busy() or player.moving:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_menu_open = true
		AudioManager.play_sfx("confirm")
		var menu = load("res://src/ui/FieldMenu.gd").new()
		menu.can_save = map.kind == "overworld"
		SceneStack.push(menu)
	elif event.is_action_pressed("debug_encounter") and map.encounter_zone != "":
		var zone := Database.zone(_current_zone())
		var terrain := TileDefs.terrain(map.tile_at(player.tile.x, player.tile.y))
		var gid := zone.pick(terrain, GameState.rng)
		if gid != "":
			start_encounter(gid)

func _on_resume(_result) -> void:
	_menu_open = false
	if GameState.is_party_wiped():
		EventRunner.game_over()

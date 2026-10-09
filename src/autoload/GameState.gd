extends Node
## The single source of truth for a playthrough: party, bag, gold, flags and location.

signal gold_changed(amount: int)
signal party_changed
signal flags_changed(flag: String)
signal location_changed

var party: Array[Actor] = []
var inventory: Inventory = Inventory.new()
var gold: int = 0
var flags: Dictionary = {}
var map_id: String = ""
var map_x: int = 0
var map_y: int = 0
var facing: String = "down"
var steps: int = 0
var play_time: float = 0.0
var rng := RandomNumberGenerator.new()
var save_slot: int = 0            # last slot used, for "Save" shortcuts
var started: bool = false

func _ready() -> void:
	rng.randomize()

func _process(delta: float) -> void:
	if started:
		play_time += delta

## Fresh playthrough using data/config.json ("new_game" block).
func new_game() -> void:
	var ng: Dictionary = Database.cfg("new_game", {})
	party.clear()
	inventory = Inventory.new()
	flags.clear()
	gold = int(ng.get("gold", 100))
	for cid in ng.get("party", []):
		add_member(String(cid))
	for entry in ng.get("items", []):
		inventory.add(String(entry.get("id", "")), int(entry.get("count", 1)))
	map_id = ng.get("map", "")
	map_x = int(ng.get("x", 0))
	map_y = int(ng.get("y", 0))
	facing = ng.get("facing", "down")
	steps = 0
	play_time = 0.0
	started = true
	party_changed.emit()
	gold_changed.emit(gold)

## A pre-levelled party with a full bag, for exercising subsystems from the Debug Lab.
func debug_party(level: int = 8) -> void:
	new_game()
	var dbg: Dictionary = Database.cfg("debug_party", {})
	gold = int(dbg.get("gold", 5000))
	for entry in dbg.get("items", []):
		inventory.add(String(entry.get("id", "")), int(entry.get("count", 1)))
	for a in party:
		while a.level < level:
			a.gain_xp(a.xp_to_next(), rng)
		a.hp = a.max_hp()
		a.mp = a.max_mp()
	for f in dbg.get("flags", {}):
		flags[f] = dbg["flags"][f]
	party_changed.emit()
	gold_changed.emit(gold)

func add_member(character_id: String) -> Actor:
	for a in party:
		if a.id == character_id:
			return a
	if party.size() >= Formulas.MAX_PARTY:
		push_warning("Party full; cannot add " + character_id)
		return null
	var a := Actor.create(character_id)
	party.append(a)
	party_changed.emit()
	return a

func remove_member(character_id: String) -> void:
	for a in party:
		if a.id == character_id:
			party.erase(a)
			party_changed.emit()
			return

func has_member(character_id: String) -> bool:
	for a in party:
		if a.id == character_id:
			return true
	return false

func member(character_id: String) -> Actor:
	for a in party:
		if a.id == character_id:
			return a
	return null

func swap_members(i: int, j: int) -> void:
	if i == j or i < 0 or j < 0 or i >= party.size() or j >= party.size():
		return
	var tmp := party[i]
	party[i] = party[j]
	party[j] = tmp
	party_changed.emit()

func alive_members() -> Array[Actor]:
	var out: Array[Actor] = []
	for a in party:
		if a.is_alive():
			out.append(a)
	return out

func is_party_wiped() -> bool:
	return alive_members().is_empty()

func average_level() -> float:
	if party.is_empty():
		return 1.0
	var sum := 0
	for a in party:
		sum += a.level
	return float(sum) / party.size()

func add_gold(amount: int) -> void:
	gold = clampi(gold + amount, 0, 9999999)
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	add_gold(-amount)
	return true

## Full restore (inn / tent). Also cures everything incl. KO, the classic generous inn.
func heal_party_fully() -> void:
	for a in party:
		a.statuses.clear()
		a.hp = a.max_hp()
		a.mp = a.max_mp()
	party_changed.emit()

func set_flag(flag: String, value = true) -> void:
	flags[flag] = value
	flags_changed.emit(flag)

func add_flag(flag: String, amount: int = 1) -> void:
	flags[flag] = int(flags.get(flag, 0)) + amount
	flags_changed.emit(flag)

func flag(flag: String, default = false):
	return flags.get(flag, default)

func set_location(new_map: String, x: int, y: int, new_facing: String = "") -> void:
	map_id = new_map
	map_x = x
	map_y = y
	if new_facing != "":
		facing = new_facing
	location_changed.emit()

## Conditions are strings like "met_elder", "!has_crystal", "shards>=3", "has_item:key",
## "gold>=100", "in_party:mira", "level>=5". An Array means every entry must hold.
func check(cond) -> bool:
	if cond == null:
		return true
	if cond is bool:
		return cond
	if cond is Array:
		for c in cond:
			if not check(c):
				return false
		return true
	var s := String(cond).strip_edges()
	if s == "":
		return true
	if s.begins_with("!"):
		return not check(s.substr(1))
	for op in [">=", "<=", "==", "!=", ">", "<"]:
		var idx := s.find(op)
		if idx > 0:
			var lhs = _value(s.substr(0, idx).strip_edges())
			var rhs = _value(s.substr(idx + op.length()).strip_edges())
			match op:
				">=": return lhs >= rhs
				"<=": return lhs <= rhs
				"==": return lhs == rhs
				"!=": return lhs != rhs
				">": return lhs > rhs
				"<": return lhs < rhs
	if s.begins_with("has_item:"):
		return inventory.has(s.substr(9))
	if s.begins_with("in_party:"):
		return has_member(s.substr(9))
	var v = flags.get(s, false)
	if v is bool:
		return v
	return int(v) != 0

func _value(token: String):
	if token.is_valid_int():
		return int(token)
	if token == "gold":
		return gold
	if token == "level":
		return int(average_level())
	if token == "party_size":
		return party.size()
	if token.begins_with("item:"):
		return inventory.count(token.substr(5))
	var v = flags.get(token, 0)
	if v is bool:
		return 1 if v else 0
	return int(v)

func to_dict() -> Dictionary:
	var members: Array = []
	for a in party:
		members.append(a.to_dict())
	return {
		"version": 1,
		"party": members,
		"inventory": inventory.to_dict(),
		"gold": gold,
		"flags": flags.duplicate(),
		"map_id": map_id, "map_x": map_x, "map_y": map_y, "facing": facing,
		"steps": steps,
		"play_time": play_time,
	}

func load_dict(d: Dictionary) -> void:
	party.clear()
	for m in d.get("party", []):
		party.append(Actor.from_dict(m))
	inventory = Inventory.new()
	inventory.load_dict(d.get("inventory", {}))
	gold = int(d.get("gold", 0))
	flags = d.get("flags", {}).duplicate()
	map_id = d.get("map_id", "")
	map_x = int(d.get("map_x", 0))
	map_y = int(d.get("map_y", 0))
	facing = d.get("facing", "down")
	steps = int(d.get("steps", 0))
	play_time = float(d.get("play_time", 0.0))
	started = true
	party_changed.emit()
	gold_changed.emit(gold)

func format_play_time() -> String:
	var t := int(play_time)
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

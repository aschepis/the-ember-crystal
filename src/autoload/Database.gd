extends Node
## Loads every JSON content file under res://data into typed lookup tables.
## Content is JSON (not .tres) so the external asset/content pipeline can emit it directly.

var items: Dictionary = {}        # id -> ItemData
var skills: Dictionary = {}       # id -> SkillData
var classes: Dictionary = {}      # id -> ClassData
var characters: Dictionary = {}   # id -> CharacterData
var enemies: Dictionary = {}      # id -> EnemyData
var groups: Dictionary = {}       # id -> EncounterData.Group
var zones: Dictionary = {}        # id -> EncounterData.Zone
var shops: Dictionary = {}        # id -> ShopData
var maps: Dictionary = {}         # id -> MapData
var dialogs: Dictionary = {}      # id -> Array (command list)
var config: Dictionary = {}       # data/config.json
var raw: Dictionary = {}          # category -> id -> source dict (for the data browser)
var load_errors: Array[String] = []

func _ready() -> void:
	reload()

func reload() -> void:
	items.clear(); skills.clear(); classes.clear(); characters.clear(); enemies.clear()
	groups.clear(); zones.clear(); shops.clear(); maps.clear(); dialogs.clear(); load_errors.clear()
	raw = {"items": {}, "skills": {}, "classes": {}, "characters": {}, "enemies": {}, "groups": {}, "zones": {}, "shops": {}, "maps": {}, "dialogs": {}}
	config = _read_json("res://data/config.json")
	if config == null:
		config = {}
	for d in _read_list("res://data/items.json"):
		var it := ItemData.from_dict(d); items[it.id] = it; raw["items"][it.id] = d
	for d in _read_list("res://data/skills.json"):
		var s := SkillData.from_dict(d); skills[s.id] = s; raw["skills"][s.id] = d
	for d in _read_list("res://data/classes.json"):
		var c := ClassData.from_dict(d); classes[c.id] = c; raw["classes"][c.id] = d
	for d in _read_list("res://data/characters.json"):
		var c := CharacterData.from_dict(d); characters[c.id] = c; raw["characters"][c.id] = d
	for d in _read_list("res://data/enemies.json"):
		var e := EnemyData.from_dict(d); enemies[e.id] = e; raw["enemies"][e.id] = d
	var enc = _read_json("res://data/encounters.json")
	if enc is Dictionary:
		for d in enc.get("groups", []):
			var g := EncounterData.Group.from_dict(d); groups[g.id] = g; raw["groups"][g.id] = d
		for d in enc.get("zones", []):
			var z := EncounterData.Zone.from_dict(d); zones[z.id] = z; raw["zones"][z.id] = d
	for d in _read_list("res://data/shops.json"):
		var s := ShopData.from_dict(d); shops[s.id] = s; raw["shops"][s.id] = d
	for path in _list_files("res://data/maps", ".json"):
		var d = _read_json(path)
		if d is Dictionary:
			var m := MapData.from_dict(d); maps[m.id] = m; raw["maps"][m.id] = d
	for path in _list_files("res://data/dialogs", ".json"):
		var d = _read_json(path)
		if d is Dictionary:
			for key in d:
				dialogs[key] = d[key]; raw["dialogs"][key] = d[key]
	_validate()

func _validate() -> void:
	for c in characters.values():
		if not classes.has(c.class_id):
			load_errors.append("character %s references unknown class %s" % [c.id, c.class_id])
		for slot in c.start_equipment:
			if not items.has(c.start_equipment[slot]):
				load_errors.append("character %s start_equipment %s unknown item" % [c.id, c.start_equipment[slot]])
	for cl in classes.values():
		for sp in cl.spells:
			if not skills.has(sp.get("skill", "")):
				load_errors.append("class %s references unknown skill %s" % [cl.id, sp.get("skill", "")])
	for e in enemies.values():
		for a in e.actions:
			if a.get("kind", "") == "skill" and not skills.has(a.get("skill", "")):
				load_errors.append("enemy %s references unknown skill %s" % [e.id, a.get("skill", "")])
		for dr in e.drops:
			if not items.has(dr.get("item", "")):
				load_errors.append("enemy %s drop references unknown item %s" % [e.id, dr.get("item", "")])
	for g in groups.values():
		for en in g.enemies:
			if not enemies.has(en["enemy"]):
				load_errors.append("group %s references unknown enemy %s" % [g.id, en["enemy"]])
	for z in zones.values():
		for en in z.entries:
			if not groups.has(en.get("group", "")):
				load_errors.append("zone %s references unknown group %s" % [z.id, en.get("group", "")])
	for s in shops.values():
		for it in s.items:
			if not items.has(it):
				load_errors.append("shop %s sells unknown item %s" % [s.id, it])
	for m in maps.values():
		if m.encounter_zone != "" and not zones.has(m.encounter_zone):
			load_errors.append("map %s references unknown zone %s" % [m.id, m.encounter_zone])
		for e in m.entities:
			var t: String = e.get("type", "")
			if t == "warp" and not maps.has(e.get("map", "")):
				load_errors.append("map %s warp to unknown map %s" % [m.id, e.get("map", "")])
			if t == "npc" and e.has("dialog") and not dialogs.has(e["dialog"]):
				load_errors.append("map %s npc references unknown dialog %s" % [m.id, e["dialog"]])
			if t == "chest" and e.has("item") and not items.has(e["item"]):
				load_errors.append("map %s chest has unknown item %s" % [m.id, e["item"]])
	for err in load_errors:
		push_warning("Database: " + err)

func item(id: String) -> ItemData: return items.get(id)
func skill(id: String) -> SkillData: return skills.get(id)
func klass(id: String) -> ClassData: return classes.get(id)
func character(id: String) -> CharacterData: return characters.get(id)
func enemy(id: String) -> EnemyData: return enemies.get(id)
func group(id: String) -> EncounterData.Group: return groups.get(id)
func zone(id: String) -> EncounterData.Zone: return zones.get(id)
func shop(id: String) -> ShopData: return shops.get(id)
func map(id: String) -> MapData: return maps.get(id)
func dialog(id: String) -> Array: return dialogs.get(id, [])

func cfg(key: String, default = null):
	return config.get(key, default)

func sorted_ids(table: Dictionary) -> Array:
	var ids := table.keys()
	ids.sort()
	return ids

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		load_errors.append("missing file " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		load_errors.append("%s: parse error line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

func _read_list(path: String) -> Array:
	var d = _read_json(path)
	return d if d is Array else []

func _list_files(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(ext):
			out.append(dir_path.path_join(f))
		f = dir.get_next()
	out.sort()
	return out

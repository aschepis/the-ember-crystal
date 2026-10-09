class_name Actor
extends Battler
## A party member: persistent stats, level/XP, equipment and known spells.

const STAT_KEYS := ["str", "agi", "vit", "int", "spi", "luck"]

var id: String
var character: CharacterData
var klass: ClassData
var level: int = 1
var xp: int = 0
var base: Dictionary = {}            # str, agi, vit, int, spi, luck, max_hp, max_mp (grown values)
var equipment: Dictionary = {}       # slot -> item id ("" when empty)
var extra_skills: Array[String] = [] # learned outside the class list (scrolls, events)

static func create(character_id: String) -> Actor:
	var a := Actor.new()
	a.id = character_id
	a.character = Database.character(character_id)
	assert(a.character != null, "Unknown character " + character_id)
	a.klass = Database.klass(a.character.class_id)
	assert(a.klass != null, "Unknown class " + a.character.class_id)
	a.display_name = a.character.name
	a.base = a.klass.base_stats.duplicate()
	for slot in ItemData.EQUIP_SLOTS:
		a.equipment[slot] = ""
	a.level = 1
	a.xp = 0
	# Grow deterministically to the start level so a lvl 5 start has lvl 5 stats.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(character_id)
	while a.level < a.character.start_level:
		a._grow_one_level(rng)
	a.xp = Formulas.xp_for_level(a.level)
	for slot in a.character.start_equipment:
		a.equipment[slot] = a.character.start_equipment[slot]
	a.hp = a.max_hp()
	a.mp = a.max_mp()
	return a

func color() -> Color:
	return Color(character.color if character.color != "" else klass.color)

func glyph() -> String:
	return character.glyph if character.glyph != "" else klass.glyph

func max_hp() -> int:
	return maxi(1, int(base.get("max_hp", 1)) + _equip_sum("max_hp"))

func max_mp() -> int:
	return maxi(0, int(base.get("max_mp", 0)) + _equip_sum("max_mp"))

func stat(key: String) -> int:
	return maxi(0, int(base.get(key, 0)) + _equip_sum(key) + buff(key))

func attack() -> int:
	return stat("str") / 2 + _equip_sum("atk") + buff("atk")

func defense() -> int:
	return stat("vit") / 4 + _equip_sum("def") + buff("def")

func magic_defense() -> int:
	return stat("spi") / 4 + _equip_sum("mdef") + buff("mdef")

func evade() -> int:
	return stat("agi") / 4 + _equip_sum("evade") + buff("evade")

func hit() -> int:
	return _equip_sum("hit") + buff("hit")

func weapon_element() -> String:
	var w := equipped_item("weapon")
	return w.element if w else ""

func weapon_inflicts() -> String:
	var w := equipped_item("weapon")
	return w.inflicts if w else ""

func element_multiplier(element: String) -> float:
	var resist: Array = []
	for slot in equipment:
		var it := equipped_item(slot)
		if it:
			resist.append_array(it.resist_elements)
	return Formulas.element_multiplier(element, [], resist, [])

func is_status_immune(status: String) -> bool:
	for slot in equipment:
		var it := equipped_item(slot)
		if it and status in it.resist_status:
			return true
	return false

func equipped_item(slot: String) -> ItemData:
	var id: String = equipment.get(slot, "")
	return Database.item(id) if id != "" else null

func _equip_sum(key: String) -> int:
	var total := 0
	for slot in equipment:
		var it := equipped_item(slot)
		if it:
			total += it.stat(key)
	return total

func can_equip(item: ItemData) -> bool:
	return item != null and item.is_equipment() and item.can_equip_class(klass.id)

## Swaps the item into its slot; returns the previously equipped id ("" if none).
func equip(item: ItemData) -> String:
	assert(can_equip(item))
	var prev: String = equipment.get(item.type, "")
	equipment[item.type] = item.id
	_clamp_vitals()
	return prev

func unequip(slot: String) -> String:
	var prev: String = equipment.get(slot, "")
	equipment[slot] = ""
	_clamp_vitals()
	return prev

func _clamp_vitals() -> void:
	hp = mini(hp, max_hp())
	mp = mini(mp, max_mp())

func known_skills() -> Array[String]:
	var out: Array[String] = klass.spells_at_level(level)
	for s in extra_skills:
		if not s in out:
			out.append(s)
	return out

func knows_skill(id: String) -> bool:
	return id in known_skills()

func xp_to_next() -> int:
	if level >= Formulas.MAX_LEVEL:
		return 0
	return Formulas.xp_for_level(level + 1) - xp

## Adds XP and levels up as many times as needed. Returns a report for the victory screen.
func gain_xp(amount: int, rng: RandomNumberGenerator) -> Dictionary:
	var report := {"levels": 0, "from": level, "new_skills": [], "gains": {}}
	xp += amount
	while level < Formulas.MAX_LEVEL and xp >= Formulas.xp_for_level(level + 1):
		var before_skills := known_skills()
		var gains := _grow_one_level(rng)
		report["levels"] += 1
		for k in gains:
			report["gains"][k] = int(report["gains"].get(k, 0)) + gains[k]
		for s in known_skills():
			if not s in before_skills:
				report["new_skills"].append(s)
	report["to"] = level
	return report

## Growth: each stat gains floor(rate) plus one more with probability frac(rate).
func _grow_one_level(rng: RandomNumberGenerator) -> Dictionary:
	level += 1
	var gains := {}
	for key in STAT_KEYS + ["max_hp", "max_mp"]:
		var rate := float(klass.growth.get(key, 0.0))
		var gain := int(floor(rate))
		if rng.randf() < rate - floor(rate):
			gain += 1
		if key == "max_hp":
			gain += stat("vit") / 8
		if gain > 0:
			base[key] = int(base.get(key, 0)) + gain
			gains[key] = gain
	hp = mini(hp + int(gains.get("max_hp", 0)), max_hp())
	mp = mini(mp + int(gains.get("max_mp", 0)), max_mp())
	return gains

func to_dict() -> Dictionary:
	return {
		"id": id, "level": level, "xp": xp, "hp": hp, "mp": mp,
		"base": base.duplicate(), "equipment": equipment.duplicate(),
		"statuses": Array(statuses), "extra_skills": Array(extra_skills),
	}

static func from_dict(d: Dictionary) -> Actor:
	var a := Actor.create(d["id"])
	a.level = int(d.get("level", 1))
	a.xp = int(d.get("xp", 0))
	a.base = d.get("base", a.base).duplicate()
	for k in a.base:
		a.base[k] = int(a.base[k])
	a.equipment = d.get("equipment", a.equipment).duplicate()
	a.statuses.clear()
	for s in d.get("statuses", []):
		a.statuses.append(String(s))
	a.extra_skills.clear()
	for s in d.get("extra_skills", []):
		a.extra_skills.append(String(s))
	a.hp = int(d.get("hp", a.max_hp()))
	a.mp = int(d.get("mp", a.max_mp()))
	return a

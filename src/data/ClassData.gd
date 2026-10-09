class_name ClassData
extends RefCounted
## A job/class: base stats at level 1, per-level growth, spell list and equipment permissions.

var id: String
var name: String
var description: String = ""
var base_stats: Dictionary = {}    # str, agi, vit, int, spi, luck, max_hp, max_mp
var growth: Dictionary = {}        # same keys; value = average gain per level (float)
var spells: Array = []             # [{level: int, skill: String}]
var weapon_types: Array = []       # informational; equip permission is on the item side
var color: String = "ffffff"
var glyph: String = "?"

static func from_dict(d: Dictionary) -> ClassData:
	var c := ClassData.new()
	c.id = d.get("id", "")
	c.name = d.get("name", c.id)
	c.description = d.get("description", "")
	c.base_stats = d.get("base_stats", {})
	c.growth = d.get("growth", {})
	c.spells = d.get("spells", [])
	c.weapon_types = d.get("weapon_types", [])
	c.color = d.get("color", "ffffff")
	c.glyph = d.get("glyph", "?")
	return c

func spells_at_level(level: int) -> Array[String]:
	var out: Array[String] = []
	for entry in spells:
		if int(entry.get("level", 1)) <= level:
			out.append(entry["skill"])
	return out

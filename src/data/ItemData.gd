class_name ItemData
extends RefCounted
## One row of data/items.json. Consumables, equipment and key items share this type.

const EQUIP_SLOTS := ["weapon", "shield", "head", "body", "accessory"]

var id: String
var name: String
var description: String = ""
var type: String = "consumable"   # consumable | weapon | shield | head | body | accessory | key
var price: int = 0
var sellable: bool = true
var usable_field: bool = false
var usable_battle: bool = false
var target: String = "one_ally"   # one_ally | all_allies | one_enemy | all_enemies | self
var effect: Dictionary = {}       # see Effects.gd for the vocabulary
var stats: Dictionary = {}        # equipment: atk, def, mdef, agi, hit, evade, str, vit, int, spi, luck, max_hp, max_mp
var element: String = ""          # weapon element
var inflicts: String = ""         # weapon status on hit
var resist_status: Array = []     # armor status immunities
var resist_elements: Array = []   # armor elemental resistances
var classes: Array = []           # empty = anyone can equip
var icon_color: String = "ffffff"

static func from_dict(d: Dictionary) -> ItemData:
	var it := ItemData.new()
	it.id = d.get("id", "")
	it.name = d.get("name", it.id)
	it.description = d.get("description", "")
	it.type = d.get("type", "consumable")
	it.price = int(d.get("price", 0))
	it.sellable = d.get("sellable", it.type != "key")
	it.usable_field = d.get("usable_field", false)
	it.usable_battle = d.get("usable_battle", false)
	it.target = d.get("target", "one_ally")
	it.effect = d.get("effect", {})
	it.stats = d.get("stats", {})
	it.element = d.get("element", "")
	it.inflicts = d.get("inflicts", "")
	it.resist_status = d.get("resist_status", [])
	it.resist_elements = d.get("resist_elements", [])
	it.classes = d.get("classes", [])
	it.icon_color = d.get("icon_color", "ffffff")
	return it

func is_equipment() -> bool:
	return type in EQUIP_SLOTS

func is_usable() -> bool:
	return usable_field or usable_battle

func stat(key: String) -> int:
	return int(stats.get(key, 0))

func can_equip_class(class_id: String) -> bool:
	return classes.is_empty() or class_id in classes

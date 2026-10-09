class_name CharacterData
extends RefCounted
## A playable character definition (name, class, starting kit). Runtime state lives in Actor.

var id: String
var name: String
var class_id: String
var start_level: int = 1
var start_equipment: Dictionary = {}   # slot -> item id
var color: String = ""                 # overrides class color
var glyph: String = ""
var bio: String = ""

static func from_dict(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = d.get("id", "")
	c.name = d.get("name", c.id)
	c.class_id = d.get("class", "fighter")
	c.start_level = int(d.get("start_level", 1))
	c.start_equipment = d.get("start_equipment", {})
	c.color = d.get("color", "")
	c.glyph = d.get("glyph", "")
	c.bio = d.get("bio", "")
	return c

class_name SkillData
extends RefCounted
## One row of data/skills.json. "Magic" in menus; also covers enemy special attacks.

var id: String
var name: String
var description: String = ""
var school: String = "black"      # white | black | enemy
var mp_cost: int = 0
var target: String = "one_enemy"
var effect: Dictionary = {}
var usable_field: bool = false
var usable_battle: bool = true
var icon_color: String = "ffffff"

static func from_dict(d: Dictionary) -> SkillData:
	var s := SkillData.new()
	s.id = d.get("id", "")
	s.name = d.get("name", s.id)
	s.description = d.get("description", "")
	s.school = d.get("school", "black")
	s.mp_cost = int(d.get("mp_cost", 0))
	s.target = d.get("target", "one_enemy")
	s.effect = d.get("effect", {})
	s.usable_field = d.get("usable_field", false)
	s.usable_battle = d.get("usable_battle", true)
	s.icon_color = d.get("icon_color", "ffffff")
	return s

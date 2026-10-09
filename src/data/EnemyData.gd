class_name EnemyData
extends RefCounted
## One row of data/enemies.json.

var id: String
var name: String
var level: int = 1
var stats: Dictionary = {}     # max_hp, max_mp, str, agi, vit, int, spi, luck, atk, def, mdef, evade, hit
var xp: int = 0
var gold: int = 0
var drops: Array = []          # [{item: String, chance: float}]
var weak: Array = []
var resist: Array = []
var immune: Array = []
var status_immune: Array = []
var actions: Array = []        # [{kind: attack|skill, skill: String, weight: int}]
var boss: bool = false
var color: String = "aa3333"
var size: int = 64
var description: String = ""

static func from_dict(d: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.id = d.get("id", "")
	e.name = d.get("name", e.id)
	e.level = int(d.get("level", 1))
	e.stats = d.get("stats", {})
	e.xp = int(d.get("xp", 0))
	e.gold = int(d.get("gold", 0))
	e.drops = d.get("drops", [])
	e.weak = d.get("weak", [])
	e.resist = d.get("resist", [])
	e.immune = d.get("immune", [])
	e.status_immune = d.get("status_immune", [])
	e.actions = d.get("actions", [{"kind": "attack", "weight": 1}])
	e.boss = d.get("boss", false)
	e.color = d.get("color", "aa3333")
	e.size = int(d.get("size", 64))
	e.description = d.get("description", "")
	return e

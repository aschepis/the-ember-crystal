class_name MapData
extends RefCounted
## A JSON map: a grid of tile ids plus entities (NPCs, warps, chests, triggers).
##
## Rows are strings of legend characters so maps are readable and easy to generate.

var id: String
var name: String
var width: int = 0
var height: int = 0
var tiles: Array = []            # Array[Array[String]] row-major tile ids
var legend: Dictionary = {}
var encounter_zone: String = ""  # "" = no random encounters
var bgm: String = ""
var kind: String = "overworld"   # overworld | town | dungeon | interior
var entities: Array = []         # dictionaries, see FieldScene for the vocabulary
var on_enter: String = ""        # dialog script id run when the map loads
var background: String = ""      # battle background override

static func from_dict(d: Dictionary) -> MapData:
	var m := MapData.new()
	m.id = d.get("id", "")
	m.name = d.get("name", m.id)
	m.encounter_zone = d.get("encounter_zone", "")
	m.bgm = d.get("bgm", "")
	m.kind = d.get("kind", "overworld")
	m.entities = d.get("entities", [])
	m.on_enter = d.get("on_enter", "")
	m.background = d.get("background", "")
	m.legend = TileDefs.DEFAULT_LEGEND.duplicate()
	for k in d.get("legend", {}):
		m.legend[k] = d["legend"][k]
	var rows: Array = d.get("rows", [])
	m.height = rows.size()
	m.width = 0
	for r in rows:
		m.width = maxi(m.width, (r as String).length())
	for r in rows:
		var row: Array = []
		for x in m.width:
			var ch: String = r[x] if x < (r as String).length() else " "
			row.append(m.legend.get(ch, "void"))
		m.tiles.append(row)
	return m

func tile_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= width or y >= height:
		return "void"
	return tiles[y][x]

func is_walkable(x: int, y: int) -> bool:
	return TileDefs.is_walkable(tile_at(x, y))

func entities_at(x: int, y: int) -> Array:
	var out: Array = []
	for e in entities:
		if int(e.get("x", -1)) == x and int(e.get("y", -1)) == y:
			out.append(e)
	return out

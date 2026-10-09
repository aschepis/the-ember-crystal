class_name TileDefs
## Tile vocabulary shared by maps (JSON legend chars), the renderer and the encounter system.
## Order matters: index = atlas column. A real tileset.png must follow this order.

const DEFS: Array = [
	{"id": "grass",    "glyph": "",  "color": Color("5fa84a"), "walk": true,  "terrain": "plains"},
	{"id": "forest",   "glyph": "^", "color": Color("2e6b2a"), "walk": true,  "terrain": "forest"},
	{"id": "mountain", "glyph": "M", "color": Color("8a7a66"), "walk": false, "terrain": "mountain"},
	{"id": "water",    "glyph": "~", "color": Color("3a6fd8"), "walk": false, "terrain": "water"},
	{"id": "sand",     "glyph": "",  "color": Color("d9c77a"), "walk": true,  "terrain": "desert"},
	{"id": "road",     "glyph": "",  "color": Color("b59a6a"), "walk": true,  "terrain": "road"},
	{"id": "floor",    "glyph": "",  "color": Color("9a8f86"), "walk": true,  "terrain": "indoor"},
	{"id": "wall",     "glyph": "",  "color": Color("4a4349"), "walk": false, "terrain": "indoor"},
	{"id": "door",     "glyph": "D", "color": Color("8a5a2a"), "walk": true,  "terrain": "indoor"},
	{"id": "town",     "glyph": "T", "color": Color("d08a4a"), "walk": true,  "terrain": "road"},
	{"id": "cave",     "glyph": "C", "color": Color("3a3a3a"), "walk": true,  "terrain": "cave"},
	{"id": "bridge",   "glyph": "=", "color": Color("a67c52"), "walk": true,  "terrain": "road"},
	{"id": "cave_floor","glyph": "", "color": Color("6a6060"), "walk": true,  "terrain": "cave"},
	{"id": "cave_wall","glyph": "",  "color": Color("2a2426"), "walk": false, "terrain": "cave"},
	{"id": "stairs",   "glyph": "S", "color": Color("c0b0a0"), "walk": true,  "terrain": "cave"},
	{"id": "counter",  "glyph": "",  "color": Color("7a5a3a"), "walk": false, "terrain": "indoor"},
	{"id": "roof",     "glyph": "",  "color": Color("a03a3a"), "walk": false, "terrain": "indoor"},
	{"id": "lava",     "glyph": "!", "color": Color("e04a1a"), "walk": false, "terrain": "cave"},
	{"id": "crystal",  "glyph": "*", "color": Color("ff9a4a"), "walk": true,  "terrain": "cave"},
	{"id": "void",     "glyph": "",  "color": Color("000000"), "walk": false, "terrain": "none"},
]

## Default legend characters used by the JSON maps. Maps may override per-file.
const DEFAULT_LEGEND: Dictionary = {
	".": "grass", "f": "forest", "M": "mountain", "~": "water", "s": "sand", "r": "road",
	"_": "floor", "#": "wall", "D": "door", "T": "town", "C": "cave", "=": "bridge",
	",": "cave_floor", "%": "cave_wall", "S": "stairs", "c": "counter", "R": "roof",
	"!": "lava", "*": "crystal", " ": "void",
}

static var _index: Dictionary = {}

static func index_of(id: String) -> int:
	if _index.is_empty():
		for i in DEFS.size():
			_index[DEFS[i]["id"]] = i
	return _index.get(id, DEFS.size() - 1)

static func def(id: String) -> Dictionary:
	return DEFS[index_of(id)]

static func is_walkable(id: String) -> bool:
	return def(id).get("walk", false)

static func terrain(id: String) -> String:
	return def(id).get("terrain", "none")

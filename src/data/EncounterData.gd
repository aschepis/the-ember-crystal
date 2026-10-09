class_name EncounterData
extends RefCounted
## Encounter groups (a concrete set of enemies) and zone tables (weighted groups per terrain).

class Group:
	var id: String
	var enemies: Array = []     # [{enemy: String, count: int}] or ["slime", "slime"]
	var can_run: bool = true
	var background: String = ""
	var bgm: String = ""

	static func from_dict(d: Dictionary) -> Group:
		var g := Group.new()
		g.id = d.get("id", "")
		g.can_run = d.get("can_run", true)
		g.background = d.get("background", "")
		g.bgm = d.get("bgm", "")
		for entry in d.get("enemies", []):
			if entry is String:
				g.enemies.append({"enemy": entry, "count": 1})
			else:
				g.enemies.append({"enemy": entry["enemy"], "count": int(entry.get("count", 1))})
		return g

	## Expands to a flat list of enemy ids (e.g. ["slime", "slime", "bat"]).
	func expand() -> Array[String]:
		var out: Array[String] = []
		for entry in enemies:
			for i in int(entry["count"]):
				out.append(entry["enemy"])
		return out

class Zone:
	var id: String
	var steps_per_encounter: int = 12   # average steps between fights
	var entries: Array = []             # [{group: String, weight: int, terrain: [optional]}]
	var background: String = ""

	static func from_dict(d: Dictionary) -> Zone:
		var z := Zone.new()
		z.id = d.get("id", "")
		z.steps_per_encounter = int(d.get("steps_per_encounter", 12))
		z.entries = d.get("entries", [])
		z.background = d.get("background", "")
		return z

	## Picks a group id for the given terrain using weighted random selection.
	func pick(terrain: String, rng: RandomNumberGenerator) -> String:
		var candidates: Array = []
		var total := 0
		for e in entries:
			var terrains: Array = e.get("terrain", [])
			if terrains.is_empty() or terrain in terrains:
				candidates.append(e)
				total += int(e.get("weight", 1))
		if candidates.is_empty():
			return ""
		var roll := rng.randi_range(1, total)
		for e in candidates:
			roll -= int(e.get("weight", 1))
			if roll <= 0:
				return e["group"]
		return candidates.back()["group"]

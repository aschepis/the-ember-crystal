extends RefCounted
## Content integrity: every cross-reference in data/ resolves and maps are consistent.
var t: TestRunner

func test_no_load_errors() -> void:
	t.check(Database.load_errors.is_empty(), "load errors: " + ", ".join(Database.load_errors))

func test_dialog_labels_resolve() -> void:
	for id in Database.dialogs:
		var cmds: Array = Database.dialogs[id]
		var labels := {}
		for c in cmds:
			if c is Dictionary and c.has("label"):
				labels[c["label"]] = true
		for c in cmds:
			if not c is Dictionary:
				continue
			for key in ["goto", "then", "else", "win", "lose", "escape"]:
				if c.has(key) and c[key] != "":
					t.check(labels.has(c[key]), "dialog %s: label %s missing" % [id, c[key]])
			if c.has("choice"):
				for opt in c["choice"]:
					if opt.has("goto"):
						t.check(labels.has(opt["goto"]), "dialog %s: choice label %s missing" % [id, opt["goto"]])
			if c.has("battle"):
				t.check(Database.group(c["battle"]) != null, "dialog %s: unknown group %s" % [id, c["battle"]])
			if c.has("shop"):
				t.check(Database.shop(c["shop"]) != null, "dialog %s: unknown shop %s" % [id, c["shop"]])
			if c.has("join"):
				t.check(Database.character(c["join"]) != null, "dialog %s: unknown character %s" % [id, c["join"]])
			if c.has("give_item"):
				t.check(Database.item(c["give_item"]) != null, "dialog %s: unknown item %s" % [id, c["give_item"]])

func test_map_entities_are_placed_sensibly() -> void:
	for m in Database.maps.values():
		for e in m.entities:
			var x := int(e.get("x", -1))
			var y := int(e.get("y", -1))
			t.check(x >= 0 and y >= 0 and x < m.width and y < m.height, "map %s: entity out of bounds %s" % [m.id, str(e)])
			match e.get("type", ""):
				"npc", "chest", "sign", "save_point":
					t.check(m.is_walkable(x, y) or m.tile_at(x, y) == "counter", "map %s: %s at (%d,%d) on unwalkable %s" % [m.id, e["type"], x, y, m.tile_at(x, y)])
				"warp", "stairs":
					t.check(m.is_walkable(x, y), "map %s: warp at (%d,%d) must be walkable" % [m.id, x, y])
					var target := Database.map(e["map"])
					t.check(target != null and target.is_walkable(int(e["tx"]), int(e["ty"])), "map %s: warp lands on unwalkable tile in %s (%d,%d)" % [m.id, e["map"], int(e["tx"]), int(e["ty"])])
				"trigger":
					t.check(Database.dialogs.has(e["dialog"]), "map %s: trigger dialog %s missing" % [m.id, e["dialog"]])

func test_new_game_start_is_walkable() -> void:
	var ng: Dictionary = Database.cfg("new_game", {})
	var m := Database.map(ng["map"])
	t.check(m != null and m.is_walkable(int(ng["x"]), int(ng["y"])), "new game start tile walkable")

func test_every_zone_picks_for_every_terrain_in_its_maps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for m in Database.maps.values():
		if m.encounter_zone == "":
			continue
		var zone := Database.zone(m.encounter_zone)
		var terrains := {}
		for y in m.height:
			for x in m.width:
				var tid: String = m.tiles[y][x]
				if TileDefs.is_walkable(tid):
					terrains[TileDefs.terrain(tid)] = true
		for terr in terrains:
			if terr in ["road", "indoor", "none"]:
				continue
			t.check(zone.pick(terr, rng) != "", "zone %s has no group for terrain %s (map %s)" % [zone.id, terr, m.id])

func test_classes_can_equip_their_start_gear() -> void:
	for c in Database.characters.values():
		var a := Actor.create(c.id)
		for slot in c.start_equipment:
			t.check(a.can_equip(Database.item(c.start_equipment[slot])), "%s cannot equip start item %s" % [c.id, c.start_equipment[slot]])

func test_map_parsing() -> void:
	var m := MapData.from_dict({"id": "x", "rows": ["#..", "#~D"], "entities": [{"type": "sign", "x": 1, "y": 0}]})
	t.eq(m.width, 3, "width")
	t.eq(m.height, 2, "height")
	t.eq(m.tile_at(0, 0), "wall", "legend")
	t.check(not m.is_walkable(1, 1), "water blocked")
	t.check(m.is_walkable(2, 1), "door walkable")
	t.eq(m.tile_at(9, 9), "void", "out of bounds is void")
	t.eq(m.entities_at(1, 0).size(), 1, "entities_at")

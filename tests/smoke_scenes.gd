extends SceneTree
## Instantiates every scene for a few frames to catch runtime errors without a display.
## godot --headless --path . --script res://tests/smoke_scenes.gd

func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	var stack = root.get_node("SceneStack")
	var db = root.get_node("Database")
	gs.debug_party(8)
	var scenes := [
		"res://src/debug/DebugLab.gd", "res://src/ui/TitleScene.gd", "res://src/ui/GameOverScene.gd",
		"res://src/ui/EndingScene.gd", "res://src/ui/FieldMenu.gd", "res://src/debug/FlagsInspector.gd",
		"res://src/debug/DataBrowser.gd", "res://src/debug/LevelSim.gd", "res://src/debug/TestRunnerScene.gd",
	]
	for path in scenes:
		print("smoke: ", path)
		var node = load(path).new()
		stack.push(node)
		for i in 5:
			await process_frame
		stack.pop()
	for map_id in db.maps.keys():
		print("smoke: field ", map_id)
		var m = db.map(map_id)
		# Find a walkable tile.
		var placed := false
		for y in m.height:
			for x in m.width:
				if m.is_walkable(x, y) and not placed:
					gs.set_location(map_id, x, y, "down")
					placed = true
		var field = load("res://src/field/FieldScene.gd").new()
		stack.push(field)
		for i in 5:
			await process_frame
		stack.pop()
	for gid in ["slimes", "boss_wyrm", "debug_all_statuses"]:
		print("smoke: battle ", gid)
		var b = load("res://src/battle/BattleScene.gd").new()
		b.setup(gid)
		stack.push(b)
		for i in 80:
			await process_frame
		stack.pop()
	print("smoke: shop")
	var shop = load("res://src/ui/ShopScene.gd").new()
	shop.setup("debug_everything")
	stack.push(shop)
	for i in 5:
		await process_frame
	stack.pop()
	print("smoke: save menu")
	var sm = load("res://src/ui/SaveMenu.gd").new()
	sm.setup("both")
	stack.push(sm)
	for i in 5:
		await process_frame
	stack.pop()
	await process_frame
	print("smoke: done")
	quit(0)

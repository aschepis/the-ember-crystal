extends Node
## Interprets dialog/event scripts (data/dialogs/*.json). A script is an Array of commands.
##
## Command vocabulary (each command is a Dictionary, or a bare String meaning "say"):
##   {"say": text, "speaker": name}            {"choice": [{"text":..,"goto":label}], "prompt": text}
##   {"label": name}  {"goto": label}           {"if": cond, "then": label, "else": label}
##   {"set_flag": name, "value": v}             {"add_flag": name, "value": n}
##   {"give_item": id, "count": n}              {"take_item": id, "count": n}
##   {"give_gold": n}  {"take_gold": n}         {"battle": group_id, "lose": label, "win": label, "escape": label}
##   {"shop": shop_id}  {"inn": shop_id}        {"warp": map, "x": n, "y": n, "facing": dir}
##   {"join": character_id} {"leave": id}       {"heal_party": true}
##   {"learn": {"character": id, "skill": id}}  {"sfx": name} {"bgm": name}
##   {"wait": seconds}  {"end": true}           {"game_over": true} {"ending": true}
##   {"message": text}  (same as say but without speaker; used for system messages)
## Conditions use GameState.check(): "flag", "!flag", "count>=3", "has_item:id", "in_party:id".

signal event_started
signal event_finished
signal message_shown(text: String)

var dialog_box: DialogBox
var running: bool = false
var last_battle_result: String = ""
var _depth := 0

func _ready() -> void:
	dialog_box = DialogBox.new()
	add_child(dialog_box)

## Runs a dialog by id (or an inline Array). Awaitable.
func run(script) -> void:
	var commands: Array = script if script is Array else Database.dialog(String(script))
	if commands.is_empty():
		push_warning("EventRunner: empty or unknown script %s" % [script])
		return
	_depth += 1
	if _depth == 1:
		running = true
		event_started.emit()
	await _execute(commands)
	_depth -= 1
	if _depth == 0:
		dialog_box.hide_box()
		running = false
		event_finished.emit()

func say(text: String, speaker: String = "") -> void:
	await run([{"say": text, "speaker": speaker}])

func _find_label(commands: Array, label: String) -> int:
	for i in commands.size():
		var c = commands[i]
		if c is Dictionary and c.get("label", null) == label:
			return i
	push_warning("EventRunner: unknown label " + label)
	return -1

func _execute(commands: Array) -> void:
	var pc := 0
	while pc < commands.size():
		var cmd = commands[pc]
		pc += 1
		if cmd is String:
			await dialog_box.say(cmd)
			continue
		if not cmd is Dictionary:
			continue
		var jump := ""
		if cmd.has("say"):
			await dialog_box.say(_fmt(cmd["say"]), cmd.get("speaker", ""))
		elif cmd.has("message"):
			message_shown.emit(_fmt(cmd["message"]))
			await dialog_box.say(_fmt(cmd["message"]))
		elif cmd.has("choice"):
			var labels: Array = []
			for opt in cmd["choice"]:
				labels.append(opt["text"])
			var picked: int = await dialog_box.choose(labels, _fmt(cmd.get("prompt", "")), cmd.get("speaker", ""))
			var opt: Dictionary = cmd["choice"][picked]
			if opt.has("set_flag"):
				GameState.set_flag(opt["set_flag"], opt.get("value", true))
			jump = opt.get("goto", "")
		elif cmd.has("label"):
			pass
		elif cmd.has("goto"):
			jump = cmd["goto"]
		elif cmd.has("if"):
			jump = cmd.get("then", "") if GameState.check(cmd["if"]) else cmd.get("else", "")
		elif cmd.has("set_flag"):
			GameState.set_flag(cmd["set_flag"], cmd.get("value", true))
		elif cmd.has("add_flag"):
			GameState.add_flag(cmd["add_flag"], int(cmd.get("value", 1)))
		elif cmd.has("give_item"):
			var n := int(cmd.get("count", 1))
			GameState.inventory.add(cmd["give_item"], n)
			AudioManager.play_sfx("chest")
			if not cmd.get("silent", false):
				var item := Database.item(cmd["give_item"])
				await dialog_box.say("Received %s%s!" % [item.name if item else cmd["give_item"], (" x%d" % n) if n > 1 else ""])
		elif cmd.has("take_item"):
			GameState.inventory.remove(cmd["take_item"], int(cmd.get("count", 1)))
		elif cmd.has("give_gold"):
			GameState.add_gold(int(cmd["give_gold"]))
			AudioManager.play_sfx("buy")
			if not cmd.get("silent", false):
				await dialog_box.say("Received %d gold!" % int(cmd["give_gold"]))
		elif cmd.has("take_gold"):
			GameState.spend_gold(int(cmd["take_gold"]))
		elif cmd.has("battle"):
			dialog_box.hide_box()
			var result: String = await start_battle(cmd["battle"], cmd.get("background", ""))
			last_battle_result = result
			match result:
				"victory": jump = cmd.get("win", "")
				"defeat": jump = cmd.get("lose", "")
				"escape": jump = cmd.get("escape", "")
		elif cmd.has("shop"):
			dialog_box.hide_box()
			await open_shop(cmd["shop"])
		elif cmd.has("inn"):
			await _inn(cmd["inn"], cmd.get("speaker", "Innkeeper"))
		elif cmd.has("warp"):
			dialog_box.hide_box()
			await warp(cmd["warp"], int(cmd.get("x", 0)), int(cmd.get("y", 0)), cmd.get("facing", ""))
		elif cmd.has("join"):
			var a := GameState.add_member(cmd["join"])
			if a and not cmd.get("silent", false):
				AudioManager.play_sfx("levelup")
				await dialog_box.say("%s joined the party!" % a.display_name)
		elif cmd.has("leave"):
			GameState.remove_member(cmd["leave"])
		elif cmd.has("heal_party"):
			GameState.heal_party_fully()
			AudioManager.play_sfx("heal")
		elif cmd.has("learn"):
			var a := GameState.member(cmd["learn"]["character"])
			if a and not a.knows_skill(cmd["learn"]["skill"]):
				a.extra_skills.append(cmd["learn"]["skill"])
				await dialog_box.say("%s learned %s!" % [a.display_name, Database.skill(cmd["learn"]["skill"]).name])
		elif cmd.has("sfx"):
			AudioManager.play_sfx(cmd["sfx"])
		elif cmd.has("bgm"):
			AudioManager.play_bgm(cmd["bgm"])
		elif cmd.has("wait"):
			await get_tree().create_timer(float(cmd["wait"])).timeout
		elif cmd.has("end"):
			return
		elif cmd.has("game_over"):
			dialog_box.hide_box()
			game_over()
			return
		elif cmd.has("ending"):
			dialog_box.hide_box()
			SceneStack.replace_all(load("res://src/ui/EndingScene.gd").new())
			return
		if jump != "":
			var target := _find_label(commands, jump)
			if target < 0:
				return
			pc = target

## Substitutes {leader}, {gold}, {flag:name} in text.
func _fmt(text: String) -> String:
	if GameState.party.size() > 0:
		text = text.replace("{leader}", GameState.party[0].display_name)
	text = text.replace("{gold}", str(GameState.gold))
	var idx := text.find("{flag:")
	while idx >= 0:
		var end := text.find("}", idx)
		if end < 0:
			break
		var fname := text.substr(idx + 6, end - idx - 6)
		text = text.substr(0, idx) + str(GameState.flag(fname, 0)) + text.substr(end + 1)
		idx = text.find("{flag:")
	return text

func _inn(shop_or_price, speaker: String) -> void:
	var price := 0
	var shop := Database.shop(String(shop_or_price)) if shop_or_price is String else null
	if shop:
		price = Formulas.inn_cost(shop.inn_price, GameState.party.size())
	else:
		price = int(shop_or_price)
	var choice: int = await dialog_box.choose(["Yes", "No"], "A room is %d gold for the night. Stay?" % price, speaker)
	if choice != 0:
		await dialog_box.say("Come back anytime.", speaker)
		return
	if not GameState.spend_gold(price):
		AudioManager.play_sfx("error")
		await dialog_box.say("You don't have enough gold.", speaker)
		return
	dialog_box.hide_box()
	await SceneStack.fade_out(0.5)
	GameState.heal_party_fully()
	AudioManager.play_sfx("heal")
	await get_tree().create_timer(0.6).timeout
	await SceneStack.fade_in(0.5)
	await dialog_box.say("Good morning! Your party is fully rested.", speaker)

## Pushes a battle scene and waits for it. Returns "victory" | "defeat" | "escape".
func start_battle(group_id: String, background: String = "") -> String:
	var BattleScene = load("res://src/battle/BattleScene.gd")
	var scene = BattleScene.new()
	scene.setup(group_id, background)
	AudioManager.play_sfx("encounter")
	await SceneStack.flash(Color.WHITE, 0.2)
	SceneStack.push(scene)
	var result: String = await scene.finished
	await SceneStack.fade_out(0.2)
	SceneStack.pop(result)
	await SceneStack.fade_in(0.2)
	if result == "defeat":
		game_over()
	return result

func open_shop(shop_id: String) -> void:
	var ShopScene = load("res://src/ui/ShopScene.gd")
	var scene = ShopScene.new()
	scene.setup(shop_id)
	SceneStack.push(scene)
	await scene.finished
	SceneStack.pop()

func warp(map_id: String, x: int, y: int, facing: String = "") -> void:
	AudioManager.play_sfx("door")
	await SceneStack.fade_out(0.2)
	GameState.set_location(map_id, x, y, facing)
	var field := SceneStack.top()
	if field and field.has_method("load_map"):
		field.call("load_map", map_id, x, y, facing)
	await SceneStack.fade_in(0.2)

func game_over() -> void:
	SceneStack.replace_all(load("res://src/ui/GameOverScene.gd").new())

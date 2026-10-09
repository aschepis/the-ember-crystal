extends RefCounted
## Plays the main quest through the event system with dialogs auto-advancing and
## battles scripted, verifying every plot gate opens in order.
var t: TestRunner

func before_each() -> void:
	GameState.new_game()
	EventRunner.dialog_box.auto_advance = true
	EventRunner.dialog_box.auto_choice = 0
	EventRunner.dialog_box.transcript.clear()
	EventRunner.scripted_battle_result = "victory"

func _after() -> void:
	EventRunner.dialog_box.auto_advance = false
	EventRunner.scripted_battle_result = ""

func _npc_visible(map_id: String, npc_id: String) -> bool:
	for e in Database.map(map_id).entities:
		if e.get("id", "") == npc_id:
			return GameState.check(e.get("condition", null))
	return false

func test_main_quest_gates() -> void:
	# Before the elder: guard blocks, hermit refuses, Vex hidden.
	t.check(_npc_visible("overworld", "pass_guard"), "guard blocks the pass")
	t.check(not _npc_visible("overworld", "pass_guard_open"), "open guard hidden")
	t.check(not _npc_visible("emberfall", "vex_town"), "vex hidden before quest")
	EventRunner.run("hermit")
	t.check(not GameState.inventory.has("cave_key"), "hermit refuses before quest")
	# Elder: hesitate first (choice 1), then accept (choice 0).
	EventRunner.dialog_box.auto_choice = 1
	EventRunner.run("elder")
	t.check(not GameState.flag("met_elder"), "hesitating does not start the quest")
	EventRunner.dialog_box.auto_choice = 0
	var gold := GameState.gold
	EventRunner.run("elder")
	t.check(GameState.flag("met_elder"), "quest accepted")
	t.eq(GameState.gold, gold + 100, "elder's gold")
	t.check(not _npc_visible("overworld", "pass_guard") and _npc_visible("overworld", "pass_guard_open"), "guard moves aside")
	t.check(_npc_visible("emberfall", "vex_town"), "vex appears")
	# Recruits.
	EventRunner.run("vex_recruit")
	t.check(GameState.has_member("vex"), "vex joins")
	EventRunner.run("juno_recruit")
	t.check(not GameState.has_member("juno"), "juno cannot join a full party")
	t.check(EventRunner.dialog_box.transcript.back().find("full") >= 0, "party-full line shown")
	# Key and door.
	EventRunner.run("hermit")
	t.check(GameState.inventory.has("cave_key"), "hermit gives the key")
	EventRunner.run("cave_sealed_door")
	t.check(GameState.flag("cave_door_open"), "door opens with key")
	t.check(not GameState.inventory.has("cave_key"), "key consumed")
	# Golem and boss (scripted victories).
	EventRunner.run("golem_ambush")
	t.check(GameState.flag("golem_defeated"), "golem flag")
	EventRunner.run("boss_wyrm")
	t.check(GameState.flag("wyrm_defeated"), "wyrm flag")
	EventRunner.run("crystal_pickup")
	t.check(GameState.inventory.has("ember_crystal") and GameState.flag("has_crystal"), "crystal taken")
	# Elder ends the game (ending scene is pushed; we only check the flag).
	EventRunner.run("elder")
	t.check(GameState.flag("game_complete"), "game complete")
	_after()

func test_losing_the_boss_does_not_set_flags() -> void:
	EventRunner.scripted_battle_result = "defeat"
	EventRunner.run("boss_wyrm")
	t.check(not GameState.flag("wyrm_defeated"), "no flag on defeat")
	_after()

func test_child_counter_branch() -> void:
	for i in 3:
		EventRunner.run("villager_2")
	t.eq(GameState.flag("child_stories"), 3, "counter")
	t.check(EventRunner.dialog_box.transcript.back().find("3 times") >= 0, "counter substituted into text")
	_after()

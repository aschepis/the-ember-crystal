extends RefCounted
## EventRunner commands that need no UI (flags, items, gold, branching).
var t: TestRunner

func before_each() -> void:
	GameState.new_game()

func test_flags_items_gold_and_branching() -> void:
	EventRunner.run([
		{"set_flag": "a"},
		{"add_flag": "n", "value": 2},
		{"add_flag": "n", "value": 3},
		{"give_item": "ether", "count": 2, "silent": true},
		{"give_gold": 40, "silent": true},
		{"take_gold": 10},
		{"if": "n>=5", "then": "yes", "else": "no"},
		{"label": "no"}, {"set_flag": "wrong"}, {"end": true},
		{"label": "yes"}, {"set_flag": "right"},
		{"take_item": "ether"},
	])
	t.check(GameState.flag("a"), "set_flag")
	t.eq(GameState.flag("n"), 5, "add_flag accumulates")
	t.check(GameState.flag("right") and not GameState.flag("wrong"), "branch")
	t.eq(GameState.inventory.count("ether"), 1, "give then take")
	t.eq(GameState.gold, 150 + 30, "gold")

func test_goto_and_end() -> void:
	EventRunner.run([{"goto": "skip"}, {"set_flag": "x"}, {"label": "skip"}, {"set_flag": "y"}, {"end": true}, {"set_flag": "z"}])
	t.check(not GameState.flag("x") and GameState.flag("y") and not GameState.flag("z"), "goto/end")

func test_join_and_leave_silent() -> void:
	EventRunner.run([{"join": "vex", "silent": true}])
	t.check(GameState.has_member("vex"), "joined")
	EventRunner.run([{"leave": "vex"}])
	t.check(not GameState.has_member("vex"), "left")

func test_learn_skill_via_event_text_substitution() -> void:
	var text := EventRunner._fmt("{leader} has {gold} gold and {flag:n} n")
	t.eq(text, "Ash has 150 gold and 0 n", "substitution")

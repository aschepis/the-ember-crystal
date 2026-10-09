extends RefCounted
var t: TestRunner
var rng: RandomNumberGenerator

func before_each() -> void:
	GameState.debug_party(8)
	rng = RandomNumberGenerator.new()
	rng.seed = 42

func _logic(group: String) -> BattleLogic:
	var l := BattleLogic.new()
	l.setup(group, GameState.party, rng)
	return l

func test_setup_names_duplicates() -> void:
	var l := _logic("slime_trio")
	t.eq(l.enemies.size(), 3, "three slimes")
	t.eq(l.enemies[0].display_name, "Slime A", "lettered")
	t.eq(l.enemies[2].display_name, "Slime C", "lettered")
	var l2 := _logic("bandit_solo")
	t.eq(l2.enemies[0].display_name, "Bandit", "no suffix when unique")

func test_attack_kills_and_victory() -> void:
	var l := _logic("slimes")
	var rounds := 0
	while l.outcome() == "" and rounds < 30:
		rounds += 1
		for a in l.party:
			var act := BattleAction.make(a, "attack")
			act.target_mode = "one_enemy"
			act.targets = l.resolve_targets(a, "one_enemy")
			l.execute(act)
	t.eq(l.outcome(), "victory", "party wins")
	t.check(rounds < 10, "lvl 8 party beats slimes quickly (%d rounds)" % rounds)

func test_fire_on_slime_is_weak() -> void:
	var l := _logic("slimes")
	var vex := GameState.member("vex")
	var act := BattleAction.make(vex, "skill")
	act.skill = Database.skill("fire")
	act.target_mode = "one_enemy"
	act.targets = [l.enemies[0]]
	var mp := vex.mp
	var ev := l.execute(act)
	t.eq(vex.mp, mp - 4, "mp spent")
	var found := false
	for e in ev:
		if e["type"] == "damage":
			found = true
			t.check(e["text"].begins_with("Weak!"), "weakness noted")
	t.check(found, "damage event")

func test_immune_element_does_nothing() -> void:
	var l := _logic("lizards")
	var vex := GameState.member("vex")
	var act := BattleAction.make(vex, "skill")
	act.skill = Database.skill("fire")
	act.target_mode = "one_enemy"
	act.targets = [l.enemies[0]]
	var hp := l.enemies[0].hp
	var ev := l.execute(act)
	t.eq(l.enemies[0].hp, hp, "no damage")
	t.check(ev.back()["type"] == "miss", "immune message")

func test_heal_and_revive() -> void:
	var l := _logic("slimes")
	var mira := GameState.member("mira")
	var ash := GameState.member("ash")
	ash.hp = 1
	var act := BattleAction.make(mira, "skill")
	act.skill = Database.skill("cure")
	act.target_mode = "one_ally"
	act.targets = [ash]
	l.execute(act)
	t.check(ash.hp > 1, "healed")
	ash.take_damage(9999)
	var item := BattleAction.make(mira, "item")
	item.item = Database.item("phoenix_down")
	item.target_mode = "one_ally"
	item.targets = [ash]
	var n := GameState.inventory.count("phoenix_down")
	l.execute(item)
	t.check(ash.is_alive(), "revived")
	t.eq(GameState.inventory.count("phoenix_down"), n - 1, "item consumed")

func test_status_and_end_of_round() -> void:
	var l := _logic("slimes")
	var vex := GameState.member("vex")
	var act := BattleAction.make(vex, "skill")
	act.skill = Database.skill("poison")
	act.target_mode = "one_enemy"
	act.targets = [l.enemies[0]]
	var landed := false
	for i in 10:
		l.execute(act)
		vex.mp = 99
		if l.enemies[0].has_status("poison"):
			landed = true
			break
	t.check(landed, "poison lands within 10 tries")
	var hp := l.enemies[0].hp
	l.end_of_round()
	t.check(l.enemies[0].hp < hp, "poison ticks")

func test_sleeping_actor_skips_turn() -> void:
	var l := _logic("slimes")
	var ash := GameState.member("ash")
	ash.add_status("sleep")
	var act := BattleAction.make(ash, "attack")
	act.targets = l.resolve_targets(ash, "one_enemy")
	var ev := l.execute(act)
	t.eq(ev.size(), 1, "one message")
	t.check(ev[0]["text"].find("asleep") >= 0, "asleep text")
	ash.take_damage(1)
	t.check(not ash.has_status("sleep"), "damage wakes")

func test_run_rules() -> void:
	var l := _logic("boss_wyrm")
	t.check(not l.can_run(), "no running from boss")
	var l2 := _logic("slimes")
	var escaped := false
	for i in 20:
		var act := BattleAction.make(GameState.party[0], "run")
		l2.execute(act)
		if l2.escaped:
			escaped = true
			break
	t.check(escaped, "eventually escapes")
	t.eq(l2.outcome(), "escape", "outcome escape")

func test_order_puts_run_first_and_sorts_by_agility() -> void:
	var l := _logic("slimes")
	var acts: Array[BattleAction] = []
	var run := BattleAction.make(GameState.member("vex"), "run")
	var atk := BattleAction.make(GameState.member("ash"), "attack")
	var def := BattleAction.make(GameState.member("mira"), "defend")
	acts.append(atk)
	acts.append(run)
	acts.append(def)
	l.order(acts)
	t.eq(acts[0].kind, "run", "run first")
	t.eq(acts[1].kind, "defend", "defend second")

func test_rewards_and_level_up() -> void:
	GameState.new_game()
	var l := _logic("skeletons")
	for e in l.enemies:
		e.take_damage(9999)
	var r := l.rewards()
	t.eq(r["xp"], 48, "xp summed")
	t.eq(r["gold"], 30, "gold summed")
	var gold := GameState.gold
	var ev := l.apply_rewards(r)
	t.eq(GameState.gold, gold + 30, "gold granted")
	var leveled := false
	for e in ev:
		if e["type"] == "levelup":
			leveled = true
	t.check(leveled, "48 xp levels a lvl 1 character")

func test_enemy_actions_target_party() -> void:
	var l := _logic("spider_pack")
	var acts := l.enemy_actions()
	t.eq(acts.size(), 3, "every enemy acts")
	for a in acts:
		t.check(a.kind in ["attack", "skill"], "kind")
		for tg in a.targets:
			t.check(not tg.is_enemy, "targets party")

func test_defeat_outcome() -> void:
	var l := _logic("slimes")
	for a in l.party:
		a.take_damage(9999)
	t.eq(l.outcome(), "defeat", "wipe")
	GameState.heal_party_fully()

func test_cleanup_clears_battle_statuses_but_keeps_poison() -> void:
	var l := _logic("slimes")
	var ash := GameState.member("ash")
	ash.add_status("sleep")
	ash.add_status("poison")
	ash.buffs["def"] = 8
	l.cleanup()
	t.check(not ash.has_status("sleep"), "sleep cleared")
	t.check(ash.has_status("poison"), "poison persists")
	t.eq(ash.buff("def"), 0, "buffs cleared")

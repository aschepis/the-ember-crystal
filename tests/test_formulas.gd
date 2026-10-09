extends RefCounted
var t: TestRunner

func test_xp_curve_is_monotonic() -> void:
	var prev := -1
	for lvl in range(1, Formulas.MAX_LEVEL + 1):
		var xp := Formulas.xp_for_level(lvl)
		t.check(xp > prev, "xp for level %d (%d) must exceed previous (%d)" % [lvl, xp, prev])
		prev = xp
	t.eq(Formulas.xp_for_level(1), 0, "level 1 needs 0 xp")

func test_level_for_xp_inverts_curve() -> void:
	for lvl in [1, 2, 5, 10, 23, 50]:
		t.eq(Formulas.level_for_xp(Formulas.xp_for_level(lvl)), lvl, "level_for_xp at exact threshold")
		if lvl < Formulas.MAX_LEVEL:
			t.eq(Formulas.level_for_xp(Formulas.xp_for_level(lvl + 1) - 1), lvl, "one xp short stays at level")

func test_physical_damage_floor_and_crit() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	t.check(Formulas.physical_damage(1, 999, rng) >= 1, "damage never below 1")
	var normal := 0
	var crit := 0
	for i in 50:
		normal += Formulas.physical_damage(20, 5, rng)
		crit += Formulas.physical_damage(20, 5, rng, true)
	t.check(crit > normal * 1.5, "crits roughly double damage")
	var defended := Formulas.physical_damage(20, 5, rng, false, true)
	t.check(defended < 30, "defending halves damage")

func test_element_multiplier() -> void:
	t.eq(Formulas.element_multiplier("fire", ["fire"], [], []), 2.0, "weak")
	t.eq(Formulas.element_multiplier("fire", [], ["fire"], []), 0.5, "resist")
	t.eq(Formulas.element_multiplier("fire", [], [], ["fire"]), 0.0, "immune")
	t.eq(Formulas.element_multiplier("", ["fire"], [], []), 1.0, "no element")

func test_run_chance_clamps() -> void:
	t.check(Formulas.run_chance(0, 100, 0) >= 10, "min 10")
	t.check(Formulas.run_chance(100, 0, 5) <= 95, "max 95")
	t.check(Formulas.run_chance(10, 10, 1) > Formulas.run_chance(10, 10, 0), "retries get easier")

func test_hit_chance_blind_penalty() -> void:
	t.check(Formulas.hit_chance(0, 10, 0, true) < Formulas.hit_chance(0, 10, 0, false), "blind lowers hit")
	t.check(Formulas.hit_chance(0, 0, 500, false) >= 10, "hit floor")

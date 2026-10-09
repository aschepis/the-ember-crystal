extends RefCounted
var t: TestRunner

func test_create_from_character_data() -> void:
	var a := Actor.create("ash")
	t.eq(a.display_name, "Ash", "name")
	t.eq(a.level, 1, "level")
	t.eq(a.equipment["weapon"], "bronze_sword", "start weapon")
	t.eq(a.hp, a.max_hp(), "starts at full hp")
	t.check(a.attack() > a.stat("str") / 2, "weapon adds attack")

func test_start_level_grows_stats() -> void:
	var vex := Actor.create("vex")
	t.eq(vex.level, 2, "vex starts at level 2")
	var base := Database.klass("black_mage").base_stats
	t.check(vex.base["int"] >= int(base["int"]), "int grew or stayed")
	t.eq(vex.xp, Formulas.xp_for_level(2), "xp matches level")

func test_equip_and_unequip() -> void:
	var a := Actor.create("ash")
	var before := a.attack()
	var prev := a.equip(Database.item("iron_sword"))
	t.eq(prev, "bronze_sword", "returns previous")
	t.check(a.attack() > before, "iron sword is stronger")
	t.check(not a.can_equip(Database.item("rod")), "fighter cannot use rod")
	t.check(a.can_equip(Database.item("knife")), "anyone can use a knife")
	a.unequip("weapon")
	t.eq(a.equipment["weapon"], "", "slot empty")

func test_accessory_grants_status_immunity() -> void:
	var a := Actor.create("mira")
	t.check(not a.is_status_immune("poison"), "no immunity by default")
	a.equip(Database.item("ribbon"))
	t.check(a.is_status_immune("poison"), "ribbon blocks poison")
	t.check(not a.add_status("sleep"), "add_status fails when immune")

func test_gain_xp_levels_and_learns_spells() -> void:
	var a := Actor.create("mira")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	t.check(a.knows_skill("cure"), "knows cure at 1")
	t.check(not a.knows_skill("dia"), "no dia yet")
	var report := a.gain_xp(Formulas.xp_for_level(5), rng)
	t.eq(a.level, 5, "reached 5")
	t.eq(report["levels"], 4, "four level ups")
	t.check("dia" in report["new_skills"], "learned dia on the way")
	t.check(a.max_hp() > int(Database.klass("white_mage").base_stats["max_hp"]), "hp grew")

func test_max_level_cap() -> void:
	var a := Actor.create("ash")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	a.gain_xp(10000000, rng)
	t.eq(a.level, Formulas.MAX_LEVEL, "capped")
	t.eq(a.xp_to_next(), 0, "no next level")

func test_serialization_roundtrip() -> void:
	var a := Actor.create("dorn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	a.gain_xp(500, rng)
	a.equip(Database.item("dagger"))
	a.hp = 5
	a.add_status("poison")
	a.extra_skills.append("fire")
	var b := Actor.from_dict(a.to_dict())
	t.eq(b.level, a.level, "level")
	t.eq(b.hp, 5, "hp")
	t.eq(b.equipment["weapon"], "dagger", "weapon")
	t.check(b.has_status("poison"), "status")
	t.check(b.knows_skill("fire"), "extra skill")
	t.eq(b.max_hp(), a.max_hp(), "max hp")

func test_ko_and_revive() -> void:
	var a := Actor.create("ash")
	a.take_damage(9999)
	t.check(not a.is_alive(), "dead")
	t.eq(a.heal(50), 0, "cannot heal the dead")
	a.revive(0.5)
	t.check(a.is_alive(), "alive")
	t.eq(a.hp, int(round(a.max_hp() * 0.5)), "half hp")

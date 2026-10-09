extends RefCounted
var t: TestRunner

func before_each() -> void:
	GameState.new_game()

func test_new_game_from_config() -> void:
	t.eq(GameState.party.size(), 3, "three starters")
	t.eq(GameState.party[0].id, "ash", "ash leads")
	t.check(GameState.inventory.has("potion"), "starting potions")
	t.eq(GameState.map_id, "emberfall", "starts in town")

func test_party_limits_and_swap() -> void:
	t.check(GameState.add_member("vex") != null, "4th joins")
	t.check(GameState.add_member("juno") == null, "5th rejected")
	GameState.swap_members(0, 3)
	t.eq(GameState.party[0].id, "vex", "swapped leader")
	GameState.remove_member("vex")
	t.eq(GameState.party.size(), 3, "removed")

func test_conditions() -> void:
	GameState.set_flag("met_elder")
	GameState.set_flag("shards", 3)
	GameState.inventory.add("cave_key")
	t.check(GameState.check("met_elder"), "bool flag")
	t.check(not GameState.check("!met_elder"), "negation")
	t.check(GameState.check("shards>=3"), ">=")
	t.check(not GameState.check("shards>3"), ">")
	t.check(GameState.check("shards==3"), "==")
	t.check(GameState.check("has_item:cave_key"), "has_item")
	t.check(GameState.check("in_party:ash"), "in_party")
	t.check(not GameState.check("in_party:juno"), "not in party")
	t.check(GameState.check("gold>=100"), "gold")
	t.check(GameState.check(["met_elder", "shards>=1"]), "array = all")
	t.check(not GameState.check(["met_elder", "nope"]), "array fails")
	t.check(GameState.check("party_size<4"), "party_size")
	t.check(GameState.check(null), "null is true")
	t.check(not GameState.check("unset_flag"), "unset is false")

func test_gold() -> void:
	GameState.gold = 50
	t.check(not GameState.spend_gold(60), "cannot overspend")
	t.check(GameState.spend_gold(50), "spend all")
	t.eq(GameState.gold, 0, "zero")

func test_save_load_roundtrip() -> void:
	GameState.set_flag("met_elder")
	GameState.add_gold(123)
	GameState.party[0].hp = 7
	GameState.set_location("overworld", 5, 6, "left")
	GameState.steps = 42
	var slot := 9
	t.check(SaveSystem.save(slot), "saved")
	GameState.new_game()
	t.check(not GameState.flag("met_elder"), "state reset")
	t.check(SaveSystem.load(slot), "loaded")
	t.check(GameState.flag("met_elder"), "flag restored")
	t.eq(GameState.party[0].hp, 7, "hp restored")
	t.eq(GameState.map_id, "overworld", "map restored")
	t.eq(GameState.map_x, 5, "x restored")
	t.eq(GameState.steps, 42, "steps restored")
	t.eq(GameState.gold, 150 + 123, "gold restored")
	var info := SaveSystem.slot_info(slot)
	t.eq(info.get("leader", ""), "Ash", "meta leader")
	SaveSystem.delete(slot)
	t.check(not SaveSystem.exists(slot), "deleted")

func test_heal_party_fully() -> void:
	for a in GameState.party:
		a.hp = 1
		a.add_status("poison")
	GameState.heal_party_fully()
	for a in GameState.party:
		t.eq(a.hp, a.max_hp(), "full hp")
		t.check(a.statuses.is_empty(), "no statuses")

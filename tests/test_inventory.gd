extends RefCounted
var t: TestRunner

func test_add_remove_and_cap() -> void:
	var inv := Inventory.new()
	t.eq(inv.add("potion", 3), 3, "added 3")
	t.eq(inv.count("potion"), 3, "count")
	t.eq(inv.add("potion", 200), Formulas.MAX_ITEM_STACK - 3, "capped at stack max")
	t.check(inv.remove("potion", 99), "remove all")
	t.check(not inv.has("potion"), "gone")
	t.check(not inv.remove("potion"), "cannot remove missing")
	t.eq(inv.add("nonexistent_item", 1), 0, "unknown id rejected")

func test_order_and_sort() -> void:
	var inv := Inventory.new()
	inv.add("iron_sword")
	inv.add("potion")
	inv.add("leather_cap")
	t.eq(inv.ids(), ["iron_sword", "potion", "leather_cap"], "acquisition order")
	inv.sort_by_type()
	t.eq(inv.ids(), ["potion", "iron_sword", "leather_cap"], "sorted by type")

func test_filter_and_roundtrip() -> void:
	var inv := Inventory.new()
	inv.add("potion", 2)
	inv.add("cave_key")
	var usable := inv.filter(func(it): return it.usable_field)
	t.eq(usable, ["potion"], "filter")
	var inv2 := Inventory.new()
	inv2.load_dict(inv.to_dict())
	t.eq(inv2.count("potion"), 2, "roundtrip count")
	t.eq(inv2.ids(), inv.ids(), "roundtrip order")

class_name Inventory
extends RefCounted
## Item bag: counts per id, display order = first acquisition. Equipped items are not in the bag.

signal changed

var _counts: Dictionary = {}
var _order: Array[String] = []

func count(id: String) -> int:
	return int(_counts.get(id, 0))

func has(id: String, n: int = 1) -> bool:
	return count(id) >= n

func ids() -> Array[String]:
	return _order.duplicate()

func is_empty() -> bool:
	return _order.is_empty()

## Adds up to the stack cap; returns how many were actually added.
func add(id: String, n: int = 1) -> int:
	if n <= 0 or Database.item(id) == null:
		return 0
	var room := Formulas.MAX_ITEM_STACK - count(id)
	var added := mini(n, room)
	if added <= 0:
		return 0
	if not _counts.has(id):
		_order.append(id)
	_counts[id] = count(id) + added
	changed.emit()
	return added

func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	_counts[id] = count(id) - n
	if _counts[id] <= 0:
		_counts.erase(id)
		_order.erase(id)
	changed.emit()
	return true

func sort_by_type() -> void:
	var order := ["consumable", "weapon", "shield", "head", "body", "accessory", "key"]
	_order.sort_custom(func(a, b):
		var ia := order.find(Database.item(a).type)
		var ib := order.find(Database.item(b).type)
		if ia != ib:
			return ia < ib
		return Database.item(a).name < Database.item(b).name)
	changed.emit()

func filter(pred: Callable) -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if pred.call(Database.item(id)):
			out.append(id)
	return out

func to_dict() -> Dictionary:
	var list: Array = []
	for id in _order:
		list.append({"id": id, "count": count(id)})
	return {"items": list}

func load_dict(d: Dictionary) -> void:
	_counts.clear()
	_order.clear()
	for entry in d.get("items", []):
		var id := String(entry["id"])
		if Database.item(id) == null:
			continue
		_order.append(id)
		_counts[id] = int(entry["count"])
	changed.emit()

extends Node
## JSON save files in user://saves/slot_N.json. Three slots, FF-style.

const SLOTS := 3
const DIR := "user://saves"

func path_for(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]

func save(slot: int) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var data := GameState.to_dict()
	data["meta"] = {
		"saved_at": Time.get_datetime_string_from_system(),
		"leader": GameState.party[0].display_name if not GameState.party.is_empty() else "-",
		"level": int(GameState.average_level()),
		"map": GameState.map_id,
		"play_time": GameState.format_play_time(),
		"gold": GameState.gold,
	}
	var f := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write slot %d" % slot)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	GameState.save_slot = slot
	return true

func load(slot: int) -> bool:
	var d := read(slot)
	if d.is_empty():
		return false
	GameState.load_dict(d)
	GameState.save_slot = slot
	return true

func exists(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot))

func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var text := FileAccess.get_file_as_string(path_for(slot))
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func slot_info(slot: int) -> Dictionary:
	var d := read(slot)
	return d.get("meta", {}) if not d.is_empty() else {}

func delete(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path_for(slot))

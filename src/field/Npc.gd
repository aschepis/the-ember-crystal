class_name Npc
extends FieldEntity
## A map character with a dialog. Wanderers take a random step every couple of seconds.

var data: Dictionary = {}
var wander := false
var _wander_timer := 0.0
var home := Vector2i.ZERO
const WANDER_RADIUS := 3

func setup(entity: Dictionary) -> void:
	data = entity
	entity_id = entity.get("id", "")
	wander = entity.get("wander", false)
	var color := Color(entity.get("color", "c0a080"))
	setup_sprite(Placeholder.character_sheet(entity_id, color, entity.get("glyph", "N")))
	place(int(entity["x"]), int(entity["y"]), entity.get("facing", "down"))
	home = tile
	_wander_timer = randf_range(1.0, 3.0)

func _process(delta: float) -> void:
	super._process(delta)
	if not wander or moving or (field and field.is_busy()):
		return
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = randf_range(1.2, 3.5)
	var dir: String = DIRS.keys()[randi() % 4]
	var target: Vector2i = tile + DIRS[dir]
	if (target - home).length() > WANDER_RADIUS:
		face(dir)
		return
	try_step(dir)

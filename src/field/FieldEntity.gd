class_name FieldEntity
extends Node2D
## A thing on the tile grid with a 3x4 walk sheet: the player and NPCs. Moves one tile at a time.

signal step_finished(x: int, y: int)

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
const SHEET_ROW := {"down": 0, "left": 1, "right": 2, "up": 3}
const WALK_TIME := 0.16
const RUN_TIME := 0.09

var tile := Vector2i.ZERO
var facing := "down"
var moving := false
var solid := true
var entity_id := ""
var sprite: Sprite2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _duration := WALK_TIME
var _anim_t := 0.0
var field: Node = null   # FieldScene, set by the scene

func _ready() -> void:
	if sprite == null:
		setup_sprite(Placeholder.character_sheet("unknown", Color.GRAY, "?"))

func setup_sprite(tex: Texture2D) -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = Vector2(0, -Placeholder.TILE / 2)  # draw taller than a tile, feet on the grid
		add_child(sprite)
	sprite.texture = tex
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.position = Vector2(0, -(tex.get_height() / 4 - Placeholder.TILE))
	_update_frame(1)

func place(x: int, y: int, dir: String = "") -> void:
	tile = Vector2i(x, y)
	position = Vector2(tile * Placeholder.TILE)
	moving = false
	if dir != "":
		facing = dir
	_update_frame(1)

func face(dir: String) -> void:
	facing = dir
	_update_frame(1)

func face_towards(other: Vector2i) -> void:
	var d := other - tile
	if abs(d.x) > abs(d.y):
		face("right" if d.x > 0 else "left")
	else:
		face("down" if d.y > 0 else "up")

func opposite(dir: String) -> String:
	match dir:
		"up": return "down"
		"down": return "up"
		"left": return "right"
	return "left"

func facing_tile() -> Vector2i:
	return tile + DIRS[facing]

## Attempts to walk one tile. Returns false if blocked (the entity still turns to face it).
func try_step(dir: String, run: bool = false) -> bool:
	if moving:
		return false
	facing = dir
	var target: Vector2i = tile + DIRS[dir]
	if field and field.is_blocked(target.x, target.y, self):
		_update_frame(1)
		return false
	_from = position
	_to = Vector2(target * Placeholder.TILE)
	tile = target
	_t = 0.0
	_duration = RUN_TIME if run else WALK_TIME
	moving = true
	return true

func _process(delta: float) -> void:
	if not moving:
		return
	_t += delta
	_anim_t += delta
	var p := clampf(_t / _duration, 0.0, 1.0)
	position = _from.lerp(_to, p)
	var frame: int = [0, 1, 2, 1][int(_anim_t / (_duration / 2.0)) % 4]
	_update_frame(frame)
	if p >= 1.0:
		position = _to
		moving = false
		_update_frame(1)
		step_finished.emit(tile.x, tile.y)

func _update_frame(col: int) -> void:
	if sprite:
		sprite.frame = SHEET_ROW.get(facing, 0) * 3 + col

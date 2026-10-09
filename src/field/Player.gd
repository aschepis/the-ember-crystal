class_name Player
extends FieldEntity
## The party leader on the map. Reads input; the FieldScene decides what each step triggers.

signal interact_requested

func setup() -> void:
	var leader: Actor = GameState.party[0] if not GameState.party.is_empty() else null
	if leader:
		entity_id = leader.id
		setup_sprite(Placeholder.character_sheet(leader.id, leader.color(), leader.glyph()))
	else:
		entity_id = "player"
		setup_sprite(Placeholder.character_sheet("player", Color.WHITE, "P"))

func refresh_leader() -> void:
	setup()
	_update_frame(1)

func _process(delta: float) -> void:
	super._process(delta)
	if moving or field == null or field.is_busy():
		return
	var dir := ""
	if Input.is_action_pressed("ui_up"):
		dir = "up"
	elif Input.is_action_pressed("ui_down"):
		dir = "down"
	elif Input.is_action_pressed("ui_left"):
		dir = "left"
	elif Input.is_action_pressed("ui_right"):
		dir = "right"
	if dir != "":
		try_step(dir, Input.is_action_pressed("run"))

func _unhandled_input(event: InputEvent) -> void:
	if field == null or field.is_busy() or moving:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		interact_requested.emit()

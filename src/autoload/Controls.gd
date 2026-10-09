extends Node
## Registers keyboard bindings in code so there is a single readable place for them.
## Built-in ui_* actions are reused so Godot's Control focus navigation works for free.

const BINDINGS := {
	"ui_accept": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z],
	"ui_cancel": [KEY_ESCAPE, KEY_X, KEY_BACKSPACE],
	"ui_up": [KEY_UP, KEY_W],
	"ui_down": [KEY_DOWN, KEY_S],
	"ui_left": [KEY_LEFT, KEY_A],
	"ui_right": [KEY_RIGHT, KEY_D],
	"ui_page_up": [KEY_Q, KEY_PAGEUP],
	"ui_page_down": [KEY_E, KEY_PAGEDOWN],
	"run": [KEY_SHIFT],
	"debug_lab": [KEY_F1],
	"debug_encounter": [KEY_F2],
}

func _ready() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in BINDINGS[action]:
			if _has_key(action, key):
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

func _has_key(action: String, key: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev.physical_keycode == key or ev.keycode == key):
			return true
	return false

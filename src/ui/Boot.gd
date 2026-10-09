extends Node
## Entry point: applies the theme and opens the Debug Lab (the subsystem test menu).

func _ready() -> void:
	get_tree().root.theme = UITheme.theme()
	RenderingServer.set_default_clear_color(Color("0a0a1a"))
	var args := OS.get_cmdline_user_args()
	if "--title" in args:
		SceneStack.replace_all(load("res://src/ui/TitleScene.gd").new())
	else:
		SceneStack.replace_all(load("res://src/debug/DebugLab.gd").new())

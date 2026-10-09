extends Control
## Grows each class from 1 to 50 with the real growth formula and tabulates the curve.

signal _choice(index: int)

var _classes: MenuList
var _table: RichTextLabel
var _ids: Array = []

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0a0a1a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var w1 := UITheme.make_window(Vector2(130, 340))
	w1.position = Vector2(8, 8)
	add_child(w1)
	_classes = MenuList.new()
	_classes.column_width = 100
	w1.add_child(_classes)
	_ids = Database.sorted_ids(Database.classes)
	_classes.set_items(_ids)
	_classes.selected.connect(func(i): _choice.emit(i))
	_classes.cancelled.connect(func(): _choice.emit(-1))
	_classes.cursor_moved.connect(_simulate)
	var w2 := UITheme.make_window(Vector2(490, 340))
	w2.position = Vector2(142, 8)
	add_child(w2)
	_table = RichTextLabel.new()
	_table.theme = UITheme.theme()
	_table.add_theme_font_size_override("normal_font_size", UITheme.FONT_SIZE_SMALL)
	_table.add_theme_font_size_override("mono_font_size", UITheme.FONT_SIZE_SMALL)
	_table.bbcode_enabled = true
	_table.custom_minimum_size = Vector2(470, 320)
	w2.add_child(_table)
	_simulate(0)
	_run()

func _simulate(i: int) -> void:
	var a := Actor.create_for_class(_ids[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var lines: Array[String] = []
	lines.append("[code]%-4s %6s %5s %5s %4s %4s %4s %4s %4s %4s[/code]" % ["Lv", "XP", "HP", "MP", "STR", "AGI", "VIT", "INT", "SPI", "LCK"])
	var marks := [1, 2, 3, 5, 8, 10, 12, 15, 20, 25, 30, 40, 50]
	while a.level <= Formulas.MAX_LEVEL:
		if a.level in marks:
			lines.append("[code]%-4d %6d %5d %5d %4d %4d %4d %4d %4d %4d[/code]" % [a.level, Formulas.xp_for_level(a.level), a.max_hp(), a.max_mp(), a.stat("str"), a.stat("agi"), a.stat("vit"), a.stat("int"), a.stat("spi"), a.stat("luck")])
		if a.level >= Formulas.MAX_LEVEL:
			break
		a.gain_xp(a.xp_to_next(), rng)
	var spells: Array[String] = []
	for sp in a.klass.spells:
		spells.append("%s@%d" % [sp["skill"], int(sp["level"])])
	lines.append("\n%s — %s\nSpells: %s" % [a.klass.name, a.klass.description, ", ".join(spells) if not spells.is_empty() else "none"])
	_table.text = "\n".join(lines)

func _run() -> void:
	await get_tree().process_frame
	while true:
		_classes.activate()
		var idx: int = await _choice
		_classes.deactivate()
		if idx < 0:
			SceneStack.pop()
			return

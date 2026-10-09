class_name UITheme
## Builds the classic "blue window, white border" JRPG theme in code.

const WINDOW_BG := Color("10104a")
const WINDOW_BORDER := Color("e8e8ff")
const TEXT := Color("f4f4f4")
const TEXT_DIM := Color("8a8aa8")
const TEXT_HIGHLIGHT := Color("ffe680")
const HP_COLOR := Color("6ee36e")
const HP_LOW := Color("ffb347")
const HP_CRIT := Color("ff5c5c")
const MP_COLOR := Color("7ab8ff")
const FONT_SIZE := 14
const FONT_SIZE_SMALL := 12
const FONT_SIZE_LARGE := 20

static var _theme: Theme

static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = FONT_SIZE
	var panel := window_style()
	_theme.set_stylebox("panel", "PanelContainer", panel)
	_theme.set_stylebox("panel", "Panel", panel)
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_color("default_color", "RichTextLabel", TEXT)
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_hover_color", "Button", TEXT_HIGHLIGHT)
	_theme.set_color("font_focus_color", "Button", TEXT_HIGHLIGHT)
	_theme.set_color("font_pressed_color", "Button", TEXT_HIGHLIGHT)
	_theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 6; flat.content_margin_right = 6
	flat.content_margin_top = 2; flat.content_margin_bottom = 2
	for state in ["normal", "hover", "pressed", "disabled"]:
		_theme.set_stylebox(state, "Button", flat)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(1, 1, 1, 0.12)
	focus.content_margin_left = 6; focus.content_margin_right = 6
	focus.content_margin_top = 2; focus.content_margin_bottom = 2
	_theme.set_stylebox("focus", "Button", focus)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.6)
	_theme.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = HP_COLOR
	_theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return _theme

static func window_style(bg: Color = WINDOW_BG, border: Color = WINDOW_BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

## Sizes a scene-root Control to the viewport. Anchors alone give size 0 under a CanvasLayer.
static func fullscreen(c: Control) -> void:
	c.position = Vector2.ZERO
	c.size = c.get_viewport().get_visible_rect().size if c.is_inside_tree() else Vector2(640, 360)

static func make_window(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = theme()
	p.custom_minimum_size = min_size
	return p

static func make_label(text: String, size: int = FONT_SIZE, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func hp_color(hp: int, max_hp: int) -> Color:
	if hp <= 0:
		return HP_CRIT
	var r := float(hp) / maxf(1.0, float(max_hp))
	if r < 0.25:
		return HP_CRIT
	if r < 0.5:
		return HP_LOW
	return TEXT

static func status_text(b: Battler) -> String:
	if b.statuses.is_empty():
		return ""
	var parts: Array[String] = []
	for s in b.statuses:
		parts.append(StatusEffects.SHORT.get(s, s))
	return " ".join(parts)

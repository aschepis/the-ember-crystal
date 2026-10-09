extends Node
## Generates placeholder textures at runtime and swaps in real art when a PNG exists.
##
## Real art is loaded with Image.load_from_file so files dropped into res://assets by the
## external asset pipeline work immediately without an editor import pass.

const TILE := 32
var _cache: Dictionary = {}

# 3x5 bitmap font so placeholder sprites can carry a readable letter.
const GLYPHS := {
	"A": ["010","101","111","101","101"], "B": ["110","101","110","101","110"],
	"C": ["011","100","100","100","011"], "D": ["110","101","101","101","110"],
	"E": ["111","100","110","100","111"], "F": ["111","100","110","100","100"],
	"G": ["011","100","101","101","011"], "H": ["101","101","111","101","101"],
	"I": ["111","010","010","010","111"], "J": ["001","001","001","101","010"],
	"K": ["101","101","110","101","101"], "L": ["100","100","100","100","111"],
	"M": ["101","111","111","101","101"], "N": ["110","101","101","101","101"],
	"O": ["010","101","101","101","010"], "P": ["110","101","110","100","100"],
	"Q": ["010","101","101","111","011"], "R": ["110","101","110","101","101"],
	"S": ["011","100","010","001","110"], "T": ["111","010","010","010","010"],
	"U": ["101","101","101","101","111"], "V": ["101","101","101","101","010"],
	"W": ["101","101","111","111","101"], "X": ["101","101","010","101","101"],
	"Y": ["101","101","010","010","010"], "Z": ["111","001","010","100","111"],
	"0": ["111","101","101","101","111"], "1": ["010","110","010","010","111"],
	"2": ["111","001","111","100","111"], "3": ["111","001","111","001","111"],
	"4": ["101","101","111","001","001"], "5": ["111","100","111","001","111"],
	"6": ["111","100","111","101","111"], "7": ["111","001","001","001","001"],
	"8": ["111","101","111","101","111"], "9": ["111","101","111","001","111"],
	"?": ["111","001","010","000","010"], "!": ["010","010","010","000","010"],
	"$": ["011","110","010","011","110"], "*": ["101","010","111","010","101"],
	"+": ["000","010","111","010","000"], "-": ["000","000","111","000","000"],
	"^": ["010","101","000","000","000"], "~": ["000","011","110","000","000"],
	".": ["000","000","000","000","010"], " ": ["000","000","000","000","000"],
}

func real_art_path(category: String, id: String) -> String:
	return "res://assets/%s/%s.png" % [category, id]

## Returns a real texture from res://assets/<category>/<id>.png if present, else null.
func load_real(category: String, id: String) -> Texture2D:
	var path := real_art_path(category, id)
	if not FileAccess.file_exists(path):
		return null
	var key := "real:" + path
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_warning("Placeholder: failed to load %s (%s)" % [path, err])
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## A single colored square with a border and optional glyph. Used for NPCs, players, icons.
func sprite(id: String, color: Color, glyph: String = "", size: int = TILE) -> Texture2D:
	var key := "sprite:%s:%s:%s:%d" % [id, color.to_html(), glyph, size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inset := maxi(2, size / 8)
	_fill_rect(img, Rect2i(inset, inset, size - inset * 2, size - inset * 2), color)
	_stroke_rect(img, Rect2i(inset, inset, size - inset * 2, size - inset * 2), color.darkened(0.5))
	if glyph != "":
		var scale := maxi(1, size / 12)
		_draw_text(img, glyph, Vector2i(size / 2, size / 2), scale, _contrast(color))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## A 4-direction, 3-frame character sheet (cols: frames, rows: down,left,right,up).
## The facing is indicated by a small dark notch so direction is visible without real art.
func character_sheet(id: String, color: Color, glyph: String) -> Texture2D:
	var real := load_real("sprites/characters", id)
	if real:
		return real
	var key := "charsheet:%s:%s:%s" % [id, color.to_html(), glyph]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(TILE * 3, TILE * 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dirs := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
	for row in 4:
		for frame in 3:
			var ox := frame * TILE
			var oy := row * TILE
			var bob := 1 if frame == 1 else 0
			var body := Rect2i(ox + 8, oy + 6 + bob, 16, 22 - bob)
			_fill_rect(img, body, color)
			_stroke_rect(img, body, color.darkened(0.5))
			var d: Vector2i = dirs[row]
			var notch := Vector2i(ox + 16 + d.x * 7, oy + 17 + d.y * 9)
			_fill_rect(img, Rect2i(notch.x - 2, notch.y - 2, 4, 4), color.darkened(0.6))
			if frame != 1:
				var foot := Rect2i(ox + (6 if frame == 0 else 18), oy + 28, 8, 3)
				_fill_rect(img, foot, color.darkened(0.3))
			_draw_text(img, glyph, Vector2i(ox + 16, oy + 14), 2, _contrast(color))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Enemy battle sprite: a bigger block with a silhouette-like shape and the name's initials.
func enemy_sprite(id: String, color: Color, label: String, size: int = 64) -> Texture2D:
	var real := load_real("sprites/enemies", id)
	if real:
		return real
	var key := "enemy:%s:%s:%s:%d" % [id, color.to_html(), label, size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Rect2i(size / 6, size / 5, size * 2 / 3, size * 3 / 4)
	_fill_rect(img, body, color)
	_stroke_rect(img, body, color.darkened(0.5))
	# "eyes" so the blob reads as a creature.
	var eye := maxi(2, size / 16)
	_fill_rect(img, Rect2i(size / 3, size / 3, eye, eye), Color.BLACK)
	_fill_rect(img, Rect2i(size * 2 / 3 - eye, size / 3, eye, eye), Color.BLACK)
	_draw_text(img, label.substr(0, 3), Vector2i(size / 2, size * 2 / 3), maxi(1, size / 24), _contrast(color))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

func portrait(id: String, color: Color, glyph: String) -> Texture2D:
	var real := load_real("portraits", id)
	if real:
		return real
	return sprite("portrait_" + id, color, glyph, 48)

func background(id: String, top: Color, bottom: Color, width: int = 640, height: int = 200) -> Texture2D:
	var real := load_real("backgrounds", id)
	if real:
		return real
	var key := "bg:%s" % id
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var c := top.lerp(bottom, float(y) / height)
		for x in width:
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Builds the tile atlas (one row, one 32px tile per TileDefs entry) unless a real tileset exists.
func tile_atlas(defs: Array) -> Texture2D:
	var real := load_real("tiles", "tileset")
	if real:
		return real
	var key := "tileatlas:%d" % defs.size()
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(TILE * defs.size(), TILE, false, Image.FORMAT_RGBA8)
	for i in defs.size():
		var def: Dictionary = defs[i]
		var color: Color = def.get("color", Color.MAGENTA)
		var r := Rect2i(i * TILE, 0, TILE, TILE)
		_fill_rect(img, r, color)
		# Checker pattern makes tile boundaries readable on open terrain.
		for y in range(0, TILE, 8):
			for x in range(0, TILE, 8):
				if ((x + y) / 8) % 2 == 0:
					_fill_rect(img, Rect2i(r.position.x + x, y, 8, 8), color.darkened(0.06))
		var glyph: String = def.get("glyph", "")
		if glyph != "":
			_draw_text(img, glyph, Vector2i(r.position.x + TILE / 2, TILE / 2), 2, _contrast(color, 0.35))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

func _fill_rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)

func _stroke_rect(img: Image, r: Rect2i, c: Color) -> void:
	_fill_rect(img, Rect2i(r.position.x, r.position.y, r.size.x, 1), c)
	_fill_rect(img, Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), c)
	_fill_rect(img, Rect2i(r.position.x, r.position.y, 1, r.size.y), c)
	_fill_rect(img, Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), c)

func _draw_text(img: Image, text: String, center: Vector2i, scale: int, c: Color) -> void:
	text = text.to_upper()
	var total_w := text.length() * 4 * scale - scale
	var x0 := center.x - total_w / 2
	var y0 := center.y - 5 * scale / 2
	for i in text.length():
		var rows: Array = GLYPHS.get(text[i], GLYPHS["?"])
		for ry in 5:
			for rx in 3:
				if rows[ry][rx] == "1":
					_fill_rect(img, Rect2i(x0 + (i * 4 + rx) * scale, y0 + ry * scale, scale, scale), c)

func _contrast(c: Color, alpha: float = 1.0) -> Color:
	var out := Color.BLACK if c.get_luminance() > 0.5 else Color.WHITE
	out.a = alpha
	return out

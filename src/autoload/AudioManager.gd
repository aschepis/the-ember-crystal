extends Node
## BGM/SFX by id. Real files are used from res://assets/audio when present; otherwise SFX
## are synthesized beeps so every interaction still has feedback, and BGM is silence.

const SFX_DEFS := {
	# name: [frequency, duration, waveform(square|sine|noise|sweep_down|sweep_up)]
	"cursor": [880, 0.04, "square"],
	"confirm": [1320, 0.07, "square"],
	"cancel": [440, 0.08, "square"],
	"error": [180, 0.15, "square"],
	"hit": [220, 0.10, "noise"],
	"crit": [160, 0.18, "noise"],
	"miss": [600, 0.08, "sweep_down"],
	"magic": [660, 0.25, "sweep_up"],
	"heal": [990, 0.25, "sine"],
	"item": [740, 0.10, "sine"],
	"encounter": [300, 0.35, "sweep_down"],
	"victory": [1046, 0.30, "sine"],
	"levelup": [1568, 0.35, "sweep_up"],
	"chest": [1174, 0.15, "square"],
	"buy": [1046, 0.12, "sine"],
	"door": [330, 0.12, "sweep_down"],
	"run": [500, 0.20, "sweep_up"],
	"ko": [120, 0.40, "sweep_down"],
	"step": [200, 0.02, "noise"],
}

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var current_bgm: String = ""
var muted: bool = false

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8
		add_child(p)
		_sfx_players.append(p)

func play_bgm(id: String) -> void:
	if id == current_bgm:
		return
	current_bgm = id
	_bgm_player.stop()
	if id == "" or muted:
		return
	var stream := _load_stream("res://assets/audio/bgm/" + id)
	if stream:
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_bgm_player.stream = stream
		_bgm_player.play()

func stop_bgm() -> void:
	current_bgm = ""
	_bgm_player.stop()

func play_sfx(name: String) -> void:
	if muted:
		return
	var stream := _sfx_stream(name)
	if stream == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_sfx_players[0].stream = stream
	_sfx_players[0].play()

func _sfx_stream(name: String) -> AudioStream:
	if _sfx_cache.has(name):
		return _sfx_cache[name]
	var stream := _load_stream("res://assets/audio/sfx/" + name)
	if stream == null and SFX_DEFS.has(name):
		var def: Array = SFX_DEFS[name]
		stream = _synth(def[0], def[1], def[2])
	_sfx_cache[name] = stream
	return stream

func _load_stream(base: String) -> AudioStream:
	if FileAccess.file_exists(base + ".ogg"):
		return AudioStreamOggVorbis.load_from_file(base + ".ogg")
	if FileAccess.file_exists(base + ".wav"):
		return AudioStreamWAV.load_from_file(base + ".wav")
	return null

func _synth(freq: float, duration: float, wave: String) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in n:
		var t := float(i) / rate
		var env := 1.0 - float(i) / n
		var f := freq
		if wave == "sweep_down":
			f = freq * (1.0 - 0.5 * t / duration)
		elif wave == "sweep_up":
			f = freq * (1.0 + 0.5 * t / duration)
		var v := 0.0
		match wave:
			"square", "sweep_down", "sweep_up":
				v = 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0
			"sine":
				v = sin(TAU * f * t)
			"noise":
				v = rng.randf_range(-1.0, 1.0)
		var sample := int(clampf(v * env * 0.4, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	return s

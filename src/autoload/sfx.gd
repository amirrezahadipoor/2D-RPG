extends Node
## Fully procedural audio: every SFX and every biome music loop is synthesized
## at runtime into 16-bit WAV streams — zero audio assets, tiny binary, and
## deterministic across machines. One autoload, two buses (SFX / Music).

const SR := 22050
const SFX_NAMES := ["swing", "hit", "crit", "hurt", "puff", "coin", "potion",
	"click", "levelup", "death", "fireball", "stairs", "craft", "cast", "buy"]

## biome -> [root_hz, scale_semitones, tempo_bpm, wave, mood_seed]
const MUSIC_KEYS := {
	"field":     [220.0, [0, 3, 5, 7, 10], 84, "sine",     11],
	"forest":    [233.1, [0, 2, 3, 7, 8],  92, "sine",     22],
	"village":   [261.6, [0, 2, 4, 7, 9],  104, "triangle", 33],
	"town":      [261.6, [0, 2, 4, 7, 9],  104, "triangle", 33],
	"swamp":     [174.6, [0, 2, 3, 5, 6],  72, "triangle", 44],
	"desert":    [293.7, [0, 2, 4, 5, 9],  96, "triangle", 55],
	"snow":      [329.6, [0, 3, 5, 7, 10], 70, "sine",     66],
	"graveyard": [146.8, [0, 1, 3, 6, 8],  60, "saw",      77],
	"dungeon":   [130.8, [0, 1, 3, 5, 8],  66, "saw",      88],
}

var _cache := {}
var _music_cache := {}
var _players: Array = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _current_biome := ""
var _last_gold := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_a)
	add_child(_music_b)
	_active_music = _music_a
	_music_b.volume_db = -80.0
	Stats.gold_changed.connect(_on_gold)
	Stats.level_changed.connect(func(_l, _x, _n): play("levelup"))
	_last_gold = Stats.gold

# ------------------------------------------------------------------ API ----
func play(sfx_name: String, vol_db := 0.0, pitch_rand := 0.07) -> void:
	if sfx_name not in SFX_NAMES:
		return
	var stream: AudioStreamWAV = _sfx(sfx_name)
	var p: AudioStreamPlayer = _free_player()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_rand, pitch_rand)
	p.play()

func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[randi() % _players.size()]

func _on_gold(gold: int) -> void:
	if _last_gold >= 0 and gold > _last_gold:
		play("coin", -6.0)
	_last_gold = gold

## Crossfades the generative music loop for a biome ("dungeon" works too).
func set_biome(biome: String) -> void:
	if biome == _current_biome:
		return
	_current_biome = biome
	var key: String = biome if MUSIC_KEYS.has(biome) else "field"
	var stream: AudioStreamWAV = _music(key)
	var next := _music_b if _active_music == _music_a else _music_a
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	var fade_out := _active_music
	var fade_in := next
	_active_music = next
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(fade_in, "volume_db", -6.0, 1.4)
	t.tween_property(fade_out, "volume_db", -80.0, 1.4)

func stop_music() -> void:
	_current_biome = ""
	_music_a.stop()
	_music_b.stop()

# ------------------------------------------------------------ synthesis ----
func _sfx(n: String) -> AudioStreamWAV:
	if _cache.has(n):
		return _cache[n]
	var f: PackedFloat32Array
	match n:
		"swing":
			f = _env(_sweep(760.0, 190.0, 0.13, "noise", 1.0), 0.004, 0.12)
		"hit":
			f = _mix(_env(_tone(150.0, 0.10, "sine", 6.0), 0.001, 0.10),
				_env(_sweep(900.0, 300.0, 0.05, "noise", 1.0), 0.001, 0.05) )
		"crit":
			f = _mix(_sfx_frames("hit"),
				_env(_tone(1568.0, 0.16, "square", 5.0), 0.002, 0.16))
		"hurt":
			f = _env(_sweep(420.0, 160.0, 0.20, "saw", 1.0), 0.003, 0.19)
		"puff":
			f = _env(_sweep(300.0, 90.0, 0.09, "noise", 1.0), 0.003, 0.09)
		"coin":
			f = _seq([_env(_tone(988.0, 0.05, "square", 2.0), 0.002, 0.05),
				_env(_tone(1319.0, 0.10, "square", 4.0), 0.002, 0.10)])
		"potion":
			f = _env(_sweep(300.0, 950.0, 0.26, "sine", 0.6, 7.0, 18.0), 0.01, 0.25)
		"click":
			f = _env(_tone(1150.0, 0.035, "square", 3.0), 0.001, 0.035)
		"levelup":
			var notes := [523.3, 659.3, 784.0, 1046.5]
			var parts: Array = []
			for i in notes.size():
				parts.append(_env(_tone(notes[i], 0.16, "triangle", 2.2), 0.006, 0.16))
				if i < notes.size() - 1:
					parts.append(_silence(0.09))
			f = _seq(parts)
		"death":
			f = _mix(_env(_sweep(220.0, 52.0, 0.85, "saw", 1.0), 0.01, 0.84),
				_env(_sweep(500.0, 80.0, 0.5, "noise", 1.0), 0.05, 0.5))
		"fireball":
			f = _env(_sweep(180.0, 780.0, 0.30, "noise", 0.8), 0.02, 0.29)
		"stairs":
			f = _seq([_env(_tone(110.0, 0.09, "sine", 5.0), 0.002, 0.09),
				_silence(0.07),
				_env(_tone(88.0, 0.12, "sine", 5.0), 0.002, 0.12)])
		"craft":
			var parts2: Array = []
			for i in 3:
				parts2.append(_mix(_env(_tone(2100.0 - 200.0 * i, 0.045, "square", 8.0), 0.001, 0.045),
					_env(_tone(160.0, 0.06, "sine", 7.0), 0.001, 0.06)))
				if i < 2:
					parts2.append(_silence(0.085))
			f = _seq(parts2)
		"cast":
			f = _env(_sweep(560.0, 640.0, 0.34, "sine", 0.5, 9.0, 14.0), 0.03, 0.33)
		"buy":
			f = _seq([_sfx_frames("coin"), _silence(0.03), _sfx_frames("click")])
	f = _normalize(f, 0.85)
	var wav := _to_wav(f, false)
	_cache[n] = wav
	return wav

func _sfx_frames(n: String) -> PackedFloat32Array:
	# raw (un-cached-as-wav) frames for composing compound sounds
	var wav := _sfx(n)
	return _wav_frames(wav)

func _wav_frames(wav: AudioStreamWAV) -> PackedFloat32Array:
	var data := wav.data
	var out := PackedFloat32Array()
	out.resize(data.size() / 2)
	for i in out.size():
		out[i] = float(data.decode_s16(i * 2)) / 32767.0
	return out

func _music(key: String) -> AudioStreamWAV:
	if _music_cache.has(key):
		return _music_cache[key]
	var spec: Array = MUSIC_KEYS[key]
	var root: float = spec[0]
	var scale: Array = spec[1]
	var bpm: float = spec[2]
	var wave: String = spec[3]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * int(spec[4]) + 13

	var beat := 60.0 / bpm
	var step := beat / 2.0            # 8th notes
	var steps := 32                   # 2 bars of 4/4 in 8ths
	var total := step * steps + 1.2   # tail for decays
	var frames := PackedFloat32Array()
	frames.resize(int(total * SR))
	frames.fill(0.0)

	# melody: seeded random walk over the pentatonic-ish scale
	var degree := rng.randi_range(0, scale.size() - 1)
	for s in steps:
		degree += rng.randi_range(-2, 2)
		degree = clampi(degree, 0, scale.size() * 2 - 1)
		var oct := int(float(degree) / scale.size())
		var idx := degree % scale.size()
		var freq := root * pow(2.0, float(scale[idx]) / 12.0) * pow(2.0, float(oct))
		if rng.randf() < 0.18:
			continue   # rests make it breathe
		var dur := step * (1.6 if rng.randf() < 0.3 else 0.9)
		var note := _env(_tone(freq, dur, wave, 2.4, 0.0), 0.012, dur)
		_overlay(frames, note, int(float(s) * step * SR), 0.5)
	# bass: root / fifth on every beat
	for b in int(steps / 2):
		var fifth := b % 4 == 2
		var bf := root * 0.5 * (pow(2.0, float(scale[3]) / 12.0) if fifth else 1.0)
		var bass := _env(_tone(bf, beat * 0.92, "triangle", 3.0), 0.008, beat * 0.92)
		_overlay(frames, bass, int(float(b) * beat * SR), 0.42)
	# drone pad underneath the eerie keys
	if key in ["graveyard", "dungeon", "swamp"]:
		var drone := _env(_tone(root * 0.25, total - 0.1, "saw", 0.06, 1.5, 0.21), 0.9, 0.9)
		_overlay(frames, drone, 0, 0.16)

	frames = _normalize(frames, 0.7)
	var wav := _to_wav(frames, true)
	_music_cache[key] = wav
	return wav

# ------------------------------------------------------------- dsp bits ----
func _tone(freq: float, dur: float, wave: String, decay := 3.0,
		vibrato := 0.0, vib_rate := 5.5) -> PackedFloat32Array:
	var n := maxi(int(dur * SR), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var f := freq
		if vibrato > 0.0:
			f *= 1.0 + vibrato * 0.01 * sin(TAU * vib_rate * t)
		phase += f / SR
		var v := 0.0
		match wave:
			"sine":
				v = sin(TAU * phase)
			"square":
				v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				v *= 0.55
			"triangle":
				var p := fmod(phase, 1.0)
				v = (4.0 * absf(p - 0.5) - 1.0) * 0.7
			"saw":
				v = (2.0 * fmod(phase, 1.0) - 1.0) * 0.5
			"noise":
				v = randf_range(-1.0, 1.0)
		out[i] = v * exp(-decay * t)
	return out

func _sweep(f0: float, f1: float, dur: float, wave: String, decay := 3.0,
		vibrato := 0.0, vib_rate := 5.5) -> PackedFloat32Array:
	var n := maxi(int(dur * SR), 1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var k := float(i) / float(n)
		var freq := lerpf(f0, f1, k)
		if vibrato > 0.0:
			freq *= 1.0 + vibrato * 0.01 * sin(TAU * vib_rate * t)
		phase += freq / SR
		var v := 0.0
		match wave:
			"sine":
				v = sin(TAU * phase)
			"square":
				v = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * 0.55
			"triangle":
				var p := fmod(phase, 1.0)
				v = (4.0 * absf(p - 0.5) - 1.0) * 0.7
			"saw":
				v = (2.0 * fmod(phase, 1.0) - 1.0) * 0.5
			"noise":
				v = randf_range(-1.0, 1.0)
				# one-pole lowpass that opens with the sweep: whoosh character
		out[i] = v * exp(-decay * t * 0.9)
	if wave == "noise":
		out = _lowpass_sweep(out, f0, f1)
	return out

func _lowpass_sweep(frames: PackedFloat32Array, f0: float, f1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames.size())
	var z := 0.0
	for i in frames.size():
		var k := float(i) / float(maxi(frames.size() - 1, 1))
		var cutoff := lerpf(f0, f1, k)
		var rc := 1.0 / (TAU * maxf(cutoff, 20.0))
		var alpha := (1.0 / SR) / (rc + 1.0 / SR)
		z += alpha * (frames[i] - z)
		out[i] = z * 2.2
	return out

func _env(frames: PackedFloat32Array, attack: float, dur: float) -> PackedFloat32Array:
	var out := frames.duplicate()
	var a := int(attack * SR)
	for i in mini(a, out.size()):
		out[i] *= float(i) / float(maxi(a, 1))
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	for i in a.size():
		out[i] += a[i]
	for i in b.size():
		out[i] += b[i]
	return out

func _seq(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		var frames: PackedFloat32Array = p
		var grown := PackedFloat32Array()
		grown.resize(out.size() + frames.size())
		for i in out.size():
			grown[i] = out[i]
		for i in frames.size():
			grown[out.size() + i] = frames[i]
		out = grown
	return out

func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * SR))
	out.fill(0.0)
	return out

func _overlay(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int, gain: float) -> void:
	for i in src.size():
		var j := offset + i
		if j >= 0 and j < dst.size():
			dst[j] += src[i] * gain

func _normalize(frames: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in frames:
		m = maxf(m, absf(v))
	var out := frames.duplicate()
	var g := peak / m
	for i in out.size():
		out[i] *= g
	return out

func _to_wav(frames: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(frames.size() * 2)
	for i in frames.size():
		data.encode_s16(i * 2, int(clampf(frames[i], -1.0, 1.0) * 32767.0))
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frames.size()
	return wav

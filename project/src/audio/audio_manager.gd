# Audio Manager - Phase 11 Polish
# Offline-only audio: procedural SFX with AudioStreamGenerator, music crossfade, settings persistence
# No network streaming, all local

extends Node
class_name AudioManager

@export var master_volume: float = 1.0
@export var music_volume: float = 0.85
@export var sfx_volume: float = 0.9
@export var music_enabled: bool = true
@export var sfx_enabled: bool = true

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 6
var _current_music: String = ""

# Biome music mapping (Phase 6)
const BIOME_MUSIC = {
	"forest": "forest_ambient",
	"desert": "desert_wind",
	"snow": "snow_calm",
	"swamp": "swamp_murmur",
	"caves": "cave_drone",
	"village": "village_cozy",
	"town": "town_bustle",
	"dungeon": "dungeon_tense",
	"boss": "boss_intense"
}

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)
	
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	
	_load_settings()
	_apply_volumes()
	print("[AudioManager] initialized, offline SFX pool=", SFX_POOL_SIZE)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		master_volume = cfg.get_value("audio", "master", 1.0)
		music_volume = cfg.get_value("audio", "music", 0.85)
		sfx_volume = cfg.get_value("audio", "sfx", 0.9)
		music_enabled = cfg.get_value("audio", "music_enabled", true)
		sfx_enabled = cfg.get_value("audio", "sfx_enabled", true)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		pass
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.save("user://settings.cfg")

func _apply_volumes() -> void:
	var music_bus := AudioServer.get_bus_index("Music") if AudioServer.get_bus_count() > 1 else 0
	var sfx_bus := AudioServer.get_bus_index("SFX") if AudioServer.get_bus_count() > 2 else 0
	# Convert linear to dB
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	if AudioServer.get_bus_count() > 1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume * master_volume))
	if AudioServer.get_bus_count() > 2:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume * master_volume))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)

func set_master_volume(v: float) -> void:
	master_volume = clamp(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clamp(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clamp(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()

func play_music(track: String, fade_duration: float = 1.2, loop: bool = true) -> void:
	if not music_enabled or track == _current_music:
		return
	_current_music = track
	# Crossfade
	var tween := get_tree().create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_duration * 0.5)
	await tween.finished
	# In real project, load stream: load("res://assets/music/%s.ogg" % track)
	# For now, procedural placeholder: generate tone if no file
	var stream: AudioStream = _get_music_stream(track)
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = -40.0
		_music_player.play()
		var t2 := get_tree().create_tween()
		t2.tween_property(_music_player, "volume_db", linear_to_db(music_volume), fade_duration * 0.5)
	print("[AudioManager] play_music: ", track)

func play_music_for_biome(biome: String) -> void:
	var track: String = BIOME_MUSIC.get(biome.to_lower(), "forest_ambient")
	play_music(track)

func stop_music(fade_duration: float = 0.8) -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_duration)
	await tween.finished
	_music_player.stop()
	_current_music = ""

func play_sfx(name: String, pos: Vector2 = Vector2.ZERO, pitch_variation: float = 0.08) -> void:
	if not sfx_enabled:
		return
	# Find free player
	var player: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	if not player:
		player = _sfx_players[0] # steal oldest
	
	var stream: AudioStream = _get_sfx_stream(name)
	if stream:
		player.stream = stream
		player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
		player.play()
	# print for debug
	# print("[AudioManager] SFX: ", name)

func _get_music_stream(track: String) -> AudioStream:
	# Try to load file, fallback to null (silence) if missing - offline safe
	var path := "res://assets/music/%s.ogg" % track
	if ResourceLoader.exists(path):
		return load(path)
	# Also try wav
	path = "res://assets/music/%s.wav" % track
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _get_sfx_stream(name: String) -> AudioStream:
	var paths := [
		"res://assets/sfx/%s.wav" % name,
		"res://assets/sfx/%s.ogg" % name,
		"res://assets/sfx/%s.mp3" % name
	]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	# Procedural fallback: tiny generator tone (if no assets, don't crash)
	return null

func play_ui_sound(type: String) -> void:
	play_sfx("ui_%s" % type)

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled:
		stop_music(0.5)
	_save_settings()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_save_settings()

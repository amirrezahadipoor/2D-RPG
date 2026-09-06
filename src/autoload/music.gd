# Adaptive soundtrack (Phase E2): day / night / dungeon beds crossfade into
# each other, and the weather layer breathes underneath (rain, wind, crickets).
extends Node

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _front := 0          # 0 = _a is live
var _track := ""
var _amb_track := ""
var _tick := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _player()
	_b = _player()
	_amb = _player()
	_amb.volume_db = -14.0

func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p

func _desired() -> String:
	if get_tree().root.find_child("Dungeon", true, false) != null:
		return "music_dungeon"
	if Game.is_night():
		return "music_night"
	return "music_day"

func _desired_amb() -> String:
	var w := get_tree().get_first_node_in_group("world")
	if w != null and w.weather != null and w.weather.mode == "rain":
		return "amb_rain"
	if Game.is_night():
		return "amb_crickets"
	return "amb_wind"

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.8:
		return
	_tick = 0.0
	var want := _desired()
	if want != _track:
		_cross(want)
	var want_amb := _desired_amb()
	if want_amb != _amb_track:
		_amb_track = want_amb
		_amb.stream = load("res://assets/audio/%s.wav" % want_amb)
		_amb.play()

func _cross(track: String) -> void:
	_track = track
	var incoming := _b if _front == 0 else _a
	var outgoing := _a if _front == 0 else _b
	incoming.stream = load("res://assets/audio/%s.wav" % track)
	incoming.volume_db = -24.0
	incoming.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, 2.0)
	tw.tween_property(outgoing, "volume_db", -24.0, 2.0)
	tw.chain().tween_callback(outgoing.stop)
	_front = 1 - _front

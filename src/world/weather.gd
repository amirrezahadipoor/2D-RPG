# Pixel weather: wind-blown rain streaks or drifting snow, drawn in a screen
# sized box that follows the hero (Phase B2). Pure _draw, zero textures.
class_name Weather
extends Node2D

var mode := "off"          # "off" | "rain" | "snow"
var _t := 0.0
var _seeds: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 90:
		_seeds.append([rng.randf(), rng.randf(), rng.randf()])

func _process(delta: float) -> void:
	_t += delta
	if mode != "off":
		queue_redraw()

func _draw() -> void:
	if mode == "off" or _seeds.is_empty():
		return
	var cam := get_viewport().get_camera_2d()
	var c := Vector2.ZERO
	if cam:
		c = cam.global_position
	var half := Vector2(240.0, 135.0)
	if mode == "rain":
		for s in _seeds:
			var x := c.x - half.x + fmod(s[0] * 480.0 + _t * 60.0, 480.0)
			var y := c.y - half.y + fmod(s[1] * 270.0 + _t * 420.0, 270.0)
			draw_line(Vector2(x, y), Vector2(x - 2.0, y + 7.0), Color(0.75, 0.85, 1.0, 0.35), 1.0)
	else:
		for s in _seeds:
			var x := c.x - half.x + fmod(s[0] * 480.0 + sin(_t * 0.8 + s[2] * 6.0) * 14.0 + _t * 12.0, 480.0)
			var y := c.y - half.y + fmod(s[1] * 270.0 + _t * 46.0, 270.0)
			draw_rect(Rect2(x, y, 1.5, 1.5), Color(1, 1, 1, 0.55))

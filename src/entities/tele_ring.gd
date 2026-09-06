# Telegraphed danger zone: a pulsing warning circle under a boss slam
# (Phase C1). Reads instantly on a phone screen.
class_name TeleRing
extends Node2D

var radius := 40.0
var _t := 0.0

func _process(d: float) -> void:
	_t += d
	queue_redraw()

func _draw() -> void:
	var a := 0.45 + 0.25 * sin(_t * 14.0)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1.0, 0.3, 0.25, a), 1.5)
	draw_arc(Vector2.ZERO, radius * 0.55, 0, TAU, 24, Color(1.0, 0.3, 0.25, a * 0.6), 1.0)

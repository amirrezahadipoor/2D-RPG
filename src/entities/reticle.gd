# A pulsing chevron over whoever the hero is auto-fighting (Phase D1):
# touch players always see WHY the hero swings.
class_name Reticle
extends Node2D

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var b := 2.0 + sin(_t * 8.0) * 1.0
	var col := Color(1.0, 0.35, 0.3, 0.85)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -b), Vector2(4, -b), Vector2(0, 4.0 - b)]), col)

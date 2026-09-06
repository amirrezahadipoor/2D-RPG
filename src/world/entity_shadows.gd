# Soft ground ellipses under every actor: the cheapest trick that makes
# sprites feel standing IN the world instead of floating over it (Phase A4).
class_name EntityShadows
extends Node2D

var pts: Array = []

func _draw() -> void:
	for p in pts:
		var poly := PackedVector2Array()
		for i in range(12):
			var a := i / 12.0 * TAU
			poly.append(p + Vector2(cos(a) * 8.0, sin(a) * 3.0))
		draw_colored_polygon(poly, Color(0, 0, 0, 0.28))

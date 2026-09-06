# One-node, one-draw-call accent painter: eave shadows, roof highlights and
# dungeon wall rims. Makes silhouettes readable without new art (Phase 3.4/3.5).
class_name EdgePainter
extends Node2D

var edges: Array = []   # [Rect2, Color]

func _draw() -> void:
	for e in edges:
		draw_rect(e[0], e[1])

func rebuild() -> void:
	queue_redraw()

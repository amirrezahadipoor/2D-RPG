# Living air: biome-specific ambient particles (snowfall, fireflies at night,
# desert dust, graveyard wisps, cave motes) drifting around the camera view.
class_name AmbientFX
extends Node2D

const COUNT := 26

var world: Overworld
var _bits: Array = []      # {rect, pos, vel, phase}
var _kind := ""
var _hero: Node2D = null

func _ready() -> void:
	for i in COUNT:
		var r := ColorRect.new()
		r.size = Vector2(1, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		_bits.append({"rect": r, "pos": Vector2.ZERO, "vel": Vector2.ZERO,
			"phase": randf() * TAU})

func _process(delta: float) -> void:
	if world == null or world.hero == null:
		return
	_hero = world.hero
	var biome := world.biome_at(_hero.global_position)
	var kind := _kind_for(biome)
	if kind != _kind:
		_kind = kind
		_scatter_all()
	if _kind == "":
		for b in _bits:
			b["rect"].visible = false
		return

	var view := _view_rect()
	for b in _bits:
		b["phase"] += delta
		var p: Vector2 = b["pos"]
		match _kind:
			"snow":
				p += Vector2(sin(b["phase"] * 1.7) * 6.0, 26.0) * delta
			"dust":
				p += Vector2(18.0, sin(b["phase"] * 1.3) * 4.0) * delta
			"flies":
				p += Vector2(cos(b["phase"] * 0.9), sin(b["phase"] * 1.1)) * 9.0 * delta
			"wisps":
				p += Vector2(sin(b["phase"] * 0.7) * 5.0, -12.0) * delta
			"motes":
				p += Vector2(sin(b["phase"] * 0.5), cos(b["phase"] * 0.4)) * 3.0 * delta
		if not view.grow(4).has_point(p):
			p = _random_in(view)
		b["pos"] = p
		var r: ColorRect = b["rect"]
		r.global_position = p
		r.visible = true
		r.color = _color_for(b)

func _view_rect() -> Rect2:
	var c := _hero.global_position
	return Rect2(c - Vector2(130, 74), Vector2(260, 148))

func _random_in(view: Rect2) -> Vector2:
	return view.position + Vector2(randf() * view.size.x, randf() * view.size.y)

func _scatter_all() -> void:
	var view := _view_rect()
	for b in _bits:
		b["pos"] = _random_in(view)
		b["phase"] = randf() * TAU

func _kind_for(biome: String) -> String:
	match biome:
		"snow": return "snow"
		"desert": return "dust"
		"graveyard": return "wisps"
		"caves": return "motes"
		"forest", "swamp", "village", "town":
			return "flies" if Game.is_night() else ""
	return ""

func _color_for(b: Dictionary) -> Color:
	var tw := 0.5 + 0.5 * sin(b["phase"] * 3.0)
	match _kind:
		"snow": return Color(1, 1, 1, 0.75)
		"dust": return Color(0.9, 0.75, 0.5, 0.35)
		"flies": return Color(1.0, 0.9, 0.3, 0.25 + 0.6 * tw)
		"wisps": return Color(0.45, 1.0, 0.55, 0.2 + 0.45 * tw)
		"motes": return Color(0.8, 0.8, 0.9, 0.25)
	return Color(1, 1, 1, 0.3)

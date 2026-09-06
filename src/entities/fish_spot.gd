# A rippling fishing spot (Phase C4): tap, wait for the bob, eat well.
class_name FishSpot
extends Node2D

var uses := 3
var _ring: TeleRing
var _prompt: Label

func _ready() -> void:
	add_to_group("interact")
	_ring = TeleRing.new()
	_ring.radius = 7.0
	_ring.modulate = Color(0.7, 0.85, 1.0, 0.8)
	add_child(_ring)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 2)
	_prompt.text = "[E] " + I18N.tr_str("fish.prompt")
	_prompt.position = Vector2(-24, -22)
	_prompt.visible = false
	add_child(_prompt)

func _process(_d: float) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null:
		return
	_prompt.visible = uses > 0 and global_position.distance_to(hero.global_position) < 22.0

func interact() -> void:
	if uses <= 0:
		return
	uses -= 1
	Juice.puff(global_position)
	Sfx.play("potion", -10.0)
	var pk := Pickup.new()
	get_parent().add_child(pk)
	pk.global_position = global_position
	pk.setup({"id": "fish", "qty": 1})
	if uses == 0:
		_ring.visible = false
		_prompt.visible = false

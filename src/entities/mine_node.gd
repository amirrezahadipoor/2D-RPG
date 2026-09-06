# A glittering ore vein (Phase C4): hold-tap three times and it is spent.
class_name MineNode
extends Node2D

var uses := 3
var _spr: Sprite2D
var _prompt: Label

func _ready() -> void:
	add_to_group("interact")
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/sprites/tiles/props.png")
	_spr.hframes = 8
	_spr.vframes = int(_spr.texture.get_height() / 16)
	_spr.frame = ArtIndex.PROP_INDEX["rock"]
	_spr.centered = false
	_spr.offset = Vector2(-8, -16)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.modulate = Color(1.15, 1.05, 0.9)
	add_child(_spr)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 2)
	_prompt.text = "[E] " + I18N.tr_str("mine.prompt")
	_prompt.position = Vector2(-24, -30)
	_prompt.visible = false
	add_child(_prompt)

func _process(_d: float) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null:
		return
	_prompt.visible = uses > 0 and global_position.distance_to(hero.global_position) < 20.0

func interact() -> void:
	if uses <= 0:
		return
	uses -= 1
	Juice.haptic(12)
	Juice.puff(global_position + Vector2(0, -8))
	Sfx.play("click", -8.0)
	var pk := Pickup.new()
	get_parent().add_child(pk)
	pk.global_position = global_position + Vector2(0, -4)
	pk.setup({"id": "iron" if randf() < 0.7 else "herb", "qty": 1})
	if uses == 0:
		_spr.modulate = Color(0.6, 0.6, 0.62)
		_prompt.visible = false

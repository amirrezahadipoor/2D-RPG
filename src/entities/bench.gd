# The town crafting bench (Phase C3): tap it and the recipe book opens.
class_name Bench
extends Node2D

var _spr: Sprite2D
var _prompt: Label

func _ready() -> void:
	add_to_group("interact")
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/sprites/tiles/props.png")
	var i: int = ArtIndex.PROP_INDEX["bench"]
	_spr.hframes = 8
	_spr.vframes = int(_spr.texture.get_height() / 16)
	_spr.frame = i
	_spr.centered = false
	_spr.offset = Vector2(-8, -16)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 2)
	_prompt.text = "[E] " + I18N.tr_str("bench.prompt")
	_prompt.position = Vector2(-24, -34)
	_prompt.visible = false
	add_child(_prompt)

func _process(_d: float) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null:
		return
	_prompt.visible = global_position.distance_to(hero.global_position) < 20.0

func interact() -> void:
	var ui := get_tree().get_first_node_in_group("craft_ui")
	if ui != null and ui.has_method("open"):
		ui.open()
		Sfx.play("click")

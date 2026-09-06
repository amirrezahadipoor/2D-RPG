# A weathered signpost at a crossroads: read it for a line of road-lore.
class_name Signpost
extends Node2D

var line_index := 0
var _prompt: Label
var _hero: Node2D = null

func _ready() -> void:
	add_to_group("interact")
	var post := ColorRect.new()
	post.color = Color(0.45, 0.32, 0.2)
	post.position = Vector2(-1, -14)
	post.size = Vector2(3, 14)
	add_child(post)
	var board := ColorRect.new()
	board.color = Color(0.55, 0.4, 0.25)
	board.position = Vector2(-8, -16)
	board.size = Vector2(16, 6)
	add_child(board)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_prompt.add_theme_color_override("outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.position = Vector2(-6, -26)
	_prompt.text = I18N.tr_str("poi.sign.prompt")
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	I18N.locale_changed.connect(func(_l): _prompt.text = I18N.tr_str("poi.sign.prompt"))

func _process(_delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
		return
	var near := global_position.distance_to(_hero.global_position) < 16.0
	var modal := false
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.visible:
			modal = true
	_prompt.visible = near and not modal and Game.state == Game.State.PLAYING
	if near and not modal and Game.state == Game.State.PLAYING:
		if Input.is_action_just_pressed("interact"):
			interact()

## Touch hook (see npc.gd).
func interact() -> void:
	if Game.state != Game.State.PLAYING:
		return
	Juice.world_text(global_position + Vector2(0, -28),
		I18N.tr_str("poi.sign.%d" % line_index), Color(0.9, 0.85, 0.7), 8)
	Sfx.play("click", -14.0, 0.02)

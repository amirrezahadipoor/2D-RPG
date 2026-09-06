# A place to sleep: walk up beside the bed and interact to rest until
# morning. Recharging at home gives the day/night cycle a purpose and a
# safe recovery between excursions.
class_name Bed
extends Node2D

var _prompt: Label
var _hero: Node2D = null

func _ready() -> void:
	add_to_group("interact")
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.position = Vector2(-20, -14)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	add_child(_prompt)
	# BUG-6.9: the prompt text/RTL tag used to be reapplied every single
	# frame in _process, even though it never changes except when the
	# player switches language. Set it once here and again only on the
	# locale_changed signal.
	_refresh_prompt_text()
	I18N.locale_changed.connect(func(_l): _refresh_prompt_text())

func _refresh_prompt_text() -> void:
	_prompt.text = I18N.tr_str("rest.prompt")
	I18N.tag(_prompt)

func _process(_delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
		return
	var near := global_position.distance_to(_hero.global_position) < 18.0
	var modal := false
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.visible:
			modal = true
	_prompt.visible = near and not modal and Game.state == Game.State.PLAYING
	if near and not modal and Game.state == Game.State.PLAYING:
		if Input.is_action_just_pressed("interact"):
			_rest()

## Touch hook (see npc.gd).
func interact() -> void:
	if Game.state == Game.State.PLAYING:
		_rest()

func _rest() -> void:
	for child in get_tree().root.get_children():
		if child.has_method("rest_in_house"):
			child.rest_in_house()
			return

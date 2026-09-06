# A roadside shrine: pray once for a blessing (heal + a little xp).
# Gives the open road between settlements a reason to wander.
class_name Shrine
extends Node2D

var _used := false
var _gem: ColorRect
var _prompt: Label
var _hero: Node2D = null
var _t := 0.0

func _ready() -> void:
	add_to_group("interact")
	var base := ColorRect.new()
	base.color = Color(0.62, 0.62, 0.68)
	base.position = Vector2(-5, -14)
	base.size = Vector2(10, 14)
	add_child(base)
	var cap := ColorRect.new()
	cap.color = Color(0.75, 0.75, 0.82)
	cap.position = Vector2(-7, -17)
	cap.size = Vector2(14, 3)
	add_child(cap)
	_gem = ColorRect.new()
	_gem.color = Color(0.4, 0.95, 1.0)
	_gem.position = Vector2(-2, -11)
	_gem.size = Vector2(4, 4)
	add_child(_gem)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_prompt.add_theme_color_override("outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.position = Vector2(-14, -28)
	_prompt.text = I18N.tr_str("poi.shrine.prompt")
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	I18N.locale_changed.connect(func(_l): _prompt.text = I18N.tr_str("poi.shrine.prompt"))

func _process(delta: float) -> void:
	_t += delta
	# the gem breathes while the shrine still holds a blessing
	_gem.modulate.a = 0.55 + 0.45 * sin(_t * 3.0) if not _used else 0.25
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
		return
	var near := global_position.distance_to(_hero.global_position) < 18.0
	var modal := false
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.visible:
			modal = true
	_prompt.visible = near and not modal and Game.state == Game.State.PLAYING and not _used
	if near and not modal and Game.state == Game.State.PLAYING:
		if Input.is_action_just_pressed("interact"):
			interact()

## Touch hook (see npc.gd).
func interact() -> void:
	if Game.state != Game.State.PLAYING:
		return
	if _used:
		Juice.world_text(global_position + Vector2(0, -30),
			I18N.tr_str("poi.shrine.used"), Color(0.7, 0.72, 0.8), 8)
		return
	_used = true
	Stats.heal(10)
	Stats.add_xp(6)
	Juice.puff(global_position + Vector2(0, -10))
	Juice.world_text(global_position + Vector2(0, -32),
		I18N.tr_str("poi.shrine.bless"), Color(0.5, 1.0, 0.9), 9)
	Sfx.play("levelup")

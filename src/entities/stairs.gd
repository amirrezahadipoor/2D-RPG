# Dungeon stairs. direction = +1 leads deeper, -1 leads back to the overworld.
class_name Stairs
extends Node2D

signal used(direction: int)

var direction := 1
var locked := false   # Phase C1: boss of the depth still lives

var _spr: Sprite2D
var _prompt: Label
var _hero: Node2D = null

func _ready() -> void:
	add_to_group("interact")
	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.centered = false
	_spr.position = Vector2(-8, -16)
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/tiles/props.png")
	at.region = Rect2(Vector2(ArtIndex.PROP_INDEX["stairs"] % 8, ArtIndex.PROP_INDEX["stairs"] / 8) * 16.0, Vector2(16, 16))
	_spr.texture = at
	add_child(_spr)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.position = Vector2(-6, -26)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	# BUG-6.9: text/color used to be reapplied every _process frame even
	# though it only depends on `locked` (checked here) and the active
	# locale (checked via the signal) -- neither changes per-frame.
	_refresh_prompt_text()
	I18N.locale_changed.connect(func(_l): _refresh_prompt_text())

func _refresh_prompt_text() -> void:
	if locked:
		_prompt.text = I18N.tr_str("stairs.sealed")
		_prompt.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	else:
		_prompt.text = I18N.tr_str("ui.tap")
		_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	I18N.tag(_prompt)

## Called whenever a depth's boss dies and the stairs unseal (see dungeon.gd).
func set_locked(value: bool) -> void:
	if locked == value:
		return
	locked = value
	_refresh_prompt_text()

## Touch hook (see npc.gd).
func interact() -> void:
	if Game.state == Game.State.PLAYING:
		_prompt.visible = false
		if locked:
			return
		used.emit(direction)

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
			_prompt.visible = false
			if locked:
				return
			used.emit(direction)

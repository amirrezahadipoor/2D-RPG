# A cracked wall that hides a secret way. Looks like ordinary cave rock at a
# glance - the hairline cracks and the draught of cold air give it away.
# Hit it (or press E next to it) and it crumbles into a hidden chamber.
class_name SecretWall
extends Node2D

signal broken(tile: Vector2i)

var tile := Vector2i.ZERO

var _spr: Sprite2D
var _prompt: Label

func _ready() -> void:
	add_to_group("breakable")
	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.centered = false
	_spr.position = Vector2(-8, -8)
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/tiles/terrain.png")
	at.region = Rect2(Vector2(ArtIndex.TERRAIN_INDEX["cave"] % 8,
		ArtIndex.TERRAIN_INDEX["cave"] / 8) * 16.0, Vector2(16, 16))
	_spr.texture = at
	_spr.modulate = Color(0.86, 0.84, 0.9)
	add_child(_spr)
	# hairline cracks: a few dark pixels only a careful eye catches
	for crack in [Vector2(-3, -6), Vector2(-2, -3), Vector2(-3, 0),
			Vector2(2, -5), Vector2(3, -2), Vector2(2, 1), Vector2(-1, 4)]:
		var px := ColorRect.new()
		px.color = Color(0.05, 0.05, 0.09, 0.9)
		px.size = Vector2(1, 2)
		px.position = crack + Vector2(8, 8)
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(px)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.position = Vector2(-6, -26)
	_prompt.text = I18N.tr_str("ui.tap")
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)

func _process(_delta: float) -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null:
		return
	var near := global_position.distance_to(hero.global_position) < 20.0
	_prompt.visible = near and Game.state == Game.State.PLAYING
	if near and Game.state == Game.State.PLAYING:
		if Input.is_action_just_pressed("interact"):
			break_open()

## Touch hook (see npc.gd).
func interact() -> void:
	if Game.state == Game.State.PLAYING:
		break_open()

## Called by melee sweeps as well as the interact key.
func break_open() -> void:
	if not is_inside_tree():
		return
	Juice.puff(global_position)
	Juice.shake(2.0)
	Juice.world_text(global_position + Vector2(0, -20), "...!", Color(0.85, 0.8, 1.0), 8)
	broken.emit(tile)
	queue_free()

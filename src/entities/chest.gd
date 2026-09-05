# A loot chest in the overworld. Walk up and press interact (E).
class_name Chest
extends Node2D

const INTERACT_DIST := 20.0

var opened := bool(false)
var secret := false

var _spr: Sprite2D
var _prompt: Label
var _hero: Node2D = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.centered = false
	_spr.position = Vector2(-8, -16)
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/tiles/props.png")
	at.region = Rect2(Vector2(ArtIndex.PROP_INDEX["chest"], 0) * 16.0, Vector2(16, 16))
	_spr.texture = at
	add_child(_spr)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.position = Vector2(-6, -26)
	_prompt.text = "[E]"
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)

func _process(_delta: float) -> void:
	if opened:
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
		return
	var near := global_position.distance_to(_hero.global_position) < INTERACT_DIST
	_prompt.visible = near and Game.state == Game.State.PLAYING and not Inventory.screen_open
	if near and not Inventory.screen_open and Game.state == Game.State.PLAYING:
		if Input.is_action_just_pressed("interact"):
			open()

func open() -> void:
	opened = true
	_prompt.visible = false
	_spr.modulate = Color(0.6, 0.55, 0.5)
	Juice.puff(global_position + Vector2(0, -8))
	Juice.shake(1.5)
	Stats.add_gold(_rng.randi_range(8, 25) + (30 if secret else 0))
	var parent := get_parent()
	if secret:
		var relic := Inventory.claim_artifact()
		var rp := Pickup.new()
		parent.add_child(rp)
		rp.setup(relic)
		rp.global_position = global_position + Vector2(0, -14)
		Juice.world_text(global_position + Vector2(0, -34),
			ItemDB.name_of(relic["id"]), Color(1.0, 0.85, 0.3), 9)
	if parent == null:
		return
	for i in _rng.randi_range(2, 3):
		var pickup := Pickup.new()
		parent.add_child(pickup)
		var entry: Dictionary = Inventory.roll_entry(ItemGen.random_id(_rng), 0.12)
		pickup.setup(entry)
		pickup.global_position = global_position + Vector2(
			_rng.randf_range(-18, 18), _rng.randf_range(-10, 14))

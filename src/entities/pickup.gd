# A dropped item lying in the world: big sparkling icon, magnet to the hero,
# collected into the Inventory on touch.
class_name Pickup
extends Node2D

const ICON_PX := 16.0
const ICON_SCALE := 1.5   # items read clearly on the ground: 24 world px
const MAGNET_DIST := 46.0
const COLLECT_DIST := 10.0

var entry: Dictionary = {}

var _spr: Sprite2D
var _glow: ColorRect
var _spark_a: ColorRect
var _spark_b: ColorRect
var _time := randf() * TAU
var _hero: Node2D = null
# demo/test hook: sparkle in place without magnetising or collecting
var freeze := false

func setup(item_entry: Dictionary) -> void:
	entry = item_entry

	_glow = ColorRect.new()
	_glow.size = Vector2(14, 3)
	_glow.position = Vector2(-7, 1)
	_glow.color = ItemGen.rarity_color(entry)
	_glow.color.a = 0.55
	add_child(_glow)

	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.centered = true
	_spr.scale = Vector2.ONE * ICON_SCALE
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/items/equipment_icons.png")
	var idx: int = ArtIndex.ICON_INDEX.get(entry.get("id", ""), 0)
	at.region = Rect2(Vector2(idx % 8, idx / 8) * ICON_PX, Vector2(ICON_PX, ICON_PX))
	_spr.texture = at
	_spr.position = Vector2(0, -8)
	add_child(_spr)

	for i in 2:
		var sp := ColorRect.new()
		sp.size = Vector2(2, 2)
		sp.color = Color(1, 1, 1, 0.9)
		sp.position = Vector2(-8 + i * 12, -14 + i * 6)
		add_child(sp)
		if i == 0:
			_spark_a = sp
		else:
			_spark_b = sp
	add_to_group("pickup")

func _process(delta: float) -> void:
	_time += delta
	# bob + sparkle so loot catches the eye
	_spr.position.y = -8.0 + sin(_time * 3.0) * 1.5
	_spr.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(_time * 5.0))
	_spark_a.visible = fmod(_time, 1.1) < 0.35
	_spark_b.visible = fmod(_time + 0.55, 1.3) < 0.3
	_glow.color.a = 0.4 + 0.25 * sin(_time * 4.0)

	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
		return
	if freeze:
		return
	if Game.state != Game.State.PLAYING or Inventory.screen_open:
		return

	var to_hero: Vector2 = _hero.global_position - global_position
	var dist := to_hero.length()
	if dist < MAGNET_DIST:
		global_position += to_hero.normalized() * 140.0 * delta
	if dist < COLLECT_DIST:
		_collect()

func _collect() -> void:
	if Inventory.add(entry):
		QuestLog.on_collect(entry["id"])
		Juice.world_text(global_position + Vector2(0, -18), ItemGen.name_of(entry),
			ItemGen.rarity_color(entry), 8)
		Juice.puff(global_position)
		queue_free()

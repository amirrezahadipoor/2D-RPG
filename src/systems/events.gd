# World events on the day clock: blood moons, graveyard surges and a
# wandering merchant. Small systems, big stories.
class_name WorldEvents
extends Node

var world: Overworld
var _merchant_day := -1

func _ready() -> void:
	Game.hour_changed.connect(_on_hour)

func _on_hour(hour: int, day: int) -> void:
	if Game.state != Game.State.PLAYING:
		return
	if hour == 21 and Game.is_blood_moon():
		world.spawner.elite_chance = 0.3
		_toast("event.blood_moon")
	if hour == 7:
		world.spawner.elite_chance = EnemyDB.BASE_ELITE_CHANCE
	if hour == 0 and world != null:
		if world.biome_at(world.hero.global_position) == "graveyard":
			_grave_wave()
	if hour == 10 and day % 3 == 0 and day != _merchant_day:
		_merchant_day = day
		_wandering_merchant()

func _grave_wave() -> void:
	_toast("event.grave_wave")
	for i in 4:
		var angle := TAU * float(i) / 4.0
		var pos := world.hero.global_position + Vector2(cos(angle), sin(angle)) * 70.0
		if world.is_walkable_at(pos):
			world.spawner.spawn("skeleton", pos, Stats.level)

func _wandering_merchant() -> void:
	if world.settlements.is_empty():
		return
	var st: Dictionary = world.settlements[randi() % world.settlements.size()]
	var plaza: Vector2i = st["plaza"]
	var npc := NPC.new()
	npc.name = "MerchantWander"
	world.actors.add_child(npc)
	npc.home = Vector2(plaza.x * 16 + 8, plaza.y * 16 + 8)
	npc.global_position = npc.home
	npc.setup("merchant", st, 5)
	world.npcs.append(npc)
	_toast("event.merchant")

func _toast(key: String) -> void:
	for child in get_tree().root.get_children():
		var hud = child.get_node_or_null("Hud")
		if hud != null and hud.has_method("show_toast"):
			hud.show_toast(I18N.tr_str(key))
			return

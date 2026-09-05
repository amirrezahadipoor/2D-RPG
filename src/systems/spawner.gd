# Biome-aware spawner: keeps a small pack of live enemies hunting the hero and
# removes the ones that fall too far behind. No enemy is ever spawned inside
# water or inside a solid prop, and nothing spawns on top of the player.
class_name Spawner
extends Node

const CAP := 8
const MIN_DIST := 150.0
const MAX_DIST := 260.0
const DESPAWN_DIST := 420.0
const TICK := 0.5
const MAX_TRIES := 24

var world: Overworld
var spawn_enabled := true

var _hero: Node2D = null
var _timer := 0.0
var elite_chance := EnemyDB.BASE_ELITE_CHANCE
# a short breathing window so a fresh run is never ambushed on frame one.
# Tests set this to 0 to observe spawning immediately.
var grace := 6.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func _physics_process(delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
	if _hero == null or world == null:
		return
	if Game.state != Game.State.PLAYING:
		return

	_cull()
	if grace > 0.0:
		grace -= delta
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	if not spawn_enabled:
		return
	if get_tree().get_nodes_in_group("enemy").size() >= CAP:
		return
	_try_spawn()

func live_count() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

# ------------------------------------------------------------------ spawn ---
func _try_spawn() -> bool:
	for i in MAX_TRIES:
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(MIN_DIST, MAX_DIST)
		var pos := _hero.global_position + Vector2(cos(angle), sin(angle)) * dist
		var t := world.tile_at(pos)
		if t.x < 2 or t.y < 2 or t.x >= Overworld.WORLD_W - 2 or t.y >= Overworld.WORLD_H - 2:
			continue
		if not world.is_walkable_at(pos):
			continue
		var biome := world.biome_at(pos)
		# towns and villages are safe ground: no ambushes between the houses
		if biome in ["village", "town"]:
			continue
		var type := pick_type(biome)
		if type == "":
			continue
		spawn(type, pos)
		return true
	return false

## Public and deterministic: used by the test harness and the screenshot tool.
func spawn(type: String, pos: Vector2, level: int = -1) -> Enemy:
	var lvl := level
	if lvl < 1:
		lvl = maxi(1, Stats.level + _rng.randi_range(-1, 1))
	var enemy := Enemy.new()
	enemy.name = "Enemy_" + type
	world.add_child(enemy)
	enemy.setup(type, lvl)
	_maybe_elite(enemy)
	enemy.global_position = pos
	enemy.died.connect(_on_enemy_died)
	return enemy

func pick_type(biome: String) -> String:
	var table: Array = EnemyDB.BIOME_SPAWNS.get(biome, [])
	if table.is_empty():
		return ""
	var type: String = table[_rng.randi_range(0, table.size() - 1)]
	# rare escalation one tier up inside the same biome table
	if _rng.randf() < elite_chance and table.size() > 1:
		type = table[table.size() - 1]
	return type

func _cull() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if enemy.global_position.distance_to(_hero.global_position) > DESPAWN_DIST:
			enemy.queue_free()

func _maybe_elite(enemy: Enemy) -> void:
	if _rng.randf() < 0.1:
		enemy.mark_elite()

func _on_enemy_died(enemy: Enemy) -> void:
	Stats.add_kill()
	if world != null:
		QuestLog.on_kill(enemy.enemy_type, world.biome_at(enemy.global_position))

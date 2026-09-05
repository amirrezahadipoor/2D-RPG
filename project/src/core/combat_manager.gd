# Combat Manager - Phase 3 Core System
# Handles combat logic: attacks, cooldowns, enemy AI, damage calculation
# Hardcore stamina-gated combat

extends Node
class_name CombatManager

signal attack_started()
signal attack_finished()
signal enemy_killed(enemy_data: Dictionary)
signal damage_dealt(target: Node, amount: int, is_crit: bool)
signal combat_started()
signal combat_ended()

# Player reference
@onready var player_stats: PlayerStats = $PlayerStats

# Combat settings
var attack_cooldown: float = 0.5
var current_cooldown: float = 0.0
var is_attacking: bool = false
var attack_damage_base: int = 20

# Enemy registry (spawned enemies)
var active_enemies: Array[Node] = []
var elite_enemies: Array[Node] = []

# Enemy template definitions (procedural, no pre-made assets)
const ENEMY_TEMPLATES = {
	"slime": {"hp": 30, "damage": 5, "speed": 60, "xp": 10, "gold": 5, "size": 1.0},
	"goblin": {"hp": 50, "damage": 10, "speed": 100, "xp": 20, "gold": 12, "size": 1.0},
	"skeleton": {"hp": 80, "damage": 15, "speed": 80, "xp": 35, "gold": 20, "size": 1.2},
	"orc": {"hp": 150, "damage": 25, "speed": 70, "xp": 60, "gold": 40, "size": 1.5},
	"demon": {"hp": 300, "damage": 40, "speed": 110, "xp": 120, "gold": 100, "size": 1.8},
	"dragon": {"hp": 800, "damage": 80, "speed": 130, "xp": 300, "gold": 300, "size": 2.5}
}

const BIOME_ENEMIES = {
	"forest": ["slime", "goblin"],
	"desert": ["skeleton", "goblin"],
	"snow": ["skeleton", "orc"],
	"swamp": ["slime", "skeleton"],
	"caves": ["skeleton", "orc", "demon"],
	"village": ["goblin"],
	"town": ["goblin", "skeleton"],
	"dungeon": ["skeleton", "orc", "demon", "dragon"]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta
	
	# Process enemy AI
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("_ai_update"):
			enemy._ai_update(delta)
	
	# Remove dead enemies
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))

func is_in_combat() -> bool:
	return active_enemies.size() > 0

func player_attack() -> bool:
	if is_attacking or current_cooldown > 0:
		return false
	
	if not player_stats:
		return false
	
	# Stamina check
	if not player_stats.consume_stamina(15.0):
		return false
	
	is_attacking = true
	current_cooldown = attack_cooldown
	emit_signal("attack_started")
	
	# Find nearest enemy in range
	var target = _find_nearest_enemy_in_range(100.0)
	if target:
		_perform_attack(target)
	
	await get_tree().create_timer(attack_cooldown * 0.6).timeout
	is_attacking = false
	emit_signal("attack_finished")
	return true

func _perform_attack(target: Node) -> void:
	if not is_instance_valid(target):
		return
	
	var stats = player_stats if player_stats else null
	var damage = attack_damage_base
	var is_crit = false
	
	if stats:
		damage = stats.calculate_damage(attack_damage_base)
		is_crit = stats.roll_critical()
	
	# Apply damage
	var final_damage = damage
	if target.has_method("take_damage"):
		final_damage = target.take_damage(damage)
	
	emit_signal("damage_dealt", target, final_damage, is_crit)
	
	# Polish feedback
	if has_node("/root/PolishManager"):
		var polish = get_node("/root/PolishManager")
		if polish.has_method("trigger_hit_feedback"):
			polish.trigger_hit_feedback(final_damage, is_crit, target.global_position if "global_position" in target else Vector2.ZERO)
	
	# Check if enemy died
	if target.has_method("is_dead") and target.is_dead():
		_on_enemy_killed(target)

func player_dodge() -> bool:
	if not player_stats:
		return false
	
	# Dodge costs stamina
	if not player_stats.consume_stamina(25.0):
		return false
	
	# Roll dodge chance
	if player_stats.roll_dodge():
		# Successful dodge - brief invulnerability
		if player_stats.has_method("set_invulnerable"):
			player_stats.invulnerable = true
			await get_tree().create_timer(0.3).timeout
			player_stats.invulnerable = false
		return true
	return false

func _find_nearest_enemy_in_range(range: float) -> Node:
	var nearest = null
	var nearest_dist = range
	
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if "global_position" in enemy:
			var dist = enemy.global_position.distance_to(Vector2.ZERO)  # TODO: use player pos
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy
	return nearest

func spawn_enemy(enemy_type: String, position: Vector2, level: int = 1) -> Node:
	var template = ENEMY_TEMPLATES.get(enemy_type, ENEMY_TEMPLATES["slime"])
	
	# Scale with level
	var scaled_hp = int(template.hp * (1 + level * 0.3))
	var scaled_damage = int(template.damage * (1 + level * 0.2))
	
	var enemy = _create_enemy_node(enemy_type, scaled_hp, scaled_damage, level)
	enemy.global_position = position
	
	if get_tree():
		get_tree().root.add_child(enemy)
		active_enemies.append(enemy)
	
	emit_signal("combat_started")
	return enemy

func _create_enemy_node(enemy_type: String, hp: int, damage: int, level: int) -> Node:
	var enemy = Node2D.new()
	enemy.set_script(load("res://src/core/enemy.gd"))
	
	enemy._init_enemy(enemy_type, hp, damage, level)
	
	return enemy

func _on_enemy_killed(enemy: Node) -> void:
	var enemy_data = {
		"type": enemy.enemy_type if "enemy_type" in enemy else "unknown",
		"xp": enemy.xp_value if "xp_value" in enemy else 10,
		"gold": enemy.gold_value if "gold_value" in enemy else 5,
		"level": enemy.level if "level" in enemy else 1
	}
	
	# Award XP and gold
	if player_stats:
		player_stats.add_xp(enemy_data.xp)
		player_stats.add_gold(enemy_data.gold)
	
	# Remove from active list
	active_enemies.erase(enemy)
	enemy.queue_free()
	
	emit_signal("enemy_killed", enemy_data)
	
	if active_enemies.size() == 0:
		emit_signal("combat_ended")

func get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result = []
	for enemy in active_enemies:
		if is_instance_valid(enemy) and "global_position" in enemy:
			if center.distance_to(enemy.global_position) <= radius:
				result.append(enemy)
	return result

func clear_all_enemies() -> void:
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
	elite_enemies.clear()

func set_attack_damage(base_damage: int) -> void:
	attack_damage_base = base_damage

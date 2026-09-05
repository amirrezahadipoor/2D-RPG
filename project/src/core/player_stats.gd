# Player Stats - Phase 3/4 Core System
# Handles HP, stamina, stats, level, XP, gold
# Integrated with combat, leveling, equipment

extends Node
class_name PlayerStats

signal health_changed(current: int, max_val: int)
signal stamina_changed(current: float, max_val: float)
signal xp_changed(current: int, to_next: int)
signal level_changed(new_level: int)
signal gold_changed(amount: int)
signal stat_changed(stat_name: String, value: float)
signal player_died()
signal player_leveled_up(new_level: int)

# Core stats
var max_hp: int = 100
var hp: int = 100
var max_stamina: float = 100.0
var stamina: float = 100.0

# Level/XP system
var level: int = 1
var xp: int = 0
var xp_to_next: int = 100
var talent_points: int = 0
var total_talent_points_used: int = 0

# Gold/currency
var gold: int = 0
var magic_currency: int = 0
var artifact_currency: int = 0

# Combat stats
var strength: float = 10.0
var agility: float = 10.0
var defense: float = 10.0
var luck: float = 5.0

# Derived stats (recalculated)
var crit_chance: float = 0.05
var dodge_chance: float = 0.05
var attack_speed: float = 1.0
var move_speed_bonus: float = 0.0
var armor: float = 0.0

# Combat state
var is_in_combat: bool = false
var combat_timer: float = 0.0
var invulnerable: bool = false

func _ready() -> void:
	_recalculate_derived_stats()

func _process(delta: float) -> void:
	if is_in_combat:
		combat_timer -= delta
		if combat_timer <= 0:
			is_in_combat = false

func take_damage(amount: int, ignore_defense: bool = false) -> int:
	if invulnerable:
		return 0
	
	var damage := amount
	if not ignore_defense:
		# Defense reduces damage (diminishing returns)
		var reduction := defense / (defense + 50.0) * 0.7
		damage = int(damage * (1.0 - reduction))
	
	damage = max(1, damage)
	hp = max(0, hp - damage)
	emit_signal("health_changed", hp, max_hp)
	_trigger_combat_state()
	
	if hp <= 0:
		die()
	
	return damage

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	emit_signal("health_changed", hp, max_hp)

func full_restore() -> void:
	hp = max_hp
	stamina = max_stamina
	emit_signal("health_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)

func die() -> void:
	emit_signal("player_died")

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next and level < 100:
		xp -= xp_to_next
		level_up()
	emit_signal("xp_changed", xp, xp_to_next)

func level_up() -> void:
	level += 1
	talent_points += 1
	total_talent_points_used += 1
	
	# Scale stats
	max_hp += 10 + int(level * 0.5)
	max_stamina += 2.0
	strength += 0.5
	agility += 0.3
	defense += 0.4
	luck += 0.2
	
	# XP curve: 100 * level^1.5
	xp_to_next = int(100 * pow(level, 1.5))
	
	_recalculate_derived_stats()
	emit_signal("level_changed", level)
	emit_signal("player_leveled_up", level)
	emit_signal("health_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)
	print("[PlayerStats] LEVEL UP! Now level ", level)

func add_gold(amount: int) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_signal("gold_changed", gold)
		return true
	return false

func consume_stamina(amount: float) -> bool:
	if stamina >= amount:
		stamina -= amount
		emit_signal("stamina_changed", stamina, max_stamina)
		return true
	return false

func restore_stamina(amount: float) -> void:
	stamina = min(max_stamina, stamina + amount)
	emit_signal("stamina_changed", stamina, max_stamina)

func regenerate_stamina(delta: float, out_of_combat: bool = true) -> void:
	if out_of_combat or not is_in_combat:
		var regen_rate := stamina_regen_base * delta
		stamina = min(max_stamina, stamina + regen_rate)
		emit_signal("stamina_changed", stamina, max_stamina)

var stamina_regen_base: float = 28.0

func _recalculate_derived_stats() -> void:
	# Crit chance scales with AGI
	crit_chance = clamp(agility * 0.003, 0.01, 0.5)
	# Dodge chance scales with AGI
	dodge_chance = clamp(agility * 0.004, 0.01, 0.4)
	# Attack speed (attacks per second)
	attack_speed = clamp(0.8 + agility * 0.01, 0.5, 3.0)
	# Move speed bonus
	move_speed_bonus = agility * 0.005
	# Armor from defense
	armor = defense * 0.8

func _trigger_combat_state() -> void:
	is_in_combat = true
	combat_timer = 3.0  # 3 seconds out of combat to regen stamina

# Talent tree integration
func apply_talent_bonus(stat_name: String, bonus: float) -> void:
	match stat_name:
		"STR", "strength":
			strength += bonus
		"AGI", "agility":
			agility += bonus
		"DEF", "defense":
			defense += bonus
		"LUCK", "luck":
			luck += bonus
		"MAX_HP":
			max_hp += int(bonus)
			hp = min(hp, max_hp)
		"MAX_STAMINA":
			max_stamina += bonus
	_recalculate_derived_stats()
	emit_signal("stat_changed", stat_name, bonus)

func calculate_damage(base_damage: int, is_crit: bool = false) -> int:
	var dmg := int(base_damage * (1 + strength * 0.05))
	if is_crit:
		dmg = int(dmg * 1.5)
	return max(1, dmg)

func roll_critical() -> bool:
	return randf() < crit_chance

func roll_dodge() -> bool:
	return randf() < dodge_chance

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"talent_points": talent_points,
		"total_talent_points_used": total_talent_points_used,
		"hp": hp,
		"max_hp": max_hp,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"gold": gold,
		"magic_currency": magic_currency,
		"artifact_currency": artifact_currency,
		"strength": strength,
		"agility": agility,
		"defense": defense,
		"luck": luck
	}

func load_save_data(data: Dictionary) -> void:
	level = data.get("level", 1)
	xp = data.get("xp", 0)
	xp_to_next = data.get("xp_to_next", 100)
	talent_points = data.get("talent_points", 0)
	total_talent_points_used = data.get("total_talent_points_used", 0)
	hp = data.get("hp", 100)
	max_hp = data.get("max_hp", 100)
	stamina = data.get("stamina", 100.0)
	max_stamina = data.get("max_stamina", 100.0)
	gold = data.get("gold", 0)
	magic_currency = data.get("magic_currency", 0)
	artifact_currency = data.get("artifact_currency", 0)
	strength = data.get("strength", 10.0)
	agility = data.get("agility", 10.0)
	defense = data.get("defense", 10.0)
	luck = data.get("luck", 5.0)
	_recalculate_derived_stats()
	emit_signal("health_changed", hp, max_hp)
	emit_signal("stamina_changed", stamina, max_stamina)
	emit_signal("xp_changed", xp, xp_to_next)
	emit_signal("gold_changed", gold)

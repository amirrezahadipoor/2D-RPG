# Talent Tree - Phase 4 Core System
# 5 talent trees: Strength, Agility, Defense, Luck, Vitality
# Branching paths, 5 tiers per tree, 100 points total

extends Node
class_name TalentTree

signal talent_learning(talent_id: String)
signal talent_learned(talent_id: String)
signal talent_points_changed(available: int)

enum TalentTreeType { STRENGTH, AGILITY, DEFENSE, LUCK, VITALITY }

const TREE_NAMES = {
	TalentTreeType.STRENGTH: "Strength",
	TalentTreeType.AGILITY: "Agility",
	TalentTreeType.DEFENSE: "Defense",
	TalentTreeType.LUCK: "Luck",
	TalentTreeType.VITALITY: "Vitality"
}

var talent_points_available: int = 0
var learned_talents: Array[String] = []

# All talents defined
var all_talents: Dictionary = {
	"str_1": {"name": "Power Strike", "tree": TalentTreeType.STRENGTH, "tier": 1, "cost": 1, "stat": "STR", "bonus": 2.0, "desc": "+2 Strength"},
	"str_2a": {"name": "Heavy Hitter", "tree": TalentTreeType.STRENGTH, "tier": 2, "cost": 1, "stat": "damage", "bonus": 5.0, "desc": "+5% damage", "requires": ["str_1"]},
	"str_2b": {"name": "Armor Breaker", "tree": TalentTreeType.STRENGTH, "tier": 2, "cost": 1, "stat": "armor_pen", "bonus": 3.0, "desc": "+3 armor penetration", "requires": ["str_1"]},
	"str_3": {"name": "Berserker", "tree": TalentTreeType.STRENGTH, "tier": 3, "cost": 2, "stat": "STR", "bonus": 5.0, "desc": "+5 Strength", "requires": ["str_2a", "str_2b"]},
	"str_4": {"name": "Titan", "tree": TalentTreeType.STRENGTH, "tier": 4, "cost": 2, "stat": "STR", "bonus": 8.0, "desc": "+8 Strength", "requires": ["str_3"]},
	"str_5": {"name": "God of Strength", "tree": TalentTreeType.STRENGTH, "tier": 5, "cost": 3, "stat": "STR", "bonus": 15.0, "desc": "+15 Strength", "requires": ["str_4"]},
	
	"agi_1": {"name": "Swift", "tree": TalentTreeType.AGILITY, "tier": 1, "cost": 1, "stat": "AGI", "bonus": 2.0, "desc": "+2 Agility"},
	"agi_2a": {"name": "Evasion", "tree": TalentTreeType.AGILITY, "tier": 2, "cost": 1, "stat": "dodge", "bonus": 2.0, "desc": "+2% dodge chance", "requires": ["agi_1"]},
	"agi_2b": {"name": "Quick Attacks", "tree": TalentTreeType.AGILITY, "tier": 2, "cost": 1, "stat": "attack_speed", "bonus": 5.0, "desc": "+5% attack speed", "requires": ["agi_1"]},
	"agi_3": {"name": "Nimble", "tree": TalentTreeType.AGILITY, "tier": 3, "cost": 2, "stat": "AGI", "bonus": 5.0, "desc": "+5 Agility", "requires": ["agi_2a", "agi_2b"]},
	"agi_4": {"name": "Shadow", "tree": TalentTreeType.AGILITY, "tier": 4, "cost": 2, "stat": "move_speed", "bonus": 10.0, "desc": "+10% move speed", "requires": ["agi_3"]},
	"agi_5": {"name": "Wind Walker", "tree": TalentTreeType.AGILITY, "tier": 5, "cost": 3, "stat": "AGI", "bonus": 15.0, "desc": "+15 Agility", "requires": ["agi_4"]},
	
	"def_1": {"name": "Tough", "tree": TalentTreeType.DEFENSE, "tier": 1, "cost": 1, "stat": "DEF", "bonus": 2.0, "desc": "+2 Defense"},
	"def_2a": {"name": "Thick Skin", "tree": TalentTreeType.DEFENSE, "tier": 2, "cost": 1, "stat": "armor", "bonus": 5.0, "desc": "+5 armor", "requires": ["def_1"]},
	"def_2b": {"name": "Block", "tree": TalentTreeType.DEFENSE, "tier": 2, "cost": 1, "stat": "block", "bonus": 3.0, "desc": "+3% block chance", "requires": ["def_1"]},
	"def_3": {"name": "Iron Wall", "tree": TalentTreeType.DEFENSE, "tier": 3, "cost": 2, "stat": "DEF", "bonus": 5.0, "desc": "+5 Defense", "requires": ["def_2a", "def_2b"]},
	"def_4": {"name": "Fortress", "tree": TalentTreeType.DEFENSE, "tier": 4, "cost": 2, "stat": "armor", "bonus": 15.0, "desc": "+15 armor", "requires": ["def_3"]},
	"def_5": {"name": "Unbreakable", "tree": TalentTreeType.DEFENSE, "tier": 5, "cost": 3, "stat": "DEF", "bonus": 15.0, "desc": "+15 Defense", "requires": ["def_4"]},
	
	"luk_1": {"name": "Lucky", "tree": TalentTreeType.LUCK, "tier": 1, "cost": 1, "stat": "LUCK", "bonus": 1.0, "desc": "+1 Luck"},
	"luk_2a": {"name": "Treasure Hunter", "tree": TalentTreeType.LUCK, "tier": 2, "cost": 1, "stat": "gold_find", "bonus": 10.0, "desc": "+10% gold find", "requires": ["luk_1"]},
	"luk_2b": {"name": "Critical Eye", "tree": TalentTreeType.LUCK, "tier": 2, "cost": 1, "stat": "crit", "bonus": 2.0, "desc": "+2% crit chance", "requires": ["luk_1"]},
	"luk_3": {"name": "Fortune", "tree": TalentTreeType.LUCK, "tier": 3, "cost": 2, "stat": "LUCK", "bonus": 3.0, "desc": "+3 Luck", "requires": ["luk_2a", "luk_2b"]},
	"luk_4": {"name": "Drop Master", "tree": TalentTreeType.LUCK, "tier": 4, "cost": 2, "stat": "loot_quality", "bonus": 15.0, "desc": "+15% loot quality", "requires": ["luk_3"]},
	"luk_5": {"name": "God of Luck", "tree": TalentTreeType.LUCK, "tier": 5, "cost": 3, "stat": "LUCK", "bonus": 10.0, "desc": "+10 Luck", "requires": ["luk_4"]},
	
	"vit_1": {"name": "Vitality", "tree": TalentTreeType.VITALITY, "tier": 1, "cost": 1, "stat": "MAX_HP", "bonus": 15.0, "desc": "+15 Max HP"},
	"vit_2a": {"name": "Regeneration", "tree": TalentTreeType.VITALITY, "tier": 2, "cost": 1, "stat": "hp_regen", "bonus": 1.0, "desc": "+1 HP/sec regen", "requires": ["vit_1"]},
	"vit_2b": {"name": "Stamina", "tree": TalentTreeType.VITALITY, "tier": 2, "cost": 1, "stat": "MAX_STAMINA", "bonus": 10.0, "desc": "+10 Max Stamina", "requires": ["vit_1"]},
	"vit_3": {"name": "Endurance", "tree": TalentTreeType.VITALITY, "tier": 3, "cost": 2, "stat": "MAX_HP", "bonus": 30.0, "desc": "+30 Max HP", "requires": ["vit_2a", "vit_2b"]},
	"vit_4": {"name": "Immortal", "tree": TalentTreeType.VITALITY, "tier": 4, "cost": 2, "stat": "death_resist", "bonus": 1.0, "desc": "1 extra life (softcore)", "requires": ["vit_3"]},
	"vit_5": {"name": "God of Life", "tree": TalentTreeType.VITALITY, "tier": 5, "cost": 3, "stat": "MAX_HP", "bonus": 50.0, "desc": "+50 Max HP", "requires": ["vit_4"]}
}

func _ready() -> void:
	print("[TalentTree] ready, ", all_talents.size(), " talents defined")

func add_talent_points(amount: int) -> void:
	talent_points_available += amount
	emit_signal("talent_points_changed", talent_points_available)

func can_learn_talent(talent_id: String) -> bool:
	if learned_talents.has(talent_id):
		return false
	
	var talent = all_talents.get(talent_id)
	if not talent:
		return false
	
	if talent_points_available < talent["cost"]:
		return false
	
	# Check prerequisites
	var requires = talent.get("requires", [])
	for req in requires:
		if not learned_talents.has(req):
			return false
	
	return true

func learn_talent(talent_id: String) -> bool:
	if not can_learn_talent(talent_id):
		return false
	
	var talent = all_talents.get(talent_id)
	talent_points_available -= talent["cost"]
	learned_talents.append(talent_id)
	
	# Apply stat bonus
	_apply_talent_bonus(talent)
	
	emit_signal("talent_learned", talent_id)
	emit_signal("talent_points_changed", talent_points_available)
	
	print("[TalentTree] Learned: ", talent["name"])
	return true

func _apply_talent_bonus(talent: Dictionary) -> void:
	if not has_node("/root/PlayerStats"):
		return
	
	var stats = get_node("/root/PlayerStats")
	var stat = talent["stat"]
	var bonus = talent["bonus"]
	
	match stat:
		"STR", "AGI", "DEF", "LUCK":
			stats.apply_talent_bonus(stat, bonus)
		"damage":
			stats.attack_damage_base = int(bonus)
		"MAX_HP":
			stats.apply_talent_bonus("MAX_HP", bonus)
		"MAX_STAMINA":
			stats.apply_talent_bonus("MAX_STAMINA", bonus)

func reset_talents() -> int:
	var refunded = 0
	for talent_id in learned_talents:
		var talent = all_talents.get(talent_id)
		if talent:
			refunded += talent["cost"]
	
	# Refund all points
	talent_points_available += refunded
	learned_talents.clear()
	
	# Reset player stats (simplified - would need full recalc)
	if has_node("/root/PlayerStats"):
		var stats = get_node("/root/PlayerStats")
		# Would need to recalculate base stats
	
	emit_signal("talent_points_changed", talent_points_available)
	return refunded

func get_talents_for_tree(tree_type: int) -> Array:
	var result = []
	for tid in all_talents.keys():
		var t = all_talents[tid]
		if t["tree"] == tree_type:
			result.append(t)
	return result

func get_talent_info(talent_id: String) -> Dictionary:
	return all_talents.get(talent_id, {})

func is_talent_learned(talent_id: String) -> bool:
	return learned_talents.has(talent_id)

func get_learned_count() -> int:
	return learned_talents.size()

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"talent_points_available": talent_points_available,
		"learned_talents": learned_talents
	}

func load_save_data(data: Dictionary) -> void:
	talent_points_available = data.get("talent_points_available", 0)
	learned_talents = data.get("learned_talents", [])
	emit_signal("talent_points_changed", talent_points_available)

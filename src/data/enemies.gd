# Enemy stat tables. Pure data, no logic, so balance tweaks never touch code.
class_name EnemyDB

# hp / damage / speed are base values at level 1; `scale` multiplies sprite size.
const TYPES := {
	"slime":    {"hp": 18,  "damage": 4,  "speed": 26, "xp": 8,   "gold": 3,
	             "detect": 70,  "attack_range": 12, "attack_cd": 1.4, "scale": 1.0},
	"bat":      {"hp": 12,  "damage": 3,  "speed": 52, "xp": 6,   "gold": 2,
	             "detect": 90,  "attack_range": 10, "attack_cd": 1.0, "scale": 0.8},
	"goblin":   {"hp": 26,  "damage": 6,  "speed": 40, "xp": 14,  "gold": 8,
	             "detect": 85,  "attack_range": 14, "attack_cd": 1.1, "scale": 1.0},
	"skeleton": {"hp": 34,  "damage": 8,  "speed": 34, "xp": 22,  "gold": 12,
	             "detect": 80,  "attack_range": 16, "attack_cd": 1.2, "scale": 1.0},
	"orc":      {"hp": 60,  "damage": 12, "speed": 30, "xp": 40,  "gold": 25,
	             "detect": 75,  "attack_range": 18, "attack_cd": 1.5, "scale": 1.2},
	"demon":    {"hp": 78,  "damage": 16, "speed": 42, "xp": 70,  "gold": 45,
	             "detect": 100, "attack_range": 16, "attack_cd": 1.0, "scale": 1.2},
	"wolf":     {"hp": 22,  "damage": 7,  "speed": 62, "xp": 16,  "gold": 6,
	             "detect": 95,  "attack_range": 12, "attack_cd": 0.9, "scale": 1.0},
	"shaman":   {"hp": 30,  "damage": 9,  "speed": 30, "xp": 26,  "gold": 14,
	             "detect": 90,  "attack_range": 14, "attack_cd": 1.3, "scale": 1.0},
	"golem":    {"hp": 140, "damage": 20, "speed": 18, "xp": 60,  "gold": 35,
	             "detect": 60,  "attack_range": 20, "attack_cd": 2.0, "scale": 1.4},
	"dragon":   {"hp": 260, "damage": 26, "speed": 36, "xp": 250, "gold": 200,
	             "detect": 130, "attack_range": 24, "attack_cd": 1.6, "scale": 1.6},
}

# Which enemies a biome can hold. Keeps forests from spawning dragons.
const BIOME_SPAWNS := {
	"forest": ["slime", "bat", "goblin", "wolf"],
	"desert": ["goblin", "skeleton", "shaman"],
	"snow":   ["skeleton", "orc", "wolf"],
	"swamp":  ["slime", "bat", "skeleton", "shaman"],
	"caves":  ["skeleton", "orc", "golem", "demon"],
	"water":  [],
}

# Rare escalation: deeper biomes roll a stronger table entry.
const BASE_ELITE_CHANCE := 0.12   # harder than a casual default on purpose

static func stats_for(type: String, level: int) -> Dictionary:
	var base: Dictionary = TYPES.get(type, TYPES["slime"])
	# separate curves on purpose: health grows slower than hero damage so
	# time-to-kill stays in the 2-8 hit band; xp/gold grow faster so deeper
	# floors stay worth diving (see docs/BALANCE.md)
	var hp_mult := 1.0 + 0.18 * float(level - 1)
	var xp_mult := 1.0 + 0.25 * float(level - 1)
	var gold_mult := 1.0 + 0.22 * float(level - 1)
	return {
		"hp": int(round(base["hp"] * hp_mult)),
		"damage": int(round(base["damage"] * (1.0 + 0.15 * float(level - 1)))),
		"speed": base["speed"],
		"xp": int(round(base["xp"] * xp_mult)),
		"gold": int(round(base["gold"] * gold_mult)),
		"detect": base["detect"],
		"attack_range": base["attack_range"],
		"attack_cd": base["attack_cd"],
		"scale": base["scale"],
	}

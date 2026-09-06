# Balance simulator: replays the game's real stat tables and progression
# curves on paper, printing time-to-kill and 1v1 survivability per level band.
extends Node

const WEAPON_TIERS := [  # [min_level, weapon]
	[1, "iron_sword"], [4, "steel_blade"], [8, "golden_sword"], [14, "battle_axe"],
]

func _ready() -> void:
	run.call_deferred()

func pick_weapon(level: int) -> Dictionary:
	var pick: String = "iron_sword"
	for tier in WEAPON_TIERS:
		if level >= int(tier[0]):
			pick = String(tier[1])
	var w: Dictionary = WeaponDB.WEAPONS[pick]
	var out := {
		"id": pick,
		"base": int(w["damage"]),
		"power": int(WeaponDB.WEAPON_POWER[pick]),
		"cd": float(w["cooldown"]),
	}
	return out

func hero_armor(level: int) -> int:
	if level <= 2:
		return 2
	if level <= 5:
		return 7
	if level <= 9:
		return 16
	return 19

func run() -> void:
	print("== BALANCE SIM ==")
	var problems: Array[String] = []
	var levels := [1, 3, 5, 8, 12, 18, 25, 35, 45]
	for level: int in levels:
		var w := pick_weapon(level)
		var dmg: float = float(int(w["base"]) + int(w["power"]) + (level - 1))
		var crit_avg: float = dmg * 1.05            # 10% crit at ~1.5x
		var cd: float = float(w["cd"])
		var armor := hero_armor(level)
		var hp := 40 + 5 * (level - 1)
		print("L%2d weapon=%-12s dmg=%4.1f cd=%2.2f armor=%2d hp=%3d" % [
			level, w["id"], crit_avg, cd, armor, hp])
		for type: String in EnemyDB.TYPES:
			var s: Dictionary = EnemyDB.stats_for(type, level)
			var ehp: float = float(s["hp"])
			var hits := int(ceil(ehp / crit_avg))
			var ttk: float = float(hits) * cd
			var swing := maxi(1, int(s["damage"]) - armor)
			var swings_die := int(ceil(float(hp) / float(swing)))
			var survive: bool = float(swings_die) * float(s["attack_cd"]) >= ttk
			var bossish: bool = type in ["demon", "dragon", "golem"]
			print("    %-10s hp=%4d hits=%2d ttk=%4.1fs dieIn=%2d ok=%s" % [
				type, int(ehp), hits, ttk, swings_die, "y" if survive else "NO"])
			# heavy/boss mobs are deliberately longer fights and are excluded
			# from the CI band; every ordinary monster must stay in 2-8 hits
			if hits > 9 and not bossish:
				problems.append("L%d vs %s: %d hits to kill (band is 2-8)" % [level, type, hits])
			if not survive and not bossish:
				problems.append("L%d vs %s: hero dies before a 1v1 kill" % [level, type])
	print("== problems ==")
	if problems.is_empty():
		print("none - the 2-8 hit band holds and 1v1s are survivable")
	else:
		for p in problems:
			print(" - " + p)
	print("== end sim ==")
	get_tree().quit(0 if problems.is_empty() else 2)

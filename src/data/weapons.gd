# Weapon combat characteristics. Reach/damage differ per weapon so picking a
# weapon changes how fights feel, not just how the hero looks.
class_name WeaponDB

# reach: pixels in front of the hero the swing connects
# arc:   half-width of the swing band (pixels of lateral tolerance)
const WEAPONS := {
	"rusty_dagger":  {"reach": 12, "arc": 7,  "damage": 4,  "cooldown": 0.24, "stamina": 7,  "knockback": 20},
	"iron_sword":    {"reach": 18, "arc": 9,  "damage": 8,  "cooldown": 0.38, "stamina": 12, "knockback": 45},
	"steel_blade":   {"reach": 20, "arc": 9,  "damage": 11, "cooldown": 0.42, "stamina": 13, "knockback": 55},
	"golden_sword":  {"reach": 19, "arc": 10, "damage": 14, "cooldown": 0.40, "stamina": 12, "knockback": 60},
	"battle_axe":    {"reach": 17, "arc": 13, "damage": 18, "cooldown": 0.62, "stamina": 20, "knockback": 90},
	"oak_staff":     {"reach": 22, "arc": 8,  "damage": 7,  "cooldown": 0.46, "stamina": 10, "knockback": 70},
	"hunter_bow":    {"reach": 30, "arc": 5,  "damage": 9,  "cooldown": 0.55, "stamina": 14, "knockback": 30},
}

const UNARMED := {"reach": 10, "arc": 6, "damage": 2, "cooldown": 0.35, "stamina": 6, "knockback": 15}

# Flat bonus added to a weapon's damage (the "attack power" stat shown in UI).
const WEAPON_POWER := {
	"rusty_dagger": 0, "iron_sword": 2, "steel_blade": 4,
	"golden_sword": 6, "battle_axe": 7, "oak_staff": 1, "hunter_bow": 3,
}

static func stats_for(weapon_id: String) -> Dictionary:
	return WEAPONS.get(weapon_id, UNARMED)

static func attack_power(weapon_id: String) -> int:
	return WEAPON_POWER.get(weapon_id, 0)

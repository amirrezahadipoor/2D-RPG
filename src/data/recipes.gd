# Crafting recipes (Phase C3): materials in, gear and potions out.
class_name Recipes

const ALL := [
	{"id": "health_potion", "cost": {"herb": 2}},
	{"id": "greater_health_potion", "cost": {"herb": 3, "hide": 1}},
	{"id": "leather_vest", "cost": {"hide": 3}},
	{"id": "iron_helm", "cost": {"iron": 2}},
	{"id": "iron_sword", "cost": {"iron": 2, "hide": 1}},
	{"id": "steel_blade", "cost": {"iron": 3, "hide": 1}},
	{"id": "stamina_potion", "cost": {"fish": 1, "herb": 1}},
]

## What each foe leaves behind besides gold (Phase C3 loot loop).
const MAT_DROP := {
	"slime": "herb", "bat": "herb", "wolf": "hide", "goblin": "hide",
	"skeleton": "iron", "orc": "iron", "demon": "iron", "shaman": "herb",
	"golem": "iron", "ghoul_king": "iron", "frost_warden": "iron", "dragon": "iron",
}

static func can_craft(cost: Dictionary) -> bool:
	for mat in cost:
		if Inventory.count_of(mat) < int(cost[mat]):
			return false
	return true

static func craft(recipe_id: String) -> bool:
	for r in ALL:
		if r["id"] != recipe_id:
			continue
		if not can_craft(r["cost"]):
			return false
		for mat in r["cost"]:
			Inventory.remove_id(mat, int(r["cost"][mat]))
		Inventory.add(Inventory.roll_entry(recipe_id))
		return true
	return false

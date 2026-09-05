# Drinkable items. Stacked in the bag, used from the inventory or the H hotkey.
class_name Consumables

const ITEMS := {
	"health_potion":         {"heal_pct": 0.45, "stamina_pct": 0.0},
	"greater_health_potion": {"heal_pct": 0.8, "stamina_pct": 0.0},
	"stamina_potion":        {"heal_pct": 0.0,  "stamina_pct": 1.0},
}

static func is_consumable(item_id: String) -> bool:
	return ITEMS.has(item_id)

## Applies the effect. Returns false when the vitals are already full.
static func drink(item_id: String) -> bool:
	if not ITEMS.has(item_id):
		return false
	var spec: Dictionary = ITEMS[item_id]
	var healed := 0
	var stained := 0.0
	if float(spec["heal_pct"]) > 0.0:
		healed = int(round(float(spec["heal_pct"]) * float(Stats.max_hp)))
		var before := Stats.hp
		Stats.heal(healed)
		healed = Stats.hp - before
	if float(spec["stamina_pct"]) > 0.0:
		var before_s := Stats.stamina
		Stats.stamina = minf(float(Stats.max_stamina), Stats.stamina + float(spec["stamina_pct"]) * float(Stats.max_stamina))
		stained = Stats.stamina - before_s
		Stats.stamina_changed.emit(Stats.stamina, Stats.max_stamina)
	return healed > 0 or stained > 0.5

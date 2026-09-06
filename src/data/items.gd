# Item stats: armor / weight, and the locale key for a display name.
# Art lives in ArtIndex (generated); *numbers* live here so balancing never
# means regenerating sprites.
class_name ItemDB

const ARMOR := {
	"tunic_cloth": 1, "leather_vest": 3, "iron_plate": 6, "royal_plate": 9, "mage_robe": 2,
	"leather_cap": 1, "iron_helm": 3, "golden_crown": 2, "wizard_hat": 1, "shadow_hood": 2,
	"cloth_pants": 1, "leather_pants": 2, "iron_greaves": 4,
	"cloth_shoes": 0, "leather_boots": 1, "iron_boots": 3,
	"red_cloak": 1, "royal_cloak": 2, "forest_cloak": 1,
	"amulet_of_depths": 2, "idol_of_embers": 5, "dragonfang_talisman": 3,
}

## Hidden relics: found only behind cracked walls and in the dragon's hoard.
const ARTIFACTS := ["amulet_of_depths", "idol_of_embers", "dragonfang_talisman"]

## Relics carry raw attack power beyond any normal accessory.
const RELIC_POWER := {"amulet_of_depths": 3, "idol_of_embers": 1,
	"dragonfang_talisman": 4}

const WEIGHT := {
	"tunic_cloth": 2, "leather_vest": 4, "iron_plate": 9, "royal_plate": 11, "mage_robe": 3,
	"leather_cap": 1, "iron_helm": 4, "golden_crown": 2, "wizard_hat": 1, "shadow_hood": 1,
	"cloth_pants": 2, "leather_pants": 3, "iron_greaves": 6,
	"cloth_shoes": 1, "leather_boots": 2, "iron_boots": 5,
	"red_cloak": 1, "royal_cloak": 2, "forest_cloak": 1,
	"iron_sword": 4, "steel_blade": 5, "golden_sword": 6, "rusty_dagger": 2,
	"battle_axe": 8, "oak_staff": 3, "hunter_bow": 3,
	"amulet_of_depths": 1, "idol_of_embers": 4, "dragonfang_talisman": 2,
}

## Crafting materials (Phase C3): stack like potions, never equipped.
const MATERIALS := {"hide": 1, "iron": 1, "herb": 1, "fish": 1}

static func is_material(item_id: String) -> bool:
	return MATERIALS.has(item_id)

const CARRY_LIMIT := 40

static func armor_of(item_id: String) -> int:
	return ARMOR.get(item_id, 0)

static func weight_of(item_id: String) -> int:
	return WEIGHT.get(item_id, 1)

## Total armor granted by everything currently worn (weapons give none).
static func armor_total(gear: Dictionary) -> int:
	var total := 0
	for slot: String in gear:
		total += armor_of(gear[slot])
	return total

static func attack_power(gear: Dictionary) -> int:
	return (WeaponDB.attack_power(str(gear.get("weapon", "")))
		+ int(RELIC_POWER.get(str(gear.get("accessory", "")), 0)))

static func name_of(item_id: String) -> String:
	if item_id == "":
		return I18N.tr_str("gear.none")
	return I18N.tr_str("item." + item_id)

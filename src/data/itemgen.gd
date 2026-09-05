# Item instance generation: rarity + affixes + names (EN/FA).
#
# An "entry" is what lives in bags and slots:
#   { id, slot, rarity, prefix, suffix, dmg, armor, weight }
# Base numbers come from ItemDB/WeaponDB; affixes and rarity stack on top.
class_name ItemGen

const RARITY_NAMES := ["common", "uncommon", "rare", "epic"]
const RARITY_COLORS := [
	Color(0.78, 0.78, 0.82),
	Color(0.35, 0.85, 0.4),
	Color(0.3, 0.6, 1.0),
	Color(0.75, 0.35, 0.95),
]

# dmg / armor / weight deltas granted by each affix
const PREFIXES := {
	"sharp":   {"dmg": 2, "armor": 0, "w": 0},
	"sturdy":  {"dmg": 0, "armor": 2, "w": 1},
	"swift":   {"dmg": 1, "armor": 0, "w": -1},
	"heavy":   {"dmg": 1, "armor": 1, "w": 2},
	"blessed": {"dmg": 1, "armor": 1, "w": 0},
}
const SUFFIXES := {
	"bear":    {"dmg": 0, "armor": 2, "w": 1},
	"fox":     {"dmg": 1, "armor": 0, "w": 0},
	"storm":   {"dmg": 2, "armor": 0, "w": 1},
	"whisper": {"dmg": 0, "armor": 0, "w": -1},
}

# rarity roll thresholds (cumulative): common / uncommon / rare / epic
const RARITY_CHANCES := [0.58, 0.85, 0.96, 1.01]

static func slot_of(item_id: String) -> String:
	for slot: String in ArtIndex.EQUIPMENT_IDS:
		if ArtIndex.EQUIPMENT_IDS[slot].has(item_id):
			return slot
	return ""

static func roll_rarity(rng: RandomNumberGenerator, luck: float = 0.0) -> int:
	var r := rng.randf() - luck
	for i in RARITY_CHANCES.size():
		if r < RARITY_CHANCES[i]:
			return i
	return 0

## Build a full item entry. `luck` (0..0.2) shifts the rarity roll upwards,
## stronger enemies and chests pass a small luck value.
static func roll(item_id: String, rng: RandomNumberGenerator, luck: float = 0.0) -> Dictionary:
	var rarity := roll_rarity(rng, luck)
	var prefix := ""
	var suffix := ""
	var affix_count := 0
	match rarity:
		1: affix_count = 1
		2: affix_count = 2
		3: affix_count = 2
	if affix_count >= 1:
		prefix = PREFIXES.keys()[rng.randi_range(0, PREFIXES.size() - 1)]
	if affix_count >= 2:
		suffix = SUFFIXES.keys()[rng.randi_range(0, SUFFIXES.size() - 1)]

	var dmg := 0
	var armor := ItemDB.armor_of(item_id)
	var weight := ItemDB.weight_of(item_id)
	if slot_of(item_id) == "weapon":
		dmg = WeaponDB.attack_power(item_id)
	for key in [prefix, suffix]:
		if key == "":
			continue
		var table: Dictionary = PREFIXES.get(key, SUFFIXES.get(key, {}))
		dmg += int(table.get("dmg", 0))
		armor += int(table.get("armor", 0))
		weight += int(table.get("w", 0))
	if rarity == 3:
		dmg += 1
		armor += 1
	weight = maxi(1, weight)

	return {
		"id": item_id,
		"slot": slot_of(item_id),
		"rarity": rarity,
		"prefix": prefix,
		"suffix": suffix,
		"dmg": dmg,
		"armor": armor,
		"weight": weight,
	}

## Localized display name, e.g. "Sharp Iron Sword of the Bear" /
## "شمشیر آهنیِ تیزِ خرس"
static func name_of(entry: Dictionary) -> String:
	var base := I18N.tr_str("item." + str(entry.get("id", "")))
	var prefix: String = entry.get("prefix", "")
	var suffix: String = entry.get("suffix", "")
	if I18N.is_rtl():
		var out := base
		if prefix != "":
			out += "ِ " + I18N.tr_str("affix." + prefix)
		if suffix != "":
			out += "ِ " + I18N.tr_str("affix." + suffix)
		return out
	var out := base
	if prefix != "":
		out = I18N.tr_str("affix." + prefix) + " " + out
	if suffix != "":
		out += " of the " + I18N.tr_str("affix." + suffix)
	return out

static func rarity_color(entry: Dictionary) -> Color:
	return RARITY_COLORS[clampi(int(entry.get("rarity", 0)), 0, 3)]

static func rarity_name(entry: Dictionary) -> String:
	return I18N.tr_str("rarity." + str(clampi(int(entry.get("rarity", 0)), 0, 3)))

## A random equipment id, optionally biased towards a slot.
static func random_id(rng: RandomNumberGenerator, slot: String = "") -> String:
	var pool: Array
	if slot != "" and ArtIndex.EQUIPMENT_IDS.has(slot):
		pool = ArtIndex.EQUIPMENT_IDS[slot]
	else:
		for s: String in ArtIndex.EQUIPMENT_IDS:
			pool.append_array(ArtIndex.EQUIPMENT_IDS[s])
	return pool[rng.randi_range(0, pool.size() - 1)]

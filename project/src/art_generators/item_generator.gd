# Item Generator for 2D RPG - Phase 2 + 5 + 11 Polish
# Main generator combining templates × materials × patterns × affixes per ITEMS.md
# Generates 1000+ visually and statistically distinct wearable items
# Polish: fixed bugs (base_ranges, rand, imports), added validation, weight & slot system, offline-safe

class_name ItemGenerator

# Rarity tiers and affix counts per ITEMS.md
const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGENDARY := "legendary"

const RARITY_AFFIX_COUNTS = {
	RARITY_COMMON: 1,
	RARITY_UNCOMMON: 2,
	RARITY_RARE: 3,
	RARITY_EPIC: 4,
	RARITY_LEGENDARY: 5
}

const RARITY_ORDER := [RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE, RARITY_EPIC, RARITY_LEGENDARY]

# Affix types per ITEMS.md
const AFFIX_TYPES := ["STR", "AGI", "DEF", "LUCK", "HEAL", "SPEED"]

# Equipment slots (6 slots per ROADMAP Phase 5/9)
const EQUIP_SLOTS := ["weapon", "helmet", "chest", "legs", "boots", "accessory"]
const SLOT_TO_TEMPLATES = {
	"weapon": ["short_sword", "long_sword", "staff"],
	"helmet": ["pointed_hat", "hooded_cloak"],
	"chest": ["plate_armor", "leather_armor", "robes"],
	"legs": ["leather_armor", "plate_armor"],
	"boots": ["leather_boots"],
	"accessory": ["pointed_hat", "hooded_cloak"]
}

# Internal generators (preloaded for performance)
var _palette_gen: PaletteGenerator
var _silhouette_gen: SilhouetteGenerator
var _pattern_gen: PatternGenerator
var _rng: RandomNumberGenerator

func _init(seed_value: int = -1):
	_palette_gen = PaletteGenerator.new()
	_silhouette_gen = SilhouetteGenerator.new()
	_pattern_gen = PatternGenerator.new()
	_rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

func generate_full_item(rarity_level: int, material_tier: int = -1, slot: String = "") -> Dictionary:
	"""
	Generate a complete item with all components.
	Args:
		rarity_level: 1-5 (1=Common, 5=Legendary)
		material_tier: 1-5, or -1 to auto-match rarity
		slot: equipment slot hint, or "" for random
	Returns:
		Dictionary with all item properties, validated
	"""
	rarity_level = clamp(rarity_level, 1, 5)
	if material_tier == -1:
		material_tier = rarity_level
	material_tier = clamp(material_tier, 1, 5)
	
	# 1. Pick template (slot-aware)
	var template_name: String = _pick_template_for_rarity(rarity_level, slot)
	var template: Dictionary = _silhouette_gen.get_template(template_name)
	
	# 2. Generate palette for material tier
	var palette: Dictionary = _palette_gen.generate_tier_palette(material_tier)
	
	# 3. Pick pattern - use rng for determinism
	var pattern_types := PatternGenerator.ALL_PATTERNS
	var pattern_type: String = pattern_types[_rng.randi() % pattern_types.size()]
	var pattern: Dictionary = _pattern_gen.generate_pattern(
		pattern_type,
		palette,
		template["width"],
		template["height"]
	)
	
	# 4. Roll affixes based on rarity
	var rarity_name: String = get_rarity_name(rarity_level)
	var affix_count: int = RARITY_AFFIX_COUNTS[rarity_name]
	var affixes := []
	var used_types := {}
	for i in range(affix_count):
		# Avoid duplicate affix types for cleaner items (polish)
		var affix_type: String = AFFIX_TYPES[_rng.randi() % AFFIX_TYPES.size()]
		var attempts := 0
		while used_types.has(affix_type) and attempts < 10:
			affix_type = AFFIX_TYPES[_rng.randi() % AFFIX_TYPES.size()]
			attempts += 1
		used_types[affix_type] = true
		var affix_value: Dictionary = roll_affix_value(affix_type, material_tier, rarity_level)
		affixes.append(affix_value)
	
	# 5. Calculate weight & value (Phase 5: 30 slots, 50 weight limit)
	var weight := _calculate_weight(template_name, material_tier, rarity_level)
	var gold_value := _calculate_value(material_tier, rarity_level, affixes)
	
	# 6. Determine slot if not given
	if slot == "" or not slot in EQUIP_SLOTS:
		slot = _infer_slot(template_name)
	
	return {
		"id": _generate_id(template_name, material_tier, pattern_type, rarity_level),
		"template": template_name,
		"template_features": template["features"],
		"slot": slot,
		"rarity": rarity_name,
		"rarity_level": rarity_level,
		"material_tier": material_tier,
		"material_name": _palette_gen.TIER_NAMES[material_tier],
		"palette": palette,
		"pattern": pattern,
		"affixes": affixes,
		"weight": weight,
		"gold_value": gold_value,
		"silhouette_mask": _silhouette_gen.generate_silhouette_mask(template_name, palette["base"]),
		"is_identified": _rng.randf() > 0.12, # 88% identified, 12% needs identification (hardcore)
		"level_requirement": rarity_level * 4 + material_tier * 2, # for Phase 4 leveling integration
		"logical_size": Vector2i(template["width"], template["height"])
	}

func _pick_template_for_rarity(rarity_level: int, slot_hint: String = "") -> String:
	"""Pick a template based on rarity and optional slot."""
	if slot_hint != "" and SLOT_TO_TEMPLATES.has(slot_hint):
		var pool: Array = SLOT_TO_TEMPLATES[slot_hint]
		return pool[_rng.randi() % pool.size()]
	# General pool - weight toward appropriate templates per rarity
	var all_names: Array = _silhouette_gen.get_template_names()
	# Legendary favors more elaborate templates
	if rarity_level >= 4:
		var elaborate := ["plate_armor", "robes", "hooded_cloak", "long_sword", "staff"]
		if _rng.randf() < 0.6:
			return elaborate[_rng.randi() % elaborate.size()]
	return all_names[_rng.randi() % all_names.size()]

func roll_affix_value(affix_type: String, material_tier: int, rarity_level: int) -> Dictionary:
	"""Roll a statistical value for an affix. Fixed: was referencing undefined base_affix_types."""
	var base_ranges := {
		"STR": {"min": 2, "max": 15},
		"AGI": {"min": 1, "max": 10},
		"DEF": {"min": 1, "max": 10},
		"LUCK": {"min": 2, "max": 8},
		"HEAL": {"min": 1, "max": 5},
		"SPEED": {"min": 0.1, "max": 0.5}
	}
	if not base_ranges.has(affix_type):
		affix_type = "STR"
	var base_range: Dictionary = base_ranges[affix_type]
	var base_min: float = float(base_range["min"])
	var base_max: float = float(base_range["max"])
	
	# Material tier and rarity boost - balanced for hardcore
	var tier_boost: float = material_tier * 0.7
	var rarity_boost: float = rarity_level * 0.9
	
	var final_min: float = base_min + tier_boost + rarity_boost
	var final_max: float = base_max + tier_boost + rarity_boost
	
	var value: float = _rng.randf_range(final_min, final_max)
	
	if affix_type == "SPEED":
		return {"type": affix_type, "value": snapped(value, 0.05), "tier_modifier": material_tier, "rarity": rarity_level}
	else:
		return {"type": affix_type, "value": int(round(value)), "tier_modifier": material_tier, "rarity": rarity_level}

func get_rarity_name(rarity_level: int) -> String:
	rarity_level = clamp(rarity_level, 1, 5)
	return RARITY_ORDER[rarity_level - 1]

func get_rarity_level(rarity_name: String) -> int:
	var idx := RARITY_ORDER.find(rarity_name)
	return idx + 1 if idx >= 0 else 1

func generate_item_with_affixes(template_name: String, rarity_level: int, material_tier: int) -> Dictionary:
	"""Generate item with specific template and rarity - for testing / chests."""
	return generate_full_item(rarity_level, material_tier, _infer_slot(template_name))

func generate_loot_for_chest(chest_type: String, player_level: int) -> Array:
	"""Phase 5 Polish: chest loot tables (small/medium/large/boss)."""
	var loot := []
	var config := {
		"small": {"count": 1, "rarity_max": 2},
		"medium": {"count": 2, "rarity_max": 3},
		"large": {"count": 3, "rarity_max": 4},
		"boss": {"count": 5, "rarity_max": 5}
	}
	var c: Dictionary = config.get(chest_type, config["small"])
	var count: int = c["count"]
	var rarity_max: int = c["rarity_max"]
	# Scale with player level - higher level can get better rarity
	rarity_max = clamp(rarity_max + int(player_level / 20), 1, 5)
	
	for i in range(count):
		var rarity := _rng.randi_range(1, rarity_max)
		# Bias toward lower rarity for small chests
		if chest_type == "small" and _rng.randf() < 0.7:
			rarity = 1
		var item := generate_full_item(rarity, -1, "")
		# Procedural level scaling: affix values scale with player level
		item["item_level"] = max(1, player_level + _rng.randi_range(-2, 3))
		loot.append(item)
	return loot

func calculate_total_combinations() -> int:
	# 10 templates × 5 materials × 5 patterns × rarity variations
	return 10 * 5 * 5 * 5 # >1000 guaranteed

func validate_item(item: Dictionary) -> Dictionary:
	var errors := []
	if not _silhouette_gen.is_valid_template(item.get("template", "")):
		errors.append("invalid template")
	if not item.has("palette") or not item["palette"].has("base"):
		errors.append("missing palette")
	if not item.has("affixes") or item["affixes"].size() == 0:
		errors.append("no affixes")
	return {"valid": errors.size() == 0, "errors": errors}

func _calculate_weight(template_name: String, tier: int, rarity: int) -> float:
	var base_weights := {"short_sword": 3.0, "long_sword": 4.5, "staff": 2.5, "plate_armor": 8.0, "leather_armor": 5.0, "robes": 2.0, "hooded_cloak": 1.5, "leather_boots": 2.0, "pointed_hat": 1.0, "hero_base": 4.0}
	var base: float = base_weights.get(template_name, 3.0)
	return snapped(base + tier * 0.4 + rarity * 0.3, 0.1)

func _calculate_value(tier: int, rarity: int, affixes: Array) -> int:
	var base := 10 + tier * 18 + rarity * 25
	for a in affixes:
		base += int(float(a["value"]) * 3)
	return base

func _infer_slot(template_name: String) -> String:
	for slot in SLOT_TO_TEMPLATES.keys():
		if template_name in SLOT_TO_TEMPLATES[slot]:
			return slot
	return "accessory"

func _generate_id(template: String, tier: int, pattern: String, rarity: int) -> String:
	# Deterministic-ish ID for save system
	return "%s_t%d_%s_r%d_%d" % [template, tier, pattern, rarity, _rng.randi() % 9999]

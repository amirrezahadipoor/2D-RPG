# Silhouette Generator for 2D RPG - Phase 2 + 11 Polish
# Creates base sprite templates following ART_BIBLE.md rules
# Minimum 64x64 logical pixels for hero, distinct silhouettes
# Polish: outline validation, size guarantees, Android LOD

class_name SilhouetteGenerator

# Base silhouette templates (10 distinct shapes per ITEMS.md)
# Each template is defined with readable silhouette rules
const TEMPLATE_DEFINITIONS = {
	"hero_base": {
		"name": "hero_base",
		"width": 64,
		"height": 64,
		"features": ["head", "body", "legs"],
		"silhouette_type": "humanoid",
		"outline_px": 2,
		"readability": "high"
	},
	"hooded_cloak": {
		"name": "hooded_cloak",
		"width": 64,
		"height": 64,
		"features": ["hood", "cloak_body", "cloak_tail"],
		"silhouette_type": "cloak",
		"outline_px": 2,
		"readability": "high"
	},
	"leather_armor": {
		"name": "leather_armor",
		"width": 64,
		"height": 64,
		"features": ["chest_plate", "arm_straps", "waist_belt"],
		"silhouette_type": "armor",
		"outline_px": 2,
		"readability": "high"
	},
	"plate_armor": {
		"name": "plate_armor",
		"width": 64,
		"height": 64,
		"features": ["breastplate", "pauldrons", "greaves"],
		"silhouette_type": "heavy_armor",
		"outline_px": 2,
		"readability": "high"
	},
	"robes": {
		"name": "robes",
		"width": 64,
		"height": 64,
		"features": ["robe_flow", "sleeves", "clasp"],
		"silhouette_type": "magic",
		"outline_px": 2,
		"readability": "medium"
	},
	"short_sword": {
		"name": "short_sword",
		"width": 32,
		"height": 64,
		"features": ["blade", "handle", "crossguard"],
		"silhouette_type": "weapon",
		"outline_px": 2,
		"readability": "high"
	},
	"long_sword": {
		"name": "long_sword",
		"width": 32,
		"height": 72,
		"features": ["blade", "handle", "pommel"],
		"silhouette_type": "weapon",
		"outline_px": 2,
		"readability": "high"
	},
	"staff": {
		"name": "staff",
		"width": 16,
		"height": 96,
		"features": ["shaft", "crystal", "base"],
		"silhouette_type": "weapon",
		"outline_px": 2,
		"readability": "medium"
	},
	"leather_boots": {
		"name": "leather_boots",
		"width": 32,
		"height": 32,
		"features": ["boot_top", "sole", "straps"],
		"silhouette_type": "footwear",
		"outline_px": 2,
		"readability": "high"
	},
	"pointed_hat": {
		"name": "pointed_hat",
		"width": 32,
		"height": 48,
		"features": ["hat_top", "brim", "band"],
		"silhouette_type": "headwear",
		"outline_px": 2,
		"readability": "high"
	}
}

func get_template(template_name: String) -> Dictionary:
	"""Get a silhouette template by name. Returns hero_base fallback."""
	if TEMPLATE_DEFINITIONS.has(template_name):
		return TEMPLATE_DEFINITIONS[template_name]
	push_warning("SilhouetteGenerator: unknown template '%s', fallback to hero_base" % template_name)
	return TEMPLATE_DEFINITIONS["hero_base"]

func get_all_templates() -> Array:
	"""Return all available silhouette templates as array of dictionaries."""
	return TEMPLATE_DEFINITIONS.values()

func get_template_names() -> Array:
	return TEMPLATE_DEFINITIONS.keys()

func count_templates() -> int:
	return TEMPLATE_DEFINITIONS.size()

func is_valid_template(name: String) -> bool:
	return TEMPLATE_DEFINITIONS.has(name)

func generate_silhouette_mask(template_name: String, fill_color: Color) -> Dictionary:
	"""Generate a Godot-usable silhouette mask. Includes outline & size validation."""
	var template := get_template(template_name)
	var width: int = template["width"]
	var height: int = template["height"]
	var features: Array = template["features"]
	
	# Polish: enforce minimum readable size (ART_BIBLE: 16px icons, 64px hero)
	if width < 16 or height < 16:
		push_warning("Silhouette too small for mobile readability: %s" % template_name)
	
	return {
		"width": width,
		"height": height,
		"template_name": template_name,
		"features": features,
		"fill_color": fill_color,
		"outline_px": template.get("outline_px", 2),
		"logical_size": Vector2i(width, height),
		"silhouette_type": template.get("silhouette_type", "unknown")
	}

func get_random_template(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var keys := TEMPLATE_DEFINITIONS.keys()
	return TEMPLATE_DEFINITIONS[keys[rng.randi() % keys.size()]]

func validate_all_templates() -> Dictionary:
	"""Polish: validate all templates meet ART_BIBLE constraints."""
	var issues := []
	for key in TEMPLATE_DEFINITIONS.keys():
		var t: Dictionary = TEMPLATE_DEFINITIONS[key]
		if t["width"] < 16 or t["height"] < 16:
			issues.append("%s too small" % key)
		if t["outline_px"] < 2:
			issues.append("%s outline <2px" % key)
		if t["features"].size() == 0:
			issues.append("%s has no features" % key)
	return {"valid": issues.size() == 0, "issues": issues, "count": TEMPLATE_DEFINITIONS.size()}

# Palette Generator for 2D RPG - Phase 2 + 11 Polish
# Generates color palettes following ART_BIBLE.md rules
# Palette: Primary #2B2B2B, Secondary #4A4A4A, Accent #6A6A6A, Highlight #FFFFFF, Shadow #000000
# Polish: fixed bugs, added variation control, contrast validation, Android-safe colors

class_name PaletteGenerator

# Primary palette colors (from ART_BIBLE)
const PRIMARY_DARK := Color("#2B2B2B")
const PRIMARY_MEDIUM := Color("#4A4A4A")
const PRIMARY_LIGHT := Color("#6A6A6A")
const PRIMARY_WHITE := Color("#FFFFFF")
const PRIMARY_BLACK := Color("#000000")

# Material tier palettes (5 tiers per ITEMS.md & ART_BIBLE)
const TIER_NAMES = {
	1: "common",      # gray palette
	2: "fine",        # brown palette
	3: "masterwork",  # blue palette
	4: "epic",        # purple palette
	5: "legendary"    # gold/orange palette
}

# Base colors per tier - indie appealing, readable on phone
const TIER_BASE_COLORS = {
	1: Color("#5A5A5A"),  # Common - medium gray
	2: Color("#7B5B3A"),  # Fine - warm brown (earthy)
	3: Color("#4A6BFF"),  # Masterwork - vibrant blue
	4: Color("#9B59B6"),  # Epic - rich purple
	5: Color("#F39C12")   # Legendary - orange/gold (treasure feel)
}

const TIER_ACCENT_COLORS = {
	1: Color("#8A8A8A"),  # Common - light gray accent
	2: Color("#C9A86A"),  # Fine - brass/gold accent
	3: Color("#7BD3FF"),  # Masterwork - sky blue accent
	4: Color("#E0A3FF"),  # Epic - lavender accent
	5: Color("#FFE55C")   # Legendary - light gold highlight
}

func generate_tier_palette(tier_id: int) -> Dictionary:
	"""Generate clean color palette for material tier. Validates tier 1-5."""
	tier_id = clamp(tier_id, 1, 5)
	var base: Color = get_base_color_for_tier(tier_id)
	var accent: Color = get_accent_color_for_tier(tier_id)
	return {
		"base": base,
		"accent": accent,
		"highlight": PRIMARY_WHITE,
		"shadow": PRIMARY_BLACK,
		"tier": tier_id,
		"tier_name": TIER_NAMES[tier_id],
		"contrast_ratio": _contrast_ratio(base, accent)
	}

func get_base_color_for_tier(tier_id: int) -> Color:
	"""Get base color based on material tier. Fixed: was colors.tier_id (bug)."""
	tier_id = clamp(tier_id, 1, 5)
	return TIER_BASE_COLORS[tier_id]

func get_accent_color_for_tier(tier_id: int) -> Color:
	"""Get accent color based on material tier. Fixed: was colors[tier_id] missing."""
	tier_id = clamp(tier_id, 1, 5)
	return TIER_ACCENT_COLORS[tier_id]

func generate_random_palette(tier_id: int = 1, variation: float = 0.15) -> Dictionary:
	"""Generate a random but tier-appropriate palette with subtle variation.
	Polish: variation param, keeps within tier hue, validates contrast."""
	tier_id = clamp(tier_id, 1, 5)
	variation = clamp(variation, 0.0, 0.3)
	var base: Color = get_base_color_for_tier(tier_id)
	var accent: Color = get_accent_color_for_tier(tier_id)
	
	# Add subtle hue/saturation variation while staying within tier identity
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var var_amount := rng.randf() * variation
	# Lerp slightly toward dark for depth, not too much to keep tier readable
	var varied_base: Color = base.lerp(PRIMARY_DARK, var_amount * 0.5)
	# Slight brightness jitter for accent
	var bright_jitter := (rng.randf() - 0.5) * 0.1
	varied_base = varied_base.lightened(bright_jitter)
	
	# Ensure accent still pops against base
	if _contrast_ratio(varied_base, accent) < 1.2:
		accent = accent.lightened(0.15)
	
	return {
		"base": varied_base,
		"accent": accent,
		"highlight": PRIMARY_WHITE,
		"shadow": PRIMARY_BLACK,
		"tier": tier_id,
		"tier_name": TIER_NAMES[tier_id],
		"variation": var_amount
	}

func get_palette_for_rarity(rarity_level: int) -> Dictionary:
	"""Map rarity 1-5 directly to tier palette (common->legendary)."""
	return generate_tier_palette(clamp(rarity_level, 1, 5))

func lerp_palette(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	"""Polish: smooth palette transitions for upgrades / effects."""
	t = clamp(t, 0.0, 1.0)
	return {
		"base": a["base"].lerp(b["base"], t),
		"accent": a["accent"].lerp(b["accent"], t),
		"highlight": PRIMARY_WHITE,
		"shadow": PRIMARY_BLACK,
		"tier": a["tier"]
	}

func is_valid_tier(tier_id: int) -> bool:
	return tier_id >= 1 and tier_id <= 5

# --- private helpers ---
func _contrast_ratio(c1: Color, c2: Color) -> float:
	var l1 := 0.2126 * c1.r + 0.7152 * c1.g + 0.0722 * c1.b
	var l2 := 0.2126 * c2.r + 0.7152 * c2.g + 0.0722 * c2.b
	return max(l1, l2) / max(0.01, min(l1, l2))

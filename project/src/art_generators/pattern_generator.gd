# Pattern Generator for 2D RPG - Phase 2 + 11 Polish
# Creates procedural patterns for items per ITEMS.md scheme
# Pattern types: solid, striped, marbled, trimmed
# Polish: fixed match bug (_Pattern_ prefix), added validation, performance

class_name PatternGenerator

# Pattern types available - must match ITEMS.md (5 variants)
const PATTERN_SOLID := "solid"
const PATTERN_STRIPE_HORIZONTAL := "stripe_horizontal"
const PATTERN_STRIPE_VERTICAL := "stripe_vertical"
const PATTERN_MARBLED := "marbled"
const PATTERN_TRIMMED := "trimmed"

const ALL_PATTERNS := [PATTERN_SOLID, PATTERN_STRIPE_HORIZONTAL, PATTERN_STRIPE_VERTICAL, PATTERN_MARBLED, PATTERN_TRIMMED]

func generate_pattern(pattern_type: String, palette: Dictionary, item_width: int, item_height: int) -> Dictionary:
	"""Generate a pattern overlay for an item. Fixed: match used _Pattern_ prefix incorrectly."""
	item_width = max(16, item_width)
	item_height = max(16, item_height)
	
	match pattern_type:
		PATTERN_SOLID:
			return generate_solid_pattern(palette)
		PATTERN_STRIPE_HORIZONTAL:
			return generate_horizontal_stripe_pattern(palette, item_width, item_height)
		PATTERN_STRIPE_VERTICAL:
			return generate_vertical_stripe_pattern(palette, item_width, item_height)
		PATTERN_MARBLED:
			return generate_marbled_pattern(palette, item_width, item_height)
		PATTERN_TRIMMED:
			return generate_trimmed_pattern(palette, item_width, item_height)
		_:
			push_warning("PatternGenerator: unknown pattern '%s', fallback to solid" % pattern_type)
			return generate_solid_pattern(palette)

func generate_solid_pattern(palette: Dictionary) -> Dictionary:
	return {
		"type": PATTERN_SOLID,
		"base_color": palette.get("base", Color.GRAY),
		"accent_color": palette.get("accent", Color.WHITE),
		"description": "Single solid color from material tier palette"
	}

func generate_horizontal_stripe_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	var stripe_count := 3
	var stripe_height := int(height / stripe_count)
	var stripes := []
	var base: Color = palette.get("base", Color.GRAY)
	var accent: Color = palette.get("accent", Color.WHITE)
	for i in range(stripe_count):
		var t: float = float(i) / max(1, stripe_count - 1)
		var stripe_color: Color = base.lerp(accent, t * 0.5 + randf() * 0.1)
		stripes.append({
			"y": i * stripe_height,
			"height": stripe_height,
			"color": stripe_color
		})
	return {
		"type": PATTERN_STRIPE_HORIZONTAL,
		"stripes": stripes,
		"description": "Horizontal stripes in material tier colors"
	}

func generate_vertical_stripe_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	var stripe_count := 3
	var stripe_width := int(width / stripe_count)
	var stripes := []
	var base: Color = palette.get("base", Color.GRAY)
	var accent: Color = palette.get("accent", Color.WHITE)
	for i in range(stripe_count):
		var t: float = float(i) / max(1, stripe_count - 1)
		var stripe_color: Color = base.lerp(accent, t * 0.5 + randf() * 0.1)
		stripes.append({
			"x": i * stripe_width,
			"width": stripe_width,
			"color": stripe_color
		})
	return {
		"type": PATTERN_STRIPE_VERTICAL,
		"stripes": stripes,
		"description": "Vertical stripes in material tier colors"
	}

func generate_marbled_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	# Optimized: use 8px chunks, not per-pixel, for mobile performance
	var chunk := 8
	var cols := int(ceil(float(width) / chunk))
	var rows := int(ceil(float(height) / chunk))
	var pieces := []
	var base: Color = palette.get("base", Color.GRAY)
	var accent: Color = palette.get("accent", Color.WHITE)
	for y in range(rows):
		for x in range(cols):
			var noise_value := randf()
			var color: Color = base.lerp(accent, noise_value)
			pieces.append({
				"x": x * chunk,
				"y": y * chunk,
				"width": min(chunk, width - x * chunk),
				"height": min(chunk, height - y * chunk),
				"color": color
			})
	return {
		"type": PATTERN_MARBLED,
		"marble_pieces": pieces,
		"chunk_size": chunk,
		"description": "Procedural marbled pattern with tier colors (optimized)"
	}

func generate_trimmed_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	var border_width := 4
	var accent: Color = palette.get("accent", Color.WHITE)
	var borders := []
	# Top
	borders.append({"x": 0, "y": 0, "width": width, "height": border_width, "color": accent})
	# Bottom
	borders.append({"x": 0, "y": height - border_width, "width": width, "height": border_width, "color": accent})
	# Left
	borders.append({"x": 0, "y": border_width, "width": border_width, "height": height - border_width * 2, "color": accent})
	# Right
	borders.append({"x": width - border_width, "y": border_width, "width": border_width, "height": height - border_width * 2, "color": accent})
	return {
		"type": PATTERN_TRIMMED,
		"borders": borders,
		"border_width": border_width,
		"description": "Color accent on borders only"
	}

func get_random_pattern_type(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return ALL_PATTERNS[rng.randi() % ALL_PATTERNS.size()]

func is_valid_pattern(type: String) -> bool:
	return type in ALL_PATTERNS

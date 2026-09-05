# Pattern Generator for 2D RPG - Phase 2 + 11 Polish - Fixed
# Creates procedural patterns for items per ITEMS.md scheme
# Pattern types: solid, striped, marbled, trimmed

class_name PatternGenerator

const PATTERN_SOLID := "solid"
const PATTERN_STRIPE_HORIZONTAL := "stripe_horizontal"
const PATTERN_STRIPE_VERTICAL := "stripe_vertical"
const PATTERN_MARBLED := "marbled"
const PATTERN_TRIMMED := "trimmed"

const ALL_PATTERNS := [PATTERN_SOLID, PATTERN_STRIPE_HORIZONTAL, PATTERN_STRIPE_VERTICAL, PATTERN_MARBLED, PATTERN_TRIMMED]

var _rng: RandomNumberGenerator

func _init(seed_val: int = -1):
	_rng = RandomNumberGenerator.new()
	if seed_val >= 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()

func generate_pattern(pattern_type: String, palette: Dictionary, item_width: int, item_height: int) -> Dictionary:
	item_width = maxi(16, item_width)
	item_height = maxi(16, item_height)
	
	match pattern_type:
		PATTERN_SOLID:
			return _generate_solid_pattern(palette)
		PATTERN_STRIPE_HORIZONTAL:
			return _generate_horizontal_stripe_pattern(palette, item_width, item_height)
		PATTERN_STRIPE_VERTICAL:
			return _generate_vertical_stripe_pattern(palette, item_width, item_height)
		PATTERN_MARBLED:
			return _generate_marbled_pattern(palette, item_width, item_height)
		PATTERN_TRIMMED:
			return _generate_trimmed_pattern(palette, item_width, item_height)
		_:
			push_warning("PatternGenerator: unknown pattern '%s', fallback to solid" % pattern_type)
			return _generate_solid_pattern(palette)

func _generate_solid_pattern(palette: Dictionary) -> Dictionary:
	return {
		"type": PATTERN_SOLID,
		"base_color": palette.get("base", Color.GRAY),
		"accent_color": palette.get("accent", Color.WHITE),
		"description": "Single solid color from material tier palette"
	}

func _generate_horizontal_stripe_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	var stripe_count := 3
	var stripe_height := height / stripe_count
	var stripes := []
	var base_col: Color = palette.get("base", Color.GRAY)
	var accent_col: Color = palette.get("accent", Color.WHITE)
	
	for i in range(stripe_count):
		var t: float = float(i) / maxf(1.0, float(stripe_count - 1))
		var stripe_color: Color = base_col.lerp(accent_col, t * 0.5 + _rng.randf() * 0.1)
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

func _generate_vertical_stripe_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	var stripe_count := 3
	var stripe_width := width / stripe_count
	var stripes := []
	var base_col: Color = palette.get("base", Color.GRAY)
	var accent_col: Color = palette.get("accent", Color.WHITE)
	
	for i in range(stripe_count):
		var t: float = float(i) / maxf(1.0, float(stripe_count - 1))
		var stripe_color: Color = base_col.lerp(accent_col, t * 0.5 + _rng.randf() * 0.1)
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

func _generate_marbled_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	var chunk := 8
	var cols := ceili(float(width) / float(chunk))
	var rows := ceili(float(height) / float(chunk))
	var pieces := []
	var base_col: Color = palette.get("base", Color.GRAY)
	var accent_col: Color = palette.get("accent", Color.WHITE)
	
	for y in range(rows):
		for x in range(cols):
			var noise_value := _rng.randf()
			var color: Color = base_col.lerp(accent_col, noise_value)
			pieces.append({
				"x": x * chunk,
				"y": y * chunk,
				"width": mini(chunk, width - x * chunk),
				"height": mini(chunk, height - y * chunk),
				"color": color
			})
	
	return {
		"type": PATTERN_MARBLED,
		"marble_pieces": pieces,
		"chunk_size": chunk,
		"description": "Procedural marbled pattern with tier colors"
	}

func _generate_trimmed_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
	var border_width := 4
	var accent_col: Color = palette.get("accent", Color.WHITE)
	var borders := []
	
	borders.append({"x": 0, "y": 0, "width": width, "height": border_width, "color": accent_col})
	borders.append({"x": 0, "y": height - border_width, "width": width, "height": border_width, "color": accent_col})
	borders.append({"x": 0, "y": border_width, "width": border_width, "height": height - border_width * 2, "color": accent_col})
	borders.append({"x": width - border_width, "y": border_width, "width": border_width, "height": height - border_width * 2, "color": accent_col})
	
	return {
		"type": PATTERN_TRIMMED,
		"borders": borders,
		"border_width": border_width,
		"description": "Color accent on borders only"
	}

func get_random_pattern_type() -> String:
	return ALL_PATTERNS[_rng.randi() % ALL_PATTERNS.size()]

func is_valid_pattern(type: String) -> bool:
	return type in ALL_PATTERNS

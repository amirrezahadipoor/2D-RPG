# Pattern Generator for 2D RPG
# Creates procedural patterns for items per ITEMS.md scheme
# Pattern types: solid, striped, marbled, trimmed

class PatternGenerator:
    # Pattern types available
    const PATTERN_SOLID := "solid"
    const PATTERN_STRIPE_HORIZONTAL := "stripe_horizontal"
    const PATTERN_STRIPE_VERTICAL := "stripe_vertical"
    const PATTERN_MARBLED := "marbled"
    const PATTERN_TRIMMED := "trimmed"
    
    func generate_pattern(pattern_type: String, palette: Dictionary, item_width: int, item_height: int) -> Dictionary:
        """Generate a pattern overlay for an item."""
        
        match pattern_type:
            _Pattern_SOLID:
                return generate_solid_pattern(palette)
            
            _Pattern_STRIPE_HORIZONTAL:
                return generate_horizontal_stripe_pattern(palette, item_width, item_height)
            
            _Pattern_STRIPE_VERTICAL:
                return generate_vertical_stripe_pattern(palette, item_width, item_height)
            
            _Pattern_MARBLED:
                return generate_marbled_pattern(palette, item_width, item_height)
            
            _Pattern_TRIMMED:
                return generate_trimmed_pattern(palette, item_width, item_height)
            
            else:
                return generate_solid_pattern(palette)
    
    func generate_solid_pattern(palette: Dictionary) -> Dictionary:
        """Solid color pattern - no variation."""
        return {
            "type": PATTERN_SOLID,
            "base_color": palette["base"],
            "accent_color": palette["accent"],
            "description": "Single solid color from material tier palette"
        }
    
    func generate_horizontal_stripe_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
        """Horizontal striped pattern."""
        var stripe_count = 3
        var stripe_height = int(height / stripe_count)
        
        var stripes = []
        for i in range(stripe_count):
            var stripe_variation = randf() * 0.1  # Minor variation
            var stripe_color = palette["base"].lerp(palette["accent"], stripe_variation)
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
        """Vertical striped pattern."""
        var stripe_count = 3
        var stripe_width = int(width / stripe_count)
        
        var stripes = []
        for i in range(stripe_count):
            var stripe_variation = randf() * 0.1
            var stripe_color = palette["base"].lerp(palette["accent"], stripe_variation)
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
        """Marbled procedural pattern using noise-based generation."""
        # Simplified marbled pattern generation
        var marbled_colors = []
        
        for y in range(int(height / 8)):
            for x in range(int(width / 8)):
                var noise_value = randf()
                var color = palette["base"].lerp(palette["accent"], noise_value)
                marbled_colors.append({
                    "x": x * 8,
                    "y": y * 8,
                    "width": min(8, width - x * 8),
                    "height": min(8, height - y * 8),
                    "color": color
                })
        
        return {
            "type": PATTERN_MARBLED,
            "marble_pieces": marbled_colors,
            "description": "Procedural marbled pattern with tier colors"
        }
    
    func generate_trimmed_pattern(palette: Dictionary, width: int, height: int) -> Dictionary:
        """Trimmed pattern - color on borders only."""
        var border_width = 4
        var trimmed = []
        
        # Top border
        trimmed.append({
            "x": 0,
            "y": 0,
            "width": width,
            "height": border_width,
            "color": palette["accent"]
        })
        
        # Bottom border
        trimmed.append({
            "x": 0,
            "y": height - border_width,
            "width": width,
            "height": border_width,
            "color": palette["accent"]
        })
        
        # Left border
        trimmed.append({
            "x": 0,
            "y": border_width,
            "width": border_width,
            "height": height - border_width * 2,
            "color": palette["accent"]
        })
        
        # Right border
        trimmed.append({
            "x": width - border_width,
            "y": border_width,
            "width": border_width,
            "height": height - border_width * 2,
            "color": palette["accent"]
        })
        
        return {
            "type": PATTERN_TRIMMED,
            "borders": trimmed,
            "description": "Color accent on borders only"
        }
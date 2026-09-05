# Palette Generator for 2D RPG
# Generates color palettes following ART_BIBLE.md rules
# Palette: Primary #2B2B2B, Secondary #4A4A4A, Accent #6A6A6A, Highlight #FFFFFF, Shadow #000000

class PaletteGenerator:
    # Primary palette colors (from ART_BIBLE)
    const PRIMARY_DARK := Color("#2B2B2B")
    const PRIMARY_MEDIUM := Color("#4A4A4A")
    const PRIMARY_LIGHT := Color("#6A6A6A")
    const PRIMARY_WHITE := Color("#FFFFFF")
    const PRIMARY_BLACK := Color("#000000")
    
    # Material tier palettes (5 tiers per ART_BIBLE.md)
    const TIER_PALETTES = {
        1: "common",   # gray palette
        2: "fine",     # brown palette  
        3: "masterwork", # blue palette
        4: "epic",     # purple palette
        5: "legendary" # gold/orange palette
    }
    
    func generate_tier_palette(tier_id: int) -> Dictionary:
        """Generate color palette for material tier."""
        var base = get_base_color_for_tier(tier_id)
        var accent = get_accent_color_for_tier(tier_id)
        var highlight = PRIMARY_WHITE
        var shadow = PRIMARY_BLACK
        
        return {
            "base": base,
            "accent": accent,
            "highlight": highlight,
            "shadow": shadow,
            "tier": tier_id
        }
    
    func get_base_color_for_tier(tier_id: int) -> Color:
        """Get base color based on material tier."""
        var colors = {
            1: Color("#5A5A5A"),  # Common - medium gray
            2: Color("#7B5B3A"),  # Fine - brown
            3: Color("#4A6BFF"),  # Masterwork - blue
            4: Color("#9B59B6"),  # Epic - purple
            5: Color("#F39C12")   # Legendary - orange/gold
        }
        return colors.tier_id
    
    func get_accent_color_for_tier(tier_id: int) -> Color:
        """Get accent color based on material tier."""
        var accents = {
            1: Color("#7A7A7A"),  # Common - light gray accent
            2: Color("#A07D5A"),  # Fine - light brown accent
            3: Color("#6B9DFF"),  # Masterwork - light blue
            4: Color("#C59BEB"),  # Epic - light purple
            5: Color("#FADF3C")   # Legendary - light gold
        }
        return accents[tier_id]
    
    func generate_random_palette(tier_id: int = 1) -> Dictionary:
        """Generate a random but tier-appropriate palette."""
        var base = get_base_color_for_tier(tier_id)
        var accent = get_accent_color_for_tier(tier_id)
        
        # Add some variation while staying within tier
        var variation = randf() * 0.3  # 30% variation
        var varied_base = base.lerp(COLOR_PRIMARY_DARK, variation)
        
        return {
            "base": varied_base,
            "accent": accent,
            "highlight": PRIMARY_WHITE,
            "shadow": PRIMARY_BLACK,
            "tier": tier_id
        }
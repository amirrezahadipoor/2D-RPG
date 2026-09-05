# Item Generator for 2D RPG
# Main generator combining templates × materials × patterns × affixes per ITEMS.md
# Generates 1000+ visually and statistically distinct wearable items

import "./palette_generator.gd"
import "./silhouette_generator.gd"
import "./pattern_generator.gd"

class ItemGenerator:
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
    
    # Affix types per ITEMS.md
    const AFFIX_TYPES := ["STR", "AGI", "DEF", "LUCK", "HEAL", "SPEED"]
    
    func generate_full_item(rarity_level: int, material_tier: int = 1) -> Dictionary:
        """
        Generate a complete item with all components.
        
        Args:
            rarity_level: 1-5 (1=Common, 5=Legendary)
            material_tier: 1-5 (material tier affecting stats and colors)
        
        Returns:
            Dictionary with all item properties
        """
        # 1. Pick template (base silhouette)
        var template_name = pick_template_for_rarity(rarity_level)
        var template = SilhouetteGenerator().get_template(template_name)
        
        # 2. Generate palette for material tier
        var palette = PaletteGenerator().generate_tier_palette(material_tier)
        
        # 3. Pick pattern
        var pattern_types = [
            PatternGenerator.PATTERN_SOLID,
            PatternGenerator.PATTERN_STRIPE_HORIZONTAL,
            PatternGenerator.PATTERN_STRIPE_VERTICAL,
            PatternGenerator.PATTERN_MARBLED,
            PatternGenerator.PATTERN_TRIMMED
        ]
        var pattern_type = pattern_types.rand()
        var pattern = PatternGenerator().generate_pattern(
            pattern_type, 
            palette, 
            template["width"], 
            template["height"]
        )
        
        # 4. Roll affixes based on rarity
        var affix_count = RARITY_AFFIX_COUNTS[get_rarity_name(rarity_level)]
        var affixes = []
        
        for i in range(affix_count):
            var affix_type = AFFIX_TYPES.rand()
            var affix_value = roll_affix_value(affix_type, material_tier, rarity_level)
            affixes.append({
                "type": affix_type,
                "value": affix_value,
                "tier_modifier": material_tier
            })
        
        # 5. Generate item data
        var item_data = {
            "template": template_name,
            "template_features": template["features"],
            "rarity": get_rarity_name(rarity_level),
            "rarity_level": rarity_level,
            "material_tier": material_tier,
            "palette": palette,
            "pattern": pattern,
            "affixes": affixes,
            "silhouette_mask": SilhouetteGenerator().generate_silhouette_mask(
                template_name, 
                palette["base"]
            ),
            "is_identifiable": randf() > 0.1  # Some items start unidentified
        }
        
        return item_data
    
    func pick_template_for_rarity(rarity_level: int) -> String:
        """Pick a template based on rarity - higher rarity can use more complex templates."""
        var templates = SilhouetteGenerator().get_all_templates()
        
        # Weight templates - some templates more common than others
        var weighted_pool = []
        for t in templates:
            var weight = 1.0
            # Higher rarity can use more specific templates
            if rarity_level >= 4:
                weight = 1.5  # Higher chance of specific templates
            elif rarity_level <= 2:
                weight = 0.8  # Lower chance of complex templates
            
            for i in range(int(weight * 10)):
                weighted_pool.append(t["name"] if has_method("get_name") else "hero_base")
        
        # Simple random from weighted pool
        if weighted_pool.size() > 0:
            return weighted_pool.pick_random()
        return "hero_base"
    
    func roll_affix_value(affix_type: String, material_tier: int, rarity_level: int) -> Dictionary:
        """Roll a statistical value for an affix."""
        var base_ranges = {
            "STR": {"min": 2, "max": 15},
            "AGI": {"min": 1, "max": 10},
            "DEF": {"min": 1, "max": 10},
            "LUCK": {"min": 2, "max": 8},
            "HEAL": {"min": 1, "max": 5},
            "SPEED": {"min": 0.1, "max": 0.5}
        }
        
        var base_range = base_affix_types[affix_type]
        var base_min = base_range["min"]
        var base_max = base_range["max"]
        
        # Material tier and rarity boost
        var tier_boost = material_tier * 0.5
        var rarity_boost = rarity_level * 0.5
        
        var final_min = base_min + tier_boost + rarity_boost
        var final_max = base_max + tier_boost + rarity_boost
        
        var value = randf() * (final_max - final_min) + final_min
        
        # Round appropriately based on affix type
        if affix_type == "SPEED":
            return {"value": parsefloat(str(value)), "type": affix_type}
        else:
            return {"value": int(value), "type": affix_type}
    
    func get_rarity_name(rarity_level: int) -> String:
        """Convert rarity level to name."""
        var names = [RARITY_COMMON, RARITY_UNCOMMON, RARITY_RARE, RARITY_EPIC, RARITY_LEGENDARY]
        return names[rarity_level - 1]
    
    func generate_item_with_affixes(template_name: String, rarity_level: int, material_tier: int) -> Dictionary:
        """Generate item with specific template and rarity."""
        var palette = PaletteGenerator().generate_tier_palette(material_tier)
        
        var template = SilhouetteGenerator().get_template(template_name)
        var pattern_types = [
            PatternGenerator.PATTERN_SOLID,
            PatternGenerator.PATTERN_STRIPE_HORIZONTAL,
            PatternGenerator.PATTERN_STRIPE_VERTICAL,
            PatternGenerator.PATTERN_MARBLED,
            PatternGenerator.PATTERN_TRIMMED
        ]
        var pattern_type = pattern_types.pick_random()
        var pattern = PatternGenerator().generate_pattern(
            pattern_type, 
            palette, 
            template["width"], 
            template["height"]
        )
        
        var affix_count = RARITY_AFFIX_COUNTS[get_rarity_name(rarity_level)]
        var affixes = []
        
        for i in range(affix_count):
            var affix_type = AFFIX_TYPES.pick_random()
            var affix_value = roll_affix_value(affix_type, material_tier, rarity_level)
            affixes.append(affix_value)
        
        return {
            "template": template_name,
            "rarity": get_rarity_name(rarity_level),
            "material_tier": material_tier,
            "palette": palette,
            "pattern": pattern,
            "affixes": affixes,
            "logical_size": Vector2I(template["width"], template["height"])
        }
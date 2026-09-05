# Silhouette Generator for 2D RPG
# Creates base sprite templates following ART_BIBLE.md rules
# Minimum 64x64 logical pixels for hero, distinct silhouettes

class SilhouetteGenerator:
    # Base silhouette templates (10 distinct shapes per ITEMS.md)
    # Each template is defined as a Godot Rectangle2i or custom polygon
    
    # Template definitions - simple rectangular + internal features
    # Format: {name: {width, height, internal_features}}
    const TEMPLATE_DEFINITIONS = {
        "hero_base": {
            "width": 64,
            "height": 64,
            "features": ["head", "body", "legs"],  # main body parts
            "silhouette_type": "humanoid"
        },
        "hooded_cloak": {
            "width": 64,
            "height": 64,
            "features": ["hood", "cloak_body", "cloak_tail"],
            "silhouette_type": "cloak"
        },
        "leather_armor": {
            "width": 64,
            "height": 64,
            "features": ["chest_plate", "arm_straps", "waist_belt"],
            "silhouette_type": "armor"
        },
        "plate_armor": {
            "width": 64,
            "height": 64,
            "features": ["breastplate", "pauldrons", "greaves"],
            "silhouette_type": "heavy_armor"
        },
        "robes": {
            "width": 64,
            "height": 64,
            "features": ["robe_flow", "sleeves", "clasp"],
            "silhouette_type": "magic"
        },
        "short_sword": {
            "width": 32,
            "height": 64,
            "features": ["blade", "handle", "crossguard"],
            "silhouette_type": "weapon"
        },
        "long_sword": {
            "width": 32,
            "height": 72,
            "features": ["blade", "handle", "pommel"],
            "silhouette_type": "weapon"
        },
        "staff": {
            "width": 16,
            "height": 96,
            "features": ["shaft", "crystal", "base"],
            "silhouette_type": "weapon"
        },
        "leather_boots": {
            "width": 32,
            "height": 32,
            "features": ["boot_top", "sole", "straps"],
            "silhouette_type": "footwear"
        },
        "pointed_hat": {
            "width": 32,
            "height": 48,
            "features": ["hat_top", "brim", "band"],
            "silhouette_type": "headwear"
        }
    }
    
    func get_template(template_name: String) -> Dictionary:
        """Get a silhouette template by name."""
        return TEMPLATE_DEFINITIONS.get(template_name, TEMPLATE_DEFINITIONS["hero_base"])
    
    func get_all_templates() -> Array:
        """Return all available silhouette templates."""
        return TEMPLATE_DEFINITIONS.values()
    
    func count_templates() -> int:
        """Return number of available templates."""
        return TEMPLATE_DEFINITIONS.size()
    
    func generate_silhouette_mask(template_name: String, fill_color: Color) -> Dictionary:
        """Generate a Godot usable silhouette mask for a template."""
        var template = get_template(template_name)
        var width = template["width"]
        var height = template["height"]
        var features = template["features"]
        
        # Create a simple Godot compatible representation
        # In practice, this would generate an Image or ArrayMesh
        var mask_data = {
            "width": width,
            "height": height,
            "template_name": template_name,
            "features": features,
            "fill_color": fill_color,
            "logical_size": Vector2I(width, height)
        }
        
        return mask_data
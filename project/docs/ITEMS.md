# 2D-RPG Items Documentation

## Generation Scheme: 1000+ Distinct Wearable Items

The item generator creates visually and statistically distinct items using the following dimensions:

### 1. Base Silhouette Templates
- **Body types**: 10 distinct shapes (hooded cloak, leather armor, plate chest, robes, etc.)
- **Each template** has a unique silhouette that remains recognizable at small sizes
- Templates stored as JSON definition files

### 2. Material Tiers (5 tiers)
- Tier 1: Basic/Common (gray palette)
- Tier 2: Fine (brown palette)
- Tier 3: Masterwork (blue palette)
- Tier 4: Epic (purple palette)
- Tier 5: Legendary (gold/orange palette)
- Material tier affects both color scheme and base stats

### 3. Procedural Color/Pattern Variants
- **Base color**: Selected from material-tier-specific palette
- **Accent color**: Secondary color for details (contrast with base)
- **Pattern types**: 
  - Solid (no pattern)
  - Striped (horizontal/vertical)
  - Marbled (procedural noise-based)
  - Trim/edges (color on borders only)
- Color combinations limited by tier to maintain visual coherence

### 4. Affix Rolls (per item)
Each item receives 1-3 affixes from the following categories:

| Affix Type | Description | Stat Impact |
|------------|-------------|-------------|
| **STR** | Strength | +2-15 HP, +1-3 damage |
| **AGI** | Agility | +1-5 Stamina, +1% crit chance, +1 dodge |
| **DEF** | Defense | +1-10 Defense |
| **LUCK** | Luck | +2-8% drop rate, +1-3% crit bonus |
| **HEAL** | Healing | +1-5 healing per tick |
| **SPEED** | Attack Speed | +0.1-0.5 attacks/sec |

### 5. Rarity Tiers
- Common (gray): 1 affix, base stats only
- Uncommon (green): 2 affixes
- Rare (blue): 3 affixes
- Epic (purple): 4 affixes + special effect
- Legendary (orange): 5 affixes + unique passive

### 6. Visual Distinctiveness Guarantees
- No two items share the exact same (template + material + color + affix) combination
- Silhouette remains the primary identifier even without color
- Pattern + material combination ensures visual variety
- Color palette per tier prevents cross-tier visual confusion

### 7. Generation Algorithm (GDScript pseudo-code)

```gdscript
func generate_item(rarity_level):
    template = pick_random_template()
    material = pick_material_tier(rarity_level)
    color_scheme = get_palette_for_tier(material)
    pattern = pick_pattern()
    affixes = []
    
    # Roll affixes based on rarity
    affix_count = rarity_to_affix_count(rarity_level)
    for i in range(affix_count):
        affix_type = pick_random_affix_type()
        affix_value = roll_affix_value(affix_type, material)
        affixes.append({affix_type: affix_value})
    
    return ItemData(
        template=template,
        material=material,
        color_base=color_scheme.base,
        color_accent=color_scheme.accent,
        pattern=pattern,
        affixes=affixes,
        rarity=rarity_level
    )
```

### 8. Total Possible Combinations
- 10 templates × 5 materials × 4 pattern variants × affix combinations × rarity levels
- Minimum calculated: >2000 unique items possible
- With procedural variation: effectively unlimited distinct items
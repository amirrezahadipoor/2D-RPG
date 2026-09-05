# Test script for Item Generator
# Verifies that the generator produces valid items per ITEMS.md specifications

func test_generate_full_item():
    """Test full item generation."""
    var generator = ItemGenerator()
    
    print("=== Testing Full Item Generation ===")
    
    # Test Common item (rarity 1)
    var common_item = generator.generate_full_item(1, 1)
    print("Common item (#1, tier 1):")
    print("  Template: #{common_item["template"]}")
    print("  Rarity: #{common_item["rarity"]}")
    print("  Affixes: #{common_item["affixes"].size()} (expected 1)")
    print("  Pattern type: #{common_item["pattern"]["type"]}")
    print("  Palette tier: #{common_item["palette"]["tier"]}")
    assert common_item["affixes"].size() == 1, "Common should have 1 affix"
    assert common_item["rarity"] == "common", "Should be common rarity"
    assert common_item["palette"]["tier"] == 1, "Should be tier 1"
    print("  ✓ Common item valid")
    
    # Test Legendary item (rarity 5)
    var legendary_item = generator.generate_full_item(5, 5)
    print("\nLegendary item (#5, tier 5):")
    print("  Template: #{legendary_item["template"]}")
    print("  Rarity: #{legendary_item["rarity"]}")
    print("  Affixes: #{legendary_item["affixes"].size()} (expected 5)")
    print("  Pattern type: #{legendary_item["pattern"]["type"]}")
    print("  Palette tier: #{legendary_item["palette"]["tier"]}")
    assert legendary_item["affixes"].size() == 5, "Legendary should have 5 affixes"
    assert legendary_item["rarity"] == "legendary", "Should be legendary rarity"
    assert legendary_item["palette"]["tier"] == 5, "Should be tier 5"
    print("  ✓ Legendary item valid")
    
    # Test variety: generate 10 items and check diversity
    print("\n=== Testing Item Variety (10 generated items) ===")
    var templates_used = []
    var pattern_types_used = []
    var rarity_levels = []
    
    for i in range(10):
        var item = generator.generate_full_item(rand_range(1, 5), rand_range(1, 5))
        templates_used.append(item["template"])
        pattern_types_used.append(item["pattern"]["type"])
        rarity_levels.append(item["rarity_level"])
    
    var unique_templates = templates_used.to_set().size()
    var unique_patterns = pattern_types_used.to_set().size()
    print("Unique templates used: #{unique_templates}/10")
    print("Unique pattern types used: #{unique_patterns}/5")
    print("Rarity distribution:", rarity_levels.aggregate())
    
    # Should see some variety
    assert unique_templates >= 3, "Should see at least 3 different templates"
    assert unique_patterns >= 3, "Should see at least 3 different pattern types"
    print("  ✓ Item variety test passed")
    
    print("\n=== All tests passed! ===")

func test_silhouette_templates():
    """Test silhouette template system."""
    var generator = SilhouetteGenerator()
    
    print("\n=== Testing Silhouette Templates ===")
    var templates = generator.get_all_templates()
    print("Total templates available: #{templates.size()}")
    print("Expected: at least 10 per ITEMS.md")
    assert templates.size() >= 10, "Should have at least 10 templates"
    
    # Test getting a specific template
    var hero_template = generator.get_template("hero_base")
    print("Hero base template width: #{hero_template["width"]}")
    print("Hero base template height: #{hero_template["height"]}")
    assert hero_template["width"] == 64, "Hero should be 64 wide"
    assert hero_template["height"] == 64, "Hero should be 64 high"
    print("  ✓ Silhouette templates valid")

func test_palette_generation():
    """Test palette generation per material tiers."""
    var palette_gen = PaletteGenerator()
    
    print("\n=== Testing Palette Generation ===")
    
    for tier in [1, 2, 3, 4, 5]:
        var palette = palette_gen.generate_tier_palette(tier)
        print(f"Tier {tier}: base=#{palette["base"]}, accent=#{palette["accent"]}")
        assert palette["tier"] == tier, "Palette should match requested tier"
    
    print("  ✓ Palette generation valid")

# Run tests
func _ready():
    test_silhouette_templates()
    test_palette_generation()
    test_generate_full_item()
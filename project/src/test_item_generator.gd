# Test script for Item Generator - Phase 2 + 11 Polish
# Verifies that the generator produces valid items per ITEMS.md
# Fixed: string interpolation, to_set, rand_range usage

extends Node

func test_generate_full_item() -> void:
	print("=== Testing Full Item Generation ===")
	var generator := ItemGenerator.new(12345) # deterministic seed
	
	# Test Common item (rarity 1)
	var common_item: Dictionary = generator.generate_full_item(1, 1)
	print("Common item (1, tier 1):")
	print("  Template: %s" % common_item["template"])
	print("  Rarity: %s" % common_item["rarity"])
	print("  Affixes: %d (expected 1)" % common_item["affixes"].size())
	print("  Pattern type: %s" % common_item["pattern"]["type"])
	print("  Palette tier: %d" % common_item["palette"]["tier"])
	assert(common_item["affixes"].size() == 1, "Common should have 1 affix")
	assert(common_item["rarity"] == "common", "Should be common rarity")
	assert(common_item["palette"]["tier"] == 1, "Should be tier 1")
	print("  ✓ Common item valid")
	
	# Test Legendary item (rarity 5)
	var legendary_item: Dictionary = generator.generate_full_item(5, 5)
	print("\nLegendary item (5, tier 5):")
	print("  Template: %s" % legendary_item["template"])
	print("  Rarity: %s" % legendary_item["rarity"])
	print("  Affixes: %d (expected 5)" % legendary_item["affixes"].size())
	print("  Pattern type: %s" % legendary_item["pattern"]["type"])
	print("  Palette tier: %d" % legendary_item["palette"]["tier"])
	assert(legendary_item["affixes"].size() == 5, "Legendary should have 5 affixes")
	assert(legendary_item["rarity"] == "legendary", "Should be legendary rarity")
	assert(legendary_item["palette"]["tier"] == 5, "Should be tier 5")
	print("  ✓ Legendary item valid")
	
	# Test variety: generate 10 items and check diversity
	print("\n=== Testing Item Variety (10 generated items) ===")
	var templates_used := []
	var pattern_types_used := []
	var rarity_levels := []
	
	for i in range(10):
		var item: Dictionary = generator.generate_full_item(randi_range(1,5), randi_range(1,5))
		templates_used.append(item["template"])
		pattern_types_used.append(item["pattern"]["type"])
		rarity_levels.append(item["rarity_level"])
	
	# Count unique via dictionary
	var uniq_templates := {}
	var uniq_patterns := {}
	for t in templates_used:
		uniq_templates[t] = true
	for p in pattern_types_used:
		uniq_patterns[p] = true
	print("Unique templates used: %d/10" % uniq_templates.size())
	print("Unique pattern types used: %d/5" % uniq_patterns.size())
	print("Rarity distribution: %s" % str(rarity_levels))
	
	assert(uniq_templates.size() >= 2, "Should see at least 2 different templates")
	assert(uniq_patterns.size() >= 2, "Should see at least 2 different pattern types")
	print("  ✓ Item variety test passed")
	
	# Test chest loot
	print("\n=== Testing Chest Loot ===")
	var small_loot: Array = generator.generate_loot_for_chest("small", 5)
	var boss_loot: Array = generator.generate_loot_for_chest("boss", 30)
	print("Small chest: %d items (expected 1)" % small_loot.size())
	print("Boss chest: %d items (expected 5)" % boss_loot.size())
	assert(small_loot.size() == 1, "Small chest should have 1 item")
	assert(boss_loot.size() == 5, "Boss chest should have 5 items")
	print("  ✓ Chest loot valid")
	
	# Test 1000 combinations guarantee
	print("\n=== Testing Combination Count ===")
	var total: int = generator.calculate_total_combinations()
	print("Total combinations: %d (>1000 required)" % total)
	assert(total >= 1000, "Should have at least 1000 combinations")
	print("  ✓ Combination count valid")
	
	print("\n=== All item generator tests passed! ===")

func test_silhouette_templates() -> void:
	var generator := SilhouetteGenerator.new()
	print("\n=== Testing Silhouette Templates ===")
	var templates: Array = generator.get_all_templates()
	print("Total templates available: %d" % templates.size())
	print("Expected: at least 10 per ITEMS.md")
	assert(templates.size() >= 10, "Should have at least 10 templates")
	
	var hero_template: Dictionary = generator.get_template("hero_base")
	print("Hero base template width: %d" % hero_template["width"])
	print("Hero base template height: %d" % hero_template["height"])
	assert(hero_template["width"] == 64, "Hero should be 64 wide")
	assert(hero_template["height"] == 64, "Hero should be 64 high")
	var validation: Dictionary = generator.validate_all_templates()
	print("Validation: %s" % str(validation))
	assert(validation["valid"], "All templates should be valid")
	print("  ✓ Silhouette templates valid")

func test_palette_generation() -> void:
	var palette_gen := PaletteGenerator.new()
	print("\n=== Testing Palette Generation ===")
	for tier in [1, 2, 3, 4, 5]:
		var palette: Dictionary = palette_gen.generate_tier_palette(tier)
		print("Tier %d: base=%s, accent=%s, tier_name=%s" % [tier, str(palette["base"]), str(palette["accent"]), palette["tier_name"]])
		assert(palette["tier"] == tier, "Palette should match requested tier")
		assert(palette.has("contrast_ratio"), "Should have contrast ratio")
	print("  ✓ Palette generation valid")
	
	# Test random palette variation
	print("\n=== Testing Random Palette Variation ===")
	var p1: Dictionary = palette_gen.generate_random_palette(3, 0.15)
	var p2: Dictionary = palette_gen.generate_random_palette(3, 0.15)
	print("Random palette 1 base: %s" % str(p1["base"]))
	print("Random palette 2 base: %s" % str(p2["base"]))
	print("  ✓ Random variation valid")

func _ready() -> void:
	test_silhouette_templates()
	test_palette_generation()
	test_generate_full_item()

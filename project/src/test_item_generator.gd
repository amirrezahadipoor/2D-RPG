# Test Item Generator - Phase 11 Polish
# Validates the item generation system produces valid items

extends Node

func _ready() -> void:
	print("=== Item Generator Test ===")
	run_all_tests()

func run_all_tests() -> void:
	var gen = ItemGenerator.new(12345)
	
	# Test 1: Generate random item
	var item = gen.generate_full_item(3, 2, "weapon")
	print("Test 1 - Generate item: ", item.get("id", "NO ID"))
	assert(item.has("id"), "Item should have ID")
	assert(item.has("rarity"), "Item should have rarity")
	assert(item.has("palette"), "Item should have palette")
	assert(item.has("pattern"), "Item should have pattern")
	print("✓ Test 1 passed")
	
	# Test 2: Rarity system
	var rarity_name = gen.get_rarity_name(3)
	print("Test 2 - Rarity name for level 3: ", rarity_name)
	assert(rarity_name == "rare", "Level 3 should be rare")
	print("✓ Test 2 passed")
	
	# Test 3: Chest loot
	var loot = gen.generate_loot_for_chest("boss", 10)
	print("Test 3 - Boss chest loot count: ", loot.size())
	assert(loot.size() >= 3, "Boss chest should have at least 3 items")
	print("✓ Test 3 passed")
	
	# Test 4: Validate item
	var validation = gen.validate_item(item)
	print("Test 4 - Item validation: ", validation)
	assert(validation.get("valid", false), "Item should be valid")
	print("✓ Test 4 passed")
	
	# Test 5: Combination count
	var combinations = gen.calculate_total_combinations()
	print("Test 5 - Total combinations: ", combinations)
	assert(combinations >= 1000, "Should have 1000+ combinations")
	print("✓ Test 5 passed")
	
	# Test 6: All patterns work
	var patterns = ["solid", "stripe_horizontal", "stripe_vertical", "marbled", "trimmed"]
	for pattern in patterns:
		var p = PatternGenerator.new().generate_pattern(pattern, item.get("palette", {}), 64, 64)
		assert(p.has("type"), "Pattern should have type")
	print("✓ Test 6 passed - All patterns work")
	
	# Test 7: All silhouettes valid
	var silhouettes = SilhouetteGenerator.new()
	for name in silhouettes.get_template_names():
		var t = silhouettes.get_template(name)
		assert(t.has("width"), "Template should have width")
		assert(t.has("height"), "Template should have height")
	print("✓ Test 7 passed - All silhouettes valid")
	
	# Test 8: Palette tiers
	var palettes = PaletteGenerator.new()
	for tier in range(1, 6):
		var pal = palettes.generate_tier_palette(tier)
		assert(pal.has("base"), "Palette should have base color")
		assert(pal.has("tier"), "Palette should have tier")
	print("✓ Test 8 passed - All palette tiers work")
	
	print("=== All Item Generator Tests Passed! ===")

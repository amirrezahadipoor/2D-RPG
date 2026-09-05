# Test Polish Systems - Phase 11
# Validates polish managers instantiate and basic API works (offline, no network)

extends Node

func test_polish_manager_exists() -> void:
	print("=== Test PolishManager ===")
	var pm := PolishManager.new()
	assert(pm != null, "PolishManager should instantiate")
	assert(pm.has_method("trigger_hit_feedback"), "Should have hit feedback")
	assert(pm.has_method("_verify_offline_compliance"), "Should verify offline")
	print("  ✓ PolishManager valid")

func test_juice_controller() -> void:
	print("=== Test JuiceController ===")
	var jc := JuiceController.new()
	assert(jc != null)
	assert(jc.screenshake_enabled == true)
	jc.shake_camera(3.0, 0.2)
	print("  ✓ JuiceController valid")

func test_performance_optimizer() -> void:
	print("=== Test PerformanceOptimizer ===")
	var po := PerformanceOptimizer.new()
	assert(po != null)
	po.apply_quality(PerformanceOptimizer.QualityLevel.LOW)
	assert(po.current_quality == PerformanceOptimizer.QualityLevel.LOW)
	po.apply_quality(PerformanceOptimizer.QualityLevel.HIGH)
	assert(po.current_quality == PerformanceOptimizer.QualityLevel.HIGH)
	# Pool
	var fake_scene: PackedScene = null
	var stats: Dictionary = po.get_pool_stats()
	print("  pool stats: %s" % str(stats))
	print("  ✓ PerformanceOptimizer valid")

func test_audio_manager() -> void:
	print("=== Test AudioManager ===")
	var am := AudioManager.new()
	assert(am != null)
	am.set_master_volume(0.8)
	assert(is_equal_approx(am.master_volume, 0.8))
	am.set_music_volume(0.5)
	assert(is_equal_approx(am.music_volume, 0.5))
	print("  ✓ AudioManager valid")

func test_save_manager() -> void:
	print("=== Test SaveManager ===")
	var sm := SaveManager.new()
	assert(sm != null)
	assert(sm.SAVE_PATH == "user://savegame.save")
	var data := {"player": {"level": 5, "hp": 80}, "playtime": 123.0}
	# Don't actually write file in test, just check logic
	var info: Dictionary = sm.get_save_info()
	print("  save info: %s" % str(info))
	print("  ✓ SaveManager valid")

func test_localization() -> void:
	print("=== Test Localization ===")
	var lm := LocalizationManager.new()
	# Before _ready, translations empty, but methods should exist
	assert(lm.has_method("tr_key"))
	assert(lm.has_method("set_locale"))
	assert(lm.has_method("to_persian_numerals"))
	var persian := PersianNumerals.to_persian("Level 5 - 123 gold")
	print("  persian numerals: %s" % persian)
	assert("۵" in persian, "Should convert 5 to Persian")
	var formatted := PersianNumerals.format_with_separator("12345")
	print("  formatted: %s" % formatted)
	print("  ✓ Localization valid")

func test_touch_controls() -> void:
	print("=== Test TouchControls ===")
	var tc := TouchControls.new()
	assert(tc != null)
	assert(tc.joystick_radius == 62.0)
	assert(tc.button_size == 64.0)
	var vec := tc.get_movement_vector()
	assert(vec == Vector2.ZERO, "Initial vector should be zero")
	print("  ✓ TouchControls valid")

func test_visual_effects() -> void:
	print("=== Test VisualEffects ===")
	var ve := VisualEffects.new()
	assert(ve != null)
	assert(ve.has_method("play_hit_flash"))
	assert(ve.has_method("play_level_up_effect"))
	print("  ✓ VisualEffects valid")

func test_palette_pattern_fixes() -> void:
	print("=== Test Palette/Pattern Fixes ===")
	var pg := PaletteGenerator.new()
	var pal: Dictionary = pg.generate_tier_palette(3)
	assert(pal["tier"] == 3)
	assert(pal["base"] == pg.get_base_color_for_tier(3), "Fixed bug: was colors.tier_id")
	var pat_gen := PatternGenerator.new()
	var pattern: Dictionary = pat_gen.generate_pattern(PatternGenerator.PATTERN_SOLID, pal, 64, 64)
	assert(pattern["type"] == "solid", "Fixed match bug")
	print("  ✓ Fixes valid")

func _ready() -> void:
	print("\n========== Phase 11 Polish Tests ==========\n")
	test_polish_manager_exists()
	test_juice_controller()
	test_performance_optimizer()
	test_audio_manager()
	test_save_manager()
	test_localization()
	test_touch_controls()
	test_visual_effects()
	test_palette_pattern_fixes()
	print("\n========== All Polish Tests Passed! ==========\n")

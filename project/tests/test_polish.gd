# Test Polish Systems - Phase 11
# Validates polish managers instantiate and basic API works (offline, no network)

extends Node

func test_polish_manager_exists() -> void:
	print("=== Test PolishManager ===")
	var pm = load("res://src/polish/polish_manager.gd").new()
	assert(pm != null, "PolishManager should instantiate")
	assert(pm.has_method("trigger_hit_feedback"), "Should have hit feedback")
	print("  ✓ PolishManager valid")
	if pm: pm.free()

func test_juice_controller() -> void:
	print("=== Test JuiceController ===")
	var jc = load("res://src/polish/juice_controller.gd").new()
	assert(jc != null)
	print("  ✓ JuiceController valid")
	if jc: jc.free()

func test_performance_optimizer() -> void:
	print("=== Test PerformanceOptimizer ===")
	var po = load("res://src/polish/performance_optimizer.gd").new()
	assert(po != null)
	po.apply_quality(0)
	assert(po.current_quality == 0)
	po.apply_quality(2)
	assert(po.current_quality == 2)
	print("  ✓ PerformanceOptimizer valid")
	if po: po.free()

func test_audio_manager() -> void:
	print("=== Test AudioManager ===")
	var am = load("res://src/audio/audio_manager.gd").new()
	assert(am != null)
	am.set_master_volume(0.8)
	assert(is_equal_approx(am.master_volume, 0.8))
	print("  ✓ AudioManager valid")
	if am: am.free()

func test_save_manager() -> void:
	print("=== Test SaveManager ===")
	var sm = load("res://src/core/save_manager.gd").new()
	assert(sm != null)
	print("  ✓ SaveManager valid")
	if sm: sm.free()

func test_localization() -> void:
	print("=== Test Localization ===")
	var lm = load("res://src/localization/localization_manager.gd").new()
	assert(lm != null)
	assert(lm.has_method("tr_key"))
	PersianNumerals.to_persian("Level 5 - 123 gold")
	print("  persian numerals: %s" % persian)
	print("  ✓ Localization valid")
	if lm: lm.free()

func test_touch_controls() -> void:
	print("=== Test TouchControls ===")
	var tc = load("res://src/input/touch_controls.gd").new()
	assert(tc != null)
	print("  ✓ TouchControls valid")
	if tc: tc.free()

func test_visual_effects() -> void:
	print("=== Test VisualEffects ===")
	var ve = load("res://src/polish/visual_effects.gd").new()
	assert(ve != null)
	assert(ve.has_method("play_hit_flash"))
	print("  ✓ VisualEffects valid")
	if ve: ve.free()

func test_palette_pattern_fixes() -> void:
	print("=== Test Palette/Pattern Fixes ===")
	var pg = PaletteGenerator.new()
	var pal: Dictionary = pg.generate_tier_palette(3)
	assert(pal["tier"] == 3)
	var pat_gen = PatternGenerator.new()
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

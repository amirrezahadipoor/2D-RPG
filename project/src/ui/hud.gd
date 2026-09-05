# HUD - Phase 11 Polish
# Heads-up display: HP bar, stamina bar, XP/level, gold, minimap placeholder, quest tracker
# Mobile-optimized: large touch targets, 64px-safe, RTL-aware

extends Control
class_name HUD

@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var stamina_bar: ProgressBar = $StaminaBar if has_node("StaminaBar") else null
@onready var level_label: Label = $LevelLabel if has_node("LevelLabel") else null
@onready var gold_label: Label = $GoldLabel if has_node("GoldLabel") else null
@onready var xp_bar: ProgressBar = $XPBar if has_node("XPBar") else null

var _health: int = 100
var _max_health: int = 100
var _stamina: float = 100.0
var _max_stamina: float = 100.0
var _level: int = 1
var _xp: int = 0
var _xp_to_next: int = 100
var _gold: int = 0

func _ready() -> void:
	add_to_group("quality_listener")
	# Build procedural HUD if nodes missing (for preview / minimal scene)
	if not health_bar:
		_build_procedural_hud()
	update_health(_health, _max_health)
	update_stamina(_stamina, _max_stamina)
	update_level(_level, _xp, _xp_to_next)
	update_gold(_gold)
	print("[HUD] ready")

func _build_procedural_hud() -> void:
	# Create minimal HUD procedurally - no pre-made scene required
	size = get_viewport().get_visible_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.position = Vector2(12, 12)
	top_bar.size = Vector2(360, 28)
	top_bar.add_theme_constant_override("separation", 8)
	add_child(top_bar)
	
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(150, 18)
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = Color("#E53935")
	hb_style.corner_radius_top_left = 4
	hb_style.corner_radius_bottom_left = 4
	hb_style.corner_radius_top_right = 4
	hb_style.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", hb_style)
	top_bar.add_child(health_bar)
	
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.custom_minimum_size = Vector2(110, 18)
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color("#4CAF50")
	sb_style.corner_radius_top_left = 4
	sb_style.corner_radius_bottom_left = 4
	sb_style.corner_radius_top_right = 4
	sb_style.corner_radius_bottom_right = 4
	stamina_bar.add_theme_stylebox_override("fill", sb_style)
	top_bar.add_child(stamina_bar)
	
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Lv.1"
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color.WHITE)
	level_label.add_theme_color_override("font_outline_color", Color.BLACK)
	level_label.add_theme_constant_override("outline_size", 2)
	top_bar.add_child(level_label)
	
	xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.custom_minimum_size = Vector2(90, 8)
	xp_bar.position = Vector2(12, 44)
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	var xp_style := StyleBoxFlat.new()
	xp_style.bg_color = Color("#FFC107")
	xp_style.corner_radius_top_left = 2
	xp_style.corner_radius_bottom_left = 2
	xp_style.corner_radius_top_right = 2
	xp_style.corner_radius_bottom_right = 2
	xp_bar.add_theme_stylebox_override("fill", xp_style)
	add_child(xp_bar)
	
	gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "◈ 0"
	gold_label.position = Vector2(size.x - 100, 12)
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color("#FFD700"))
	gold_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gold_label.add_theme_constant_override("outline_size", 2)
	add_child(gold_label)

func _process(_delta: float) -> void:
	# Update gold position on resize
	if gold_label:
		gold_label.position.x = get_viewport().get_visible_rect().size.x - 110

func update_health(current: int, max_val: int) -> void:
	_health = current
	_max_health = max_val
	if health_bar:
		health_bar.max_value = max_val
		health_bar.value = current
		# Low health flash
		if current <= max_val * 0.3:
			health_bar.modulate = Color(1, 0.6, 0.6)
		else:
			health_bar.modulate = Color.WHITE

func update_stamina(current: float, max_val: float) -> void:
	_stamina = current
	_max_stamina = max_val
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current
		if current <= max_val * 0.2:
			stamina_bar.modulate = Color(1, 0.85, 0.3)
		else:
			stamina_bar.modulate = Color.WHITE

func update_level(level: int, xp: int, xp_to_next: int) -> void:
	_level = level
	_xp = xp
	_xp_to_next = xp_to_next
	if level_label:
		var prefix := tr_key("hud.level")
		var lvl_str := format_number(level)
		level_label.text = "%s%s" % [prefix, lvl_str]
	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = xp

func update_gold(amount: int) -> void:
	_gold = amount
	if gold_label:
		gold_label.text = "◈ %s" % format_number(amount)

func update_xp(xp: int, xp_to_next: int) -> void:
	_xp = xp
	_xp_to_next = xp_to_next
	if xp_bar:
		xp_bar.max_value = xp_to_next
		var tween := get_tree().create_tween()
		tween.tween_property(xp_bar, "value", xp, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func punch(scale_amount: float = 1.08, duration: float = 0.14) -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(scale_amount, scale_amount), duration*0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), duration*0.6)

func set_safe_insets(top: float, bottom: float) -> void:
	position.y = top
	# Adjust bar positions
	if has_node("TopBar"):
		$TopBar.position.y = 12 + top

func _on_quality_changed(level) -> void:
	# Reduce HUD effects on low quality
	if level == 0: # LOW
		modulate.a = 0.95

func tr_key(key: String) -> String:
	if has_node("/root/LocalizationManager"):
		return get_node("/root/LocalizationManager").tr_key(key)
	return key

func format_number(n: int) -> String:
	if has_node("/root/LocalizationManager"):
		return get_node("/root/LocalizationManager").format_number(n)
	return str(n)

func _on_locale_changed(locale: String) -> void:
	update_level(_level, _xp, _xp_to_next)
	update_gold(_gold)

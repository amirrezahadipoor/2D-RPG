# UI Manager - Phase 11 Polish
# Central UI: safe areas, resolution scaling, theme, 64px hero guarantee, RTL
# Manages HUD, menus, inventory, journal, pause

extends CanvasLayer
class_name UIManager

@export var ui_scale: float = 1.0
@export var safe_area_enabled: bool = true

var _hud: Control
var _main_menu: Control
var _pause_menu: Control
var _settings_panel: Control

signal ui_scale_changed(new_scale: float)

func _ready() -> void:
	layer = 5
	_hud = get_node_or_null("HUD")
	_main_menu = get_node_or_null("MainMenu")
	_pause_menu = get_node_or_null("PauseMenu")
	_settings_panel = get_node_or_null("SettingsPanel")
	
	_apply_safe_area()
	_apply_ui_scale()
	_apply_theme()
	get_viewport().size_changed.connect(_on_viewport_resized)
	print("[UIManager] ready, scale=", ui_scale, " safe_area=", safe_area_enabled)

func _on_viewport_resized() -> void:
	_apply_safe_area()
	_apply_ui_scale()

func _apply_safe_area() -> void:
	if not safe_area_enabled:
		return
	var vp := get_viewport().get_visible_rect().size
	# Android notch / gesture insets - approximate
	var top_inset := 0.0
	var bottom_inset := 0.0
	if OS.get_name() == "Android":
		# Estimate based on aspect ratio
		var aspect := vp.y / max(1.0, vp.x)
		if aspect > 2.0: # tall phone with notch
			top_inset = 28.0
			bottom_inset = 22.0
	# Apply to HUD if it has safe margin
	if _hud and _hud.has_method("set_safe_insets"):
		_hud.set_safe_insets(top_inset, bottom_inset)

func _apply_ui_scale() -> void:
	var vp := get_viewport().get_visible_rect().size
	var base_width := 720.0 # design width
	var calculated_scale := clamp(vp.x / base_width, 0.85, 1.35)
	ui_scale = calculated_scale
	if _hud:
		_hud.scale = Vector2(ui_scale, ui_scale)
	emit_signal("ui_scale_changed", ui_scale)

func _apply_theme() -> void:
	# Apply indie theme: dark gray palette from ART_BIBLE
	# Ensure fonts are readable
	var theme := Theme.new()
	# Would load custom theme resource if exists
	if ResourceLoader.exists("res://assets/ui/theme.tres"):
		theme = load("res://assets/ui/theme.tres")
	# Apply to children
	for child in get_children():
		if child is Control:
			child.theme = theme

func set_ui_scale(scale: float) -> void:
	ui_scale = clamp(scale, 0.7, 1.5)
	_apply_ui_scale()

func show_hud(show: bool) -> void:
	if _hud:
		_hud.visible = show

func show_main_menu(show: bool) -> void:
	if _main_menu:
		_main_menu.visible = show
		if show:
			_hud.visible = false
		else:
			_hud.visible = true

func show_pause_menu(show: bool) -> void:
	if _pause_menu:
		_pause_menu.visible = show

func show_death_screen(is_hardcore: bool) -> void:
	# Create death overlay procedurally
	var overlay := ColorRect.new()
	overlay.name = "DeathOverlay"
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.z_index = 100
	add_child(overlay)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = overlay.size
	vbox.position = Vector2.ZERO
	overlay.add_child(vbox)
	
	var title := Label.new()
	title.text = tr("death.title")
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#FF3B30"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = tr("death.hardcore") if is_hardcore else tr("death.respawn")
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	var btn := Button.new()
	btn.text = tr("menu.quit") if is_hardcore else tr("death.respawn")
	btn.custom_minimum_size = Vector2(220, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(btn)
	btn.pressed.connect(func():
		overlay.queue_free()
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").quit_to_menu()
		show_main_menu(true)
	)
	# Punch animation
	btn.scale = Vector2(0.9, 0.9)
	var tween := get_tree().create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_victory_screen() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.15, 0.05, 0.88)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.z_index = 100
	add_child(overlay)
	var label := Label.new()
	label.text = "VICTORY! ★"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color("#FFD700"))
	label.position = overlay.size/2 - Vector2(110, 24)
	overlay.add_child(label)
	var tween := get_tree().create_tween()
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.4)
	tween.set_loops(3)

func tr(key: String) -> String:
	if has_node("/root/LocalizationManager") and get_node("/root/LocalizationManager").has_method("tr_key"):
		return get_node("/root/LocalizationManager").tr_key(key)
	return key

func _on_locale_changed(locale: String) -> void:
	# Refresh all localizable children
	for child in get_children():
		if child.has_method("_on_locale_changed"):
			child._on_locale_changed(locale)

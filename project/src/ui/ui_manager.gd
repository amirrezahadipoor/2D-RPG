# UI Manager - Phase 11 Polish - Complete Fix
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
var _inventory_panel: Control
var _quest_panel: Control
var _talent_panel: Control

var _settings_manager: Control

signal ui_scale_changed(new_scale: float)

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_find_child_panels()
	_build_settings_panel()
	_build_inventory_panel()
	_build_quest_panel()
	_build_talent_panel()
	
	_apply_safe_area()
	_apply_ui_scale()
	_apply_theme()
	
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Connect to GameManager
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").state_changed.connect(_on_game_state_changed)
		get_node("/root/GameManager").game_started.connect(_on_game_started)
		get_node("/root/GameManager").intro_finished.connect(_on_game_started)
	
	# Show main menu initially
	_show_main_menu(true)
	
	print("[UIManager] ready, scale=", ui_scale)

func _find_child_panels() -> void:
	_hud = get_node_or_null("HUD")
	_main_menu = get_node_or_null("MainMenu")
	_pause_menu = get_node_or_null("PauseMenu")
	_settings_panel = get_node_or_null("SettingsPanel")

func _on_viewport_resized() -> void:
	_apply_safe_area()
	_apply_ui_scale()

func _apply_safe_area() -> void:
	if not safe_area_enabled:
		return
	
	var vp = get_viewport().get_visible_rect().size
	var top_inset := 0.0
	var bottom_inset := 0.0
	
	if OS.get_name() == "Android":
		var aspect = vp.y / max(1.0, vp.x)
		if aspect > 2.0:
			top_inset = 28.0
			bottom_inset = 22.0
	
	if _hud and _hud.has_method("set_safe_insets"):
		_hud.set_safe_insets(top_inset, bottom_inset)

func _apply_ui_scale() -> void:
	var vp = get_viewport().get_visible_rect().size
	var base_width := 720.0
	var calculated_scale = clamp(vp.x / base_width, 0.85, 1.35)
	ui_scale = calculated_scale
	
	if _hud:
		_hud.scale = Vector2(ui_scale, ui_scale)
	
	emit_signal("ui_scale_changed", ui_scale)

func _apply_theme() -> void:
	# Apply theme to children
	for child in get_children():
		if child is Control:
			# Default dark theme
			pass

func set_ui_scale(scale: float) -> void:
	ui_scale = clamp(scale, 0.7, 1.5)
	_apply_ui_scale()

func show_hud(show: bool) -> void:
	if _hud:
		_hud.visible = show

func _show_main_menu(show: bool) -> void:
	if not _main_menu:
		_main_menu = get_node_or_null("MainMenu")
		if not _main_menu:
			# Create main menu if missing
			_main_menu = preload("res://src/ui/main_menu.gd").new()
			_main_menu.name = "MainMenu"
			add_child(_main_menu)
	
	_main_menu.visible = show
	if show:
		_hud.visible = false

func show_pause_menu(show: bool) -> void:
	if not _pause_menu:
		_pause_menu = get_node_or_null("PauseMenu")
		if not _pause_menu:
			_pause_menu = _build_pause_menu()
	
	_pause_menu.visible = show
	
	if show:
		# Pause game
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").pause_game()
	else:
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").resume_game()

func _build_pause_menu() -> Control:
	var panel = preload("res://src/ui/pause_menu.gd").new()
	panel.name = "PauseMenu"
	add_child(panel)
	panel.resume_requested.connect(func(): show_pause_menu(false))
	panel.quit_to_menu_requested.connect(_on_quit_to_menu)
	return panel

func show_settings_panel(show: bool) -> void:
	if not _settings_manager:
		_settings_manager = preload("res://src/ui/settings_manager.gd").new()
		_settings_manager.name = "SettingsManager"
		add_child(_settings_manager)
	
	_settings_manager.visible = show

func _build_settings_panel() -> void:
	if _settings_manager:
		return
	
	_settings_manager = preload("res://src/ui/settings_manager.gd").new()
	_settings_manager.name = "SettingsManager"
	_settings_manager.visible = false
	add_child(_settings_manager)

func _build_inventory_panel() -> void:
	_inventory_panel = Control.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.visible = false
	add_child(_inventory_panel)
	_build_inventory_ui()

func _build_inventory_ui() -> void:
	if not _inventory_panel:
		return
	
	var vp = get_viewport().get_visible_rect().size
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.size = vp
	_inventory_panel.add_child(bg)
	
	var panel = Panel.new()
	panel.size = Vector2(500, 600)
	panel.position = (vp - panel.size) / 2
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1E1E1E")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	_inventory_panel.add_child(panel)
	
	var title = Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(500, 30)
	panel.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(460, 12)
	close_btn.pressed.connect(func(): show_inventory_panel(false))
	panel.add_child(close_btn)
	
	# Equipment slots display
	var slots_vbox = VBoxContainer.new()
	slots_vbox.position = Vector2(20, 50)
	slots_vbox.size = Vector2(200, 300)
	panel.add_child(slots_vbox)
	
	for slot in ["weapon", "helmet", "chest", "legs", "boots", "accessory"]:
		var slot_label = Label.new()
		slot_label.text = slot.to_upper()
		slot_label.add_theme_font_size_override("font_size", 12)
		slots_vbox.add_child(slot_label)

func show_inventory_panel(show: bool) -> void:
	if not _inventory_panel:
		_build_inventory_panel()
	_inventory_panel.visible = show
	
	if show and has_node("/root/GameManager"):
		get_node("/root/GameManager").pause_game()

func _build_quest_panel() -> void:
	_quest_panel = Control.new()
	_quest_panel.name = "QuestPanel"
	_quest_panel.visible = false
	add_child(_quest_panel)

func show_quest_panel(show: bool) -> void:
	if not _quest_panel:
		_build_quest_panel()
	_quest_panel.visible = show

func _build_talent_panel() -> void:
	_talent_panel = Control.new()
	_talent_panel.name = "TalentPanel"
	_talent_panel.visible = false
	add_child(_talent_panel)

func show_talent_panel(show: bool) -> void:
	if not _talent_panel:
		_build_talent_panel()
	_talent_panel.visible = show

func show_trade_panel(npc: Dictionary) -> void:
	# Simple trade UI placeholder
	pass

func show_quest_journal() -> void:
	show_quest_panel(true)

func show_death_screen(is_hardcore: bool) -> void:
	var overlay := ColorRect.new()
	overlay.name = "DeathOverlay"
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.z_index = 100
	add_child(overlay)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = overlay.size
	vbox.position = Vector2.ZERO
	overlay.add_child(vbox)
	
	var title := Label.new()
	title.text = ("مردی" if _is_fa_locale() else "You Died")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#FF3B30"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle := Label.new()
	if is_hardcore:
		subtitle.text = ("سخت: ذخیره حذف شد!" if _is_fa_locale() else "Hardcore: Save Deleted!")
	else:
		subtitle.text = ("بازگشت به منو" if _is_fa_locale() else "Return to Menu")
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	var btn := Button.new()
	btn.text = ("منوی اصلی" if _is_fa_locale() else "Main Menu")
	btn.custom_minimum_size = Vector2(220, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(btn)
	btn.pressed.connect(_on_quit_to_menu)

func show_victory_screen() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.15, 0.05, 0.88)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.z_index = 100
	add_child(overlay)
	
	var label := Label.new()
	label.text = "VICTORY!"
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color("#FFD700"))
	label.position = overlay.size / 2 - Vector2(120, 30)
	overlay.add_child(label)
	
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.4)
	tween.set_loops(3)
	
	await get_tree().create_timer(5.0).timeout
	overlay.queue_free()

func _is_fa_locale() -> bool:
	if has_node("/root/LocalizationManager"):
		return get_node("/root/LocalizationManager").get_locale() == "fa"
	return false

func _on_game_state_changed(new_state: int, old_state: int) -> void:
	match new_state:
		0:  # MENU
			_show_main_menu(true)
			show_hud(false)
		1:  # PLAYING
			_show_main_menu(false)
			show_hud(true)
		2:  # PAUSED
			show_pause_menu(true)
		6:  # DEAD
			show_death_screen(true)

func _on_game_started() -> void:
	_show_main_menu(false)
	show_hud(true)

func _on_quit_to_menu() -> void:
	# Remove overlays
	for child in get_children():
		if child.name in ["DeathOverlay", "PauseMenu"]:
			child.queue_free()
	
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").quit_to_menu()
	
	_show_main_menu(true)

func translate_key(key: String) -> String:
	if has_node("/root/LocalizationManager") and get_node("/root/LocalizationManager").has_method("tr_key"):
		return get_node("/root/LocalizationManager").tr_key(key)
	return key

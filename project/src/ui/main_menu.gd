# Main Menu - Phase 11 Polish - Complete Fix
# Indie appealing design: parallax title, animated buttons, locale switch, hardcore indicator

extends Control
class_name MainMenu

signal play_requested(hardcore: bool)
signal continue_requested()
signal settings_requested()
signal quit_requested()

var _has_save: bool = false
var _menu_built: bool = false

# UI nodes
var title_label: Label
var play_btn: Button
var continue_btn: Button
var settings_btn: Button
var quit_btn: Button
var hardcore_toggle: CheckBox
var subtitle_label: Label
var version_label: Label

func _ready() -> void:
	_build_procedural_menu()
	_check_save()
	_animate_title()
	_update_locale()
	
	if has_node("/root/LocalizationManager"):
		get_node("/root/LocalizationManager").locale_changed.connect(func(_l): _update_locale())
	
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").game_loaded.connect(func(_d): _check_save())

func _build_procedural_menu() -> void:
	if _menu_built:
		return
	_menu_built = true
	
	size = get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color("#0F0F0F")
	bg.size = size
	add_child(bg)
	
	# Subtle grid pattern
	var grid = Node2D.new()
	grid.name = "GridPattern"
	add_child(grid)
	
	for i in range(0, int(size.x), 48):
		var line = ColorRect.new()
		line.color = Color(1,1,1,0.012)
		line.position = Vector2(i, 0)
		line.size = Vector2(1, size.y)
		grid.add_child(line)
	
	for i in range(0, int(size.y), 48):
		var line = ColorRect.new()
		line.color = Color(1,1,1,0.012)
		line.position = Vector2(0, i)
		line.size = Vector2(size.x, 1)
		grid.add_child(line)
	
	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "2D RPG"
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color("#FFD700"))
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 60)
	title_label.size = Vector2(size.x, 80)
	add_child(title_label)
	
	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.text = "Hardcore Offline Adventure"
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.position = Vector2(0, 135)
	subtitle_label.size = Vector2(size.x, 24)
	add_child(subtitle_label)
	
	# Button container
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(size.x/2 - 140, 220)
	vbox.size = Vector2(280, 380)
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	play_btn = _create_menu_button("▶  Play", Color("#2E7D32"))
	vbox.add_child(play_btn)
	play_btn.pressed.connect(_on_play_pressed)
	
	continue_btn = _create_menu_button("Continue", Color("#1565C0"))
	vbox.add_child(continue_btn)
	continue_btn.pressed.connect(_on_continue_pressed)
	
	settings_btn = _create_menu_button("Settings", Color("#4A4A4A"))
	vbox.add_child(settings_btn)
	settings_btn.pressed.connect(_on_settings_pressed)
	
	quit_btn = _create_menu_button("Quit", Color("#333333"))
	vbox.add_child(quit_btn)
	quit_btn.pressed.connect(_on_quit_pressed)
	
	hardcore_toggle = CheckBox.new()
	hardcore_toggle.text = "Hardcore Mode (Permadeath)"
	hardcore_toggle.button_pressed = true
	hardcore_toggle.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hardcore_toggle)
	
	# Footer
	version_label = Label.new()
	version_label.name = "Version"
	version_label.text = "v1.0 • Offline • No Ads"
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color("#555555"))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.position = Vector2(0, size.y - 30)
	version_label.size = Vector2(size.x, 20)
	add_child(version_label)

func _create_menu_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 54)
	b.add_theme_font_size_override("font_size", 18)
	
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0,0,0,0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", style)
	
	var hover := style.duplicate()
	hover.bg_color = col.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	
	var pressed := style.duplicate()
	pressed.bg_color = col.darkened(0.2)
	b.add_theme_stylebox_override("pressed", pressed)
	
	return b

func _check_save() -> void:
	_has_save = FileAccess.file_exists("user://savegame.save")
	
	if continue_btn:
		continue_btn.disabled = not _has_save
		continue_btn.modulate.a = 1.0 if _has_save else 0.5

func _animate_title() -> void:
	if not title_label:
		return
	
	title_label.scale = Vector2(0.92, 0.92)
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.03, 1.03), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_label, "scale", Vector2(0.92, 0.92), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_locale() -> void:
	var locale = "en"
	if has_node("/root/LocalizationManager"):
		locale = get_node("/root/LocalizationManager").get_locale()
	
	if play_btn:
		play_btn.text = "▶  " + ("بازی" if locale == "fa" else "Play")
	if settings_btn:
		settings_btn.text = ("تنظیمات" if locale == "fa" else "Settings")
	if quit_btn:
		quit_btn.text = ("خروج" if locale == "fa" else "Quit")
	if subtitle_label:
		subtitle_label.text = ("ماجراجویی آفلاین سخت" if locale == "fa" else "Hardcore Offline Adventure")

func _on_play_pressed() -> void:
	var hardcore = hardcore_toggle.button_pressed if hardcore_toggle else true
	
	# Button animation
	if play_btn:
		var tween = create_tween()
		tween.tween_property(play_btn, "scale", Vector2(0.95, 0.95), 0.08)
		tween.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.12)
	
	await get_tree().create_timer(0.2).timeout
	
	# Start new game via GameManager
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").new_game(hardcore)
	
	# Hide menu
	visible = false
	emit_signal("play_requested", hardcore)

func _on_continue_pressed() -> void:
	if not _has_save:
		return
	
	# Button animation
	if continue_btn:
		var tween = create_tween()
		tween.tween_property(continue_btn, "scale", Vector2(0.95, 0.95), 0.08)
		tween.tween_property(continue_btn, "scale", Vector2(1.0, 1.0), 0.12)
	
	await get_tree().create_timer(0.2).timeout
	
	# Load game
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").load_game()
	
	visible = false
	emit_signal("continue_requested")

func _on_settings_pressed() -> void:
	# Show settings panel
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").show_settings_panel(true)
	
	emit_signal("settings_requested")

func _on_quit_pressed() -> void:
	# On Android, this closes the app
	get_tree().quit()

func refresh() -> void:
	_check_save()
	visible = true

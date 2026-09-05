# Main Menu - Phase 11 Polish
# Indie appealing design: parallax title, animated buttons, locale switch, hardcore indicator

extends Control
class_name MainMenu

signal play_requested(hardcore: bool)
signal continue_requested()
signal settings_requested()
signal quit_requested()

@onready var play_btn: Button = $VBox/PlayBtn if has_node("VBox/PlayBtn") else null
@onready var continue_btn: Button = $VBox/ContinueBtn if has_node("VBox/ContinueBtn") else null
@onready var settings_btn: Button = $VBox/SettingsBtn if has_node("VBox/SettingsBtn") else null
@onready var quit_btn: Button = $VBox/QuitBtn if has_node("VBox/QuitBtn") else null
@onready var title_label: Label = $Title if has_node("Title") else null
@onready var hardcore_toggle: CheckBox = $HardcoreToggle if has_node("HardcoreToggle") else null

var _has_save: bool = false

func _ready() -> void:
	if not play_btn:
		_build_procedural_menu()
	_check_save()
	_animate_title()
	_update_locale()
	if has_node("/root/LocalizationManager"):
		get_node("/root/LocalizationManager").locale_changed.connect(func(_l): _update_locale())

func _build_procedural_menu() -> void:
	size = get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color("#0F0F0F")
	bg.size = size
	add_child(bg)
	
	# Subtle grid pattern (procedural)
	for i in range(0, int(size.x), 48):
		var line := ColorRect.new()
		line.color = Color(1,1,1,0.015)
		line.position = Vector2(i, 0)
		line.size = Vector2(1, size.y)
		bg.add_child(line)
	for i in range(0, int(size.y), 48):
		var line := ColorRect.new()
		line.color = Color(1,1,1,0.015)
		line.position = Vector2(0, i)
		line.size = Vector2(size.x, 1)
		bg.add_child(line)
	
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "2D RPG"
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color("#FFD700"))
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 5)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 70)
	title_label.size = Vector2(size.x, 60)
	add_child(title_label)
	
	var subtitle := Label.new()
	subtitle.text = "Hardcore Offline Adventure"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#AAAAAA"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 128)
	subtitle.size = Vector2(size.x, 20)
	add_child(subtitle)
	
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(size.x/2 - 130, 200)
	vbox.size = Vector2(260, 320)
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	play_btn = _create_menu_button("▶ Play  /  بازی", Color("#2E7D32"))
	vbox.add_child(play_btn)
	play_btn.pressed.connect(_on_play_pressed)
	
	continue_btn = _create_menu_button("Continue  /  ادامه", Color("#1565C0"))
	vbox.add_child(continue_btn)
	continue_btn.pressed.connect(_on_continue_pressed)
	
	settings_btn = _create_menu_button("Settings  /  تنظیمات", Color("#4A4A4A"))
	vbox.add_child(settings_btn)
	settings_btn.pressed.connect(func(): emit_signal("settings_requested"))
	
	quit_btn = _create_menu_button("Quit  /  خروج", Color("#333333"))
	vbox.add_child(quit_btn)
	quit_btn.pressed.connect(func(): emit_signal("quit_requested"))
	
	hardcore_toggle = CheckBox.new()
	hardcore_toggle.text = "Hardcore (permadeath)  /  سخت"
	hardcore_toggle.button_pressed = true
	hardcore_toggle.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hardcore_toggle)
	
	var footer := Label.new()
	footer.text = "Offline • No Ads • No IAP • v1.0-polish"
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color("#666666"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.position = Vector2(0, size.y - 24)
	footer.size = Vector2(size.x, 16)
	add_child(footer)

func _create_menu_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 54)
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
	style.shadow_color = Color(0,0,0,0.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = col.lightened(0.14)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = col.darkened(0.18)
	b.add_theme_stylebox_override("pressed", pressed)
	return b

func _check_save() -> void:
	if has_node("/root/SaveManager"):
		_has_save = get_node("/root/SaveManager").has_save()
	elif has_node("/root/PolishManager/SaveManager"):
		_has_save = get_node("/root/PolishManager/SaveManager").has_save()
	else:
		_has_save = FileAccess.file_exists("user://savegame.save")
	if continue_btn:
		continue_btn.disabled = not _has_save
		continue_btn.modulate.a = 1.0 if _has_save else 0.55

func _animate_title() -> void:
	if not title_label:
		return
	title_label.scale = Vector2(0.92, 0.92)
	var tween := get_tree().create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.03, 1.03), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_label, "scale", Vector2(0.92, 0.92), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_locale() -> void:
	if has_node("/root/LocalizationManager"):
		var lm = get_node("/root/LocalizationManager")
		if title_label:
			# Keep title in English for branding
			pass
		if play_btn:
			play_btn.text = lm.tr_key("menu.play") + "  /  بازی" if lm.get_locale() == "fa" else "▶ Play"
		if continue_btn:
			continue_btn.text = lm.tr_key("menu.load_game")
		if settings_btn:
			settings_btn.text = lm.tr_key("menu.settings")

func _on_play_pressed() -> void:
	var hardcore := hardcore_toggle.button_pressed if hardcore_toggle else true
	# Punch animation
	var tween := get_tree().create_tween()
	tween.tween_property(play_btn, "scale", Vector2(0.96, 0.96), 0.08)
	tween.tween_property(play_btn, "scale", Vector2(1.0, 1.0), 0.12)
	await tween.finished
	emit_signal("play_requested", hardcore)

func _on_continue_pressed() -> void:
	if not _has_save:
		return
	emit_signal("continue_requested")

func refresh() -> void:
	_check_save()

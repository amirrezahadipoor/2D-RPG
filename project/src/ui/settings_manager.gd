# Settings Manager - Phase 11 Polish
# Handles audio, graphics, input, language, hardcore toggle
# Persists to user://settings.cfg, offline-only

extends Control
class_name SettingsManager

@onready var master_slider: HSlider = $MasterSlider if has_node("MasterSlider") else null
@onready var music_slider: HSlider = $MusicSlider if has_node("MusicSlider") else null
@onready var sfx_slider: HSlider = $SfxSlider if has_node("SfxSlider") else null
@onready var locale_option: OptionButton = $LocaleOption if has_node("LocaleOption") else null
@onready var hardcore_check: CheckBox = $HardcoreCheck if has_node("HardcoreCheck") else null
@onready var touch_check: CheckBox = $TouchCheck if has_node("TouchCheck") else null
@onready var polish_check: CheckBox = $PolishCheck if has_node("PolishCheck") else null

func _ready() -> void:
	if not master_slider:
		_build_procedural_settings()
	_load_and_apply()

func _build_procedural_settings() -> void:
	# Procedural settings UI for preview / minimal setup
	size = Vector2(520, 420)
	position = (get_viewport().get_visible_rect().size - size) / 2
	var panel := Panel.new()
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1E1E1E")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.size = Vector2(size.x - 32, size.y - 32)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "Settings / تنظیمات"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	master_slider = _add_slider_row(vbox, "Master", 0.0, 1.0, 1.0)
	music_slider = _add_slider_row(vbox, "Music", 0.0, 1.0, 0.85)
	sfx_slider = _add_slider_row(vbox, "SFX", 0.0, 1.0, 0.9)
	
	locale_option = OptionButton.new()
	locale_option.add_item("English", 0)
	locale_option.add_item("فارسی", 1)
	locale_option.selected = 0
	locale_option.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(locale_option)
	locale_option.item_selected.connect(_on_locale_selected)
	
	hardcore_check = CheckBox.new()
	hardcore_check.text = "Hardcore (permadeath)"
	hardcore_check.button_pressed = true
	vbox.add_child(hardcore_check)
	hardcore_check.toggled.connect(_on_hardcore_toggled)
	
	touch_check = CheckBox.new()
	touch_check.text = "Touch Controls"
	touch_check.button_pressed = OS.get_name() == "Android"
	vbox.add_child(touch_check)
	touch_check.toggled.connect(_on_touch_toggled)
	
	polish_check = CheckBox.new()
	polish_check.text = "Polish Effects (screenshake, particles)"
	polish_check.button_pressed = true
	vbox.add_child(polish_check)
	polish_check.toggled.connect(_on_polish_toggled)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 44)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_btn)
	close_btn.pressed.connect(func(): visible = false)

func _add_slider_row(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, val: float) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value = val
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(220, 16)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(val*100)
	val_lbl.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(val_lbl)
	slider.value_changed.connect(func(v): val_lbl.text = "%d%%" % int(v*100))
	return slider

func _load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	if master_slider:
		master_slider.value = cfg.get_value("audio", "master", 1.0)
		master_slider.value_changed.connect(func(v): _set_bus_volume("master", v))
	if music_slider:
		music_slider.value = cfg.get_value("audio", "music", 0.85)
		music_slider.value_changed.connect(func(v): _set_bus_volume("music", v))
	if sfx_slider:
		sfx_slider.value = cfg.get_value("audio", "sfx", 0.9)
		sfx_slider.value_changed.connect(func(v): _set_bus_volume("sfx", v))
	if locale_option:
		var loc: String = cfg.get_value("localization", "locale", "en")
		locale_option.selected = 1 if loc == "fa" else 0
	if hardcore_check:
		hardcore_check.button_pressed = cfg.get_value("game", "hardcore", true)
	if touch_check:
		touch_check.button_pressed = cfg.get_value("input", "touch_enabled", OS.get_name() == "Android")
	if polish_check:
		polish_check.button_pressed = cfg.get_value("polish", "enabled", true)

func _set_bus_volume(bus: String, value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", bus, value)
	cfg.save("user://settings.cfg")
	if has_node("/root/AudioManager") or has_node("/root/PolishManager/AudioManager"):
		var am = get_node_or_null("/root/AudioManager")
		if not am:
			am = get_node_or_null("/root/PolishManager/AudioManager")
		if am:
			match bus:
				"master": am.set_master_volume(value)
				"music": am.set_music_volume(value)
				"sfx": am.set_sfx_volume(value)
	else:
		# Direct AudioServer fallback
		var bus_idx := AudioServer.get_bus_index(bus.capitalize()) if bus != "master" else 0
		if bus_idx >= 0:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_locale_selected(idx: int) -> void:
	var locale := "fa" if idx == 1 else "en"
	if has_node("/root/LocalizationManager"):
		get_node("/root/LocalizationManager").set_locale(locale)

func _on_hardcore_toggled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("game", "hardcore", enabled)
	cfg.save("user://settings.cfg")
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").set_hardcore(enabled)

func _on_touch_toggled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("input", "touch_enabled", enabled)
	cfg.save("user://settings.cfg")
	if has_node("/root/TouchControls"):
		get_node("/root/TouchControls").set_joystick_enabled(enabled)

func _on_polish_toggled(enabled: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("polish", "enabled", enabled)
	cfg.save("user://settings.cfg")
	if has_node("/root/PolishManager"):
		get_node("/root/PolishManager").set_polish_enabled(enabled)

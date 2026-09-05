# Localization Manager - Phase 8 + 11 Polish
# Bilingual EN/FA with RTL support, Persian numerals, locale files externalized
# Offline: loads from res://assets/locale/*.json or .csv

extends Node
class_name LocalizationManager

var current_locale: String = "en" # en or fa
var _translations: Dictionary = {} # key -> {en, fa}
var _rtl_enabled: bool = false

signal locale_changed(new_locale: String)

func _ready() -> void:
	_load_locale_setting()
	_load_translations()
	_apply_locale()
	print("[LocalizationManager] locale=", current_locale, " rtl=", _rtl_enabled)

func _load_locale_setting() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		current_locale = cfg.get_value("localization", "locale", "en")
		if current_locale != "en" and current_locale != "fa":
			current_locale = "en"
	_rtl_enabled = (current_locale == "fa")

func _load_translations() -> void:
	# Try to load locale files
	var paths := [
		"res://assets/locale/en.json",
		"res://assets/locale/fa.json",
		"res://project/assets/locale/en.json",
		"res://project/assets/locale/fa.json"
	]
	# Also try CSV
	var csv_paths := [
		"res://assets/locale/translations.csv",
		"res://project/assets/locale/translations.csv"
	]
	# Load JSONs if exist
	for p in paths:
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f:
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
					var locale_code := "en" if "en" in p else "fa"
					for k in json.data.keys():
						if not _translations.has(k):
							_translations[k] = {}
						_translations[k][locale_code] = str(json.data[k])
	# Load CSV if exists
	for p in csv_paths:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f:
				var header := f.get_csv_line()
				while not f.eof_reached():
					var line := f.get_csv_line()
					if line.size() >= 3:
						var key := line[0]
						_translations[key] = {"en": line[1], "fa": line[2]}
	
	# Fallback: built-in minimal translations if no files
	if _translations.is_empty():
		_translations = {
			"menu.play": {"en": "Play", "fa": "بازی"},
			"menu.settings": {"en": "Settings", "fa": "تنظیمات"},
			"menu.quit": {"en": "Quit", "fa": "خروج"},
			"menu.new_game": {"en": "New Game", "fa": "بازی جدید"},
			"menu.load_game": {"en": "Continue", "fa": "ادامه"},
			"menu.hardcore": {"en": "Hardcore", "fa": "سخت"},
			"hud.health": {"en": "HP", "fa": "سلامتی"},
			"hud.stamina": {"en": "Stamina", "fa": "استقامت"},
			"hud.level": {"en": "Lv.", "fa": "سطح"},
			"hud.gold": {"en": "Gold", "fa": "سکه"},
			"settings.audio": {"en": "Audio", "fa": "صدا"},
			"settings.language": {"en": "Language", "fa": "زبان"},
			"settings.touch": {"en": "Touch Controls", "fa": "کنترل لمسی"},
			"quest.journal": {"en": "Journal", "fa": "دفتر ماموریت‌ها"},
			"quest.complete": {"en": "Quest Complete!", "fa": "ماموریت کامل شد!"},
			"death.title": {"en": "You Died", "fa": "مردی"},
			"death.hardcore": {"en": "Hardcore: save deleted", "fa": "سخت: ذخیره حذف شد"},
			"death.respawn": {"en": "Respawn at checkpoint", "fa": "بازگشت به ایستگاه"},
			"inventory.title": {"en": "Inventory", "fa": "کوله‌پشتی"},
			"levelup.title": {"en": "Level Up!", "fa": "سطح جدید!"},
		}

func _apply_locale() -> void:
	_rtl_enabled = (current_locale == "fa")
	# Set Godot TranslationServer if .translation files exist
	var trans_path := "res://assets/locale/%s.translation" % current_locale
	if ResourceLoader.exists(trans_path):
		# TranslationServer would handle it
		pass
	# Notify UI to refresh
	get_tree().call_group("localizable", "_on_locale_changed", current_locale)

func tr_key(key: String) -> String:
	if _translations.has(key) and _translations[key].has(current_locale):
		return _translations[key][current_locale]
	elif _translations.has(key) and _translations[key].has("en"):
		return _translations[key]["en"]
	return key # fallback to key itself

func set_locale(locale: String) -> void:
	if locale != "en" and locale != "fa":
		push_warning("Unsupported locale: %s" % locale)
		return
	current_locale = locale
	_rtl_enabled = (locale == "fa")
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("localization", "locale", locale)
	cfg.save("user://settings.cfg")
	_apply_locale()
	emit_signal("locale_changed", locale)
	print("[LocalizationManager] switched to ", locale)

func get_locale() -> String:
	return current_locale

func is_rtl() -> bool:
	return _rtl_enabled

func to_persian_numerals(text: String) -> String:
	if current_locale != "fa":
		return text
	return PersianNumerals.to_persian(text)

func format_number(n: int) -> String:
	var s := str(n)
	if current_locale == "fa":
		s = PersianNumerals.to_persian(s)
		# Optionally use Persian thousands separator
		# s = PersianNumerals.format_with_separator(s)
	return s

func get_font_for_locale() -> Font:
	# Returns appropriate font: Vazirmatn for FA, default for EN
	if current_locale == "fa":
		var fa_font_path := "res://assets/fonts/Vazirmatn-Regular.ttf"
		if ResourceLoader.exists(fa_font_path):
			return load(fa_font_path)
	return null # use default

func localize_control(control: Control, key: String) -> void:
	if "text" in control:
		control.text = tr_key(key)
		if _rtl_enabled and control is Label:
			control.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

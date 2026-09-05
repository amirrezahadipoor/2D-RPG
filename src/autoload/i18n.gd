# Bilingual localization (EN / FA) with real RTL + Persian numerals.
#
# The previous revision shipped ZERO font files, so every Persian string
# rendered as tofu boxes. This build bundles Vazirmatn (SIL OFL, see
# assets/fonts/OFL-Vazirmatn.txt), which has full Persian glyph coverage, and
# Godot's built-in HarfBuzz text server then handles Arabic shaping + bidi
# for us as long as we tag the Control correctly.
extends Node

signal locale_changed(locale: String)

const LOCALES := ["en", "fa"]
# Loaded lazily (NOT preloaded): on a fresh clone the font's imported
# .fontdata does not exist until the first import pass finishes, and a
# preload would break the autoload at parse time.
const FONT_REGULAR_PATH := "res://assets/fonts/Vazirmatn-Regular.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/Vazirmatn-Bold.ttf"

var font_regular: Font
var font_bold: Font

var locale: String = "en"
var _strings: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fonts()
	_load_all()
	_load_setting()
	apply_theme_defaults()
	print("[I18N] locale=%s rtl=%s strings=%d font=%s" % [
		locale, is_rtl(), _strings.size(), "ok" if font_regular else "missing"])

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		font_regular = load(FONT_REGULAR_PATH)
	if ResourceLoader.exists(FONT_BOLD_PATH):
		font_bold = load(FONT_BOLD_PATH)
	if font_regular == null:
		push_warning("[I18N] fonts not imported yet; run the project once to import")

func get_font() -> Font:
	return font_regular

func _load_all() -> void:
	for code in LOCALES:
		var path := "res://assets/locale/%s.json" % code
		if not FileAccess.file_exists(path):
			push_warning("[I18N] missing locale file: " + path)
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			_strings[code] = parsed
		else:
			push_error("[I18N] bad JSON in " + path)

func _load_setting() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var saved: String = cfg.get_value("locale", "current", "en")
		if saved in LOCALES:
			locale = saved

func set_locale(code: String) -> void:
	if code not in LOCALES or code == locale:
		return
	locale = code
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("locale", "current", code)
	cfg.save("user://settings.cfg")
	apply_theme_defaults()
	locale_changed.emit(locale)

func toggle_locale() -> void:
	set_locale("fa" if locale == "en" else "en")

func is_rtl() -> bool:
	return locale == "fa"

## Translate. Falls back to EN, then to the raw key so a missing string is
## loud in the UI instead of silently blank.
func tr_str(key: String) -> String:
	var table: Dictionary = _strings.get(locale, {})
	if table.has(key):
		return str(table[key])
	var en: Dictionary = _strings.get("en", {})
	if en.has(key):
		return str(en[key])
	push_warning("[I18N] missing key: " + key)
	return key

## Configure a Control for the active locale: direction + language tag so
## Godot's bidi engine lays Persian out right-to-left.
func tag(control: Control) -> void:
	if control == null:
		return
	control.text_direction = (
		Control.TEXT_DIRECTION_RTL if is_rtl() else Control.TEXT_DIRECTION_LTR
	)
	control.language = locale

## Apply the bundled font everywhere by default.
func apply_theme_defaults() -> void:
	if font_regular == null:
		return
	var theme := Theme.new()
	theme.default_font = font_regular
	theme.default_font_size = 8
	get_tree().root.theme = theme

const _FA_DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

## Convert ASCII digits to Persian digits when the locale is FA.
func digits(text: String) -> String:
	if not is_rtl():
		return text
	var out := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			out += _FA_DIGITS[int(ch)]
		else:
			out += ch
	return out

func num(value: int) -> String:
	return digits(str(value))

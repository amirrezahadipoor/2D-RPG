# Persian Numerals Utility - Phase 8 + 11 Polish
# Converts Western Arabic numerals to Persian (Farsi) numerals
# Also handles RTL markers, display options per settings

extends Node
class_name PersianNumerals

const WESTERN := ["0","1","2","3","4","5","6","7","8","9"]
const PERSIAN := ["۰","۱","۲","۳","۴","۵","۶","۷","۸","۹"] # U+06F0..06F9
const ARABIC_INDIC := ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"] # fallback

static func to_persian(text: String, use_persian: bool = true) -> String:
	var target := PERSIAN if use_persian else ARABIC_INDIC
	var result := text
	for i in range(10):
		result = result.replace(WESTERN[i], target[i])
	return result

static func to_western(text: String) -> String:
	var result := text
	for i in range(10):
		result = result.replace(PERSIAN[i], WESTERN[i])
		result = result.replace(ARABIC_INDIC[i], WESTERN[i])
	return result

static func format_with_separator(number_str: String, separator: String = "،") -> String:
	# Persian thousands separator is U+060C "،" or comma
	var western := to_western(number_str)
	# Keep sign
	var sign := ""
	if western.begins_with("-"):
		sign = "-"
		western = western.substr(1)
	# Split decimal
	var parts := western.split(".")
	var int_part := parts[0]
	var dec_part := parts[1] if parts.size() > 1 else ""
	# Add separator every 3 digits from right
	var formatted := ""
	var count := 0
	for i in range(int_part.length() - 1, -1, -1):
		formatted = int_part[i] + formatted
		count += 1
		if count % 3 == 0 and i != 0:
			formatted = separator + formatted
	if dec_part != "":
		formatted += "." + dec_part
	return sign + to_persian(formatted)

static func format_gold(amount: int, use_separator: bool = true) -> String:
	var s := str(amount)
	if use_separator:
		s = format_with_separator(s)
	else:
		s = to_persian(s)
	return s

static func wrap_rtl(text: String) -> String:
	# Add RLM marker for proper RTL display in mixed text
	const RLM := "\u200F" # Right-to-Left Mark
	return RLM + text + RLM

static func is_persian_numeral_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		return cfg.get_value("localization", "persian_numerals", true)
	return true

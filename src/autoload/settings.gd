extends Node
## Player settings: volumes + quality tier, persisted in user://settings.cfg
## (the same file I18N already uses for the locale — one settings home).

signal settings_changed

const PATH := "user://settings.cfg"
const QUALITIES := ["low", "medium", "high"]

var master: float = 1.0    # 0..1 linear
var music: float = 0.8
var sfx: float = 1.0
var quality: String = "high"
var fps_cap: int = 60
var ui_scale: float = 1.0

# ---- touch feel (Phase 2.3) ----
var pan_speed: float = 1.0       # camera pan multiplier, 0.5 .. 2.0
var tap_radius: float = 16.0     # design px a tap may land from a thing, 8..28
var auto_combat: bool = true     # swing at foes that close in / attack us
var tutorial_seen := false       # first-run touch tutorial already shown

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
		music = clampf(float(cfg.get_value("audio", "music", 0.8)), 0.0, 1.0)
		sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
		fps_cap = int(cfg.get_value("video", "fps", 60))
		ui_scale = float(cfg.get_value("video", "ui_scale", 1.0))
		Engine.max_fps = fps_cap
		var q: String = str(cfg.get_value("video", "quality", "high"))
		if q in QUALITIES:
			quality = q
		pan_speed = clampf(float(cfg.get_value("touch", "pan_speed", 1.0)), 0.5, 2.0)
		tap_radius = clampf(float(cfg.get_value("touch", "tap_radius", 16.0)), 8.0, 28.0)
		auto_combat = bool(cfg.get_value("touch", "auto_combat", true))
		tutorial_seen = bool(cfg.get_value("touch", "tutorial_seen", false))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # keep the [locale] section I18N writes
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fps", fps_cap)
	cfg.set_value("video", "ui_scale", ui_scale)
	cfg.set_value("touch", "pan_speed", pan_speed)
	cfg.set_value("touch", "tap_radius", tap_radius)
	cfg.set_value("touch", "auto_combat", auto_combat)
	cfg.set_value("touch", "tutorial_seen", tutorial_seen)
	cfg.save(PATH)

## Push the values into the audio buses so they take effect immediately.
func apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(maxf(master, 0.0001)))
	var mi := AudioServer.get_bus_index("Music")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(music * 0.9, 0.0001)))
	var si := AudioServer.get_bus_index("SFX")
	if si >= 0:
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sfx, 0.0001)))
	settings_changed.emit()

func set_master(v: float) -> void:
	master = clampf(v, 0.0, 1.0)
	save_settings()
	apply()

func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	save_settings()
	apply()

func set_sfx(v: float) -> void:
	sfx = clampf(v, 0.0, 1.0)
	save_settings()
	apply()

## Phase E3: bigger UI for small eyes / small phones.
func set_ui_scale(v: float) -> void:
	ui_scale = clampf(v, 1.0, 1.6)
	settings_changed.emit()
	save_settings()

## Phase E1: battery-saving 30 fps cap for weak phones.
func set_fps_cap(v: int) -> void:
	fps_cap = 30 if v == 30 else 60
	Engine.max_fps = fps_cap
	save_settings()
	settings_changed.emit()

func set_quality(q: String) -> void:
	if q not in QUALITIES:
		return
	quality = q
	save_settings()
	settings_changed.emit()

func set_pan_speed(v: float) -> void:
	pan_speed = clampf(v, 0.5, 2.0)
	save_settings()
	settings_changed.emit()

func set_tap_radius(v: float) -> void:
	tap_radius = clampf(v, 8.0, 28.0)
	save_settings()
	settings_changed.emit()

func set_auto_combat(on: bool) -> void:
	auto_combat = on
	save_settings()
	settings_changed.emit()

func set_tutorial_seen(seen: bool) -> void:
	tutorial_seen = seen
	save_settings()
	settings_changed.emit()

func quality_at_least(q: String) -> bool:
	return QUALITIES.find(quality) >= QUALITIES.find(q)

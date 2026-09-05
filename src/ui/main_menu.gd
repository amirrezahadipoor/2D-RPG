# Title screen: continue / new run (adventure or hardcore) / settings / quit.
# Entry point of the game — the run itself lives in scenes/main.tscn.
# Lives on its own canvas layer so the in-game camera can never move it.
class_name MainMenu
extends CanvasLayer

const STAR_COUNT := 90

var _sel := 0
var _items: Array = []          # Array of {label: Label, action: Callable, enabled: bool, key: String}
var _root: Control
var _bg: _Starfield
var _title: Label
var _version: Label
var _hint: Label
var settings_ui: SettingsUI

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.change_state(Game.State.MENU)
	Sfx.stop_music()
	Sfx.set_biome("menu")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_bg = _Starfield.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)
	_build()
	I18N.locale_changed.connect(func(_l): _rebuild_texts())

func _build() -> void:
	for child in _root.get_children():
		if child is Label:
			child.queue_free()
	_items.clear()
	_title = _mk_label(Vector2(0, 40), 22, Color(1.0, 0.85, 0.35), 480)
	_title.text = "PIXEL REALMS"
	var sub := _mk_label(Vector2(0, 66), 8, Color(0.65, 0.7, 0.9), 480)
	sub.text = _tr("menu.subtitle")
	var y := 104.0
	_add_item("menu.continue", y, _continue, Game.has_save())
	_add_item("menu.play", y + 18, func(): _new_run(false), true)
	_add_item("menu.hardcore", y + 36, func(): _new_run(true), true)
	_add_item("menu.settings", y + 54, _open_settings, true)
	_add_item("menu.quit", y + 72, func(): get_tree().quit(), true)
	_hint = _mk_label(Vector2(0, 232), 7, Color(0.45, 0.47, 0.58), 480)
	_hint.text = _tr("menu.hint")
	_version = _mk_label(Vector2(388, 258), 7, Color(0.4, 0.42, 0.5), 90)
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_selection()

func _mk_label(pos: Vector2, size: int, col: Color, width: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, size + 8)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

func _add_item(key: String, y: float, action: Callable, enabled: bool) -> void:
	var l := _mk_label(Vector2(0, y), 10, Color(0.9, 0.91, 1.0) if enabled else Color(0.4, 0.4, 0.45), 480)
	l.text = _tr(key)
	_items.append({"label": l, "action": action, "enabled": enabled, "key": key})

func _tr(key: String) -> String:
	return I18N.tr_str(key)

func _rebuild_texts() -> void:
	_build()

func _refresh_selection() -> void:
	for i in _items.size():
		var item: Dictionary = _items[i]
		var l: Label = item["label"]
		if not item["enabled"]:
			l.text = _tr(item["key"])
			continue
		l.text = ("> " + _tr(item["key"]) + " <") if i == _sel else _tr(item["key"])

func _unhandled_input(event: InputEvent) -> void:
	if settings_ui != null and settings_ui.visible:
		return
	if event.is_action_pressed("move_up"):
		_step(-1)
	elif event.is_action_pressed("move_down"):
		_step(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		Sfx.play("click")
		var item: Dictionary = _items[_sel]
		if item["enabled"]:
			(item["action"] as Callable).call()
	elif event.is_action_pressed("locale"):
		I18N.toggle_locale()

func _step(dir: int) -> void:
	var n := _items.size()
	for i in n:
		_sel = (_sel + dir + n) % n
		if _items[_sel]["enabled"]:
			break
	Sfx.play("click", -14.0, 0.02)
	_refresh_selection()

# ---------------------------------------------------------------- actions ----
func _continue() -> void:
	Game.pending_load = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _new_run(hardcore: bool) -> void:
	Game.pending_load = false
	Game.wipe_save()
	Game.seen_intro = false
	Game.start_new_run(hardcore)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _open_settings() -> void:
	if settings_ui == null:
		settings_ui = SettingsUI.new()
		add_child(settings_ui)
	settings_ui.open()

# ------------------------------------------------------- animated backdrop ----
class _Starfield extends Control:
	var _t := 0.0
	var _stars := PackedVector2Array()
	var _bright := PackedFloat32Array()

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260905
		for i in MainMenu.STAR_COUNT:
			_stars.append(Vector2(rng.randf() * 480.0, rng.randf() * 170.0))
			_bright.append(rng.randf_range(0.25, 1.0))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 480, 270), Color(0.035, 0.035, 0.07))
		for i in _stars.size():
			var tw := 0.6 + 0.4 * sin(_t * 1.7 + float(i))
			var c := Color(0.9, 0.92, 1.0, _bright[i] * tw * 0.8)
			draw_rect(Rect2(_stars[i], Vector2(1, 1)), c)
		draw_circle(Vector2(392, 46), 13.0, Color(0.95, 0.93, 0.8, 0.9))
		draw_circle(Vector2(397, 42), 11.0, Color(0.035, 0.035, 0.07))
		for layer in 2:
			var base := 196.0 + layer * 26.0
			var col := Color(0.06, 0.07, 0.12) if layer == 0 else Color(0.045, 0.05, 0.09)
			var pts := PackedVector2Array([Vector2(0, 270)])
			for x in range(0, 481, 8):
				var y := base + sin((float(x) + _t * (4.0 - layer * 2.0)) * 0.02 + layer * 2.0) * 9.0
				pts.append(Vector2(x, y))
			pts.append(Vector2(480, 270))
			draw_colored_polygon(pts, col)

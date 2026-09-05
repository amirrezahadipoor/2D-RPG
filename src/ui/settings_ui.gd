# Settings overlay: master/music/sfx volumes, quality tier, language.
# Shared by the main menu and the pause menu; values persist via Settings.
class_name SettingsUI
extends CanvasLayer

signal closed

enum Row { MASTER, MUSIC, SFX, QUALITY, LANGUAGE, DONE }

var _sel: int = Row.MASTER
var _root: Control
var _rows: Dictionary = {}      # Row -> {label: Label, value: Label}
var _panel: ColorRect
var _handled_touch_frame := -1

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	_build()
	visible = false
	# re-translate the rows currently on screen (the panel used to stay in the
	# old language until reopened)
	I18N.locale_changed.connect(func(_l): if visible: _refresh())

func _build() -> void:
	_root = Control.new()
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = ColorRect.new()
	_panel.color = Color(0.08, 0.07, 0.12, 0.97)
	_panel.position = Vector2(110, 44)
	_panel.size = Vector2(260, 182)
	_root.add_child(_panel)
	var title := _mk_label(Vector2(0, 52), 12, Color(1, 0.86, 0.4))
	title.text = I18N.tr_str("menu.settings")
	_add_row(Row.MASTER, "settings.master", 78)
	_add_row(Row.MUSIC, "settings.music", 96)
	_add_row(Row.SFX, "settings.sfx", 114)
	_add_row(Row.QUALITY, "settings.quality", 132)
	_add_row(Row.LANGUAGE, "settings.language", 150)
	_add_row(Row.DONE, "menu.done", 176)
	_refresh()

func _mk_label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(480, size + 6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	I18N.tag(l)
	_root.add_child(l)
	return l

func _add_row(row: Row, key: String, y: float) -> void:
	var left := Label.new()
	left.position = Vector2(126, y)
	left.size = Vector2(140, 14)
	left.add_theme_font_size_override("font_size", 9)
	left.add_theme_color_override("font_color", Color(0.85, 0.87, 1.0))
	left.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	left.add_theme_constant_override("outline_size", 2)
	left.text = I18N.tr_str(key)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	I18N.tag(left)
	_root.add_child(left)
	var right := _mk_label(Vector2(0, y), 9, Color(1, 0.95, 0.7))
	right.position = Vector2(262, y)
	right.size = Vector2(96, 14)
	_rows[row] = {"name": key, "left": left, "value": right, "y": y}

func open() -> void:
	visible = true
	_sel = Row.MASTER
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _refresh() -> void:
	for row in _rows:
		var r: Dictionary = _rows[row]
		var value: Label = r["value"]
		var left: Label = r["left"]
		match row:
			Row.MASTER:
				value.text = _bar(Settings.master)
			Row.MUSIC:
				value.text = _bar(Settings.music)
			Row.SFX:
				value.text = _bar(Settings.sfx)
			Row.QUALITY:
				value.text = I18N.tr_str("quality." + Settings.quality)
			Row.LANGUAGE:
				value.text = "فارسی / EN" if I18N.locale == "en" else "EN / فارسی"
			Row.DONE:
				value.text = ""
		var is_sel := int(row) == _sel
		var name_text: String = I18N.tr_str(r["name"])
		left.text = ("« " + name_text + " »") if is_sel and I18N.is_rtl() \
			else ("> " + name_text if is_sel else name_text)
		I18N.tag(left)
		I18N.tag(value)
		var col: Color = Color(1, 0.95, 0.7) if is_sel else Color(0.75, 0.78, 0.9)
		value.add_theme_color_override("font_color", col)

func _bar(v: float) -> String:
	var filled := int(round(v * 10.0))
	return "[" + "|".repeat(filled) + ".".repeat(10 - filled) + "] %d%%" % int(v * 100.0)

# ------------------------------------------------------------ pointer -------
## Touch/mouse control for the rows: tap a row to select it; tapping the value
## column scrubs volumes directly, and LANGUAGE / QUALITY / DONE act on tap.
## (Keyboard arrows keep working for the desktop/gamepad path.)
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		_handled_touch_frame = Engine.get_process_frames()
		_pointer_press(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Engine.get_process_frames() == _handled_touch_frame:
			return
		_pointer_press(event.position)
		get_viewport().set_input_as_handled()

func _canvas_point(event_pos: Vector2) -> Vector2:
	return _root.get_canvas_transform().affine_inverse() * event_pos

func _row_at(canvas_y: float) -> int:
	var best := int(Row.MASTER)
	var best_d := 1e9
	for row in _rows:
		var r: Dictionary = _rows[row]
		var d := absf(float(r["y"]) + 7.0 - canvas_y)
		if d < best_d:
			best_d = d
			best = int(row)
	# only when the tap actually lands on the panel body
	if canvas_y < 70.0 or canvas_y > 196.0:
		return -1
	return best

func _pointer_press(event_pos: Vector2) -> void:
	var p := _canvas_point(event_pos)
	var row := _row_at(p.y)
	if row < 0:
		return
	_sel = row
	_refresh()
	# volume rows scrub on the value column; everything else acts on tap
	if row == Row.DONE or row == Row.LANGUAGE or row == Row.QUALITY:
		Sfx.play("click")
		_activate()
	elif p.x >= 258.0:
		Sfx.play("click", -12.0, 0.02)
		_scrub_value(p.x)
	else:
		Sfx.play("click", -14.0, 0.02)

func _scrub_value(x: float) -> void:
	var target := clampf((x - 258.0) / 100.0, 0.0, 1.0)
	match _sel:
		Row.MASTER:
			Settings.set_master(target)
		Row.MUSIC:
			Settings.set_music(target)
		Row.SFX:
			Settings.set_sfx(target)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		Sfx.play("click")
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up"):
		_sel = (_sel + Row.size() - 1) % Row.size()
		Sfx.play("click", -14.0, 0.02)
		_refresh()
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % Row.size()
		Sfx.play("click", -14.0, 0.02)
		_refresh()
	elif event.is_action_pressed("move_left"):
		_adjust(-1)
	elif event.is_action_pressed("move_right"):
		_adjust(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		_activate()
	get_viewport().set_input_as_handled()

func _adjust(dir: int) -> void:
	var step := 0.05 * dir
	match _sel:
		Row.MASTER:
			Settings.set_master(Settings.master + step)
			Sfx.play("click", -12.0, 0.02)
		Row.MUSIC:
			Settings.set_music(Settings.music + step)
		Row.SFX:
			Settings.set_sfx(Settings.sfx + step)
			Sfx.play("click", -12.0, 0.02)
		Row.QUALITY:
			var i := (Settings.QUALITIES.find(Settings.quality) + dir + 3) % 3
			Settings.set_quality(Settings.QUALITIES[i])
			Sfx.play("click")
		Row.LANGUAGE:
			I18N.toggle_locale()
			Sfx.play("click")
	_refresh()

func _activate() -> void:
	match _sel:
		Row.LANGUAGE:
			I18N.toggle_locale()
			Sfx.play("click")
			_refresh()
		Row.QUALITY:
			var i := (Settings.QUALITIES.find(Settings.quality) + 1) % 3
			Settings.set_quality(Settings.QUALITIES[i])
			Sfx.play("click")
			_refresh()
		Row.DONE:
			Sfx.play("click")
			close()
		_:
			Sfx.play("click", -12.0, 0.02)

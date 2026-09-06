# Pause overlay — touch-native, responsive.
class_name PauseMenu
extends CanvasLayer

const ROW_FIRST_Y := 110.0
const ROW_STEP_Y := 28.0

var _sel := 0
var _root: Control
var _items: Array = []
var _clock: Label
var settings_ui: SettingsUI
var _handled_touch_frame := -1

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	_build()
	visible = false
	Game.state_changed.connect(_on_state)
	I18N.locale_changed.connect(func(_l): if visible: _rebuild())
	Settings.settings_changed.connect(func(): if visible: _rebuild())

func _on_state(next_state: int, _old: int) -> void:
	var show_it := next_state == Game.State.PAUSED
	if show_it == visible:
		return
	visible = show_it
	if show_it:
		_sel = 0
		_rebuild()
		Sfx.play("click")

func _build() -> void:
	_root = Control.new()
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

func _rebuild() -> void:
	for child in _root.get_children():
		if child is Label:
			child.queue_free()
	_items.clear()
	var safe := SafeArea.get_safe_margins(get_viewport()) if get_viewport() != null else Vector4.ZERO
	var bars := SafeArea.get_bars(get_viewport()) if get_viewport() != null else Vector2.ZERO
	var base_w := 480.0
	var usable_w := base_w - safe.x - safe.z - bars.x - bars.y
	var title := _mk_label(Vector2(safe.x + bars.x, 66 + safe.y), 14, Color(1, 0.86, 0.4), usable_w)
	title.text = I18N.tr_str("menu.paused")
	_clock = _mk_label(Vector2(safe.x + bars.x, 88 + safe.y), 9, Color(0.7, 0.75, 0.95), usable_w)
	_clock.text = "%s  |  %s" % [I18N.tr_str("hud.day"), Game.formatted_playtime()]
	_add_item("menu.resume", ROW_FIRST_Y + safe.y, func(): Game.change_state(Game.State.PLAYING), usable_w, safe.x + bars.x)
	_add_item("menu.settings", ROW_FIRST_Y + ROW_STEP_Y + safe.y, _open_settings, usable_w, safe.x + bars.x)
	_add_item("menu.save_quit", ROW_FIRST_Y + ROW_STEP_Y * 2 + safe.y, _save_quit, usable_w, safe.x + bars.x)
	_refresh()

func _mk_label(pos: Vector2, size: int, col: Color, w: float = 480.0) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, size + 6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	I18N.tag(l)
	_root.add_child(l)
	return l

func _add_item(key: String, y: float, action: Callable, w: float = 480.0, x_off: float = 0.0) -> void:
	var l := _mk_label(Vector2(x_off, y), 11, Color(0.9, 0.91, 1.0), w)
	l.text = I18N.tr_str(key)
	_items.append({"label": l, "action": action, "key": key, "y": y})

func _refresh() -> void:
	for i in _items.size():
		var item: Dictionary = _items[i]
		var l: Label = item["label"]
		var text: String = I18N.tr_str(item["key"])
		if i == _sel:
			text = ("« " + text + " »") if I18N.is_rtl() else ("> " + text + " <")
		l.text = text
		I18N.tag(l)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if settings_ui != null and settings_ui.visible:
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
	elif event is InputEventMouseMotion:
		_pointer_hover(event.position)

func _canvas_y(event_pos: Vector2) -> float:
	var inv := _root.get_canvas_transform().affine_inverse()
	return (inv * event_pos).y

func _row_at(canvas_y: float) -> int:
	var vp := get_viewport()
	var safe_y := 0.0
	if vp != null:
		safe_y = SafeArea.get_safe_margins(vp).y
	var idx := int(floor((canvas_y - safe_y - ROW_FIRST_Y) / ROW_STEP_Y))
	return clampi(idx, 0, _items.size() - 1)

func _pointer_hover(event_pos: Vector2) -> void:
	var cy := _canvas_y(event_pos)
	var vp := get_viewport()
	var safe_y := 0.0
	if vp != null:
		safe_y = SafeArea.get_safe_margins(vp).y
	if cy < safe_y + ROW_FIRST_Y - 6.0 or cy > safe_y + ROW_FIRST_Y + ROW_STEP_Y * _items.size() + 4.0:
		return
	var idx := _row_at(cy)
	if idx != _sel:
		_sel = idx
		_refresh()

func _pointer_press(event_pos: Vector2) -> void:
	var cy := _canvas_y(event_pos)
	var vp := get_viewport()
	var safe_y := 0.0
	if vp != null:
		safe_y = SafeArea.get_safe_margins(vp).y
	if cy < safe_y + ROW_FIRST_Y - 6.0 or cy > safe_y + ROW_FIRST_Y + ROW_STEP_Y * _items.size() + 4.0:
		return
	var idx := _row_at(cy)
	_sel = idx
	_refresh()
	Sfx.play("click")
	(_items[idx]["action"] as Callable).call()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if settings_ui != null and settings_ui.visible:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		var dir := 1 if event.is_action_pressed("move_down") else -1
		_sel = (_sel + dir + _items.size()) % _items.size()
		Sfx.play("click", -14.0, 0.02)
		_refresh()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		Sfx.play("click")
		(_items[_sel]["action"] as Callable).call()
	get_viewport().set_input_as_handled()

func _open_settings() -> void:
	if settings_ui == null:
		settings_ui = SettingsUI.new()
		add_child(settings_ui)
	settings_ui.open()

func _save_quit() -> void:
	Game.save_run()
	Game.change_state(Game.State.MENU)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")

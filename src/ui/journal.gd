# Quest journal — touch-native, responsive.
class_name JournalUI
extends CanvasLayer

var _scroll := 0
var _root: Control
var _panel: ColorRect
var _title: Label
var _counts: Label
var _list: Label
var _hint: Label

func _ready() -> void:
	layer = 22
	add_to_group("modal_ui")
	_build()
	visible = false
	QuestLog.changed.connect(func(): if visible: _refresh())
	I18N.locale_changed.connect(func(_l): if visible: _refresh())
	Settings.settings_changed.connect(_layout)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_panel = ColorRect.new()
	_panel.color = Color(0.08, 0.07, 0.11, 0.97)
	_root.add_child(_panel)
	_title = _label(Vector2.ZERO, Color(1, 0.86, 0.4), 12, 480)
	_counts = _label(Vector2.ZERO, Color(0.75, 0.78, 0.85), 9, 390)
	_list = _label(Vector2.ZERO, Color(0.92, 0.93, 1.0), 10, 384)
	_hint = _label(Vector2.ZERO, Color(0.6, 0.62, 0.7), 9, 480)
	_layout()

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	var base_w := 480.0
	var base_h := 270.0
	var avail_w := base_w - safe.x - safe.z - bars.x - bars.y - 20.0
	var avail_h := base_h - safe.y - safe.w - 30.0
	var pw := minf(avail_w * 0.9, 420.0)
	var ph := minf(avail_h * 0.92, 240.0)
	var px := safe.x + bars.x + (base_w - safe.x - safe.z - bars.x - bars.y - pw) * 0.5
	var py := safe.y + (base_h - safe.y - safe.w - ph) * 0.5
	_panel.position = Vector2(px, py)
	_panel.size = Vector2(pw, ph)
	_title.position = Vector2(px, py + 6)
	_title.size = Vector2(pw, 14)
	_counts.position = Vector2(px + 8, py + 20)
	_counts.size = Vector2(pw - 16, 14)
	_list.position = Vector2(px + 8, py + 36)
	_list.size = Vector2(pw - 16, ph - 56)
	_hint.position = Vector2(px, py + ph - 14)
	_hint.size = Vector2(pw, 12)

func _label(pos: Vector2, col: Color, size: int, width: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, 12)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

func toggle() -> void:
	visible = not visible
	if visible:
		_scroll = 0
		_layout()
		_refresh()

func _on_gui(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		var p: Vector2 = event.position
		if not Rect2(_panel.position, _panel.size).has_point(p):
			visible = false
			get_viewport().set_input_as_handled()

var _drag_y := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# keyboard/mouse-wheel kept for desktop testing but hint is touch-only
	if event.is_action_pressed("move_up"):
		_scroll = maxi(0, _scroll - 1); _refresh(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_scroll += 1; _refresh(); get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = maxi(0, _scroll - 1); _refresh(); get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll += 1; _refresh(); get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenDrag:
		_drag_y += (event as InputEventScreenDrag).relative.y
		if absf(_drag_y) >= 14.0:
			_scroll += -1 if _drag_y > 0 else 1
			_drag_y = 0.0
			_scroll = maxi(0, _scroll)
			_refresh()
			get_viewport().set_input_as_handled()

func _entries() -> Array:
	var out := []
	var m := QuestLog.current_main()
	if not m.is_empty():
		out.append(">> %s\n   %s  [%s/%s]  Lv>=%s" % [
			QuestDB.title_of(m), QuestDB.desc_of(m),
			I18N.num(int(m.get("progress", 0))), I18N.num(int(m["goal"])),
			I18N.num(int(m["level_gate"]))])
	for q in QuestLog.active:
		out.append("* %s\n   %s  [%s/%s]" % [
			QuestDB.title_of(q), QuestDB.desc_of(q),
			I18N.num(int(q.get("progress", 0))), I18N.num(int(q["goal"]))])
	return out

func _refresh() -> void:
	_title.text = I18N.tr_str("journal.title")
	_counts.text = "%s: %s/%s   %s: %s/%s   %s: %s" % [
		I18N.tr_str("journal.main"), I18N.num(QuestLog.completed_main_count()), I18N.num(QuestDB.main_count()),
		I18N.tr_str("journal.side"), I18N.num(QuestLog.completed_side_count()), I18N.num(QuestDB.side_count()),
		I18N.tr_str("talent.points"), I18N.num(Stats.talent_points)]
	var entries := _entries()
	_scroll = clampi(_scroll, 0, maxi(0, entries.size() - 1))
	var text := ""
	if entries.is_empty():
		text = I18N.tr_str("inv.empty")
	else:
		for i in range(_scroll, entries.size()):
			text += entries[i] + "\n"
	_list.text = text
	_hint.text = I18N.tr_str("journal.close")
	for l in [_title, _counts, _list, _hint]:
		I18N.tag(l)

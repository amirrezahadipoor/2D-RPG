# Act card — touch-native, responsive.
class_name ActCard
extends CanvasLayer

var _root: Control
var _title: Label
var _lead: Label
var _body: Label
var _hint: Label
var _band: ColorRect
var _gold_top: ColorRect
var _gold_bot: ColorRect

func _ready() -> void:
	layer = 50
	_build()
	visible = false
	Settings.settings_changed.connect(_layout)
	I18N.locale_changed.connect(func(_l): if visible: _refresh_texts())

func _build() -> void:
	_root = Control.new()
	_root.name = "ActCardRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_tap)
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_band = ColorRect.new()
	_band.color = Color(0.12, 0.08, 0.03, 0.94)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_band)
	_gold_top = ColorRect.new()
	_gold_top.color = Color(0.75, 0.58, 0.22)
	_gold_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gold_top)
	_gold_bot = ColorRect.new()
	_gold_bot.color = Color(0.75, 0.58, 0.22)
	_gold_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gold_bot)

	_title = _label(Vector2.ZERO, Color(1, 0.86, 0.4), 13, 480)
	_lead = _label(Vector2.ZERO, Color(0.85, 0.72, 0.45), 8, 480)
	_body = _label(Vector2.ZERO, Color(0.95, 0.93, 0.85), 10, 360)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint = _label(Vector2.ZERO, Color(0.6, 0.6, 0.68), 9, 480)
	_layout()

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	var base_w := 480.0
	var base_h := 270.0
	var usable_w := base_w - safe.x - safe.z - bars.x - bars.y
	var bw := minf(440.0, usable_w - 20.0)
	var bh := 112.0
	var bx := safe.x + bars.x + (usable_w - bw) * 0.5
	var by := (base_h - bh) * 0.5
	_band.position = Vector2(bx, by)
	_band.size = Vector2(bw, bh)
	_gold_top.position = Vector2(bx - 1, by - 1)
	_gold_top.size = Vector2(bw + 2, 3)
	_gold_bot.position = Vector2(bx - 1, by + bh)
	_gold_bot.size = Vector2(bw + 2, 3)
	_title.position = Vector2(bx, by + 6)
	_title.size = Vector2(bw, 16)
	_lead.position = Vector2(bx, by + 24)
	_lead.size = Vector2(bw, 12)
	_body.position = Vector2(bx + bw * 0.08, by + 44)
	_body.size = Vector2(bw * 0.84, 56)
	_hint.position = Vector2(bx, by + bh - 16)
	_hint.size = Vector2(bw, 14)

func _label(pos: Vector2, col: Color, size: int, width: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

func _refresh_texts() -> void:
	_layout()

func show_act(act: int) -> void:
	var done := QuestLog.completed_main_count()
	_title.text = I18N.tr_str("story.lead")
	_body.text = I18N.tr_str("story.act.%d" % clampi(act, 0, 9))
	_hint.text = I18N.tr_str("ui.tap")
	var count_line := "%s  %s %s/%s" % [
		I18N.tr_str("journal.title"),
		I18N.tr_str("journal.main"), I18N.num(done), I18N.num(QuestDB.main_count())]
	_lead.text = count_line
	for l in [_title, _lead, _body, _hint]:
		I18N.tag(l)
	_layout()
	visible = true

func hide_card() -> void:
	visible = false

var _tap_frame := -1

func _on_tap(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return
	if Engine.get_process_frames() == _tap_frame:
		return
	_tap_frame = Engine.get_process_frames()
	hide_card()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# touch-only: tap to dismiss, keyboard kept for desktop tests only
	if event is InputEventScreenTouch and event.pressed:
		hide_card()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_card()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack") \
		or event.is_action_pressed("dodge") or event.is_action_pressed("pause") \
		or event.is_action_pressed("inventory"):
		hide_card()
		get_viewport().set_input_as_handled()

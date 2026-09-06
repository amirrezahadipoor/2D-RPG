# Act card: a brief full-screen chronicle interlude shown whenever the main
# story moves into a new act (every tenth completed objective). It gives the
# open world a narrative beat between long stretches of gameplay without
# locking the player into a scripted cutscene - one tap or key dismisses it.
class_name ActCard
extends CanvasLayer

var _root: Control
var _title: Label
var _lead: Label
var _body: Label
var _hint: Label

func _ready() -> void:
	layer = 50
	_build()
	visible = false

func _build() -> void:
	_root = Control.new()
	_root.name = "ActCardRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_tap)
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var band := ColorRect.new()
	band.color = Color(0.12, 0.08, 0.03, 0.94)
	band.position = Vector2(20, 86)
	band.size = Vector2(440, 112)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(band)
	var gold_top := ColorRect.new()
	gold_top.color = Color(0.75, 0.58, 0.22)
	gold_top.position = Vector2(19, 85)
	gold_top.size = Vector2(442, 3)
	gold_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(gold_top)
	var gold_bot := ColorRect.new()
	gold_bot.color = Color(0.75, 0.58, 0.22)
	gold_bot.position = Vector2(19, 199)
	gold_bot.size = Vector2(442, 3)
	gold_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(gold_bot)

	_title = _label(Vector2(0, 92), Color(1, 0.86, 0.4), 12, 480)
	_lead = _label(Vector2(0, 110), Color(0.85, 0.72, 0.45), 8, 480)
	_body = _label(Vector2(60, 130), Color(0.95, 0.93, 0.85), 9, 360)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint = _label(Vector2(0, 196), Color(0.6, 0.6, 0.68), 8, 480)

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

## Fill the card for the given act (0..9) and reveal it. The body re-reads
## the locale on every show, so language flips stay correct.
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
	if event.is_action_pressed("interact") or event.is_action_pressed("attack") \
		or event.is_action_pressed("dodge") or event.is_action_pressed("pause") \
		or event.is_action_pressed("inventory"):
		hide_card()
		get_viewport().set_input_as_handled()

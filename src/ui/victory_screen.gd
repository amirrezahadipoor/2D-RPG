# Victory screen: shown by Main when the hundredth main-story stage completes
# and Game enters State.VICTORY (there was no defined ending before).
class_name VictoryScreen
extends CanvasLayer

signal continue_pressed
signal new_run_pressed
signal menu_pressed

var _root: Control
var _dim: ColorRect
var _title: Label
var _sub: Label
var _summary: Label
var _continue_btn: Button
var _new_run_btn: Button
var _menu_btn: Button

func _ready() -> void:
	layer = 30
	_build()
	visible = false
	I18N.locale_changed.connect(func(_l): if Game.state == Game.State.VICTORY: show_victory())

func _build() -> void:
	_root = Control.new()
	_root.name = "VictoryRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.03, 0.0, 0.82)
	_dim.position = Vector2.ZERO
	_root.add_child(_dim)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)

	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 9)
	_sub.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_sub)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 9)
	_summary.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_summary)

	_continue_btn = Button.new()
	_continue_btn.pressed.connect(func(): continue_pressed.emit())
	_root.add_child(_continue_btn)
	_new_run_btn = Button.new()
	_new_run_btn.pressed.connect(func(): new_run_pressed.emit())
	_root.add_child(_new_run_btn)
	_menu_btn = Button.new()
	_menu_btn.pressed.connect(func(): menu_pressed.emit())
	_root.add_child(_menu_btn)

	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_dim.size = vp
	_title.position = Vector2(0, vp.y * 0.18)
	_title.size = Vector2(vp.x, 28)
	_sub.position = Vector2(0, vp.y * 0.18 + 32)
	_sub.size = Vector2(vp.x, 14)
	_summary.position = Vector2(0, vp.y * 0.5)
	_summary.size = Vector2(vp.x, 34)
	var bw := 130.0
	var y := vp.y * 0.72
	_continue_btn.position = Vector2(vp.x * 0.5 - bw * 0.5, y)
	_continue_btn.size = Vector2(bw, 16)
	_new_run_btn.position = Vector2(vp.x * 0.5 - bw * 0.5, y + 22)
	_new_run_btn.size = Vector2(bw, 16)
	_menu_btn.position = Vector2(vp.x * 0.5 - bw * 0.5, y + 44)
	_menu_btn.size = Vector2(bw, 16)

func show_victory() -> void:
	_title.text = I18N.tr_str("victory.title")
	_sub.text = I18N.tr_str("victory.sub")
	_summary.text = "%s: %s    %s: %s    %s: %s" % [
		I18N.tr_str("hud.day"), I18N.num(Game.day()),
		I18N.tr_str("death.kills"), I18N.num(Stats.kills),
		I18N.tr_str("death.gold"), I18N.num(Stats.gold),
	]
	_continue_btn.text = I18N.tr_str("victory.continue")
	_new_run_btn.text = I18N.tr_str("victory.new_run")
	_menu_btn.text = I18N.tr_str("victory.menu")
	for control: Control in [_title, _sub, _summary, _continue_btn, _new_run_btn, _menu_btn]:
		I18N.tag(control)
	visible = true

func hide_victory() -> void:
	visible = false

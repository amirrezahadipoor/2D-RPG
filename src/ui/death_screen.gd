# Death screen: run summary + restart. Shown by Main when Game goes DEAD.
class_name DeathScreen
extends CanvasLayer

signal retry_pressed
signal revive_pressed

var _root: Control
var _dim: ColorRect
var _title: Label
var _hardcore_note: Label
var _summary: Label
var _retry: Button
var _revive: Button

func _ready() -> void:
	layer = 30
	_build()
	visible = false
	# re-translate only while the screen is actually up. Guarding on the root
	# Control's visibility is wrong: it is always visible, the CanvasLayer is
	# what gets hidden, so this used to resurrect the death screen on every
	# language switch.
	I18N.locale_changed.connect(func(_l): if Game.state == Game.State.DEAD: show_death())

func _build() -> void:
	_root = Control.new()
	_root.name = "DeathRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.0, 0.02, 0.78)
	_dim.position = Vector2.ZERO
	_root.add_child(_dim)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.9, 0.18, 0.22))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)

	_hardcore_note = Label.new()
	_hardcore_note.add_theme_font_size_override("font_size", 8)
	_hardcore_note.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	_hardcore_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hardcore_note)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 9)
	_summary.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_summary)

	_retry = Button.new()
	_retry.add_theme_font_size_override("font_size", 9)
	_retry.pressed.connect(func(): retry_pressed.emit())
	_root.add_child(_retry)

	_revive = Button.new()
	_revive.add_theme_font_size_override("font_size", 9)
	_revive.pressed.connect(func(): revive_pressed.emit())
	_root.add_child(_revive)

	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_dim.size = vp
	_title.position = Vector2(0, vp.y * 0.22)
	_title.size = Vector2(vp.x, 26)
	_hardcore_note.position = Vector2(0, vp.y * 0.22 + 28)
	_hardcore_note.size = Vector2(vp.x, 12)
	_summary.position = Vector2(0, vp.y * 0.5)
	_summary.size = Vector2(vp.x, 34)
	_retry.position = Vector2(vp.x * 0.5 - 50, vp.y * 0.78 if _revive.visible else vp.y * 0.72)
	_retry.size = Vector2(100, 16)
	_revive.position = Vector2(vp.x * 0.5 - 50, vp.y * 0.66)
	_revive.size = Vector2(100, 16)

func show_death() -> void:
	_title.text = I18N.tr_str("death.title")
	_hardcore_note.text = I18N.tr_str("death.hardcore") if Game.last_death_was_hardcore else ""
	_hardcore_note.visible = Game.last_death_was_hardcore
	_summary.text = "%s: %s\n%s: %s    %s: %s" % [
		I18N.tr_str("death.level"), I18N.num(Stats.level),
		I18N.tr_str("death.kills"), I18N.num(Stats.kills),
		I18N.tr_str("death.gold"), I18N.num(Stats.gold),
	]
	_retry.text = I18N.tr_str("death.retry")
	var can_revive := not Game.last_death_was_hardcore and Game.has_save()
	_revive.visible = can_revive
	_revive.text = I18N.tr_str("death.revive")
	for control: Control in [_title, _hardcore_note, _summary, _retry, _revive]:
		I18N.tag(control)
	visible = true

func hide_death() -> void:
	visible = false

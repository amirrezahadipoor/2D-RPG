# Heads-up display.
#
# Reads Stats via signals (the previous HUD was built but never connected to
# anything, so it displayed 100/100 forever). Also shows the currently
# equipped item icons straight from the generated icon atlas.
class_name Hud
extends CanvasLayer

const BAR_W := 64.0
const ICON_PX := 16.0

var _hp_fill: ColorRect
var _hp_bg: ColorRect
var _sta_fill: ColorRect
var _sta_bg: ColorRect
var _level_label: Label
var _gold_label: Label
var _biome_label: Label
var _gear_icons: Array[TextureRect] = []
var _prompts: Label
var _strip: HBoxContainer
var _last_biome := ""
var _root: Control
var _grade: TextureRect
var _vignette: ColorRect
var _chips: Array[Control] = []
var _tl: Array[Control] = []
var _tl_base: Dictionary = {}
var _rail_l: ColorRect
var _rail_r: ColorRect
var _rail_hint: Label
var safe_l := 0.0
var safe_t := 0.0
var safe_r := 0.0
var safe_b := 0.0
var _safe_override := Rect2()   # test hook: pretend a notch, in window px
var _rail_override := 0.0       # test hook: pretend letterbox bars, design px
var _chip_rects: Array[Rect2] = []
var _toast: Label
var _last_level := 1
var _clock: Label
var _night: ColorRect

func _ready() -> void:
	layer = 10
	_build()
	_connect()
	I18N.locale_changed.connect(func(_l): _refresh_text())
	Juice.hurt_taken.connect(_flash_hurt)
	_refresh_text()

func _build() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- ambient vignette: soft radial darkening for a cinematic frame ---
	_grade = TextureRect.new()
	_grade.name = "Grade"
	_grade.texture = load("res://assets/sprites/fx/vignette.png")
	_grade.visible = Settings.quality != "low"
	Settings.settings_changed.connect(func(): _grade.visible = Settings.quality != "low")
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_grade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_grade.modulate = Color(1, 1, 1, 0.6)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_grade)

	# --- hurt vignette: full-screen red flash, drawn under the rest ---
	_vignette = ColorRect.new()
	_vignette.name = "HurtFlash"
	_vignette.color = Color(0.75, 0.05, 0.1)
	_vignette.modulate.a = 0.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)

	_toast = Label.new()
	_toast.name = "Toast"
	_toast.add_theme_font_size_override("font_size", 12)
	_toast.add_theme_color_override("font_color", Color(1, 0.86, 0.35))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_toast.add_theme_constant_override("outline_size", 3)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast)

	# --- day/night tint over the world, under the HUD text ---
	_night = ColorRect.new()
	_night.name = "NightTint"
	_night.color = Color(0.05, 0.07, 0.2)
	_night.modulate.a = 0.0
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_night)

	_clock = Label.new()
	_clock.name = "Clock"
	_clock.add_theme_font_size_override("font_size", 8)
	_clock.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_clock.add_theme_constant_override("outline_size", 2)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_clock)

	# --- vitals (top-left) ---
	_hp_bg = _bar(Vector2(6, 6), BAR_W, 7, Color(0.15, 0.08, 0.1))
	_hp_fill = _bar(Vector2(7, 7), BAR_W - 2, 5, Color(0.82, 0.2, 0.25))
	_sta_bg = _bar(Vector2(6, 15), BAR_W, 5, Color(0.1, 0.12, 0.15))
	_sta_fill = _bar(Vector2(7, 16), BAR_W - 2, 3, Color(0.3, 0.75, 0.4))

	_level_label = _label(Vector2(6, 23), Color(1, 0.85, 0.4))
	_gold_label = _label(Vector2(6, 33), Color(1, 0.82, 0.3))

	_biome_label = _label(Vector2(0, 6), Color(0.85, 0.9, 1.0))
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- letterbox rails: the black bars on 20:9 phones become useful chrome ---
	_rail_l = ColorRect.new()
	_rail_l.color = Color(0.03, 0.03, 0.05, 1.0)
	_rail_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_l.visible = false
	_root.add_child(_rail_l)
	_rail_r = ColorRect.new()
	_rail_r.color = Color(0.03, 0.03, 0.05, 1.0)
	_rail_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_r.visible = false
	_root.add_child(_rail_r)
	_rail_hint = Label.new()
	_rail_hint.add_theme_font_size_override("font_size", 7)
	_rail_hint.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
	_rail_hint.add_theme_color_override("font_color", Color(0.6, 0.63, 0.72))
	_rail_hint.rotation_degrees = -90.0
	_rail_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_hint.visible = false
	_root.add_child(_rail_hint)

	for n in [_hp_bg, _hp_fill, _sta_bg, _sta_fill, _level_label, _gold_label]:
		_tl.append(n)
		_tl_base[n] = n.position

	# --- gear strip (bottom-right): live icons of what is equipped ---
	_strip = HBoxContainer.new()
	_strip.name = "GearStrip"
	_strip.add_theme_constant_override("separation", 2)
	_root.add_child(_strip)
	var strip := _strip
	for i in ArtIndex.EQUIPMENT_SLOTS.size():
		var box := ColorRect.new()
		box.color = Color(0.08, 0.08, 0.12, 0.75)
		box.custom_minimum_size = Vector2(18, 18)
		strip.add_child(box)
		var icon := TextureRect.new()
		icon.position = Vector2(1, 1)
		icon.size = Vector2(ICON_PX, ICON_PX)
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		box.add_child(icon)
		_gear_icons.append(icon)

	# --- prompts (bottom-left) ---
	_prompts = _label(Vector2(6, 0), Color(0.6, 0.62, 0.7))
	_prompts.size = Vector2(300, 30)
	_prompts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --- quick chips (right edge) ---
	# The ONLY on-screen buttons: tiny, dim, out of the way of the world.
	# Everything else is a gesture on the map itself.
	var defs := [["use_potion", "H"], ["inventory", "B"], ["quests", "J"],
			["map", "M"], ["pause", "II"]]
	for d in defs:
		var chip := Control.new()
		chip.size = Vector2(24, 24)
		chip.custom_minimum_size = Vector2(24, 24)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var border := ColorRect.new()
		border.color = Color(0.55, 0.5, 0.4, 0.8)
		border.size = Vector2(24, 24)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(border)
		var bg := ColorRect.new()
		bg.color = Color(0.09, 0.09, 0.13, 0.92)
		bg.position = Vector2(1, 1)
		bg.size = Vector2(22, 22)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(bg)
		var gi := ChipIcon.new()
		gi.kind = String(d[0])
		gi.size = Vector2(24, 24)
		gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(gi)
		chip.gui_input.connect(_on_chip_gui.bind(String(d[0])))
		_root.add_child(chip)
		_chips.append(chip)

	# Anchor presets with equal opposite anchors collapse the Control's size to
	# zero (Godot recomputes size from the anchors), which silently hid the
	# biome label and the prompts. Layout is therefore done explicitly.
	add_to_group("hud")
	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_update_safe(vp)
	var bars := _bars(vp)
	var railed := bars.x > 6.0 or bars.y > 6.0
	if _rail_l:
		_rail_l.visible = railed
		_rail_l.position = Vector2.ZERO
		_rail_l.size = Vector2(bars.x, vp.y)
		_rail_r.visible = railed
		_rail_r.position = Vector2(vp.x - bars.y, 0.0)
		_rail_r.size = Vector2(bars.y, vp.y)
	if _rail_hint:
		_rail_hint.visible = railed and bars.x > 14.0
		_rail_hint.text = I18N.tr_str("hud.gestures")
		_rail_hint.size = Vector2(vp.y - 48.0, 10.0)
		_rail_hint.position = Vector2(bars.x * 0.5 + 3.0, vp.y - 24.0)
	if _biome_label:
		_biome_label.position = Vector2(vp.x - safe_r - 140, safe_t + 6)
		_biome_label.size = Vector2(134, 12)
	if _prompts:
		_prompts.position = Vector2(6 + safe_l, vp.y - safe_b - 30)
		_prompts.visible = not railed
	if _strip:
		# fixed width: the container's own size is 0 on the first layout pass;
		# keep it on the stage, never on a letterbox rail
		var strip_w := float(ArtIndex.EQUIPMENT_SLOTS.size()) * 20.0 - 2.0
		var inset_r := bars.y if railed else safe_r
		_strip.position = Vector2(vp.x - inset_r - 6 - strip_w, vp.y - safe_b - 6 - 18)
	if _vignette:
		_vignette.position = Vector2.ZERO
		_vignette.size = vp
	if _toast:
		_toast.position = Vector2(0, vp.y * 0.3)
		_toast.size = Vector2(vp.x, 14)
	if _night:
		_night.position = Vector2.ZERO
		_night.size = vp
	_chip_rects.clear()
	var chip_x := vp.x - safe_r - 28.0
	var chip_y0 := vp.y * 0.42
	if railed and bars.y > 26.0:
		# park the chips inside the right bar instead of over the world
		chip_x = vp.x - bars.y + (bars.y - 24.0) * 0.5
		chip_y0 = (vp.y - 5.0 * 26.0) * 0.5
	for i in _chips.size():
		_chips[i].position = Vector2(chip_x, chip_y0 + float(i) * 26.0)
		_chip_rects.append(Rect2(_chips[i].position, _chips[i].size))
	for n in _tl:
		n.position = (_tl_base[n] as Vector2) + Vector2(safe_l, safe_t)
	if _clock:
		_clock.position = Vector2(bars.x, safe_t + 6)
		_clock.size = Vector2(vp.x - bars.x - bars.y, 10)

## Notch / punch-hole margins, in design px, from the OS safe area.
func _update_safe(vp: Vector2) -> void:
	var st := get_viewport().get_screen_transform()
	var s := st.get_scale()
	var o := st.get_origin()
	var area := _safe_override
	if area.size == Vector2.ZERO:
		area = Rect2(DisplayServer.get_display_safe_area())
		var win := DisplayServer.window_get_size()
		if area.position == Vector2.ZERO and area.size == Vector2(win):
			safe_l = 0.0
			safe_t = 0.0
			safe_r = 0.0
			safe_b = 0.0
			return
	safe_l = maxf(0.0, (area.position.x - o.x) / s.x)
	safe_t = maxf(0.0, (area.position.y - o.y) / s.y)
	safe_r = maxf(0.0, vp.x - (area.position.x + area.size.x - o.x) / s.x)
	safe_b = maxf(0.0, vp.y - (area.position.y + area.size.y - o.y) / s.y)

## Letterbox bar widths in design px (aspect "keep" centres the 480x270 stage).
func _bars(vp: Vector2) -> Vector2:
	if _rail_override > 0.0:
		return Vector2(_rail_override, _rail_override)
	var st := get_viewport().get_screen_transform()
	var s := st.get_scale()
	var o := st.get_origin()
	var win := DisplayServer.window_get_size()
	var l := o.x / s.x
	var r := (float(win.x) - o.x) / s.x - vp.x
	return Vector2(maxf(0.0, l), maxf(0.0, r))

## True when a design-space point lands on one of the quick chips
## (TouchUI uses this to let taps on chips pass through to the GUI).
func chip_hit(design_pos: Vector2) -> bool:
	for r in _chip_rects:
		if r.has_point(design_pos):
			return true
	return false

func _on_chip_gui(ev: InputEvent, action: String) -> void:
	if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton
			and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		_fire_action(action)

## Fire a UI action exactly like the matching key press would.
func _fire_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

func _bar(pos: Vector2, w: float, h: float, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r

func _label(pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

func _process(_delta: float) -> void:
	_update_clock()

## Smooth night tint: dark blue after dusk, blood-red on blood moons.
func _update_clock() -> void:
	if _clock:
		_clock.text = "%s %s  %02d:00" % [
			I18N.tr_str("hud.day"), I18N.num(Game.day()), Game.hour()]
		if Game.is_blood_moon():
			_clock.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			_clock.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	if _night:
		var h := float(Game.hour()) + fmod(Game.game_minutes, 60.0) / 60.0
		var night_amount := 0.0
		if h >= 19.0:
			night_amount = clampf((h - 19.0) / 3.0, 0.0, 1.0)
		elif h < 6.0:
			night_amount = 1.0
		elif h < 8.0:
			night_amount = clampf((8.0 - h) / 2.0, 0.0, 1.0)
		_night.modulate.a = night_amount * 0.5
		_night.color = Color(0.45, 0.05, 0.08) if Game.is_blood_moon() else Color(0.05, 0.07, 0.2)

func _connect() -> void:
	Stats.health_changed.connect(_on_health)
	Stats.stamina_changed.connect(_on_stamina)
	Stats.level_changed.connect(_on_level)
	Stats.gold_changed.connect(_on_gold)
	_last_level = Stats.level
	_on_health(Stats.hp, Stats.max_hp)
	_on_stamina(Stats.stamina, Stats.max_stamina)
	_on_level(Stats.level, Stats.xp, Stats.xp_next)
	_on_gold(Stats.gold)

func _on_health(cur: int, maxi: int) -> void:
	_hp_fill.size.x = (BAR_W - 2) * clampf(float(cur) / maxf(1.0, float(maxi)), 0, 1)

func _on_stamina(cur: float, maxi: int) -> void:
	_sta_fill.size.x = (BAR_W - 2) * clampf(cur / maxf(1.0, float(maxi)), 0, 1)

func _on_level(level: int, xp: int, xp_next: int) -> void:
	_level_label.text = "%s %s" % [I18N.tr_str("hud.level"), I18N.num(level)]
	I18N.tag(_level_label)
	if level > _last_level:
		_show_toast(I18N.tr_str("toast.levelup"))
	_last_level = level

# ---------------------------------------------------------------- juice -----
func _flash_hurt() -> void:
	if _vignette == null:
		return
	_vignette.modulate.a = 0.55
	var tween := create_tween()
	tween.tween_property(_vignette, "modulate:a", 0.0, 0.35)

## Public entry point so other systems (bag full, quest notes) can toast.
func show_toast(text: String) -> void:
	_show_toast(text)

func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	I18N.tag(_toast)
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.5)

func _on_gold(gold: int) -> void:
	_gold_label.text = "%s: %s" % [I18N.tr_str("hud.gold"), I18N.num(gold)]
	I18N.tag(_gold_label)

var _boss_bg: ColorRect = null
var _boss_fill: ColorRect = null
var _boss_lbl: Label = null

## Phase C1: top-centre boss bar, only while the king is near.
func set_boss(boss_name: String, ratio: float, show: bool) -> void:
	if _boss_bg == null:
		_boss_bg = ColorRect.new()
		_boss_bg.color = Color(0, 0, 0, 0.65)
		_boss_bg.size = Vector2(200, 7)
		_boss_bg.position = Vector2(140, 6)
		add_child(_boss_bg)
		_boss_fill = ColorRect.new()
		_boss_fill.color = Color(0.85, 0.2, 0.2)
		_boss_fill.size = Vector2(196, 3)
		_boss_fill.position = Vector2(142, 8)
		add_child(_boss_fill)
		_boss_lbl = Label.new()
		_boss_lbl.add_theme_font_size_override("font_size", 7)
		_boss_lbl.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
		_boss_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.7))
		_boss_lbl.position = Vector2(0, 13)
		_boss_lbl.size = Vector2(480, 10)
		_boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_boss_lbl)
	_boss_bg.visible = show
	_boss_fill.visible = show
	_boss_lbl.visible = show
	if show:
		_boss_fill.size.x = 196.0 * clampf(ratio, 0.0, 1.0)
		_boss_lbl.text = boss_name

func set_biome_text(text: String) -> void:
	_biome_label.text = text
	I18N.tag(_biome_label)

func set_biome(biome: String) -> void:
	_last_biome = biome
	_biome_label.text = I18N.tr_str("biome." + biome)
	I18N.tag(_biome_label)

## Refresh the icon strip from the paper-doll's current gear.
func set_gear(gear: Dictionary) -> void:
	for i in ArtIndex.EQUIPMENT_SLOTS.size():
		var slot: String = ArtIndex.EQUIPMENT_SLOTS[i]
		var item: String = gear.get(slot, "")
		var icon := _gear_icons[i]
		if item.is_empty() or not ArtIndex.ICON_INDEX.has(item):
			icon.texture = null
			continue
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/sprites/items/equipment_icons.png")
		var idx: int = ArtIndex.ICON_INDEX[item]
		at.region = Rect2(Vector2(idx % 8, idx / 8) * ICON_PX, Vector2(ICON_PX, ICON_PX))
		icon.texture = at

func _refresh_text() -> void:
	# re-translate the biome label too, otherwise it stays in the old locale
	if _last_biome != "":
		_biome_label.text = I18N.tr_str("biome." + _last_biome)
		I18N.tag(_biome_label)
	_on_level(Stats.level, Stats.xp, Stats.xp_next)
	_on_gold(Stats.gold)
	if DisplayServer.is_touchscreen_available():
		_prompts.text = I18N.tr_str("hud.gestures")
		I18N.tag(_prompts)
		I18N.tag(_biome_label)
		return
	_prompts.text = "%s [J]  %s [K]  %s [I]  %s [U]  %s [T]  %s [H]  %s [L]" % [
		I18N.tr_str("hud.prompt.attack"),
		I18N.tr_str("hud.prompt.dodge"),
		I18N.tr_str("hud.prompt.inv"),
		I18N.tr_str("hud.prompt.journal"),
		I18N.tr_str("hud.prompt.talents"),
		I18N.tr_str("hud.prompt.potion"),
		I18N.tr_str("hud.prompt.locale"),
	]
	I18N.tag(_prompts)
	I18N.tag(_biome_label)


## Tiny drawn pixel icons for the quick chips — no keyboard glyphs on screen.
class ChipIcon extends Control:
	var kind := ""

	func _draw() -> void:
		match kind:
			"use_potion":
				draw_rect(Rect2(9, 6, 6, 3), Color(0.7, 0.62, 0.5))
				draw_rect(Rect2(8, 9, 8, 9), Color(0.85, 0.2, 0.25))
				draw_rect(Rect2(9, 11, 6, 2), Color(0.98, 0.45, 0.45))
			"inventory":
				draw_rect(Rect2(9, 6, 6, 4), Color(0.42, 0.28, 0.16))
				draw_rect(Rect2(7, 9, 10, 9), Color(0.55, 0.38, 0.22))
				draw_rect(Rect2(11, 12, 2, 4), Color(0.85, 0.7, 0.4))
			"quests":
				draw_rect(Rect2(8, 6, 8, 12), Color(0.88, 0.82, 0.66))
				draw_rect(Rect2(9, 9, 6, 1), Color(0.35, 0.3, 0.25))
				draw_rect(Rect2(9, 12, 6, 1), Color(0.35, 0.3, 0.25))
				draw_rect(Rect2(9, 15, 4, 1), Color(0.35, 0.3, 0.25))
			"map":
				draw_rect(Rect2(6, 8, 4, 9), Color(0.33, 0.52, 0.43))
				draw_rect(Rect2(10, 7, 4, 10), Color(0.5, 0.7, 0.55))
				draw_rect(Rect2(14, 8, 4, 9), Color(0.33, 0.52, 0.43))
				draw_rect(Rect2(11, 10, 2, 2), Color(0.92, 0.85, 0.6))
			"pause":
				draw_rect(Rect2(9, 7, 3, 10), Color(0.9, 0.9, 0.92))
				draw_rect(Rect2(13, 7, 3, 10), Color(0.9, 0.9, 0.92))

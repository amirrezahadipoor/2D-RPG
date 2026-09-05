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
var _vignette: ColorRect
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

	# Anchor presets with equal opposite anchors collapse the Control's size to
	# zero (Godot recomputes size from the anchors), which silently hid the
	# biome label and the prompts. Layout is therefore done explicitly.
	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if _biome_label:
		_biome_label.position = Vector2(vp.x - 140, 6)
		_biome_label.size = Vector2(134, 12)
	if _prompts:
		_prompts.position = Vector2(6, vp.y - 30)
	if _strip:
		# fixed width: the container's own size is 0 on the first layout pass
		var strip_w := float(ArtIndex.EQUIPMENT_SLOTS.size()) * 20.0 - 2.0
		_strip.position = Vector2(vp.x - 6 - strip_w, vp.y - 6 - 18)
	if _vignette:
		_vignette.position = Vector2.ZERO
		_vignette.size = vp
	if _toast:
		_toast.position = Vector2(0, vp.y * 0.3)
		_toast.size = Vector2(vp.x, 14)
	if _night:
		_night.position = Vector2.ZERO
		_night.size = vp
	if _clock:
		_clock.position = Vector2(0, 6)
		_clock.size = Vector2(vp.x, 10)

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
		_night.modulate.a = night_amount * 0.38
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

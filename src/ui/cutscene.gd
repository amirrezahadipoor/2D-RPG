# Story intro: letterboxed pixel slides (sky/ground bands, 3x prop silhouettes,
# real paper-dolls) with typewriter text. E/Space advances, Esc skips.
class_name Cutscene
extends CanvasLayer

signal finished

var active := false

var _root: Control
var _stage: Node2D
var _sky: ColorRect
var _ground: ColorRect
var _text: Label
var _hint: Label
var _slide := 0
var _reveal := 0.0
var _slides := []

func _ready() -> void:
	layer = 40
	add_to_group("cutscene")
	_build()
	_define_slides()
	visible = false

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(black)
	_sky = ColorRect.new()
	_root.add_child(_sky)
	_ground = ColorRect.new()
	_root.add_child(_ground)
	_stage = Node2D.new()
	_root.add_child(_stage)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 11)
	_text.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_text.add_theme_constant_override("outline_size", 3)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_text)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_root.add_child(_hint)
	_layout()
	Settings.settings_changed.connect(_layout)

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	_sky.position = Vector2(bars.x + safe.x, 30 + safe.y)
	_sky.size = Vector2(480 - bars.x - bars.y - safe.x - safe.z, 120)
	_ground.position = Vector2(bars.x + safe.x, 150)
	_ground.size = Vector2(480 - bars.x - bars.y - safe.x - safe.z, 90)
	_text.position = Vector2(40 + bars.x + safe.x, 200)
	_text.size = Vector2(400 - safe.x - safe.z, 44)
	_hint.position = Vector2(bars.x + safe.x, 252 - safe.w)
	_hint.size = Vector2(480 - bars.x - bars.y - safe.x - safe.z, 14)

func _define_slides() -> void:
	_slides = [
		{"sky": Color(0.16, 0.1, 0.22), "ground": Color(0.12, 0.1, 0.08),
		 "props": [["tomb", 90, 3], ["tomb", 200, 4], ["tomb", 330, 3]], "dolls": [], "text": "story.intro.1"},
		{"sky": Color(0.05, 0.05, 0.12), "ground": Color(0.1, 0.09, 0.08),
		 "props": [["tomb", 60, 3], ["torch", 160, 3], ["tomb", 260, 4], ["torch", 380, 3]], "dolls": [], "text": "story.intro.2"},
		{"sky": Color(0.35, 0.55, 0.8), "ground": Color(0.2, 0.4, 0.2),
		 "props": [["fence", 70, 3], ["well", 210, 3], ["sign", 350, 3]], "dolls": [], "text": "story.intro.3"},
		{"sky": Color(0.75, 0.4, 0.25), "ground": Color(0.25, 0.2, 0.15),
		 "props": [["torch", 120, 3], ["torch", 360, 3]],
		 "dolls": [{"chest": "leather_vest", "weapon": "iron_sword", "legs": "leather_pants", "boots": "leather_boots"}], "text": "story.intro.4"},
		{"sky": Color(0.45, 0.1, 0.12), "ground": Color(0.15, 0.12, 0.1),
		 "props": [["tomb", 100, 3], ["tomb", 380, 3]],
		 "dolls": [{"chest": "iron_plate", "helmet": "iron_helm", "weapon": "battle_axe", "legs": "iron_greaves", "boots": "iron_boots", "accessory": "red_cloak"}], "text": "story.intro.5"},
	]

func play() -> void:
	_slide = 0
	active = true
	visible = true
	_apply_slide()

func _apply_slide() -> void:
	var s: Dictionary = _slides[_slide]
	_sky.color = s["sky"]
	_ground.color = s["ground"]
	for child in _stage.get_children():
		child.queue_free()
	for p in s["props"]:
		var spr := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/sprites/tiles/props.png")
		var idx: int = ArtIndex.PROP_INDEX[p[0]]
		at.region = Rect2(Vector2(idx % 8, idx / 8) * 16.0, Vector2(16, 16))
		spr.texture = at
		spr.centered = false
		spr.scale = Vector2.ONE * float(p[2])
		spr.position = Vector2(float(p[1]), 150.0 - 16.0 * float(p[2]))
		spr.modulate = Color(0.25, 0.22, 0.3) if _slide < 2 else Color(0.4, 0.35, 0.35)
		_stage.add_child(spr)
	for d in s["dolls"]:
		var doll := PaperDoll.new()
		_stage.add_child(doll)
		doll.scale = Vector2(2.5, 2.5)
		doll.position = Vector2(230, 150)
		for slot in d:
			doll.equip(slot, d[slot])
		doll.play("down", "idle", 0)
	_text.text = ""
	_reveal = 0.0
	_hint.text = I18N.tr_str("ui.tap")
	I18N.tag(_text)
	I18N.tag(_hint)

func _process(delta: float) -> void:
	if not visible:
		return
	_reveal = minf(_reveal + delta * 45.0, 300.0)
	_text.text = I18N.tr_str(_slides[_slide]["text"]).substr(0, int(_reveal))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		_end()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		_advance()
		get_viewport().set_input_as_handled()
		return
	# Touch parity: a tap advances the story; a tap in the top-right corner
	# skips the whole cutscene (the Esc equivalent on a phone).
	if event is InputEventScreenTouch and event.pressed:
		if event.position.x > 400.0 and event.position.y < 54.0:
			_end()
		else:
			_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	var full: String = I18N.tr_str(_slides[_slide]["text"])
	if _reveal < len(full):
		_reveal = 300.0
	else:
		_slide += 1
		if _slide >= _slides.size():
			_end()
		else:
			_apply_slide()

func _end() -> void:
	active = false
	visible = false
	Game.seen_intro = true
	finished.emit()

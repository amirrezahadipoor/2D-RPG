# Talking to people: portrait, typewriter, quest, shop — touch-native, responsive.
class_name DialogueUI
extends CanvasLayer

var npc: NPC = null
var _pages: Array = []       # {text, mode}
var _page := 0
var _reveal := 0.0
var _offer_index := -1
var _shop_offers: Array = []  # {entry, price, sold}
var _shop_sel := 0
var _shop_selected_row := -1

var _root: Control
var _box: ColorRect
var _edge: ColorRect
var _portrait_bg: ColorRect
var _portrait_body: TextureRect
var _portrait_hat: TextureRect
var _name: Label
var _text: Label
var _hint: Label

func _ready() -> void:
	layer = 25
	add_to_group("modal_ui")
	_build()
	_root.gui_input.connect(_on_pointer)
	visible = false
	Settings.settings_changed.connect(_layout)
	I18N.locale_changed.connect(func(_l): if visible: _apply_page())

func _build() -> void:
	_root = Control.new()
	_root.name = "DlgRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_box = ColorRect.new()
	_box.color = Color(0.07, 0.06, 0.1, 0.96)
	_root.add_child(_box)
	_edge = ColorRect.new()
	_edge.color = Color(0.5, 0.42, 0.28)
	_root.add_child(_edge)

	_portrait_bg = ColorRect.new()
	_portrait_bg.color = Color(0.15, 0.13, 0.2)
	_root.add_child(_portrait_bg)
	_portrait_body = TextureRect.new()
	_portrait_body.stretch_mode = TextureRect.STRETCH_KEEP
	_portrait_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_portrait_body)
	_portrait_hat = TextureRect.new()
	_portrait_hat.stretch_mode = TextureRect.STRETCH_KEEP
	_portrait_hat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_portrait_hat)

	for child: Control in _root.get_children():
		if child != _root:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 10)
	_name.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	_root.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 10)
	_text.add_theme_color_override("font_color", Color(0.92, 0.93, 1.0))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_text)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	_root.add_child(_hint)

	_layout()

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	var base_w := 480.0
	var base_h := 270.0
	# responsive box: 90% width minus safe margins, height auto
	var bw := minf(base_w - safe.x - safe.z - bars.x - bars.y - 24.0, 460.0)
	var bh := 86.0
	var bx := safe.x + bars.x + (base_w - safe.x - safe.z - bars.x - bars.y - bw) * 0.5
	var by := base_h - safe.w - bh - 12.0
	# ensure not under notch
	_edge.position = Vector2(bx - 1, by - 1)
	_edge.size = Vector2(bw + 2, bh + 2)
	_box.position = Vector2(bx, by)
	_box.size = Vector2(bw, bh)

	_portrait_bg.position = Vector2(bx + 6, by + 6)
	_portrait_bg.size = Vector2(54, 54)
	_portrait_body.position = Vector2(bx + 10, by + 18)
	_portrait_body.size = Vector2(48, 28)
	_portrait_hat.position = Vector2(bx + 10, by + 10)
	_portrait_hat.size = Vector2(48, 36)

	_name.position = Vector2(bx + 68, by + 4)
	_name.size = Vector2(bw - 74, 14)
	_text.position = Vector2(bx + 68, by + 18)
	_text.size = Vector2(bw - 74, 48)
	_hint.position = Vector2(bx + 68, by + 70)
	_hint.size = Vector2(bw - 74, 12)

func _process(delta: float) -> void:
	if not visible:
		return
	_reveal = minf(_reveal + delta * 60.0, 400.0)
	var page: Dictionary = _pages[_page]
	if page["mode"] == "shop":
		_text.text = _shop_text()
		_hint.text = _shop_hint()
		return
	_text.text = str(page["text"]).substr(0, int(_reveal))

func open_with(target: NPC) -> void:
	npc = target
	_pages = _compose_pages()
	_page = 0
	_reveal = 0.0
	_layout()
	_apply_page()
	visible = true
	QuestLog.on_talk(npc.sett_index, npc.role_name)

func close() -> void:
	visible = false
	npc = null

func _compose_pages() -> Array:
	var pages := []
	pages.append({"text": "%s\n%s" % [
		I18N.tr_str("npc.role." + npc.role_name),
		I18N.tr_str("npc.hello." + npc.role_name)], "mode": "talk"})
	var live_main := QuestLog.current_main()
	if npc.role_name in ["elder", "king"] and not live_main.is_empty():
		var act_line: String = I18N.tr_str("story.act.%d" % QuestLog.current_act())
		if not act_line.begins_with("story.act."):
			pages.append({"text": act_line, "mode": "talk"})
	var turn_in = QuestLog.turn_in_at(npc.sett_index, npc.role_name)
	if turn_in != null:
		pages.append({"text": QuestDB.desc_of(turn_in) + "\n%s: %s/%s" % [
			I18N.tr_str("quest.progress"), I18N.num(int(turn_in.get("progress", 0))),
			I18N.num(int(turn_in["goal"]))], "mode": "turn_in", "quest": turn_in})
	else:
		_offer_index = QuestLog.offer_at(npc.sett_index, npc.role_name)
		if _offer_index >= 0:
			var q := QuestDB.side_quest(_offer_index)
			var tone_key := "quest.tone." + String(q["kind"])
			var tone: String = I18N.tr_str(tone_key)
			var flavor := "" if tone == tone_key else tone + "\n"
			pages.append({"text": flavor + QuestDB.desc_of(q) + "\n%s: %s XP, %s G" % [
				I18N.tr_str("quest.reward"), I18N.num(int(q["xp"])), I18N.num(int(q["gold"]))],
				"mode": "offer"})
		elif npc.role_name == "merchant":
			_make_shop()
			pages.append({"text": "", "mode": "shop"})
		elif npc.role_name == "elder" or npc.role_name == "king":
			var m := QuestLog.current_main()
			if not m.is_empty():
				if QuestLog.main_gate_ok():
					pages.append({"text": QuestDB.desc_of(m) + "\n%s: %s/%s" % [
						I18N.tr_str("quest.progress"), I18N.num(int(m.get("progress", 0))),
						I18N.num(int(m["goal"]))], "mode": "main"})
				else:
					pages.append({"text": I18N.tr_str("quest.gate") % I18N.num(int(m["level_gate"])) +
						"\n" + QuestDB.desc_of(m), "mode": "talk"})
	pages.append({"text": "...", "mode": "bye"})
	return pages

func _make_shop() -> void:
	_shop_offers = []
	_shop_sel = 0
	_shop_selected_row = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = npc.npc_index * 131 + Game.day() * 17
	var lvl := maxi(1, Stats.level)
	_shop_offers.append({"entry": {"id": "health_potion", "slot": "", "rarity": 0,
		"prefix": "", "suffix": "", "dmg": 0, "armor": 0, "weight": 1, "qty": 1},
		"price": 25 + 8 * (lvl - 1), "sold": false})
	_shop_offers.append({"entry": {"id": "greater_health_potion", "slot": "", "rarity": 0,
		"prefix": "", "suffix": "", "dmg": 0, "armor": 0, "weight": 1, "qty": 1},
		"price": 60 + 16 * (lvl - 1), "sold": false})
	var entry: Dictionary = Inventory.roll_entry(ItemGen.random_id(rng), 0.25)
	_shop_offers.append({"entry": entry,
		"price": 40 * (int(entry["rarity"]) + 1) + 15 * (lvl - 1), "sold": false})

func _shop_text() -> String:
	var lines := []
	for i in _shop_offers.size():
		var o: Dictionary = _shop_offers[i]
		var mark := "> " if i == _shop_sel else "  "
		if o["sold"]:
			lines.append("%s%s  -" % [mark, ItemGen.name_of(o["entry"])])
		else:
			lines.append("%s%s  %s G" % [mark, ItemGen.name_of(o["entry"]), I18N.num(int(o["price"]))])
	return "\n".join(lines)

func _shop_hint() -> String:
	# touch-only: always touch hint (removed keyboard [W/S][E][K])
	return "%s: %s G  ·  %s" % [
		I18N.tr_str("hud.gold"), I18N.num(Stats.gold), I18N.tr_str("shop.touch")]

func _toast(key: String) -> void:
	for child in get_tree().root.get_children():
		var hud = child.get_node_or_null("Hud")
		if hud != null and hud.has_method("show_toast"):
			hud.show_toast(I18N.tr_str(key))
			return

func _apply_page() -> void:
	var page: Dictionary = _pages[_page]
	_reveal = 0.0
	if page["mode"] == "shop":
		var vp := get_viewport()
		if vp != null:
			var safe := SafeArea.get_safe_margins(vp)
			var bars := SafeArea.get_bars(vp)
			var base_w := 480.0
			var base_h := 270.0
			var bw := minf(base_w - safe.x - safe.z - bars.x - bars.y - 24.0, 460.0)
			var bh := 94.0
			var bx := safe.x + bars.x + (base_w - safe.x - safe.z - bars.x - bars.y - bw) * 0.5
			var by := base_h - safe.w - bh - 12.0
			_edge.size = Vector2(bw + 2, bh + 2)
			_box.size = Vector2(bw, bh)
			_edge.position = Vector2(bx - 1, by - 1)
			_box.position = Vector2(bx, by)
		_text.text = _shop_text()
		_hint.text = _shop_hint()
		I18N.tag(_hint)
		_name.text = npc.display_name
		I18N.tag(_name)
		_reveal = 400.0
		return
	_text.text = ""
	_name.text = npc.display_name
	if npc and npc.doll:
		var body: Sprite2D = npc.doll.get_node_or_null("Layer_body")
		var hat: Sprite2D = npc.doll.get_node_or_null("Layer_helmet")
		_portrait_body.texture = _head_atlas(body)
		_portrait_hat.texture = _head_atlas(hat)
	match page["mode"]:
		"offer":
			_hint.text = "%s: %s   %s: %s" % [I18N.tr_str("ui.tap"),
				I18N.tr_str("quest.accept"), I18N.tr_str("ui.tap"), I18N.tr_str("quest.decline")]
		"turn_in":
			_hint.text = "%s: %s" % [I18N.tr_str("ui.tap"), I18N.tr_str("quest.complete")]
		"bye":
			_hint.text = "%s: %s" % [I18N.tr_str("ui.tap"), I18N.tr_str("shop.leave")]
		_:
			_hint.text = I18N.tr_str("ui.tap")
	for l in [_name, _text, _hint]:
		I18N.tag(l)

func _head_atlas(layer: Sprite2D) -> Texture:
	if layer == null or layer.texture == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = layer.texture
	at.region = Rect2(0, 0, 24, 16)
	return at

var _tap_frame := -1

func _on_pointer(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := false
	var p: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		p = mb.position
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		pressed = st.pressed
		p = st.position
	if not pressed:
		return
	var frame := Engine.get_process_frames()
	if frame == _tap_frame:
		return
	_tap_frame = frame
	# responsive hit: inside box
	if not Rect2(_box.position, _box.size).has_point(p):
		# tap outside closes? no, keep open, but allow close via dim? dim is ignored
		return
	var page: Dictionary = _pages[_page]
	if page["mode"] == "shop":
		_shop_tap(p)
	else:
		_advance(page)
	get_viewport().set_input_as_handled()

func _shop_tap(tap_p: Vector2) -> void:
	# responsive row calc
	var row_h := 16.0 # bigger touch target
	var base_y := _text.position.y
	if tap_p.y < base_y - 4 or tap_p.y > base_y + _shop_offers.size() * row_h + 8:
		return
	var row := clampi(int((tap_p.y - base_y) / row_h), 0, _shop_offers.size() - 1)
	get_viewport().set_input_as_handled()
	if row != _shop_sel or _shop_selected_row != row:
		_shop_sel = row
		_shop_selected_row = row
		_text.text = _shop_text()
		Sfx.play("click", -14.0, 0.02)
		return
	var o: Dictionary = _shop_offers[_shop_sel]
	if not o["sold"] and Stats.gold >= int(o["price"]):
		Stats.add_gold(-int(o["price"]))
		Inventory.add(o["entry"].duplicate())
		Sfx.play("buy")
		o["sold"] = not Consumables.is_consumable(o["entry"]["id"])
		_text.text = _shop_text()
	else:
		_toast("shop.no_gold")

func _advance(page: Dictionary) -> void:
	Sfx.play("click", -10.0, 0.02)
	if _reveal < len(str(page["text"])):
		_reveal = 400.0
		get_viewport().set_input_as_handled()
		return
	match page["mode"]:
		"offer":
			QuestLog.start_side(_offer_index)
			_pages = _compose_pages()
			_page = 0
		"turn_in":
			QuestLog.complete(page["quest"])
			_pages = _compose_pages()
			_page = 0
		_:
			_page += 1
	if _page >= _pages.size():
		close()
	else:
		_apply_page()
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		# tap outside box closes dialogue (touch-native)
		var touch_ev: InputEventScreenTouch = event as InputEventScreenTouch
		var p: Vector2 = touch_ev.position
		if not Rect2(_box.position, _box.size).has_point(p):
			# allow tap outside to advance? For touch, outside tap closes
			close()
			get_viewport().set_input_as_handled()
			return
	# keyboard still works for desktop testing but hints are touch-only
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		var page: Dictionary = _pages[_page]
		_advance(page)
	elif event.is_action_pressed("dodge"):
		if _pages[_page]["mode"] == "offer":
			QuestLog.decline_side(_offer_index)
			_pages = _compose_pages()
			_page = 0
			_apply_page()
			get_viewport().set_input_as_handled()

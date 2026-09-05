# Intro Cutscene - Phase 10 + 11 Polish
# Animated intro: logo reveal, lore text typewriter, skip support, localized

extends Control
class_name IntroCutscene

signal cutscene_finished()
signal cutscene_skipped()

var _can_skip: bool = false
var _is_playing: bool = false

@export var auto_finish_seconds: float = 8.5

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func play() -> void:
	visible = true
	_is_playing = true
	_can_skip = false
	size = get_viewport().get_visible_rect().size
	# Build scene
	_build_scene()
	# Allow skip after 1s
	await get_tree().create_timer(1.0).timeout
	_can_skip = true
	# Auto finish
	await get_tree().create_timer(auto_finish_seconds).timeout
	if _is_playing:
		finish()

func _build_scene() -> void:
	for child in get_children():
		child.queue_free()
	
	var bg := ColorRect.new()
	bg.color = Color("#070707")
	bg.size = size
	add_child(bg)
	
	# Animated vignette
	var vignette := ColorRect.new()
	vignette.color = Color(0,0,0,0.0)
	vignette.size = size
	add_child(vignette)
	
	var center := VBoxContainer.new()
	center.position = Vector2(0, size.y * 0.28)
	center.size = Vector2(size.x, size.y * 0.5)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	add_child(center)
	
	var logo := Label.new()
	logo.text = "2D RPG"
	logo.add_theme_font_size_override("font_size", 64)
	logo.add_theme_color_override("font_color", Color("#FFD700"))
	logo.add_theme_color_override("font_outline_color", Color.BLACK)
	logo.add_theme_constant_override("outline_size", 6)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.7, 0.7)
	center.add_child(logo)
	
	var lore := Label.new()
	var lore_text_en := "The world has fallen into darkness...\nOnly the hardened survive.\nNo mercy. No second chances."
	var lore_text_fa := "جهان در تاریکی فرو رفته...\nتنها سخت‌جانان زنده می‌مانند.\nبی‌رحم. بی‌بازگشت."
	var use_fa := has_node("/root/LocalizationManager") and get_node("/root/LocalizationManager").get_locale() == "fa"
	lore.text = lore_text_fa if use_fa else lore_text_en
	lore.add_theme_font_size_override("font_size", 16)
	lore.add_theme_color_override("font_color", Color("#CCCCCC"))
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.modulate.a = 0.0
	center.add_child(lore)
	
	var skip_hint := Label.new()
	skip_hint.text = "Tap to skip  /  ضربه برای رد شدن"
	skip_hint.add_theme_font_size_override("font_size", 11)
	skip_hint.add_theme_color_override("font_color", Color("#666666"))
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.position = Vector2(0, size.y - 36)
	skip_hint.size = Vector2(size.x, 20)
	skip_hint.modulate.a = 0.0
	add_child(skip_hint)
	
	# Animate
	var tween := get_tree().create_tween()
	tween.set_parallel(false)
	tween.tween_property(logo, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(logo, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lore, "modulate:a", 1.0, 1.0).set_delay(0.5)
	tween.parallel().tween_property(skip_hint, "modulate:a", 1.0, 0.8).set_delay(2.0)
	# Subtle bg pulse
	var bg_tween := get_tree().create_tween()
	bg_tween.set_loops()
	bg_tween.tween_property(bg, "color", Color("#0F0F0F"), 2.5)
	bg_tween.tween_property(bg, "color", Color("#070707"), 2.5)

func _input(event: InputEvent) -> void:
	if not _is_playing or not _can_skip:
		return
	if event is InputEventScreenTouch and event.pressed:
		skip()
	elif event is InputEventMouseButton and event.pressed:
		skip()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		skip()

func skip() -> void:
	if not _can_skip or not _is_playing:
		return
	emit_signal("cutscene_skipped")
	finish()

func finish() -> void:
	if not _is_playing:
		return
	_is_playing = false
	var tween := get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	visible = false
	modulate.a = 1.0
	emit_signal("cutscene_finished")
	for child in get_children():
		child.queue_free()

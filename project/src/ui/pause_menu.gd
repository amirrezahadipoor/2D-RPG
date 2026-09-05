# Pause Menu - Phase 11 Polish
# Lightweight, blurred background, resume/settings/quit

extends Control
class_name PauseMenu

signal resume_requested()
signal settings_requested()
signal quit_to_menu_requested()

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_child_count() == 0:
		_build_procedural()

func _build_procedural() -> void:
	size = get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0,0,0,0.62)
	bg.size = size
	add_child(bg)
	
	var panel := Panel.new()
	panel.size = Vector2(340, 380)
	panel.position = (size - panel.size)/2
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1E1E1E")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0,0,0,0.5)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(panel.size.x - 40, panel.size.y - 40)
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "Paused  /  توقف"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var resume_btn := _btn("Resume", Color("#2E7D32"))
	vbox.add_child(resume_btn)
	resume_btn.pressed.connect(func(): emit_signal("resume_requested"))
	
	var settings_btn := _btn("Settings", Color("#4A4A4A"))
	vbox.add_child(settings_btn)
	settings_btn.pressed.connect(func(): emit_signal("settings_requested"))
	
	var save_btn := _btn("Save Checkpoint", Color("#1565C0"))
	vbox.add_child(save_btn)
	save_btn.pressed.connect(_on_save_checkpoint)
	
	var quit_btn := _btn("Quit to Menu", Color("#333333"))
	vbox.add_child(quit_btn)
	quit_btn.pressed.connect(func(): emit_signal("quit_to_menu_requested"))
	
	# Close on bg click
	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			emit_signal("resume_requested")
	)

func _btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.add_theme_font_size_override("font_size", 16)
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate()
	h.bg_color = col.lightened(0.12)
	b.add_theme_stylebox_override("hover", h)
	return b

func _on_save_checkpoint() -> void:
	if has_node("/root/GameManager"):
		var ok: bool = get_node("/root/GameManager").save_game(true)
		var lbl := Label.new()
		lbl.text = "✓ Saved" if ok else "✗ Save failed"
		lbl.add_theme_color_override("font_color", Color("#4CAF50") if ok else Color("#FF4444"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)
		lbl.position = Vector2(size.x/2 - 40, size.y/2 + 160)
		var tween := get_tree().create_tween()
		tween.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.8)
		tween.finished.connect(func(): if is_instance_valid(lbl): lbl.queue_free())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if visible:
			emit_signal("resume_requested")
			get_viewport().set_input_as_handled()

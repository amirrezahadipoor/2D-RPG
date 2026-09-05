# Visual Effects Manager - Phase 11 Polish
# Procedural VFX: hit flash, heal, level-up, chest open, critical, death
# All programmatic, no textures - lightweight for Android

extends Node
class_name VisualEffects

# Reusable tween helper
func _tween(node: Node) -> Tween:
	return get_tree().create_tween() if get_tree() else null

func play_hit_flash(target: CanvasItem, color: Color = Color("#FF4444")) -> void:
	if not target:
		return
	var orig_modulate: Color = target.modulate
	target.modulate = color
	var tween := _tween(target)
	if tween:
		tween.tween_property(target, "modulate", orig_modulate, 0.12)

func play_heal_effect(target: Node2D) -> void:
	if not target:
		return
	for i in range(5):
		var p := Label.new()
		p.text = "+"
		p.add_theme_font_size_override("font_size", 18)
		p.add_theme_color_override("font_color", Color("#4CAF50"))
		p.add_theme_color_override("font_outline_color", Color.BLACK)
		p.add_theme_constant_override("outline_size", 2)
		p.position = target.global_position + Vector2(randf_range(-10, 10), randf_range(-8, 8))
		p.z_index = 60
		get_tree().root.add_child(p)
		var tween := _tween(p)
		if tween:
			tween.tween_property(p, "position", p.position + Vector2(0, -22), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(p, "modulate:a", 0.0, 0.6).set_delay(0.2)
			tween.finished.connect(func(): if is_instance_valid(p): p.queue_free())

func play_level_up_effect(player_pos: Vector2) -> void:
	# Expanding golden ring + particles
	var ring := ColorRect.new()
	ring.color = Color("#FFD700", 0.0)
	ring.size = Vector2(8, 8)
	ring.position = player_pos - ring.size/2
	ring.z_index = 70
	get_tree().root.add_child(ring)
	var tween := _tween(ring)
	if tween:
		tween.set_parallel(true)
		tween.tween_property(ring, "size", Vector2(120, 120), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "position", player_pos - Vector2(60,60), 0.65)
		tween.tween_property(ring, "color:a", 0.45, 0.15)
		tween.chain().tween_property(ring, "color:a", 0.0, 0.45)
		tween.finished.connect(func(): if is_instance_valid(ring): ring.queue_free())
	# Star particles
	for i in range(8):
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 16)
		star.add_theme_color_override("font_color", Color("#FFE55C"))
		star.position = player_pos
		star.z_index = 71
		get_tree().root.add_child(star)
		var angle := (TAU/8.0)*i
		var target := player_pos + Vector2(cos(angle), sin(angle)) * randf_range(30, 55)
		var t2 := _tween(star)
		if t2:
			t2.tween_property(star, "position", target, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t2.parallel().tween_property(star, "modulate:a", 0.0, 0.7).set_delay(0.3)
			t2.finished.connect(func(): if is_instance_valid(star): star.queue_free())
	# Audio + screenshake via PolishManager
	if has_node("/root/PolishManager/JuiceController"):
		get_node("/root/PolishManager/JuiceController").shake_camera(4.0, 0.25)

func play_chest_open_effect(pos: Vector2, rarity: String) -> void:
	var colors := {"small": Color("#AAA"), "medium": Color("#4CAF50"), "large": Color("#2196F3"), "boss": Color("#FF9800")}
	var c: Color = colors.get(rarity, Color.GOLD)
	# Burst
	for i in range(10):
		var p := ColorRect.new()
		p.color = c
		p.size = Vector2(3, 3)
		p.position = pos
		p.z_index = 55
		get_tree().root.add_child(p)
		var angle := randf() * TAU
		var dist := randf_range(12, 36)
		var target := pos + Vector2(cos(angle), sin(angle)) * dist
		var tween := _tween(p)
		if tween:
			tween.tween_property(p, "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(p, "modulate:a", 0.0, 0.5).set_delay(0.2)
			tween.finished.connect(func(): if is_instance_valid(p): p.queue_free())

func play_critical_hit_effect(pos: Vector2) -> void:
	var label := Label.new()
	label.text = "CRITICAL!"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#FF3B30"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.position = pos + Vector2(-36, -24)
	label.z_index = 80
	label.scale = Vector2(0.5, 0.5)
	get_tree().root.add_child(label)
	var tween := _tween(label)
	if tween:
		tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12)
		tween.parallel().tween_property(label, "position", label.position + Vector2(0, -16), 0.8)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.4)
		tween.finished.connect(func(): if is_instance_valid(label): label.queue_free())

func play_death_effect(pos: Vector2) -> void:
	for i in range(12):
		var p := ColorRect.new()
		p.color = Color("#333333")
		p.size = Vector2(4,4)
		p.position = pos
		p.z_index = 40
		get_tree().root.add_child(p)
		var angle := (TAU/12.0)*i + randf_range(-0.15, 0.15)
		var dist := randf_range(18, 42)
		var target := pos + Vector2(cos(angle), sin(angle)) * dist
		var tween := _tween(p)
		if tween:
			tween.tween_property(p, "position", target + Vector2(0, 12), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(p, "modulate:a", 0.0, 0.6).set_delay(0.25)
			tween.finished.connect(func(): if is_instance_valid(p): p.queue_free())

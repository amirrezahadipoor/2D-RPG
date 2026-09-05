# Juice Controller - Phase 11 Visual/Game Feel Polish
# Handles screenshake, hitstop, tween punch, particles, vignette
# All procedural - no pre-made assets, mobile-optimized

extends Node
class_name JuiceController

@export var screenshake_enabled: bool = true
@export var hitstop_enabled: bool = true
@export var damage_numbers_enabled: bool = true

var _camera: Camera2D
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _original_camera_offset: Vector2

func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	if _camera:
		_original_camera_offset = _camera.offset

func _process(delta: float) -> void:
	if _shake_duration > 0:
		_shake_duration -= delta
		var intensity := _shake_intensity * (_shake_duration / max(0.01, _shake_duration + delta))
		if _camera:
			_camera.offset = _original_camera_offset + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		if _shake_duration <= 0:
			_shake_duration = 0
			if _camera:
				_camera.offset = _original_camera_offset

# Public API
func play_hit_feedback(damage: int, is_critical: bool, position: Vector2) -> void:
	# Screenshake
	if screenshake_enabled:
		shake_camera(clamp(damage * 0.4, 1.5, 8.0) * (1.6 if is_critical else 1.0), 0.18 if is_critical else 0.12)
	# Hitstop (freeze frames for impact)
	if hitstop_enabled and is_critical:
		hitstop(0.08)
	# Damage numbers
	if damage_numbers_enabled:
		spawn_damage_number(damage, is_critical, position)
	# Flash
	flash_screen(Color(1, 1, 1, 0.12) if is_critical else Color(1, 0.2, 0.2, 0.08))

func shake_camera(intensity: float, duration: float) -> void:
	if not screenshake_enabled or not _camera:
		return
	_camera = get_viewport().get_camera_2d()
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_duration = max(_shake_duration, duration)
	if _camera:
		_original_camera_offset = _camera.offset

func hitstop(duration: float) -> void:
	if not hitstop_enabled:
		return
	Engine.time_scale = 0.04
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func spawn_damage_number(damage: int, is_critical: bool, position: Vector2) -> void:
	# Create procedural damage label (no texture)
	var label := Label.new()
	label.text = str(damage) + ("!" if is_critical else "")
	label.add_theme_font_size_override("font_size", 22 if is_critical else 16)
	label.add_theme_color_override("font_color", Color("#FFD700") if is_critical else Color("#FFFFFF"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.position = position + Vector2(randf_range(-6, 6), -10)
	label.z_index = 100
	get_tree().root.add_child(label)
	# Animate up + fade
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -28), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tween.finished.connect(func(): if is_instance_valid(label): label.queue_free())

func flash_screen(color: Color) -> void:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.size = get_viewport().get_visible_rect().size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 99
	get_tree().root.add_child(overlay)
	var tween := get_tree().create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.22)
	tween.finished.connect(func(): if is_instance_valid(overlay): overlay.queue_free())

func play_pickup_effect(rarity: String, position: Vector2) -> void:
	var colors := {
		"common": Color("#AAAAAA"),
		"uncommon": Color("#4CAF50"),
		"rare": Color("#2196F3"),
		"epic": Color("#9C27B0"),
		"legendary": Color("#FF9800")
	}
	var c: Color = colors.get(rarity, Color.WHITE)
	# Spawn 6 particles bursting outward (procedural)
	for i in range(6):
		var p := ColorRect.new()
		p.color = c
		p.size = Vector2(4, 4)
		p.position = position
		p.z_index = 50
		get_tree().root.add_child(p)
		var angle := (TAU / 6.0) * i + randf_range(-0.2, 0.2)
		var dist := randf_range(14, 28)
		var target := position + Vector2(cos(angle), sin(angle)) * dist
		var tween := get_tree().create_tween()
		tween.tween_property(p, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.45).set_delay(0.15)
		tween.finished.connect(func(): if is_instance_valid(p): p.queue_free())
	# Light punch scale on pickup
	if has_node("/root/UIManager/HUD") and get_node("/root/UIManager/HUD").has_method("punch"):
		get_node("/root/UIManager/HUD").punch(1.08, 0.14)

func play_low_health_vignette(enabled: bool) -> void:
	# Find or create vignette overlay
	var vignette := get_node_or_null("/root/VignetteOverlay")
	if not vignette and enabled:
		vignette = ColorRect.new()
		vignette.name = "VignetteOverlay"
		vignette.color = Color(1, 0, 0, 0.0)
		vignette.size = get_viewport().get_visible_rect().size
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vignette.z_index = 90
		get_tree().root.add_child(vignette)
	if vignette:
		var tween := get_tree().create_tween()
		var target_alpha := 0.22 if enabled else 0.0
		tween.tween_property(vignette, "color:a", target_alpha, 0.6)

func punch_scale(node: Node, scale_amount: float = 1.15, duration: float = 0.2) -> void:
	if not node or not node.has_method("set_scale"):
		return
	var orig: Vector2 = node.scale if "scale" in node else Vector2.ONE
	var tween := get_tree().create_tween()
	tween.tween_property(node, "scale", orig * scale_amount, duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", orig, duration * 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

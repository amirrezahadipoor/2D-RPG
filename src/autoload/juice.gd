# Game-feel: screenshake, floating damage numbers, death puffs, hurt flash.
# Everything here is cosmetic and must never affect simulation results.
extends Node

signal hurt_taken

var _cam: Camera2D
var _world: Node
var _shake_power := 0.0
var _shake_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_camera(cam: Camera2D) -> void:
	_cam = cam

func register_world(world: Node) -> void:
	_world = world

# ---------------------------------------------------------------- shake -----
func shake(power: float) -> void:
	_shake_power = maxf(_shake_power, power)
	_shake_time = 0.22

func _process(delta: float) -> void:
	if _cam == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var t := clampf(_shake_time / 0.22, 0.0, 1.0)
		var mag := _shake_power * t
		_cam.offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
		if _shake_time <= 0.0:
			_cam.offset = Vector2.ZERO
			_shake_power = 0.0

# ----------------------------------------------------------------- hurt -----
func hurt() -> void:
	hurt_taken.emit()

# -------------------------------------------------------- damage numbers ----
func damage_number(world_pos: Vector2, amount: int, crit: bool) -> void:
	if _world == null:
		return
	var node := Node2D.new()
	node.global_position = world_pos + Vector2(randf_range(-3, 3), 0)
	_world.add_child(node)
	var label := Label.new()
	label.text = I18N.num(amount) + ("!" if crit else "")
	label.add_theme_font_size_override("font_size", 9 if crit else 8)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2) if crit else Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-8, -10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position", node.position + Vector2(0, -14), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(node.queue_free)

## Floating "miss" when a hit is dodged.
func miss(world_pos: Vector2) -> void:
	if _world == null:
		return
	var node := Node2D.new()
	node.global_position = world_pos
	_world.add_child(node)
	var label := Label.new()
	label.text = I18N.tr_str("combat.miss")
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-10, -6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position", node.position + Vector2(0, -10), 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(node.queue_free)

## Generic floating world-space text (loot names, quest notes, ...).
func world_text(world_pos: Vector2, text: String, color: Color, size: int = 8) -> void:
	if _world == null:
		return
	var node := Node2D.new()
	node.global_position = world_pos
	_world.add_child(node)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-30, -8)
	label.size = Vector2(60, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	I18N.tag(label)
	node.add_child(label)
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "position", node.position + Vector2(0, -12), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(node.queue_free)

# ----------------------------------------------------------------- puff -----
func puff(world_pos: Vector2) -> void:
	if _world == null:
		return
	var node := Node2D.new()
	node.global_position = world_pos
	_world.add_child(node)
	for i in 6:
		var bit := ColorRect.new()
		bit.color = Color(0.9, 0.9, 0.95, 0.9)
		bit.size = Vector2(2, 2)
		bit.position = Vector2.ZERO
		node.add_child(bit)
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 6.0 + randf_range(-0.3, 0.3))
		var tween := node.create_tween()
		tween.set_parallel(true)
		tween.tween_property(bit, "position", dir * randf_range(6, 12), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "modulate:a", 0.0, 0.35)
	var killer := node.create_tween()
	killer.tween_interval(0.4)
	killer.tween_callback(node.queue_free)

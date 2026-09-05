# Touch Controls - Phase 11 Polish
# Android virtual joystick + action buttons, dynamic sizing for phone readability
# Offline, no network, respects 64px minimum hero size

extends CanvasLayer
# class_name TouchControls

@export var joystick_enabled: bool = true
@export var joystick_radius: float = 62.0
@export var deadzone: float = 0.18
@export var button_size: float = 64.0 # minimum touch target (accessibility)

var _joystick_base_pos: Vector2 = Vector2(110, 0) # set in _ready based on viewport
var _touch_id: int = -1
var _current_vector: Vector2 = Vector2.ZERO
var _is_pressed: bool = false

# Action buttons
var _attack_pressed: bool = false
var _dodge_pressed: bool = false
var _interact_pressed: bool = false

# UI nodes
var _joystick_base: Control
var _joystick_knob: Control
var _attack_btn: Button
var _dodge_btn: Button
var _interact_btn: Button

signal joystick_vector_changed(vec: Vector2)
signal attack_pressed()
signal dodge_pressed()
signal interact_pressed()

func _ready() -> void:
	layer = 10 # above HUD
	# Only show on Android or if touch enabled
	var is_android := OS.get_name() == "Android"
	visible = is_android or joystick_enabled
	if not visible and not OS.has_feature("mobile"):
		# Desktop: allow toggle via settings
		visible = _load_touch_setting()
	
	_build_ui()
	_update_positions()
	get_viewport().size_changed.connect(_update_positions)
	print("[TouchControls] visible=", visible, " joystick_radius=", joystick_radius)

func _load_touch_setting() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		return cfg.get_value("input", "touch_enabled", false)
	return false

func _build_ui() -> void:
	# Joystick base
	_joystick_base = ColorRect.new()
	_joystick_base.name = "JoystickBase"
	_joystick_base.color = Color(1,1,1,0.18)
	_joystick_base.size = Vector2(joystick_radius*2, joystick_radius*2)
	# Circular via shader? For now rect with corner radius via style
	# Use panel style for rounded
	add_child(_joystick_base)
	
	_joystick_knob = ColorRect.new()
	_joystick_knob.name = "JoystickKnob"
	_joystick_knob.color = Color(1,1,1,0.55)
	_joystick_knob.size = Vector2(joystick_radius*0.9, joystick_radius*0.9)
	add_child(_joystick_knob)
	
	# Action buttons - bottom right
	_attack_btn = _create_action_button("⚔", Color("#FF4444"))
	_attack_btn.name = "AttackBtn"
	add_child(_attack_btn)
	_attack_btn.pressed.connect(func(): _attack_pressed = true; emit_signal("attack_pressed"))
	_attack_btn.button_down.connect(func(): Input.action_press("attack"))
	_attack_btn.button_up.connect(func(): Input.action_release("attack"))
	
	_dodge_btn = _create_action_button("◯", Color("#4CAF50"))
	_dodge_btn.name = "DodgeBtn"
	add_child(_dodge_btn)
	_dodge_btn.pressed.connect(func(): emit_signal("dodge_pressed"))
	_dodge_btn.button_down.connect(func(): Input.action_press("dodge"))
	_dodge_btn.button_up.connect(func(): Input.action_release("dodge"))
	
	_interact_btn = _create_action_button("✋", Color("#2196F3"))
	_interact_btn.name = "InteractBtn"
	add_child(_interact_btn)
	_interact_btn.button_down.connect(func(): Input.action_press("interact"))
	_interact_btn.button_up.connect(func(): Input.action_release("interact"))

func _create_action_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(button_size, button_size)
	b.add_theme_font_size_override("font_size", 26)
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.bg_color.a = 0.38
	style.corner_radius_top_left = int(button_size/2)
	style.corner_radius_top_right = int(button_size/2)
	style.corner_radius_bottom_left = int(button_size/2)
	style.corner_radius_bottom_right = int(button_size/2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color.a = 0.62
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b

func _update_positions() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Safe area - account for notch / gesture bar
	var safe_margin := 18.0
	# Joystick base: bottom-left, offset from corner
	_joystick_base_pos = Vector2(safe_margin + joystick_radius, vp.y - safe_margin - joystick_radius - 18)
	if _joystick_base:
		_joystick_base.position = _joystick_base_pos - Vector2(joystick_radius, joystick_radius)
		_joystick_knob.position = _joystick_base_pos - _joystick_knob.size/2
	# Buttons: bottom-right, stacked
	var btn_y := vp.y - safe_margin - button_size - 18
	var btn_x_start := vp.x - safe_margin - button_size
	if _attack_btn:
		_attack_btn.position = Vector2(btn_x_start, btn_y - button_size - 10)
	if _dodge_btn:
		_dodge_btn.position = Vector2(btn_x_start - button_size - 12, btn_y)
	if _interact_btn:
		_interact_btn.position = Vector2(btn_x_start, btn_y)

func _input(event: InputEvent) -> void:
	if not visible or not joystick_enabled:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos := event.position
	var dist_to_joy := pos.distance_to(_joystick_base_pos)
	if event.pressed:
		if dist_to_joy <= joystick_radius * 1.45:
			_touch_id = event.index
			_is_pressed = true
			_update_knob(pos)
	else:
		if event.index == _touch_id:
			_touch_id = -1
			_is_pressed = false
			_current_vector = Vector2.ZERO
			emit_signal("joystick_vector_changed", Vector2.ZERO)
			# Reset knob
			if _joystick_knob:
				_joystick_knob.position = _joystick_base_pos - _joystick_knob.size/2

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_id:
		return
	_update_knob(event.position)

func _update_knob(touch_pos: Vector2) -> void:
	var delta := touch_pos - _joystick_base_pos
	var dist := delta.length()
	var clamped_delta := delta
	if dist > joystick_radius:
		clamped_delta = delta.normalized() * joystick_radius
	if _joystick_knob:
		_joystick_knob.position = _joystick_base_pos + clamped_delta - _joystick_knob.size/2
	# Compute vector
	var vec := clamped_delta / joystick_radius
	if vec.length() < deadzone:
		vec = Vector2.ZERO
	else:
		# Remap deadzone to 0-1
		var len := (vec.length() - deadzone) / (1.0 - deadzone)
		vec = vec.normalized() * clamp(len, 0.0, 1.0)
	_current_vector = vec
	emit_signal("joystick_vector_changed", vec)
	# Inject as input actions for player_movement.gd to read via TouchControls.get_movement_vector
	# Also directly set Input actions for compatibility
	if vec.x > 0.2:
		Input.action_press("ui_right", vec.x)
	else:
		Input.action_release("ui_right")
	if vec.x < -0.2:
		Input.action_press("ui_left", abs(vec.x))
	else:
		Input.action_release("ui_left")
	if vec.y > 0.2:
		Input.action_press("ui_down", vec.y)
	else:
		Input.action_release("ui_down")
	if vec.y < -0.2:
		Input.action_press("ui_up", abs(vec.y))
	else:
		Input.action_release("ui_up")

func get_movement_vector() -> Vector2:
	return _current_vector

func is_joystick_active() -> bool:
	return _is_pressed and _current_vector.length() > deadzone

func set_joystick_enabled(enabled: bool) -> void:
	joystick_enabled = enabled
	visible = enabled
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("input", "touch_enabled", enabled)
	cfg.save("user://settings.cfg")

func get_button_size() -> float:
	return button_size

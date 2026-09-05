# Touch controls for Android: a virtual stick (left) and action buttons
# (right). Touches are translated into the very same input actions the
# keyboard uses, via Input.parse_input_event(InputEventAction) — so every
# system (hero, menus, dialogue) works unchanged on touch.
class_name TouchUI
extends CanvasLayer

const STICK_CENTER := Vector2(64, 208)
const STICK_RADIUS := 26.0
const KNOB_RADIUS := 11.0
const BUTTONS := {
	"attack":   {"pos": Vector2(430, 214), "r": 15.0, "glyph": "A"},
	"dodge":    {"pos": Vector2(402, 236), "r": 12.0, "glyph": "K"},
	"interact": {"pos": Vector2(452, 184), "r": 12.0, "glyph": "E"},
	"use_potion": {"pos": Vector2(376, 216), "r": 11.0, "glyph": "H"},
	"pause":    {"pos": Vector2(468, 12), "r": 9.0, "glyph": "="},
}

var enabled := false
var _root: Control
var _stick_id := -1
var _stick_vec := Vector2.ZERO
var _button_ids := {}           # action -> touch index
var _move_state := {"move_left": false, "move_right": false,
	"move_up": false, "move_down": false}

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := _TouchPainter.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.owner_ui = self
	_root.add_child(bg)
	visible = false
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		set_enabled(true)

func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if not on:
		_release_all()

func _release_all() -> void:
	for action in _move_state:
		if _move_state[action]:
			_emit_action(action, false)
			_move_state[action] = false
	for action in _button_ids.keys():
		_emit_action(action, false)
	_button_ids.clear()
	_stick_id = -1
	_stick_vec = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var inv := _root.get_canvas_transform().affine_inverse()
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_press(inv * t.position, t.index)
		else:
			_lift(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _stick_id:
			_update_stick(inv * d.position)

func _press(pos: Vector2, index: int) -> void:
	if pos.distance_to(STICK_CENTER) < STICK_RADIUS * 1.8:
		_stick_id = index
		_update_stick(pos)
		return
	for action in BUTTONS:
		var b: Dictionary = BUTTONS[action]
		if pos.distance_to(b["pos"]) < b["r"] + 6.0:
			_button_ids[action] = index
			_emit_action(action, true)
			Sfx.play("click", -16.0, 0.02)
			return

func _lift(index: int) -> void:
	if index == _stick_id:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		_sync_move()
		return
	for action in _button_ids.keys():
		if _button_ids[action] == index:
			_emit_action(action, false)
			_button_ids.erase(action)
			return

func _update_stick(pos: Vector2) -> void:
	var v := pos - STICK_CENTER
	if v.length() > STICK_RADIUS:
		v = v.normalized() * STICK_RADIUS
	_stick_vec = v
	_sync_move()

func _sync_move() -> void:
	var dead := 6.0
	var want := {
		"move_left": _stick_vec.x < -dead,
		"move_right": _stick_vec.x > dead,
		"move_up": _stick_vec.y < -dead,
		"move_down": _stick_vec.y > dead,
	}
	for action in want:
		if want[action] != _move_state[action]:
			_move_state[action] = want[action]
			_emit_action(action, want[action])

func _emit_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)

# ---------------------------------------------------------------- painter ----
class _TouchPainter extends Control:
	var owner_ui: TouchUI

	func _draw() -> void:
		# stick base + knob
		draw_circle(TouchUI.STICK_CENTER, TouchUI.STICK_RADIUS, Color(1, 1, 1, 0.10))
		draw_arc(TouchUI.STICK_CENTER, TouchUI.STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 1.0)
		draw_circle(TouchUI.STICK_CENTER + owner_ui._stick_vec, TouchUI.KNOB_RADIUS, Color(1, 1, 1, 0.30))
		# buttons
		for action in TouchUI.BUTTONS:
			var b: Dictionary = TouchUI.BUTTONS[action]
			var held: bool = owner_ui._button_ids.has(action)
			draw_circle(b["pos"], b["r"], Color(1, 1, 1, 0.30 if held else 0.10))
			draw_arc(b["pos"], b["r"], 0, TAU, 40, Color(1, 1, 1, 0.4), 1.0)
			draw_string(ThemeDB.fallback_font, b["pos"] + Vector2(-3, 3), b["glyph"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.75))

	func _process(_delta: float) -> void:
		queue_redraw()

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
	"inventory": {"pos": Vector2(24, 152), "r": 9.0, "glyph": "B"},
	"quests":   {"pos": Vector2(48, 152), "r": 9.0, "glyph": "J"},
	"talents":  {"pos": Vector2(72, 152), "r": 9.0, "glyph": "T"},
	"map":      {"pos": Vector2(96, 152), "r": 9.0, "glyph": "M"},
}
## toggle actions release themselves a beat after the tap
const TOGGLE_ACTIONS := {"inventory": 1, "quests": 1, "talents": 1, "pause": 1, "map": 1}

var enabled := false
var auto := false            # enabled by _ready() on real mobile builds
var _blocked := false        # a modal / pause / cutscene owns the screen
var _root: Control
var _stick_id := -1
var _stick_vec := Vector2.ZERO
var _button_ids := {}           # action -> touch index
var _auto_release := {}         # action -> seconds left
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
	# auto-enable only on real mobile builds: desktop touchscreens and X
	# servers without pads report phantom touch devices
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		auto = true
		set_enabled(true)

func set_enabled(on: bool) -> void:
	enabled = on
	_sync_visible()
	if not on:
		_release_all()

func _sync_visible() -> void:
	visible = enabled and not _blocked

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

## The gameplay overlay must never float above (or fire inside) a menu:
## any modal, the pause/menu state, the map or a cutscene takes the whole
## screen and the whole input stream (audit P0-3).
func _gate() -> void:
	var blocked := Game.state != Game.State.PLAYING or get_tree().paused
	if not blocked:
		for ui in get_tree().get_nodes_in_group("modal_ui"):
			if ui.visible:
				blocked = true
				break
	if not blocked:
		var cs := get_tree().get_first_node_in_group("cutscene")
		if cs != null and bool(cs.get("active")):
			blocked = true
	if blocked == _blocked:
		return
	_blocked = blocked
	if blocked:
		_release_all()
	_sync_visible()

func _process(delta: float) -> void:
	_gate()
	for action in _auto_release.keys():
		_auto_release[action] = float(_auto_release[action]) - delta
		if _auto_release[action] <= 0.0:
			_emit_action(action, false)
			_button_ids.erase(action)
			_auto_release.erase(action)

func _input(event: InputEvent) -> void:
	if not enabled or _blocked:
		return
	# Positions arriving at _input are ALREADY in canvas (design) space: the
	# viewport applies the stretch + letterbox transform before delivery
	# (measured at 16:9 and 20:9 windows). Re-transforming them here used to
	# shrink every finger position by the scale factor on real windows.
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_press(t.position, t.index)
		else:
			_lift(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _stick_id:
			_update_stick(d.position)

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
			if TOGGLE_ACTIONS.has(action):
				_auto_release[action] = 0.12
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

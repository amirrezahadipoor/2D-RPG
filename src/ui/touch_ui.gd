# Touch-native input for the Android build. NO virtual stick, NO Sega-style
# buttons: the whole game is played with gestures on the world itself.
#
#   tap   on ground          -> hero walks there
#   tap   on npc/chest/loot/
#         stairs/door/bed    -> hero walks over and interacts (talk/pick/open)
#   tap   on enemy           -> hero walks over and fights (auto-combat)
#   drag  (hold + move)      -> pans the camera to look around the realm
#   flick (fast short swipe) -> dodge-dash in the flick direction
#
# Menus live in small HUD chips (see hud.gd), not in a gameplay overlay.
class_name TouchUI
extends CanvasLayer

const TAP_TIME := 0.30          # seconds; longer press = not a tap
const TAP_MOVE := 14.0          # design px slop (was 9, too tight on 20:9) BUG-103
const PAN_START := 16.0         # design px before a hold becomes a pan (was 12) BUG-104
const FLICK_SPEED := 900.0      # design px/s (was 600, too sensitive) BUG-105

var enabled := false
var auto := false               # enabled by _ready() on real mobile builds
var _blocked := false           # a modal / pause / cutscene owns the screen

var _down := false
var _primary_index := -1
var _down_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _down_ms := 0
var _moved := 0.0
var _panning := false
var _last_drag_ms := 0
var _drag_vel := Vector2.ZERO
var _active_touches: Dictionary = {} # index -> pos (BUG-101 multi-touch lock fix)
var _multi_block := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		auto = true
		set_enabled(true)

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_cancel()

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
		_cancel()

func _process(_delta: float) -> void:
	_gate()
	if _panning and Time.get_ticks_msec() - _last_drag_ms > 80:
		_drag_vel = Vector2.ZERO

func _cancel() -> void:
	if _panning:
		_pan_end()
	_down = false
	_primary_index = -1
	_panning = false
	_active_touches.clear()
	_multi_block = false

func _input(event: InputEvent) -> void:
	if not enabled or _blocked:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_active_touches[t.index] = t.position
			if _active_touches.size() > 1:
				_multi_block = true
				if _panning:
					_pan_end()
					_panning = false
				return
			var vp := get_viewport().get_visible_rect().size
			if t.position.x < 0.0 or t.position.y < 0.0 or t.position.x > vp.x or t.position.y > vp.y:
				_active_touches.erase(t.index)
				return
			if _on_chip(t.position):
				_active_touches.erase(t.index)
				return
			_down = true
			_primary_index = t.index
			_down_pos = t.position
			_last_pos = t.position
			_down_ms = Time.get_ticks_msec()
			_moved = 0.0
			_panning = false
			_drag_vel = Vector2.ZERO
			_multi_block = false
		else:
			var was_primary := t.index == _primary_index
			_active_touches.erase(t.index)
			if not was_primary:
				if _active_touches.size() == 0:
					_multi_block = false
				return
			if _active_touches.size() == 0:
				if _multi_block:
					_cancel()
				else:
					_finish()
			else:
				_cancel()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index != _primary_index:
			if _active_touches.has(d.index):
				_active_touches[d.index] = d.position
			return
		if _multi_block or _active_touches.size() > 1:
			return
		var delta := d.position - _last_pos
		_last_pos = d.position
		_active_touches[d.index] = d.position
		_moved += delta.length()
		if not _panning and _moved > PAN_START:
			_panning = true
			_last_drag_ms = Time.get_ticks_msec()
		if _panning:
			var now := Time.get_ticks_msec()
			var dt := maxf(8.0, float(now - _last_drag_ms)) / 1000.0
			_last_drag_ms = now
			_drag_vel = _drag_vel.lerp(delta / dt, 0.6)
			_pan(delta)

func _finish() -> void:
	var held := float(Time.get_ticks_msec() - _down_ms) / 1000.0
	if _panning:
		if held < TAP_TIME and _drag_vel.length() > FLICK_SPEED:
			_flick(_drag_vel.normalized())
		else:
			_pan_end()
	elif held <= TAP_TIME and _moved <= TAP_MOVE:
		_tap(_down_pos)
	_down = false
	_primary_index = -1
	_panning = false
	_active_touches.clear()
	_multi_block = false

# ------------------------------------------------------------- gestures ----
func _hero() -> Hero:
	var n := get_tree().get_first_node_in_group("player")
	return n as Hero

func _on_chip(design_pos: Vector2) -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("chip_hit"):
		return hud.chip_hit(design_pos)
	return false

func _to_world(design_pos: Vector2) -> Vector2:
	var hero := _hero()
	if hero == null:
		return design_pos
	return hero.get_canvas_transform().affine_inverse() * design_pos

func _tap(design_pos: Vector2) -> void:
	var hero := _hero()
	if hero == null:
		return
	hero.command_tap(_to_world(design_pos))

func _pan(delta_design: Vector2) -> void:
	var hero := _hero()
	if hero == null:
		return
	hero.cam_pan_add(-delta_design)

func _pan_end() -> void:
	var hero := _hero()
	if hero != null:
		hero.cam_pan_return()

func _flick(dir: Vector2) -> void:
	var hero := _hero()
	if hero == null:
		return
	hero.cam_pan_return()
	hero.command_dodge(dir)

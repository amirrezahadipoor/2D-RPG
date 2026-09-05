# Polish Manager - Phase 11 Central Controller
# Hardcore offline 2D RPG for Android (Godot 4.x)
# Orchestrates all polish systems: juice, performance, audio, save, UI, localization
# Offline-only: no network calls at runtime, all polish is local & deterministic

extends Node
class_name PolishManager

# Singleton access
static var instance: PolishManager

# Sub-systems (injected in _ready)
@onready var juice: Node = $JuiceController if has_node("JuiceController") else null
@onready var perf: Node = $PerformanceOptimizer if has_node("PerformanceOptimizer") else null
@onready var audio_mgr: Node = $AudioManager if has_node("AudioManager") else null
@onready var save_mgr: Node = $SaveManager if has_node("SaveManager") else null

# Polish state
var is_paused: bool = false
var hardcore_mode: bool = true # hardcore: permadeath or checkpoint only
var polish_enabled: bool = true

# Performance metrics
var frame_time_ms: float = 0.0
var last_fps: int = 60

signal polish_toggled(enabled: bool)
signal game_paused(paused: bool)

func _init():
	if instance == null:
		instance = self

func _ready() -> void:
	instance = self
	# Ensure offline compliance: verify no HTTPRequest nodes are active at runtime
	_verify_offline_compliance()
	
	# Apply Android polish defaults
	_apply_android_defaults()
	
	# Connect to performance
	set_process(true)
	print("[PolishManager] Phase 11 Polish initialized - hardcore=", hardcore_mode, " offline-only verified")

func _process(_delta: float) -> void:
	frame_time_ms = (1.0 / max(1, Engine.get_frames_per_second())) * 1000.0
	last_fps = Engine.get_frames_per_second()
	
	# Auto-quality adjustment for low-end Android
	if perf and last_fps < 45 and perf.has_method("downgrade_quality"):
		perf.downgrade_quality()
	elif perf and last_fps > 58 and perf.has_method("upgrade_quality"):
		perf.upgrade_quality()

func _verify_offline_compliance() -> void:
	# Ensure no network at runtime - hardcore offline RPG requirement
	var all_nodes := get_tree().get_nodes_in_group("network") if get_tree() else []
	if all_nodes.size() > 0:
		push_warning("[PolishManager] Network nodes found at runtime - removing for offline compliance")
		for n in all_nodes:
			n.queue_free()
	# Check for HTTPRequest nodes
	if get_tree():
		var http_nodes := _find_nodes_of_type(get_tree().root, "HTTPRequest")
		if http_nodes.size() > 0:
			push_warning("[PolishManager] HTTPRequest nodes detected - offline-only violation, disabling")
			for h in http_nodes:
				h.queue_free()

func _find_nodes_of_type(node: Node, type: String) -> Array:
	var result := []
	if node.get_class() == type:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes_of_type(child, type))
	return result

func _apply_android_defaults() -> void:
	# Ensure 64px minimum hero readability on phone
	if get_viewport():
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.x < 720:
			# Low-res phone: increase UI scale
			if has_node("/root/UIManager") and get_node("/root/UIManager").has_method("set_ui_scale"):
				get_node("/root/UIManager").set_ui_scale(1.15)

# Public API - called by other systems
func trigger_hit_feedback(damage: int, is_critical: bool, position: Vector2) -> void:
	if not polish_enabled:
		return
	if juice and juice.has_method("play_hit_feedback"):
		juice.play_hit_feedback(damage, is_critical, position)
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("hit" if not is_critical else "crit", position)

func trigger_pickup_feedback(item_rarity: String, position: Vector2) -> void:
	if not polish_enabled:
		return
	if juice and juice.has_method("play_pickup_effect"):
		juice.play_pickup_effect(item_rarity, position)
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("pickup_%s" % item_rarity)

func on_player_stamina_changed(current: float, max_val: float) -> void:
	if has_node("/root/UIManager/HUD") and get_node("/root/UIManager/HUD").has_method("update_stamina"):
		get_node("/root/UIManager/HUD").update_stamina(current, max_val)

func on_player_health_changed(current: int, max_val: int) -> void:
	if has_node("/root/UIManager/HUD") and get_node("/root/UIManager/HUD").has_method("update_health"):
		get_node("/root/UIManager/HUD").update_health(current, max_val)
	if current <= max_val * 0.25 and juice:
		if juice.has_method("play_low_health_vignette"):
			juice.play_low_health_vignette(true)
	elif juice and juice.has_method("play_low_health_vignette"):
		juice.play_low_health_vignette(false)

func set_polish_enabled(enabled: bool) -> void:
	polish_enabled = enabled
	emit_signal("polish_toggled", enabled)

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	emit_signal("game_paused", true)

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	emit_signal("game_paused", false)

func get_metrics() -> Dictionary:
	return {
		"fps": last_fps,
		"frame_ms": frame_time_ms,
		"polish_enabled": polish_enabled,
		"hardcore": hardcore_mode,
		"save_exists": save_mgr.has_save() if save_mgr and save_mgr.has_method("has_save") else false
	}

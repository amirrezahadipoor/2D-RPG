# Performance Optimizer - Phase 11
# Mobile/Android optimization: object pooling, LOD, texture management, FPS guard
# Offline-only, no network

extends Node
class_name PerformanceOptimizer

enum QualityLevel { LOW, MEDIUM, HIGH }

@export var current_quality: QualityLevel = QualityLevel.MEDIUM
@export var target_fps: int = 60
@export var pool_enabled: bool = true

# Object pools
var _pools: Dictionary = {} # type -> Array[Node]
var _active_counts: Dictionary = {}

# LOD distances (pixels)
const LOD_NEAR := 400.0
const LOD_FAR := 900.0

var _frame_history: Array[float] = []
var _quality_cooldown: float = 0.0

func _ready() -> void:
	# Detect device tier
	var viewport_size := get_viewport().get_visible_rect().size
	var max_dim := max(viewport_size.x, viewport_size.y)
	if max_dim < 720 or OS.get_processor_count() <= 4:
		current_quality = QualityLevel.LOW
	elif max_dim >= 1080 and OS.get_processor_count() >= 8:
		current_quality = QualityLevel.HIGH
	apply_quality(current_quality)
	print("[PerformanceOptimizer] quality=", QualityLevel.keys()[current_quality], " cpus=", OS.get_processor_count(), " viewport=", viewport_size)

func _process(delta: float) -> void:
	_quality_cooldown = max(0, _quality_cooldown - delta)
	_frame_history.append(delta)
	if _frame_history.size() > 60:
		_frame_history.pop_front()

func apply_quality(level: QualityLevel) -> void:
	current_quality = level
	match level:
		QualityLevel.LOW:
			Engine.max_fps = 30
			get_viewport().msaa_2d = Viewport.MSAA_DISABLED
			# Reduce particles, disable shadows
		QualityLevel.MEDIUM:
			Engine.max_fps = 60
			get_viewport().msaa_2d = Viewport.MSAA_2X
		QualityLevel.HIGH:
			Engine.max_fps = 60
			get_viewport().msaa_2d = Viewport.MSAA_4X
	# Notify other systems
	get_tree().call_group("quality_listener", "_on_quality_changed", level)

func downgrade_quality() -> void:
	if _quality_cooldown > 0:
		return
	if current_quality > QualityLevel.LOW:
		apply_quality((current_quality - 1) as QualityLevel)
		_quality_cooldown = 3.0
		print("[PerformanceOptimizer] downgraded to ", QualityLevel.keys()[current_quality])

func upgrade_quality() -> void:
	if _quality_cooldown > 0:
		return
	if current_quality < QualityLevel.HIGH and _get_avg_fps() > 57:
		apply_quality((current_quality + 1) as QualityLevel)
		_quality_cooldown = 5.0

func _get_avg_fps() -> float:
	if _frame_history.size() == 0:
		return 60.0
	var avg_delta := 0.0
	for d in _frame_history:
		avg_delta += d
	avg_delta /= _frame_history.size()
	return 1.0 / max(0.001, avg_delta)

# Object pooling
func get_pooled(type: String, scene: PackedScene) -> Node:
	if not pool_enabled:
		return scene.instantiate() if scene else null
	if not _pools.has(type):
		_pools[type] = []
		_active_counts[type] = 0
	var pool: Array = _pools[type]
	if pool.size() > 0:
		var node: Node = pool.pop_back()
		node.visible = true
		node.process_mode = Node.PROCESS_MODE_INHERIT
		_active_counts[type] += 1
		return node
	_active_counts[type] += 1
	return scene.instantiate() if scene else null

func return_to_pool(type: String, node: Node) -> void:
	if not pool_enabled or not node:
		if node:
			node.queue_free()
		return
	if not _pools.has(type):
		_pools[type] = []
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	# Reset position
	if "position" in node:
		node.position = Vector2(-9999, -9999)
	_pools[type].append(node)
	_active_counts[type] = max(0, (_active_counts.get(type, 1) - 1))

func get_pool_stats() -> Dictionary:
	return {"pools": _pools.keys(), "active": _active_counts.duplicate()}

func should_cull(distance: float) -> bool:
	match current_quality:
		QualityLevel.LOW:
			return distance > LOD_FAR * 0.7
		QualityLevel.MEDIUM:
			return distance > LOD_FAR
		QualityLevel.HIGH:
			return distance > LOD_FAR * 1.4
	return false

func get_lod_level(distance: float) -> int:
	if distance < LOD_NEAR:
		return 0 # full detail
	elif distance < LOD_FAR:
		return 1 # medium
	else:
		return 2 # low / culled

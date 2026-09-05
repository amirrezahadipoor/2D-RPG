# Player Movement Script for 2D RPG - Phase 1 & 11 Polish - Fixed
# Godot 4.x - CharacterBody2D
# Hardcore offline RPG - minimum 64x64 logical pixels

extends CharacterBody2D

const SPEED := 180.0
const ACCELERATION := 1200.0
const FRICTION := 1400.0
const SPRINT_MULTIPLIER := 1.35
const MIN_HERO_SIZE_PX := 64.0

@export var max_stamina: float = 100.0
@export var stamina_drain_per_sec: float = 18.0
@export var stamina_regen_per_sec: float = 28.0
@export var stamina_sprint_drain: float = 25.0

var stamina: float = 100.0
var is_sprinting: bool = false
var is_moving: bool = false
var last_direction: Vector2 = Vector2.DOWN
var input_direction: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal stamina_changed(current: float, max_val: float)
signal started_moving(direction: Vector2)
signal stopped_moving()

func _ready() -> void:
	stamina = max_stamina
	
	# Connect to PlayerStats if exists
	if has_node("/root/PlayerStats"):
		var stats = get_node("/root/PlayerStats")
		max_stamina = stats.max_stamina
		stamina = stats.stamina
		stats.stamina_changed.connect(_on_stamina_changed)

func _physics_process(delta: float) -> void:
	# Input collection
	input_direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_direction.y += 1
	if Input.is_action_pressed("ui_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_direction.x += 1
	
	# Touch override
	if has_node("/root/TouchControls"):
		var touch_vec = get_node("/root/TouchControls").get_movement_vector()
		if touch_vec.length() > 0.1:
			input_direction = touch_vec
	
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	is_sprinting = Input.is_action_pressed("sprint") and stamina > 0 and input_direction.length() > 0
	var current_speed = SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)
	
	# Stamina handling
	if input_direction.length() > 0:
		if is_sprinting:
			stamina = maxf(0.0, stamina - stamina_sprint_drain * delta)
		else:
			stamina = maxf(0.0, stamina - stamina_drain_per_sec * 0.15 * delta)
		
		if stamina <= 0:
			current_speed = SPEED * 0.6
	else:
		stamina = minf(max_stamina, stamina + stamina_regen_per_sec * delta)
		emit_signal("stamina_changed", stamina, max_stamina)
	
	# Update PlayerStats
	if has_node("/root/PlayerStats"):
		var stats = get_node("/root/PlayerStats")
		stats.stamina = stamina
	
	# Movement
	var target_velocity = input_direction * current_speed
	if input_direction.length() > 0:
		velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)
		if not is_moving:
			emit_signal("started_moving", input_direction)
		is_moving = true
		last_direction = input_direction
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		if is_moving and velocity.length() < 5.0:
			emit_signal("stopped_moving")
			is_moving = false
	
	move_and_slide()
	update_animation()
	enforce_camera_bounds()

func update_animation() -> void:
	if sprite == null:
		return
	
	var anim_prefix = "idle" if not is_moving else "run"
	
	var dir_suffix = "down"
	if absf(last_direction.x) > absf(last_direction.y):
		dir_suffix = "right" if last_direction.x > 0 else "left"
	else:
		dir_suffix = "down" if last_direction.y > 0 else "up"
	
	# Flip handling
	if dir_suffix == "left":
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func enforce_camera_bounds() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return
	
	var zoom = camera.zoom
	if zoom.x == 0 or zoom.y == 0:
		return
	
	var min_zoom = MIN_HERO_SIZE_PX / 64.0
	if zoom.x < min_zoom:
		camera.zoom = Vector2(min_zoom, min_zoom)

func _on_stamina_changed(current: float, max_val: float) -> void:
	stamina = current
	max_stamina = max_val

func get_movement_speed() -> float:
	return SPEED

func get_stamina_percent() -> float:
	return stamina / max_stamina if max_stamina > 0 else 0.0

func has_stamina(amount: float) -> bool:
	return stamina >= amount

func consume_stamina(amount: float) -> bool:
	if stamina >= amount:
		stamina -= amount
		emit_signal("stamina_changed", stamina, max_stamina)
		return true
	return false

func restore_stamina(amount: float) -> void:
	stamina = minf(max_stamina, stamina + amount)
	emit_signal("stamina_changed", stamina, max_stamina)

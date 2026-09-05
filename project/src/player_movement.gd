# Player Movement Script for 2D RPG - Phase 1 & 11 Polish
# Godot 4.x - CharacterBody2D (migrated from KinematicBody2D)
# Hardcore offline RPG - minimum 64x64 logical pixels, never shrinks below readable size
# Phase 11 Polish: added stamina gating, juice integration, touch support, camera polish

extends CharacterBody2D

# Configuration - tuned for hardcore feel + mobile readability
const SPEED := 180.0  # pixels per second
const ACCELERATION := 1200.0
const FRICTION := 1400.0
const SPRINT_MULTIPLIER := 1.35
const MIN_HERO_SIZE_PX := 64.0

# Stamina system (integrated with combat core Phase 3)
@export var max_stamina: float = 100.0
@export var stamina_drain_per_sec: float = 18.0 # moving drains stamina
@export var stamina_regen_per_sec: float = 28.0 # regen when idle (out of combat)
@export var stamina_sprint_drain: float = 25.0

var stamina: float = 100.0
var is_sprinting: bool = false
var is_moving: bool = false
var last_direction: Vector2 = Vector2.DOWN

# Input buffering for polish
var input_direction: Vector2 = Vector2.ZERO

# References - set in _ready
@onready var sprite: AnimatedSprite2D = $Sprite if has_node("Sprite") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else $Collision if has_node("Collision") else null
@onready var camera: Camera2D = get_viewport().get_camera_2d()

# Polish signals
signal stamina_changed(current: float, max_val: float)
signal started_moving(direction: Vector2)
signal stopped_moving()

func _ready() -> void:
	stamina = max_stamina
	# Ensure readable size hint for phone screens
	if collision_shape:
		# Verify collision shape exists for physics
		pass
	else:
		push_warning("Player: CollisionShape2D not found - add one for physics")
	
	# Connect to polish manager if present
	if has_node("/root/PolishManager"):
		stamina_changed.connect(get_node("/root/PolishManager").on_player_stamina_changed)

func _physics_process(delta: float) -> void:
	# --- Input collection (supports both keyboard + touch) ---
	input_direction = Vector2.ZERO
	
	# Keyboard / D-pad
	if Input.is_action_pressed("ui_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_direction.y += 1
	if Input.is_action_pressed("ui_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_direction.x += 1
	
	# Touch joystick override (if TouchControls present)
	if has_node("/root/TouchControls"):
		var touch_vec = get_node("/root/TouchControls").get_movement_vector()
		if touch_vec.length() > 0.1:
			input_direction = touch_vec
	
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	is_sprinting = Input.is_action_pressed("sprint") and stamina > 0 and input_direction.length() > 0
	var current_speed := SPEED * (SPRINT_MULTIPLIER if is_sprinting else 1.0)
	
	# --- Stamina handling ---
	if input_direction.length() > 0:
		if is_sprinting:
			stamina = max(0.0, stamina - stamina_sprint_drain * delta)
		else:
			stamina = max(0.0, stamina - stamina_drain_per_sec * 0.15 * delta)
		# No stamina = forced walk, no sprint
		if stamina <= 0:
			current_speed = SPEED * 0.6
	else:
		# Regen only when idle - hardcore: no regen while moving
		stamina = min(max_stamina, stamina + stamina_regen_per_sec * delta)
		emit_signal("stamina_changed", stamina, max_stamina)
	
	# --- Movement with acceleration/friction (juicy) ---
	var target_velocity := input_direction * current_speed
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
	
	# --- Animation update ---
	update_animation()
	
	# --- Camera bounds polish: never let hero shrink below 64px ---
	enforce_camera_bounds()

func update_animation() -> void:
	if sprite == null:
		return
	# Determine 4-direction animation
	var anim_prefix := "idle"
	if is_moving:
		anim_prefix = "run"
	
	var dir_suffix := "down"
	if abs(last_direction.x) > abs(last_direction.y):
		dir_suffix = "right" if last_direction.x > 0 else "left"
	else:
		dir_suffix = "down" if last_direction.y > 0 else "up"
	
	var anim_name := anim_prefix + "_" + dir_suffix
	# Safe play - check if animation exists
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		# Flip handling for left (if only right anim exists)
		if dir_suffix == "left" and not sprite.sprite_frames.has_animation("run_left"):
			sprite.flip_h = true
			if sprite.animation != "run_right":
				sprite.play("run_right")
		else:
			sprite.flip_h = false

func enforce_camera_bounds() -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
	var zoom := camera.zoom
	if zoom.x == 0 or zoom.y == 0:
		return
	var viewport_size := get_viewport_rect().size
	var cam_size := viewport_size / zoom
	# Minimum hero size enforcement: zoom must keep 64px readable
	var min_zoom := MIN_HERO_SIZE_PX / 64.0 # 64 logical px -> screen px
	if zoom.x < min_zoom:
		camera.zoom = Vector2(min_zoom, min_zoom)
	
	# Keep inside camera limits if set
	if camera.limit_left != -10000000:
		global_position.x = clamp(global_position.x, camera.limit_left + MIN_HERO_SIZE_PX/2, camera.limit_right - MIN_HERO_SIZE_PX/2)
		global_position.y = clamp(global_position.y, camera.limit_top + MIN_HERO_SIZE_PX/2, camera.limit_bottom - MIN_HERO_SIZE_PX/2)

# Public API for other systems (combat, talents)
func get_movement_speed() -> float:
	return SPEED

func set_speed(new_speed: float) -> void:
	# Note: const SPEED can't be reassigned; use meta or variable for runtime changes
	set_meta("custom_speed", new_speed)

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
	stamina = min(max_stamina, stamina + amount)
	emit_signal("stamina_changed", stamina, max_stamina)

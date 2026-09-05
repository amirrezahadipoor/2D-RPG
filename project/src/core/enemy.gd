# Enemy - Phase 3 Combat System
# Procedural enemy with AI states: patrol, chase, attack, die

extends Node2D
class_name Enemy

enum AIState { IDLE, PATROL, CHASE, ATTACK, FLEE, DIE }

var enemy_type: String = "slime"
var level: int = 1
var max_hp: int = 30
var hp: int = 30
var damage: int = 5
var speed: float = 80.0
var xp_value: int = 10
var gold_value: int = 5
var size: float = 1.0

var ai_state: AIState = AIState.IDLE
var target: Node2D = null
var patrol_target: Vector2 = Vector2.ZERO
var patrol_origin: Vector2 = Vector2.ZERO
var state_timer: float = 0.0

# AI parameters
var detection_range: float = 200.0
var attack_range: float = 40.0
var patrol_range: float = 100.0
var chase_range: float = 400.0

# Visual
var sprite: Sprite2D
var health_bar: ProgressBar

func _init_enemy(type: String, HP: int, Damage: int, Level: int) -> void:
	enemy_type = type
	max_hp = HP
	hp = HP
	damage = Damage
	level = Level
	
	# Scale parameters based on type
	match type:
		"slime":
			speed = 60.0
			detection_range = 150.0
			patrol_range = 80.0
		"goblin":
			speed = 100.0
			detection_range = 200.0
			patrol_range = 120.0
		"skeleton":
			speed = 80.0
			detection_range = 180.0
		"orc":
			speed = 70.0
			detection_range = 160.0
			attack_range = 50.0
		"demon":
			speed = 110.0
			detection_range = 250.0
		"dragon":
			speed = 130.0
			detection_range = 300.0
			attack_range = 60.0
	
	_setup_visuals()

func _setup_visuals() -> void:
	# Create procedural sprite
	sprite = Sprite2D.new()
	sprite.name = "EnemySprite"
	add_child(sprite)
	
	# Create procedural health bar
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.custom_minimum_size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -50)
	health_bar.visible = false
	add_child(health_bar)
	
	# Color based on enemy type
	var enemy_colors = {
		"slime": Color(0.2, 0.8, 0.2),
		"goblin": Color(0.4, 0.7, 0.2),
		"skeleton": Color(0.9, 0.9, 0.85),
		"orc": Color(0.3, 0.6, 0.3),
		"demon": Color(0.7, 0.1, 0.1),
		"dragon": Color(0.8, 0.2, 0.1)
	}
	
	var col = enemy_colors.get(enemy_type, Color.GRAY)
	
	# Draw procedural sprite using Image
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Simple circle shape
	var center = Vector2i(32, 32)
	var radius = int(24 * size)
	
	for y in range(64):
		for x in range(64):
			var dist = Vector2i(x, y).distance_to(center)
			if dist < radius:
				img.set_pixel(x, y, col)
			elif dist < radius + 2:
				img.set_pixel(x, y, col.darkened(0.3))
	
	# Add eyes
	var eye_color = Color.WHITE
	if enemy_type in ["demon", "dragon"]:
		eye_color = Color.RED
	elif enemy_type == "skeleton":
		eye_color = Color.BLACK
	
	img.set_pixel(26, 26, eye_color)
	img.set_pixel(38, 26, eye_color)
	
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	
	# Scale
	sprite.scale = Vector2(size, size)
	
	# Collision
	var coll = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 24.0 * size
	coll.shape = shape
	add_child(coll)

func _ai_update(delta: float) -> void:
	if ai_state == AIState.DIE:
		return
	
	state_timer -= delta
	
	# Find player target
	target = _find_nearest_player()
	
	match ai_state:
		AIState.IDLE:
			_ai_idle(delta)
		AIState.PATROL:
			_ai_patrol(delta)
		AIState.CHASE:
			_ai_chase(delta)
		AIState.ATTACK:
			_ai_attack(delta)
		AIState.FLEE:
			_ai_flee(delta)

func _ai_idle(delta: float) -> void:
	if target and global_position.distance_to(target.global_position) < detection_range:
		ai_state = AIState.CHASE
		return
	
	if state_timer <= 0:
		# Start patrol
		patrol_origin = global_position
		ai_state = AIState.PATROL
		state_timer = randf_range(2.0, 5.0)

func _ai_patrol(delta: float) -> void:
	if target and global_position.distance_to(target.global_position) < detection_range:
		ai_state = AIState.CHASE
		return
	
	if state_timer <= 0 or global_position.distance_to(patrol_origin) > patrol_range:
		ai_state = AIState.IDLE
		state_timer = randf_range(1.0, 3.0)
		return
	
	# Move toward patrol point
	var dir = (patrol_origin + patrol_target - global_position).normalized()
	global_position += dir * speed * 0.5 * delta

func _ai_chase(delta: float) -> void:
	if not is_instance_valid(target):
		ai_state = AIState.IDLE
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	if dist > chase_range:
		ai_state = AIState.IDLE
		return
	
	if dist < attack_range:
		ai_state = AIState.ATTACK
		return
	
	# Move toward target
	var dir = (target.global_position - global_position).normalized()
	global_position += dir * speed * delta
	
	# Face target
	if sprite:
		sprite.flip_h = dir.x < 0

func _ai_attack(delta: float) -> void:
	if not is_instance_valid(target):
		ai_state = AIState.IDLE
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	if dist > attack_range * 1.5:
		ai_state = AIState.CHASE
		return
	
	# Attack player
	if state_timer <= 0:
		_attack_target(target)
		state_timer = 1.0  # Attack cooldown

func _ai_flee(delta: float) -> void:
	if not is_instance_valid(target):
		ai_state = AIState.IDLE
		return
	
	var dir = (global_position - target.global_position).normalized()
	global_position += dir * speed * 1.2 * delta

func _attack_target(t: Node) -> void:
	if t.has_method("take_damage"):
		t.take_damage(damage)

func _find_nearest_player() -> Node:
	if has_node("/root/Main/Player"):
		return get_node("/root/Main/Player")
	if has_node("/root/Player"):
		return get_node("/root/Player")
	return null

func take_damage(amount: int) -> int:
	hp -= amount
	hp = max(0, hp)
	
	# Show health bar
	if health_bar:
		health_bar.visible = true
		health_bar.value = hp
	
	# Flash effect
	if sprite:
		var orig = sprite.modulate
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = orig
	
	if hp <= 0:
		die()
	
	return amount

func is_dead() -> bool:
	return hp <= 0

func die() -> void:
	ai_state = AIState.DIE
	
	# Death effect via PolishManager
	if has_node("/root/PolishManager/VisualEffects"):
		get_node("/root/PolishManager/VisualEffects").play_death_effect(global_position)
	elif has_node("/root/PolishManager"):
		var polish = get_node("/root/PolishManager")
		if polish.has_method("juice") and polish.juice:
			polish.juice.play_death_effect(global_position)
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

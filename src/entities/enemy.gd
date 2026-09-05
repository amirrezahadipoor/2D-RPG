# A world enemy: wanders, chases, attacks, dies and pays out XP/gold.
class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

enum State { WANDER, CHASE, WINDUP, DEAD }

var enemy_type := "slime"
var level := 1
var max_hp := 10
var hp := 10
var damage := 3
var speed := 30.0
var xp_value := 5
var gold_value := 2
var detect := 70.0
var attack_range := 14.0
var attack_cd := 1.2

var state: State = State.WANDER
var _spr: Sprite2D
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _frame_w := 24
var _frame_h := 24
var _frames := 4
var _anim_time := 0.0
var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _attack_timer := 0.0
var _windup_timer := 0.0
var _flash_timer := 0.0
var _hero: Node2D = null

func setup(type: String, lvl: int) -> void:
	enemy_type = type
	level = lvl
	var s := EnemyDB.stats_for(type, lvl)
	max_hp = s["hp"]; hp = s["hp"]
	damage = s["damage"]; speed = s["speed"]
	xp_value = s["xp"]; gold_value = s["gold"]
	detect = s["detect"]; attack_range = s["attack_range"]; attack_cd = s["attack_cd"]

	var meta: Dictionary = ArtIndex.ENEMIES.get(type, ArtIndex.ENEMIES["slime"])
	_frame_w = meta["w"]; _frame_h = meta["h"]; _frames = meta["frames"]

	_spr = Sprite2D.new()
	_spr.centered = false
	_spr.offset = Vector2(-_frame_w * 0.5, -_frame_h)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.region_enabled = true
	_spr.texture = load("res://assets/sprites/enemies/%s.png" % type)
	_spr.scale = Vector2.ONE * s["scale"]
	add_child(_spr)

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8 * s["scale"], 5 * s["scale"])
	shape.shape = box
	shape.position = Vector2(0, -2)
	add_child(shape)

	# tiny hp bar, only shown once hurt
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0, 0, 0, 0.6)
	_hp_bg.size = Vector2(14, 2)
	_hp_bg.position = Vector2(-7, -_frame_h * s["scale"] - 4)
	_hp_bg.visible = false
	add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.85, 0.2, 0.25)
	_hp_fill.size = Vector2(14, 2)
	_hp_fill.position = Vector2(0, 0)
	_hp_bg.add_child(_hp_fill)

	add_to_group("enemy")
	_set_frame(0)

func _physics_process(delta: float) -> void:
	if state == State.DEAD or Game.state != Game.State.PLAYING:
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
		if _hero == null:
			return

	_flash_timer = maxf(0.0, _flash_timer - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_apply_flash()

	var to_hero: Vector2 = _hero.global_position - global_position
	var dist := to_hero.length()

	match state:
		State.WANDER:
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(1.0, 3.0)
				_wander_dir = Vector2.RIGHT.rotated(randf() * TAU) * 0.4
			velocity = velocity.move_toward(_wander_dir * speed, 200 * delta)
			if dist < detect:
				state = State.CHASE
		State.CHASE:
			velocity = velocity.move_toward(to_hero.normalized() * speed, 300 * delta)
			if dist > detect * 2.2:
				state = State.WANDER
			elif dist <= attack_range and _attack_timer <= 0.0:
				state = State.WINDUP
				_windup_timer = 0.28
				velocity = Vector2.ZERO
		State.WINDUP:
			_windup_timer -= delta
			_spr.modulate = Color(1.4, 1.1, 1.1)
			if _windup_timer <= 0.0:
				_spr.modulate = Color.WHITE
				_attack_timer = attack_cd
				if dist <= attack_range * 1.6:
					var landed := 0
					if _hero.has_method("hurt"):
						landed = int(_hero.hurt(damage))
					else:
						landed = Stats.damage(damage)
					if landed > 0:
						Juice.hurt()
						Juice.shake(3.0)
				state = State.CHASE

	move_and_slide()
	_animate(delta)

func _animate(delta: float) -> void:
	var moving := velocity.length() > 4.0
	_anim_time += delta * (7.0 if moving else 2.0)
	var frame := int(_anim_time) % _frames if moving else 0
	_set_frame(frame)
	if velocity.x < -1:
		_spr.flip_h = true
	elif velocity.x > 1:
		_spr.flip_h = false

func _set_frame(i: int) -> void:
	_spr.region_rect = Rect2(i * _frame_w, 0, _frame_w, _frame_h)

# ---------------------------------------------------------------- combat ----
func take_damage(amount: int, knock_dir: Vector2 = Vector2.ZERO, crit: bool = false) -> int:
	if state == State.DEAD:
		return 0
	var taken := mini(amount, hp)
	hp -= taken
	_flash_timer = 0.12
	_hp_bg.visible = true
	_hp_fill.size.x = 14.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if knock_dir.length() > 0.1:
		velocity += knock_dir
	Juice.damage_number(global_position + Vector2(0, -_frame_h), taken, crit)
	if hp <= 0:
		_die()
	return taken

## 35% chance to leave an item behind; tougher enemies roll better rarity.
func _maybe_drop_loot() -> void:
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.randomize()
	if drop_rng.randf() > 0.35:
		return
	var parent := get_parent()
	if parent == null:
		return
	var pickup := Pickup.new()
	parent.add_child(pickup)
	var entry: Dictionary
	if drop_rng.randf() < 0.3:
		var pid := "health_potion"
		if level >= 5 and drop_rng.randf() < 0.4:
			pid = "greater_health_potion"
		elif drop_rng.randf() < 0.3:
			pid = "stamina_potion"
		entry = {"id": pid, "slot": "", "rarity": 0, "prefix": "", "suffix": "",
			"dmg": 0, "armor": 0, "weight": 1, "qty": 1}
	else:
		entry = Inventory.roll_entry(ItemGen.random_id(drop_rng), minf(0.15, 0.03 * level))
	pickup.setup(entry)
	pickup.global_position = global_position

func _apply_flash() -> void:
	if _flash_timer > 0.0:
		_spr.modulate = Color(3.0, 2.2, 2.2)
	elif state != State.WINDUP:
		_spr.modulate = Color.WHITE

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	Stats.add_xp(xp_value)
	Stats.add_gold(gold_value)
	_maybe_drop_loot()
	Juice.shake(2.0)
	Juice.puff(global_position)
	died.emit(self)
	_spr.modulate.a = 0.0
	_hp_bg.visible = false
	set_physics_process(false)
	queue_free()

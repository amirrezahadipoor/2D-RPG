# A world enemy: wanders, chases, attacks, dies and pays out XP/gold.
class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

enum State { WANDER, CHASE, WINDUP, RETREAT, FLEE, DEAD }

## Species doctrine: how each monster fights.
##  hit_run   : strike then bounce away (goblins, bats)
##  flee_hp   : run for it below this health fraction (goblins)
##  berserk_hp: rage below this fraction - faster, harder hits (orcs)
##  skirmish  : circle-strafe while the claw cools (skeletons)
##  ranged    : hurl fireballs outside melee reach (demons, the dragon)
##  boss      : second phase below half health (the dragon)
const TACTICS := {
	"slime": {},
	"bat": {"hit_run": true},
	"goblin": {"hit_run": true, "flee_hp": 0.2},
	"skeleton": {"skirmish": true},
	"orc": {"berserk_hp": 0.35},
	"demon": {"ranged": true},
	"dragon": {"ranged": true, "boss": true},
}

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
var _retreat_timer := 0.0
var _flee_timer := 0.0
var _strafe_dir := 1.0
var _phase := 1
var _breath_timer := 4.0
var _summon_timer := 6.0
var _tele: Label = null

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

	_tele = Label.new()
	_tele.text = "!"
	_tele.add_theme_font_size_override("font_size", 10)
	_tele.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	_tele.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_tele.add_theme_constant_override("outline_size", 3)
	_tele.position = Vector2(-2, -_frame_h * s["scale"] - 14)
	_tele.visible = false
	_tele.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tele)

	add_to_group("enemy")
	_set_frame(0)

func _tactic(key: String) -> bool:
	return bool(TACTICS.get(enemy_type, {}).get(key, false))

func _speed_mult() -> float:
	var m := 1.0
	if _tactic("berserk_hp") and hp < max_hp * float(TACTICS[enemy_type]["berserk_hp"]):
		m *= 1.35
	if _phase == 2:
		m *= 1.3
	return m

func _damage_mult() -> float:
	var m := 1.0
	if _tactic("berserk_hp") and hp < max_hp * float(TACTICS[enemy_type]["berserk_hp"]):
		m *= 1.25
	return m

## One monster spotting you is every monster nearby spotting you.
func _alert_pack() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		var other := node as Enemy
		if other == null or other == self or other.state != State.WANDER:
			continue
		if other.global_position.distance_to(global_position) < 110.0:
			other.state = State.CHASE

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

	var fleeing := float(TACTICS.get(enemy_type, {}).get("flee_hp", 0.0))
	if fleeing > 0.0 and hp < max_hp * fleeing and state != State.FLEE and state != State.DEAD:
		state = State.FLEE
		_flee_timer = 2.0
		_alert_pack()

	match state:
		State.WANDER:
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(1.0, 3.0)
				_wander_dir = Vector2.RIGHT.rotated(randf() * TAU) * 0.4
			velocity = velocity.move_toward(_wander_dir * speed, 200 * delta)
			if dist < detect:
				state = State.CHASE
				_alert_pack()
		State.CHASE:
			var sp := speed * _speed_mult()
			if _tactic("skirmish") and dist <= attack_range and _attack_timer > 0.0:
				# circle the hero while the claw cools
				velocity = velocity.move_toward(to_hero.normalized().orthogonal()
					* _strafe_dir * sp, 300 * delta)
			elif _tactic("ranged") and dist > attack_range * 1.2 and _attack_timer <= 0.0:
				state = State.WINDUP
				_windup_timer = 0.45
				velocity = Vector2.ZERO
			else:
				velocity = velocity.move_toward(to_hero.normalized() * sp, 300 * delta)
			if dist > detect * 2.2:
				state = State.WANDER
			elif dist <= attack_range and _attack_timer <= 0.0:
				state = State.WINDUP
				_windup_timer = 0.28
				velocity = Vector2.ZERO
		State.WINDUP:
			_windup_timer -= delta
			_spr.modulate = Color(1.4, 1.1, 1.1)
			_tele.visible = true
			if _windup_timer <= 0.0:
				_spr.modulate = Color.WHITE
				_tele.visible = false
				_attack_timer = attack_cd * (0.6 if _phase == 2 else 1.0)
				_resolve_attack(dist, to_hero)
				if _tactic("hit_run"):
					state = State.RETREAT
					_retreat_timer = 0.7
				else:
					state = State.CHASE
		State.RETREAT:
			_retreat_timer -= delta
			velocity = velocity.move_toward(-to_hero.normalized() * speed * 1.2, 400 * delta)
			if _retreat_timer <= 0.0:
				state = State.CHASE
		State.FLEE:
			_flee_timer -= delta
			velocity = velocity.move_toward(-to_hero.normalized() * speed * 1.4, 400 * delta)
			if _flee_timer <= 0.0:
				state = State.WANDER if dist > detect else State.CHASE

	move_and_slide()
	_animate(delta)
	_boss_brain(delta, dist, to_hero)

## Melee claw, or a hurled fireball when the species fights at range.
func _resolve_attack(dist: float, to_hero: Vector2) -> void:
	var ranged := _tactic("ranged") and dist > attack_range
	if ranged:
		_cast_fireball(to_hero.normalized())
		if _tactic("boss"):
			_cast_fireball(to_hero.normalized().rotated(0.28))
			_cast_fireball(to_hero.normalized().rotated(-0.28))
		return
	if dist <= attack_range * 1.6:
		var amount := int(roundf(float(damage) * _damage_mult()))
		var landed := 0
		if _hero.has_method("hurt"):
			landed = int(_hero.hurt(amount))
		else:
			landed = Stats.damage(amount)
		if landed > 0:
			Juice.hurt()
			Juice.shake(3.0)

func _cast_fireball(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ball := Projectile.new()
	parent.add_child(ball)
	ball.setup(dir, int(roundf(float(damage) * _damage_mult())))
	ball.global_position = global_position + Vector2(0, -10)
	Juice.puff(global_position + Vector2(0, -10))

## The dragon wakes up below half health: faster, breath volleys, calls bones.
func _boss_brain(delta: float, dist: float, to_hero: Vector2) -> void:
	if not _tactic("boss") or state == State.DEAD:
		return
	if _phase == 1 and hp < max_hp * 0.5:
		_phase = 2
		Juice.shake(4.0)
		Juice.world_text(global_position + Vector2(0, -40), "!!", Color(1.0, 0.3, 0.2), 12)
		return
	if _phase != 2:
		return
	_breath_timer -= delta
	if _breath_timer <= 0.0 and dist > 30.0:
		_breath_timer = 6.0
		for ang in [-0.22, 0.0, 0.22]:
			_cast_fireball(to_hero.normalized().rotated(ang))
	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_timer = 8.0
		var parent := get_parent()
		if parent == null:
			return
		for i in 2:
			var bone := Enemy.new()
			parent.add_child(bone)
			bone.setup("skeleton", maxi(1, level - 1))
			bone.global_position = global_position + Vector2(
				randf_range(-30, 30), randf_range(-20, 20))
			bone.state = State.CHASE

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
	if state == State.WANDER:
		state = State.CHASE
	_alert_pack()
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
		_tele.visible = false

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

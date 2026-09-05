# The player character.
#
# Owns: movement + collision, the Camera2D that actually follows it (a bug the
# previous revision shipped: the camera was a sibling of the player and never
# moved), the PaperDoll, and the attack/dodge state machine.
class_name Hero
extends CharacterBody2D

signal attack_landed(hit_count: int)
signal gear_changed(gear: Dictionary)

const WALK_SPEED := 78.0
const DASH_SPEED := 210.0
const ACCEL := 900.0
const FRICTION := 1100.0
const DODGE_STAMINA := 22.0
const ATTACK_TIME := 0.28
const DODGE_TIME := 0.22
const WALK_FPS := 9.0
const IDLE_FPS := 2.5
const ATTACK_FPS := 9.0

enum Act { NONE, ATTACK, DODGE }

var doll: PaperDoll
var cam: Camera2D

var facing := "down"
var act: Act = Act.NONE
var act_timer := 0.0
var anim_time := 0.0
var _gear_slot_cursor := 0
var _attack_cooldown := 0.0

func _ready() -> void:
	# Collision: a small box at the FEET so the sprite can overhang upward
	# (hats, raised weapons) without making the hitbox huge.
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 6)
	shape.shape = box
	shape.position = Vector2(0, -3)
	add_child(shape)

	add_to_group("player")
	doll = PaperDoll.new()
	doll.gear_changed.connect(_on_gear_changed)
	add_child(doll)

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	# 2x zoom: at the 480x270 native resolution this frames ~15x8 tiles and
	# keeps the hero comfortably readable on a phone screen.
	cam.zoom = Vector2(2, 2)
	add_child(cam)
	cam.make_current()

	_starting_gear()
	_on_gear_changed(doll.get_gear())
	print("[Hero] ready")

func _starting_gear() -> void:
	doll.equip("chest", "tunic_cloth")
	doll.equip("legs", "cloth_pants")
	doll.equip("boots", "cloth_shoes")
	doll.equip("weapon", "iron_sword")

# ------------------------------------------------------------- physics ------
func _physics_process(delta: float) -> void:
	if Game.state == Game.State.DEAD:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_handle_actions(delta)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if act == Act.DODGE:
		# dash keeps its launch velocity, no steering
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * 0.25 * delta)
	elif act == Act.ATTACK:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		if input.length() > 0.1:
			velocity = velocity.move_toward(input * WALK_SPEED, ACCEL * delta)
			_update_facing(input)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

		Stats.tick_stamina(
			delta,
			input.length() > 0.1,
			6.0,
			18.0
		)

	move_and_slide()
	_animate(delta, input)

func _update_facing(input: Vector2) -> void:
	if absf(input.x) > absf(input.y):
		facing = "right" if input.x > 0 else "left"
	else:
		facing = "down" if input.y > 0 else "up"

# -------------------------------------------------------------- actions -----
func _handle_actions(delta: float) -> void:
	if act != Act.NONE:
		act_timer -= delta
		if act_timer <= 0.0:
			act = Act.NONE
		return

	if Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
		var weapon: Dictionary = WeaponDB.stats_for(current_weapon_id())
		if Stats.spend_stamina(float(weapon["stamina"])):
			act = Act.ATTACK
			act_timer = ATTACK_TIME
			anim_time = 0.0
			_attack_cooldown = float(weapon["cooldown"])
			var hits := _sweep_attack(weapon)
			attack_landed.emit(hits)
	elif Input.is_action_just_pressed("dodge"):
		if Stats.spend_stamina(DODGE_STAMINA):
			act = Act.DODGE
			act_timer = DODGE_TIME
			var dir := _aim_direction()
			velocity = dir * DASH_SPEED

	if Input.is_action_just_pressed("debug_swap_gear"):
		cycle_gear()

func _aim_direction() -> Vector2:
	match facing:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN

## Melee sweep: a band `reach` long and `arc` wide in the direction the hero
## faces. Every enemy inside it takes weapon damage + attack power + level, and
## is knocked back along the swing direction. Returns how many were hit.
func _sweep_attack(weapon: Dictionary) -> int:
	var dir := _aim_direction()
	var side := dir.orthogonal()
	var reach: float = weapon["reach"]
	var arc: float = weapon["arc"]
	var amount := attack_damage(weapon)
	var knock := float(weapon["knockback"])
	var hits := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var offset: Vector2 = enemy.global_position - global_position
		var along := offset.dot(dir)
		if along < -6.0 or along > reach:
			continue
		if absf(offset.dot(side)) > arc:
			continue
		enemy.take_damage(amount, dir * knock)
		hits += 1
	if hits > 0:
		Juice.shake(1.5)
	return hits

func current_weapon_id() -> String:
	return str(doll.get_gear().get("weapon", ""))

## What a swing from `weapon` deals with the hero's current gear and level.
func attack_damage(weapon: Dictionary = {}) -> int:
	var w: Dictionary = weapon if not weapon.is_empty() else WeaponDB.stats_for(current_weapon_id())
	return int(w["damage"]) + ItemDB.attack_power(doll.get_gear()) + (Stats.level - 1)

## Damage entry point used by enemies. Dodging grants brief invulnerability.
func hurt(amount: int) -> int:
	if Game.state == Game.State.DEAD:
		return 0
	if act == Act.DODGE:
		Juice.miss(global_position + Vector2(0, -30))
		return 0
	return Stats.damage(amount)

func _on_gear_changed(gear: Dictionary) -> void:
	Stats.set_armor(ItemDB.armor_total(gear))
	gear_changed.emit(gear)

# ------------------------------------------------------------ animation -----
func _animate(delta: float, input: Vector2) -> void:
	var state := "idle"
	var fps := IDLE_FPS
	if act == Act.ATTACK:
		state = "attack"
		fps = ATTACK_FPS
	elif act == Act.DODGE or input.length() > 0.1:
		state = "walk"
		fps = WALK_FPS
	anim_time += delta * fps
	doll.play(facing, state, int(anim_time))

# ------------------------------------------------------------- equipment ----
## Demo/debug hook: cycles the currently-focused slot through every item so
## the paper-doll change is immediately visible on the character.
func cycle_gear() -> void:
	var slots: Array = ArtIndex.EQUIPMENT_SLOTS
	var slot: String = slots[_gear_slot_cursor % slots.size()]
	_gear_slot_cursor += 1
	var ids: Array = ArtIndex.EQUIPMENT_IDS[slot]
	var current: String = doll.get_gear().get(slot, "")
	var idx: int = (ids.find(current) + 1) % (ids.size() + 1)
	if idx >= ids.size():
		doll.unequip(slot)
	else:
		doll.equip(slot, ids[idx])
	gear_changed.emit(doll.get_gear())

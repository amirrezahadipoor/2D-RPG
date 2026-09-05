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
const CRIT_CHANCE := 0.1
const DODGE_TIME := 0.22
const WALK_FPS := 9.0
const IDLE_FPS := 2.5
const ATTACK_FPS := 9.0

enum Act { NONE, ATTACK, DODGE }

var doll: PaperDoll
var cam: Camera2D
var lantern: PointLight2D

var facing := "down"
var act: Act = Act.NONE
var act_timer := 0.0
var anim_time := 0.0
var _gear_slot_cursor := 0
var _attack_cooldown := 0.0
var _combo := 0
var _combo_window := 0.0
var _charge := 0.0
var _parry_window := 0.0
var _counter_window := 0.0

const HEAVY_CHARGE := 0.45
const HEAVY_STAMINA := 18.0
const COMBO_WINDOW := 0.7
const PARRY_WINDOW := 0.22

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
	Inventory.equipment_changed.connect(_refresh_stats)

	# a warm lantern that wakes up at night and underground
	lantern = PointLight2D.new()
	lantern.texture = load("res://assets/sprites/fx/glow.png")
	lantern.color = Color(1.0, 0.82, 0.55)
	lantern.scale = Vector2(2.1, 2.1)
	lantern.energy = 0.0
	add_child(lantern)

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
	var cutscene := get_tree().get_first_node_in_group("cutscene")
	if (cutscene != null and cutscene.active) or _modal_open():
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return
	if Game.state == Game.State.DEAD or Inventory.screen_open:
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
			velocity = velocity.move_toward(input * WALK_SPEED * Stats.speed_mult(), ACCEL * delta)
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
	_update_lantern(delta)

## Any full-screen UI (inventory, journal, talents, dialogue) freezes play.
func _modal_open() -> bool:
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.visible:
			return true
	return false

## Light follows time of day and depth: dark nights, dark caves, dungeons.
func _update_lantern(delta: float) -> void:
	var target := 0.0
	if Game.is_blood_moon():
		target = 0.7
	elif Game.is_night():
		target = 0.6
	var world_node: Node = get_parent()
	while world_node != null and not world_node.has_method("ambient_light_need"):
		world_node = world_node.get_parent()
	if world_node != null:
		target = maxf(target, world_node.ambient_light_need())
	lantern.energy = lerpf(lantern.energy, target, 6.0 * delta)

func _update_facing(input: Vector2) -> void:
	if absf(input.x) > absf(input.y):
		facing = "right" if input.x > 0 else "left"
	else:
		facing = "down" if input.y > 0 else "up"

# -------------------------------------------------------------- actions -----
func _handle_actions(delta: float) -> void:
	_combo_window = maxf(0.0, _combo_window - delta)
	_parry_window = maxf(0.0, _parry_window - delta)
	_counter_window = maxf(0.0, _counter_window - delta)
	if _combo_window <= 0.0:
		_combo = 0
	if Input.is_action_pressed("attack"):
		_charge += delta
	else:
		_charge = 0.0
	doll.modulate = Color(1.35, 1.2, 0.8) if _charge >= HEAVY_CHARGE else Color.WHITE

	if act != Act.NONE:
		act_timer -= delta
		if act_timer <= 0.0:
			act = Act.NONE
		return

	if Input.is_action_just_pressed("attack"):
		_parry_window = PARRY_WINDOW
	if _attack_cooldown <= 0.0:
		var want_heavy := _charge >= HEAVY_CHARGE
		if Input.is_action_just_pressed("attack") or want_heavy:
			do_attack(want_heavy)
	if Input.is_action_just_pressed("dodge"):
		if Stats.spend_stamina(DODGE_STAMINA):
			act = Act.DODGE
			act_timer = DODGE_TIME
			var dir := _aim_direction()
			velocity = dir * DASH_SPEED

	if Input.is_action_just_pressed("debug_swap_gear"):
		cycle_gear()

	if Input.is_action_just_pressed("use_potion"):
		if Inventory.drink_health():
			Juice.world_text(global_position + Vector2(0, -30),
				I18N.tr_str("consumable.drink") + "!", Color(0.9, 0.3, 0.35), 8)

## One swing of the blade. `heavy` spends more stamina for a cleave; quick
## presses chain a three-hit combo whose finisher launches foes.
func do_attack(heavy: bool) -> void:
	var weapon: Dictionary = WeaponDB.stats_for(current_weapon_id())
	var cost := HEAVY_STAMINA if heavy else float(weapon["stamina"])
	if not Stats.spend_stamina(cost):
		return
	if not heavy:
		_combo = 0 if _combo_window <= 0.0 else _combo + 1
		if _combo > 2:
			_combo = 0
		_combo_window = COMBO_WINDOW
	else:
		_combo = 0
		_combo_window = 0.0
		_charge = 0.0
	act = Act.ATTACK
	act_timer = ATTACK_TIME + (0.1 if heavy or _combo == 2 else 0.0)
	anim_time = 0.0
	_attack_cooldown = float(weapon["cooldown"]) + (0.15 if heavy else 0.0)
	var hits := _sweep_attack(weapon, heavy)
	attack_landed.emit(hits)
	if _combo == 2:
		Juice.world_text(global_position + Vector2(0, -34), "x3!", Color(1.0, 0.8, 0.3), 9)

func _aim_direction() -> Vector2:
	match facing:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN

## Melee sweep: a band `reach` long and `arc` wide in the direction the hero
## faces. Every enemy inside it takes weapon damage + attack power + level, and
## is knocked back along the swing direction. Returns how many were hit.
func _sweep_attack(weapon: Dictionary, heavy: bool = false) -> int:
	var dir := _aim_direction()
	var side := dir.orthogonal()
	var reach: float = weapon["reach"] + (6.0 if heavy else 0.0)
	var arc: float = weapon["arc"] * (1.8 if heavy else 1.5 if _combo == 2 else 1.15 if _combo == 1 else 1.0)
	var amount := attack_damage(weapon)
	if heavy:
		amount = int(roundf(amount * 2.2))
	elif _combo == 2:
		amount = int(roundf(amount * 1.35))
	elif _combo == 1:
		amount = int(roundf(amount * 1.1))
	if _counter_window > 0.0:
		amount = int(roundf(amount * 1.5))
		_counter_window = 0.0
	var crit := randf() < CRIT_CHANCE
	if crit:
		amount *= 2
	var knock := float(weapon["knockback"]) * (2.2 if _combo == 2 or heavy else 1.0)
	if _combo == 2 or heavy:
		velocity += dir * 90.0
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
		enemy.take_damage(amount, dir * knock, crit)
		hits += 1
	for node in get_tree().get_nodes_in_group("breakable"):
		var offset: Vector2 = node.global_position - global_position
		var along := offset.dot(dir)
		if along < -6.0 or along > reach:
			continue
		if absf(offset.dot(side)) > arc:
			continue
		if node.has_method("break_open"):
			node.break_open()
			hits += 1
	if hits > 0:
		Juice.shake(1.5)
	return hits

func current_weapon_id() -> String:
	return str(doll.get_gear().get("weapon", ""))

## What a swing from `weapon` deals with the hero's current gear and level.
func attack_damage(weapon: Dictionary = {}) -> int:
	var w: Dictionary = weapon if not weapon.is_empty() else WeaponDB.stats_for(current_weapon_id())
	return (int(w["damage"]) + ItemDB.attack_power(doll.get_gear())
		+ Inventory.attack_bonus() + Stats.might_bonus() + (Stats.level - 1))

## Damage entry point used by enemies. Dodging grants brief invulnerability;
## dodging at the LAST moment banks a counter-attack bonus, and swinging just
## as a claw lands parries it outright.
func hurt(amount: int, from: Node = null) -> int:
	if Game.state == Game.State.DEAD:
		return 0
	if act == Act.DODGE:
		Juice.miss(global_position + Vector2(0, -30))
		if act_timer > DODGE_TIME - 0.12:
			_counter_window = 1.2
			Juice.world_text(global_position + Vector2(0, -36),
				I18N.tr_str("toast.perfect"), Color(0.4, 0.9, 1.0), 9)
		return 0
	if _parry_window > 0.0 and from != null and from.has_method("stagger"):
		from.stagger()
		_parry_window = 0.0
		Juice.world_text(global_position + Vector2(0, -36),
			I18N.tr_str("toast.parried"), Color(1.0, 0.9, 0.4), 9)
		Juice.shake(2.0)
		return 0
	return Stats.damage(amount)

func _on_gear_changed(gear: Dictionary) -> void:
	_refresh_stats()
	gear_changed.emit(gear)

## Armor = base of what is worn + affix/rarity bonuses of the worn entries.
func _refresh_stats() -> void:
	Stats.set_armor(ItemDB.armor_total(doll.get_gear()) + Inventory.armor_bonus())

## Sprite-side equip, used by the Inventory autoload.
func equip_visual(slot: String, item_id: String) -> void:
	doll.equip(slot, item_id)

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

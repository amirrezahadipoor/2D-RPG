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
const ATTACK_STAMINA := 12.0
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

func _ready() -> void:
	# Collision: a small box at the FEET so the sprite can overhang upward
	# (hats, raised weapons) without making the hitbox huge.
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 6)
	shape.shape = box
	shape.position = Vector2(0, -3)
	add_child(shape)

	doll = PaperDoll.new()
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
	print("[Hero] ready")

func _starting_gear() -> void:
	doll.equip("chest", "tunic_cloth")
	doll.equip("legs", "cloth_pants")
	doll.equip("boots", "cloth_shoes")
	doll.equip("weapon", "iron_sword")

# ------------------------------------------------------------- physics ------
func _physics_process(delta: float) -> void:
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

	if Input.is_action_just_pressed("attack"):
		if Stats.spend_stamina(ATTACK_STAMINA):
			act = Act.ATTACK
			act_timer = ATTACK_TIME
			anim_time = 0.0
			var hits := _sweep_attack()
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

## Melee sweep in the tile(s) directly in front of the hero. Enemies/damage
## land in a later milestone; for now it reports how many registered.
func _sweep_attack() -> int:
	var origin := global_position + _aim_direction() * 14.0
	var found := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node2D and node.global_position.distance_to(origin) < 18.0:
			found += 1
	return found

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

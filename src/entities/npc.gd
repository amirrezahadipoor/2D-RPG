# A person, not a signpost: wanders on a day schedule (home at night, well at
# noon, market in the evening...), wears real gear on a paper-doll, and talks.
class_name NPC
extends CharacterBody2D

const SPEED := 34.0

enum Role { VILLAGER, ELDER, MERCHANT, GUARD, KING, RESIDENT }

var role: Role = Role.VILLAGER
var role_name := "villager"
var home := Vector2.ZERO
var plaza := Vector2.ZERO
var field := Vector2.ZERO
var sett_index := 0
var npc_index := 0
var display_name := ""

var doll: PaperDoll
var facing := "down"
var anim_time := 0.0
var _target := Vector2.ZERO
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _fidget := 0.0

## The person who actually lives in a given house interior (R0.2 / P4): stays
## put at a fixed spot in their own room instead of walking a plaza/field
## schedule that makes no sense inside four walls.
var is_resident := false

var ROLE_GEAR := {
	"elder":    {"helmet": "shadow_hood", "chest": "mage_robe", "legs": "cloth_pants", "boots": "cloth_shoes", "weapon": "oak_staff", "accessory": "royal_cloak"},
	"merchant": {"helmet": "leather_cap", "chest": "leather_vest", "legs": "leather_pants", "boots": "leather_boots", "weapon": "", "accessory": "red_cloak"},
	"guard":    {"helmet": "iron_helm", "chest": "iron_plate", "legs": "iron_greaves", "boots": "iron_boots", "weapon": "iron_sword", "accessory": ""},
	"villager": {"helmet": "", "chest": "tunic_cloth", "legs": "cloth_pants", "boots": "cloth_shoes", "weapon": "", "accessory": ""},
	"king":    {"helmet": "golden_crown", "chest": "royal_plate", "legs": "iron_greaves", "boots": "iron_boots", "weapon": "golden_sword", "accessory": "royal_cloak"},
	# house residents (P4): distinct outfits so a cottage owner, a shopkeeper's
	# family and a palace steward do not all look the same indoors
	"resident_home":       {"helmet": "", "chest": "tunic_cloth", "legs": "cloth_pants", "boots": "cloth_shoes", "weapon": "", "accessory": "forest_cloak"},
	"resident_town_house": {"helmet": "leather_cap", "chest": "leather_vest", "legs": "leather_pants", "boots": "leather_boots", "weapon": "", "accessory": ""},
	"resident_palace":     {"helmet": "wizard_hat", "chest": "mage_robe", "legs": "cloth_pants", "boots": "cloth_shoes", "weapon": "", "accessory": "royal_cloak"},
}

func setup(role_str: String, settlement: Dictionary, index: int) -> void:
	role_name = role_str
	role = {"villager": Role.VILLAGER, "elder": Role.ELDER,
		"merchant": Role.MERCHANT, "guard": Role.GUARD, "king": Role.KING}.get(role_str, Role.VILLAGER)
	is_resident = role_str.begins_with("resident_")
	if is_resident:
		role = Role.RESIDENT
	sett_index = int(settlement.get("index", 0))
	npc_index = index
	# a wider, seeded name pool so no two settlements share a full crowd of
	# identical names (24 names, spread by settlement and slot)
	display_name = I18N.tr_str("npc.name.%d" % ((sett_index * 13 + index * 7) % 24))

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 6)
	shape.shape = box
	shape.position = Vector2(0, -3)
	add_child(shape)

	doll = PaperDoll.new()
	add_child(doll)
	var gear: Dictionary = ROLE_GEAR[role_str]
	for slot in gear:
		if gear[slot] != "":
			doll.equip(slot, gear[slot])
	# subtle skin/cloth tint so crowds do not look cloned
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(role_str) ^ (index * 2654435761) ^ sett_index
	modulate = Color(1.0, rng.randf_range(0.92, 1.0), rng.randf_range(0.92, 1.0))

	var plaza_v: Vector2i = settlement.get("plaza", Vector2i.ZERO)
	plaza = Vector2(plaza_v.x * 16 + 8, plaza_v.y * 16 + 8)
	field = plaza + Vector2(rng.randf_range(-160, 160), rng.randf_range(-120, 120))
	_target = home
	add_to_group("npc")

# ------------------------------------------------------------- schedule -----
## Where this person wants to be at a given hour of the day.
## Small personal offset so crowds do not stack on a single pixel.
func _personal_offset() -> Vector2:
	# a 7x4 personal grid (~63x32px) so a whole crowd never stacks on one spot
	return Vector2(float(npc_index % 7) * 9.0 - 27.0, float(npc_index / 7) * 8.0 - 12.0)

## Personal space: without this the whole crowd converges on the same
## schedule point and stacks into one blob of overlapping pixels.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("npc"):
		if node == self:
			continue
		var d := global_position - (node as Node2D).global_position
		var l := d.length()
		if l > 0.001 and l < 12.0:
			push += d / l * (12.0 - l)
	return push * 6.0

func schedule_target(hour: int) -> Vector2:
	# guards stay on plaza duty all day (this used to be dead code below the
	# hour match, so it never ran - audit phase 3.1)
	if role == Role.GUARD and hour >= 6 and hour <= 20:
		return plaza + _personal_offset()
	match hour:
		0, 1, 2, 3, 4, 5:
			return home                      # asleep at home
		6, 7:
			return plaza + _personal_offset()
		8, 9, 10, 11:
			return field if role == Role.VILLAGER else plaza + _personal_offset()
		12, 13:
			return plaza + Vector2(32, 0) + _personal_offset()
		14, 15, 16, 17:
			return field if role == Role.VILLAGER else home
		18, 19, 20:
			return plaza + Vector2(-24, 8) + _personal_offset()
		_:
			return home

var _bob_t := 0.0

func _physics_process(delta: float) -> void:
	_bob_t += delta
	if doll:
		doll.position.y = sin(_bob_t * 2.2 + float(npc_index)) * 0.6
	if Game.state != Game.State.PLAYING:
		return
	if is_resident:
		# a resident stays inside their own four walls: small idle fidget in
		# place instead of chasing a plaza/field schedule that only makes
		# sense out on the open map
		velocity = Vector2.ZERO
		_fidget += delta
		if _fidget > 3.0:
			_fidget = 0.0
			facing = ["down", "left", "right"][randi() % 3]
		doll.play(facing, "idle", int(_fidget * 2.0))
		_check_talk_prompt()
		return
	_target = schedule_target(Game.hour())
	var to := _target - global_position
	if to.length() > 6.0:
		var dir := to.normalized()
		velocity = velocity.move_toward(dir * SPEED, 300 * delta)
		if absf(dir.x) > absf(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
		# un-stick: shuffle sideways when blocked by a house or a fence
		_stuck_timer += delta
		if _stuck_timer > 1.2:
			if global_position.distance_to(_last_pos) < 2.0:
				velocity = velocity.rotated(PI * 0.5)
			_stuck_timer = 0.0
			_last_pos = global_position
		velocity += _separation() * delta
		move_and_slide()
		anim_time += delta * 9.0
		doll.play(facing, "walk", int(anim_time))
	else:
		velocity = Vector2.ZERO
		_fidget += delta
		if _fidget > 2.5:
			_fidget = 0.0
			facing = ["down", "left", "right", "up"][randi() % 4]
		doll.play(facing, "idle", int(_fidget * 2.5))
	_check_talk_prompt()

## Desktop-testing fallback: a keyboard press near the NPC opens dialogue.
## Touch play uses Hero.interact() directly instead (see hero.gd _touch_think).
func _check_talk_prompt() -> void:
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero == null:
		return
	var near := global_position.distance_to(hero.global_position) < 16.0
	var modal := false
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.visible:
			modal = true
	if near and not modal and Game.state == Game.State.PLAYING:
		if Input.is_action_just_pressed("interact"):
			_open_dialogue()

## Touch hook: the hero walks over and calls this directly instead of
## synthesising the interact key (which is physics-order dependent).
func interact() -> void:
	if Game.state == Game.State.PLAYING:
		_open_dialogue()

func _open_dialogue() -> void:
	for child in get_tree().root.get_children():
		var dlg := child.get_node_or_null("DialogueUI")
		if dlg != null and dlg.has_method("open_with"):
			dlg.open_with(self)
			return

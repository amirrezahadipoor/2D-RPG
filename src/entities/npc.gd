# A person, not a signpost: wanders on a day schedule (home at night, well at
# noon, market in the evening...), wears real gear on a paper-doll, and talks.
class_name NPC
extends CharacterBody2D

const SPEED := 34.0

enum Role { VILLAGER, ELDER, MERCHANT, GUARD }

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

var ROLE_GEAR := {
	"elder":    {"helmet": "shadow_hood", "chest": "mage_robe", "legs": "cloth_pants", "boots": "cloth_shoes", "weapon": "oak_staff", "accessory": "royal_cloak"},
	"merchant": {"helmet": "leather_cap", "chest": "leather_vest", "legs": "leather_pants", "boots": "leather_boots", "weapon": "", "accessory": "red_cloak"},
	"guard":    {"helmet": "iron_helm", "chest": "iron_plate", "legs": "iron_greaves", "boots": "iron_boots", "weapon": "iron_sword", "accessory": ""},
	"villager": {"helmet": "", "chest": "tunic_cloth", "legs": "cloth_pants", "boots": "cloth_shoes", "weapon": "", "accessory": ""},
}

func setup(role_str: String, settlement: Dictionary, index: int) -> void:
	role_name = role_str
	role = {"villager": Role.VILLAGER, "elder": Role.ELDER,
		"merchant": Role.MERCHANT, "guard": Role.GUARD}.get(role_str, Role.VILLAGER)
	sett_index = int(settlement.get("index", 0))
	npc_index = index
	display_name = I18N.tr_str("npc.name.%d" % (index % 8))

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
func schedule_target(hour: int) -> Vector2:
	match hour:
		0, 1, 2, 3, 4, 5:
			return home                      # asleep at home
		6, 7:
			return plaza                     # morning gathering
		8, 9, 10, 11:
			return field if role == Role.VILLAGER else plaza
		12, 13:
			return plaza + Vector2(32, 0)    # lunch by the well
		14, 15, 16, 17:
			return field if role == Role.VILLAGER else home
		18, 19, 20:
			return plaza + Vector2(-24, 8)   # market evening
		_:
			return home
	match role:
		Role.GUARD:
			return plaza                     # guards stay on duty
	return home

func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
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

	# talk prompt
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

func _open_dialogue() -> void:
	for child in get_tree().root.get_children():
		var dlg := child.get_node_or_null("DialogueUI")
		if dlg != null and dlg.has_method("open_with"):
			dlg.open_with(self)
			return

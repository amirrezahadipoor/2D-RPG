# Player vitals. One place, one source of truth, signals for the HUD.
#
# The previous revision had stamina tracked in BOTH player_movement.gd and
# player_stats.gd, fighting each other every frame. Never again.
extends Node

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: int)
signal level_changed(level: int, xp: int, xp_next: int)
signal gold_changed(gold: int)
signal armor_changed(armor: int)
signal talent_changed(points: int)
signal died

var max_hp: int = 40
var hp: int = 40
var max_stamina: int = 100
var stamina: float = 100.0

var level: int = 1
var xp: int = 0
var xp_next: int = 100
var gold: int = 25
var kills: int = 0

# Damage reduction from worn gear. Recomputed by Hero whenever gear changes.
var armor: int = 0

var talent_points: int = 0
var talents: Dictionary = {"might": 0, "vigor": 0, "swift": 0}

func rank_up(key: String) -> bool:
	if talent_points <= 0 or not talents.has(key):
		return false
	if int(talents[key]) >= 10:
		return false
	talent_points -= 1
	talents[key] = int(talents[key]) + 1
	if key == "vigor":
		max_hp += 10
		hp += 10
		health_changed.emit(hp, max_hp)
	elif key == "swift":
		max_stamina += 10
		stamina_changed.emit(stamina, max_stamina)
	talent_changed.emit(talent_points)
	return true

func speed_mult() -> float:
	return 1.0 + 0.03 * float(talents["swift"])

func might_bonus() -> int:
	return 2 * int(talents["might"])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---------------------------------------------------------------- combat ----
## Armor absorbs a flat part of every hit, but a hit always lands for at least 1.
func damage(amount: int) -> int:
	if hp <= 0:
		return 0
	var reduced := maxi(1, amount - armor)
	var taken := clampi(reduced, 0, hp)
	hp -= taken
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
	return taken

func set_armor(value: int) -> void:
	if value == armor:
		return
	armor = maxi(0, value)
	armor_changed.emit(armor)

func add_kill() -> void:
	kills += 1

func reset_run(start_gold: int = 25) -> void:
	max_hp = 40
	hp = max_hp
	max_stamina = 100
	stamina = float(max_stamina)
	level = 1
	xp = 0
	xp_next = 100
	gold = start_gold
	armor = 0
	kills = 0
	talent_points = 0
	talents = {"might": 0, "vigor": 0, "swift": 0}
	health_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)
	level_changed.emit(level, xp, xp_next)
	gold_changed.emit(gold)
	armor_changed.emit(armor)

func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)
	health_changed.emit(hp, max_hp)

func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit(stamina, max_stamina)
	return true

func tick_stamina(delta: float, draining: bool, drain_rate: float, regen_rate: float) -> void:
	var before := stamina
	if draining:
		stamina = maxf(0.0, stamina - drain_rate * delta)
	else:
		stamina = minf(float(max_stamina), stamina + regen_rate * delta)
	if before != stamina:
		stamina_changed.emit(stamina, max_stamina)

# ------------------------------------------------------------ progression ---
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = int(100.0 * pow(level, 1.3))
		max_hp += 5
		hp = max_hp
		talent_points += 1
		talent_changed.emit(talent_points)
		level_changed.emit(level, xp, xp_next)
	level_changed.emit(level, xp, xp_next)

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)

# ----------------------------------------------------------------- save -----
func serialize() -> Dictionary:
	return {
		"hp": hp, "max_hp": max_hp,
		"stamina": stamina, "max_stamina": max_stamina,
		"level": level, "xp": xp, "xp_next": xp_next,
		"gold": gold, "kills": kills,
		"talent_points": talent_points, "talents": talents.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	max_hp = int(data.get("max_hp", max_hp))
	hp = int(data.get("hp", hp))
	max_stamina = int(data.get("max_stamina", max_stamina))
	stamina = float(data.get("stamina", stamina))
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	xp_next = int(data.get("xp_next", xp_next))
	gold = int(data.get("gold", gold))
	kills = int(data.get("kills", kills))
	talent_points = int(data.get("talent_points", talent_points))
	var t: Dictionary = data.get("talents", {})
	if not t.is_empty():
		talents = t
	armor_changed.emit(armor)
	health_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)
	level_changed.emit(level, xp, xp_next)
	gold_changed.emit(gold)

# Player vitals. One place, one source of truth, signals for the HUD.
#
# The previous revision had stamina tracked in BOTH player_movement.gd and
# player_stats.gd, fighting each other every frame. Never again.
extends Node

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: int)
signal level_changed(level: int, xp: int, xp_next: int)
signal gold_changed(gold: int)

var max_hp: int = 40
var hp: int = 40
var max_stamina: int = 100
var stamina: float = 100.0

var level: int = 1
var xp: int = 0
var xp_next: int = 100
var gold: int = 25

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---------------------------------------------------------------- combat ----
func damage(amount: int) -> int:
	var taken := clampi(amount, 0, hp)
	hp -= taken
	health_changed.emit(hp, max_hp)
	return taken

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
		xp_next = int(100.0 * pow(level, 1.5))
		max_hp += 5
		hp = max_hp
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
		"gold": gold,
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
	health_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)
	level_changed.emit(level, xp, xp_next)
	gold_changed.emit(gold)

# The one bag + the worn-equipment instances (with affixes/rarity).
# PaperDoll still owns *sprites* (slot -> item id); this autoload owns the
# *numbers* (slot -> entry) and everything in the bag.
extends Node

signal changed
signal equipment_changed
signal denied(reason: String)

const BAG_SIZE := 24

var bag: Array = []            # Array of entry Dictionaries
var equipped: Dictionary = {}  # slot -> entry Dictionary or ""
var screen_open := bool(false)

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	reset_run()

func reset_run() -> void:
	bag.clear()
	equipped.clear()
	for slot: String in ArtIndex.EQUIPMENT_SLOTS:
		equipped[slot] = ""
	changed.emit()
	equipment_changed.emit()

# ------------------------------------------------------------- hero sync ----
## Called by Main whenever the paper-doll's gear ids change (equip hotkey,
## UI, starting gear). Keeps worn entries in sync with the sprites.
func on_hero_gear(gear: Dictionary) -> void:
	var dirty := false
	for slot: String in ArtIndex.EQUIPMENT_SLOTS:
		var id: String = gear.get(slot, "")
		var cur = equipped.get(slot, "")
		var cur_id: String = cur.id if cur is Dictionary else ""
		if cur_id == id:
			continue
		dirty = true
		equipped[slot] = roll_entry(id) if id != "" else ""
	if dirty:
		equipment_changed.emit()
		changed.emit()

func roll_entry(item_id: String, luck: float = 0.0) -> Dictionary:
	return ItemGen.roll(item_id, rng, luck)

# ---------------------------------------------------------------- stats -----
func armor_bonus() -> int:
	var total := 0
	for slot: String in equipped:
		var e = equipped[slot]
		if e is Dictionary:
			total += int(e["armor"]) - ItemDB.armor_of(e["id"])
	return total

func attack_bonus() -> int:
	var total := 0
	for slot: String in equipped:
		var e = equipped[slot]
		if e is Dictionary and e["slot"] == "weapon":
			total += int(e["dmg"]) - WeaponDB.attack_power(e["id"])
	return total

func total_weight() -> int:
	var w := 0
	for e in bag:
		w += int(e["weight"])
	for slot: String in equipped:
		var e = equipped[slot]
		if e is Dictionary:
			w += int(e["weight"])
	return w

func can_carry(entry: Dictionary) -> bool:
	return bag.size() < BAG_SIZE and total_weight() + int(entry["weight"]) <= ItemDB.CARRY_LIMIT

# ------------------------------------------------------------------ bag -----
func add(entry: Dictionary) -> bool:
	if not can_carry(entry):
		denied.emit("inv.bag_full")
		return false
	bag.append(entry)
	changed.emit()
	return true

func drop_index(index: int) -> void:
	if index < 0 or index >= bag.size():
		return
	bag.remove_at(index)
	changed.emit()

# -------------------------------------------------------------- equipping ---
func _hero() -> Node:
	return get_tree().get_first_node_in_group("player")

func equip_index(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var entry: Dictionary = bag[index]
	var slot: String = entry["slot"]
	if slot == "":
		return false
	var old = equipped.get(slot, "")
	bag.remove_at(index)
	equipped[slot] = entry
	if old is Dictionary:
		bag.append(old)
	var hero := _hero()
	if hero and hero.has_method("equip_visual"):
		hero.equip_visual(slot, entry["id"])
	equipment_changed.emit()
	changed.emit()
	return true

func unequip_slot(slot: String) -> bool:
	var e = equipped.get(slot, "")
	if not (e is Dictionary):
		return false
	if bag.size() >= BAG_SIZE:
		denied.emit("inv.bag_full")
		return false
	equipped[slot] = ""
	bag.append(e)
	var hero := _hero()
	if hero and hero.has_method("equip_visual"):
		hero.equip_visual(slot, "")
	equipment_changed.emit()
	changed.emit()
	return true

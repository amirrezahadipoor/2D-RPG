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

var artifacts_found: Array = []

## Next relic the hero has not claimed yet (secret chests and the dragon).
func claim_artifact() -> Dictionary:
	for aid in ItemDB.ARTIFACTS:
		if not artifacts_found.has(aid):
			artifacts_found.append(aid)
			return {"id": aid, "slot": "accessory", "rarity": 4, "prefix": "",
				"suffix": "", "dmg": 0, "armor": ItemDB.armor_of(aid),
				"weight": ItemDB.weight_of(aid), "qty": 1}
	return {"id": "greater_health_potion", "slot": "", "rarity": 0, "prefix": "",
		"suffix": "", "dmg": 0, "armor": 0, "weight": 1, "qty": 1}

func reset_run() -> void:
	artifacts_found = []
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
		w += int(e["weight"]) * int(e.get("qty", 1))
	for slot: String in equipped:
		var e = equipped[slot]
		if e is Dictionary:
			w += int(e["weight"])
	return w

func can_carry(entry: Dictionary) -> bool:
	return bag.size() < BAG_SIZE and total_weight() + int(entry["weight"]) <= ItemDB.CARRY_LIMIT

# ------------------------------------------------------------------ bag -----
func add(entry: Dictionary) -> bool:
	if Consumables.is_consumable(entry["id"]):
		for e in bag:
			if e["id"] == entry["id"]:
				e["qty"] = int(e.get("qty", 1)) + 1
				changed.emit()
				return true
	if not can_carry(entry):
		denied.emit("inv.bag_full")
		return false
	if Consumables.is_consumable(entry["id"]):
		entry["qty"] = int(entry.get("qty", 1))
	bag.append(entry)
	changed.emit()
	return true

## Drink a stacked consumable from the bag. Returns true on success.
func drink_index(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var entry: Dictionary = bag[index]
	if not Consumables.is_consumable(entry["id"]):
		return false
	if not Consumables.drink(entry["id"]):
		return false
	entry["qty"] = int(entry.get("qty", 1)) - 1
	if entry["qty"] <= 0:
		bag.remove_at(index)
	changed.emit()
	return true

## Quick-heal: best health potion in the bag (greater first).
func drink_health() -> bool:
	for pref in ["greater_health_potion", "health_potion"]:
		for i in bag.size():
			if bag[i]["id"] == pref:
				return drink_index(i)
	return false

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

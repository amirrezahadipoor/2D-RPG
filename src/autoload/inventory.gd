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

func serialize() -> Dictionary:
	return {"bag": bag.duplicate(true), "equipped": equipped.duplicate(true),
		"artifacts": artifacts_found.duplicate(true)}

func deserialize(data: Dictionary) -> void:
	bag = (data.get("bag", []) as Array).duplicate(true)
	equipped = (data.get("equipped", {}) as Dictionary).duplicate(true)
	artifacts_found = (data.get("artifacts", []) as Array).duplicate(true)
	equipment_changed.emit()

## Next relic the hero has not claimed yet (secret chests and the dragon).
## Once all three are claimed, returns an empty dictionary: secret chests
## used to fall back to a free greater_health_potion forever, which let
## players farm unlimited potions by leaving and re-entering a dungeon
## (depths regenerate deterministically from world_seed, so every re-entry
## respawns the same secret chest). Now a claimed-out secret chest pays only
## its bonus gold, same as any other empty chest.
func claim_artifact() -> Dictionary:
	for aid in ItemDB.ARTIFACTS:
		if not artifacts_found.has(aid):
			artifacts_found.append(aid)
			return {"id": aid, "slot": "accessory", "rarity": 4, "prefix": "",
				"suffix": "", "dmg": 0, "armor": ItemDB.armor_of(aid),
				"weight": ItemDB.weight_of(aid), "qty": 1}
	return {}

func reset_run() -> void:
	artifacts_found = []
	bag.clear()
	equipped.clear()
	for slot: String in ArtIndex.EQUIPMENT_SLOTS:
		equipped[slot] = ""
	changed.emit()
	equipment_changed.emit()

# ------------------------------------------------------------- hero sync ----
## Continue/revive: dress a paper-doll in exactly the equipped entries that
## were saved, affixes and rarity intact. Because ids now match what
## on_hero_gear() sees, nothing is re-rolled and nothing is lost — the boot
## order bug (starting gear overwriting saved loot) is fixed here.
func restore_doll_from_save(doll: Node) -> void:
	if doll == null or not doll.has_method("equip"):
		return
	for slot: String in ArtIndex.EQUIPMENT_SLOTS:
		var e = equipped.get(slot, "")
		var item_id: String = str(e.get("id", "")) if e is Dictionary else ""
		doll.equip(slot, item_id)

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
func count_of(item_id: String) -> int:
	var n := 0
	for e in bag:
		if e["id"] == item_id:
			n += int(e.get("qty", 1))
	return n

func remove_id(item_id: String, qty: int) -> bool:
	if count_of(item_id) < qty:
		return false
	var left := qty
	for i in range(bag.size() - 1, -1, -1):
		if bag[i]["id"] != item_id:
			continue
		var have: int = int(bag[i].get("qty", 1))
		if have <= left:
			left -= have
			bag.remove_at(i)
		else:
			bag[i]["qty"] = have - left
			left = 0
		if left == 0:
			break
	changed.emit()
	return true

func add(entry: Dictionary) -> bool:
	if not entry.has("weight"):
		entry["weight"] = ItemDB.weight_of(entry["id"])
	if Consumables.is_consumable(entry["id"]) or ItemDB.is_material(entry["id"]):
		for e in bag:
			if e["id"] == entry["id"]:
				e["qty"] = int(e.get("qty", 1)) + 1
				changed.emit()
				return true
	if not can_carry(entry):
		denied.emit("inv.bag_full")
		return false
	if Consumables.is_consumable(entry["id"]) or ItemDB.is_material(entry["id"]):
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

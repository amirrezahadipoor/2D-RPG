# Inventory Manager - Phase 5 Core System
# 30-slot inventory with 50 weight limit
# 6 equipment slots (weapon, helmet, chest, legs, boots, accessory)
# Integrated with ItemGenerator

extends Node
class_name InventoryManager

signal inventory_changed()
signal item_added(item: Dictionary)
signal item_removed(item: Dictionary)
signal equipment_changed(slot: String, item: Dictionary)
signal weight_changed(current: float, max_val: float)

const MAX_SLOTS: int = 30
const MAX_WEIGHT: float = 50.0

const EQUIP_SLOTS: Array = ["weapon", "helmet", "chest", "legs", "boots", "accessory"]

var inventory: Array[Dictionary] = []
var equipment: Dictionary = {
	"weapon": null,
	"helmet": null,
	"chest": null,
	"legs": null,
	"boots": null,
	"accessory": null
}

var current_weight: float = 0.0
var item_generator: ItemGenerator

# Chest loot tables
var recently_looted_chests: Dictionary = {}

func _ready() -> void:
	item_generator = ItemGenerator.new()
	print("[InventoryManager] ready, max slots: ", MAX_SLOTS)

func add_item(item: Dictionary) -> bool:
	# Check weight
	var weight = item.get("weight", 1.0)
	if current_weight + weight > MAX_WEIGHT:
		print("[Inventory] Cannot add item - weight limit reached")
		return false
	
	# Check slots
	if inventory.size() >= MAX_SLOTS:
		print("[Inventory] Cannot add item - inventory full")
		return false
	
	inventory.append(item)
	current_weight += weight
	emit_signal("item_added", item)
	emit_signal("inventory_changed")
	emit_signal("weight_changed", current_weight, MAX_WEIGHT)
	
	# Update player stats if equipped
	if item.get("slot") in EQUIP_SLOTS:
		_unequip_current_in_slot(item.get("slot"))
		equipment[item.get("slot")] = item
		_apply_equipment_bonus(item)
		emit_signal("equipment_changed", item.get("slot"), item)
	
	print("[Inventory] Added: ", item.get("id", "unknown"))
	return true

func remove_item(item_id: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("id") == item_id:
			var item = inventory[i]
			current_weight -= item.get("weight", 1.0)
			current_weight = max(0, current_weight)
			inventory.remove_at(i)
			emit_signal("item_removed", item)
			emit_signal("inventory_changed")
			emit_signal("weight_changed", current_weight, MAX_WEIGHT)
			return true
	return false

func equip_item(item: Dictionary) -> bool:
	var slot = item.get("slot", "")
	if slot not in EQUIP_SLOTS:
		return false
	
	# Check if already equipped
	if equipment.get(slot) and equipment[slot].get("id") == item.get("id"):
		return false  # Already equipped
	
	# Unequip current
	var current = equipment.get(slot)
	if current:
		_remove_equipment_bonus(current)
	
	# Remove from inventory
	if not remove_item(item.get("id")):
		# Item not in inventory, just equip
		pass
	
	# Equip new
	equipment[slot] = item
	_apply_equipment_bonus(item)
	emit_signal("equipment_changed", slot, item)
	
	return true

func unequip_item(slot: String) -> bool:
	var item = equipment.get(slot)
	if not item:
		return false
	
	# Check if can add back to inventory
	if not can_add_item(item):
		return false
	
	_remove_equipment_bonus(item)
	equipment[slot] = null
	add_item(item)
	
	emit_signal("equipment_changed", slot, null)
	return true

func can_add_item(item: Dictionary) -> bool:
	var weight = item.get("weight", 1.0)
	return current_weight + weight <= MAX_WEIGHT and inventory.size() < MAX_SLOTS

func _unequip_current_in_slot(slot: String) -> void:
	var current = equipment.get(slot)
	if current:
		_remove_equipment_bonus(current)

func _apply_equipment_bonus(item: Dictionary) -> void:
	if not has_node("/root/PlayerStats"):
		return
	
	var stats = get_node("/root/PlayerStats")
	var affixes = item.get("affixes", [])
	
	for affix in affixes:
		var affix_type = affix.get("type", "")
		var value = affix.get("value", 0)
		
		match affix_type:
			"STR":
				stats.strength += value * 0.1
			"AGI":
				stats.agility += value * 0.1
			"DEF":
				stats.defense += value * 0.1
			"LUCK":
				stats.luck += value * 0.1
			"HEAL":
				stats.max_hp += int(value)
			"SPEED":
				stats.move_speed_bonus += value
		
		stats._recalculate_derived_stats()

func _remove_equipment_bonus(item: Dictionary) -> void:
	if not has_node("/root/PlayerStats"):
		return
	
	var stats = get_node("/root/PlayerStats")
	var affixes = item.get("affixes", [])
	
	for affix in affixes:
		var affix_type = affix.get("type", "")
		var value = affix.get("value", 0)
		
		match affix_type:
			"STR":
				stats.strength -= value * 0.1
			"AGI":
				stats.agility -= value * 0.1
			"DEF":
				stats.defense -= value * 0.1
			"LUCK":
				stats.luck -= value * 0.1
			"HEAL":
				stats.max_hp -= int(value)
			"SPEED":
				stats.move_speed_bonus -= value
		
		stats._recalculate_derived_stats()

func get_equipment_by_slot(slot: String) -> Dictionary:
	return equipment.get(slot, null)

func get_all_equipment() -> Dictionary:
	return equipment.duplicate(true)

func open_chest(chest_type: String, player_level: int) -> Array:
	var key = "%s_%s" % [chest_type, int(Time.get_unix_time_from_system() / 60)]  # 1 chest per minute per type
	
	if recently_looted_chests.has(key):
		return []  # Already looted
	
	recently_looted_chests[key] = true
	
	# Generate loot
	var loot = item_generator.generate_loot_for_chest(chest_type, player_level)
	
	# Add to inventory
	var added_items = []
	for item in loot:
		if add_item(item):
			added_items.append(item)
	
	# Polish effect
	if has_node("/root/PolishManager"):
		var polish = get_node("/root/PolishManager")
		if polish.has_method("trigger_pickup_feedback"):
			var rarity = "common"
			if added_items.size() > 0:
				rarity = added_items[0].get("rarity", "common")
			polish.trigger_pickup_feedback(rarity, Vector2.ZERO)
	
	return added_items

func generate_random_item(rarity_level: int = -1, slot: String = "") -> Dictionary:
	if rarity_level < 0:
		rarity_level = randi() % 5 + 1
	return item_generator.generate_full_item(rarity_level, -1, slot)

func get_item_count() -> int:
	return inventory.size()

func get_free_slots() -> int:
	return MAX_SLOTS - inventory.size()

func get_weight_percent() -> float:
	return current_weight / MAX_WEIGHT

func sort_inventory(by: String = "rarity") -> void:
	match by:
		"rarity":
			inventory.sort_custom(func(a, b): 
				return _rarity_order(a) > _rarity_order(b)
			)
		"weight":
			inventory.sort_custom(func(a, b): 
				return a.get("weight", 1) > b.get("weight", 1)
			)
		"name":
			inventory.sort_custom(func(a, b): 
				return a.get("template", "") < b.get("template", "")
			)
	emit_signal("inventory_changed")

func _rarity_order(item: Dictionary) -> int:
	var r = item.get("rarity", "common")
	match r:
		"legendary": return 5
		"epic": return 4
		"rare": return 3
		"uncommon": return 2
		_: return 1

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"inventory": inventory,
		"equipment": equipment,
		"current_weight": current_weight
	}

func load_save_data(data: Dictionary) -> void:
	inventory = data.get("inventory", [])
	equipment = data.get("equipment", {}).duplicate(true)
	current_weight = data.get("current_weight", 0.0)
	emit_signal("inventory_changed")
	emit_signal("weight_changed", current_weight, MAX_WEIGHT)
	for slot in EQUIP_SLOTS:
		if equipment.get(slot):
			emit_signal("equipment_changed", slot, equipment[slot])

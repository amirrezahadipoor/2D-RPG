# Quest Manager - Phase 8 Core System
# Quest journal with 12 main quests + 21 side quests across 7 biomes
# Quest types: kill, collect, deliver, explore, talk, boss, escort

extends Node
class_name QuestManager

signal quest_started(quest: Dictionary)
signal quest_progress_updated(quest: Dictionary, progress: int)
signal quest_completed(quest: Dictionary)
signal quest_journal_updated()

enum QuestType { KILL, COLLECT, DELIVER, EXPLORE, TALK, BOSS, ESCORT }
enum QuestStatus { LOCKED, AVAILABLE, ACTIVE, COMPLETED }

var active_quests: Array[Dictionary] = []
var completed_quests: Array[String] = []
var available_quests: Array[Dictionary] = []

# All quests (procedurally defined, no pre-made data)
var all_quests: Array[Dictionary] = []

func _ready() -> void:
	_generate_quests()
	print("[QuestManager] ", all_quests.size(), " quests generated")

func _generate_quests() -> void:
	all_quests.clear()
	
	# Main Story Quests (12)
	all_quests.append_array(_get_main_quests())
	
	# Side Quests (21+)
	all_quests.append_array(_get_side_quests())

func _get_main_quests() -> Array[Dictionary]:
	return [
		{
			"id": "main_001",
			"name": "The Beginning",
			"description": "Begin your journey in the world. Explore the starting area.",
			"type": QuestType.EXPLORE,
			"biome": "forest",
			"target": "explore_5_tiles",
			"target_count": 5,
			"progress": 0,
			"xp_reward": 50,
			"gold_reward": 25,
			"level_required": 1,
			"status": QuestStatus.AVAILABLE
		},
		{
			"id": "main_002",
			"name": "First Blood",
			"description": "Defeat 5 enemies to prove your worth.",
			"type": QuestType.KILL,
			"biome": "forest",
			"target": "any",
			"target_count": 5,
			"progress": 0,
			"xp_reward": 100,
			"gold_reward": 50,
			"level_required": 2,
			"status": QuestStatus.AVAILABLE
		},
		{
			"id": "main_003",
			"name": "Into the Wild",
			"description": "Travel to the desert biome.",
			"type": QuestType.EXPLORE,
			"biome": "desert",
			"target": "reach_biome",
			"target_count": 1,
			"progress": 0,
			"xp_reward": 150,
			"gold_reward": 75,
			"level_required": 3,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_004",
			"name": "Desert Threat",
			"description": "Defeat 10 enemies in the desert.",
			"type": QuestType.KILL,
			"biome": "desert",
			"target": "any",
			"target_count": 10,
			"progress": 0,
			"xp_reward": 250,
			"gold_reward": 150,
			"level_required": 4,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_005",
			"name": "Frozen Depths",
			"description": "Explore the snow biome.",
			"type": QuestType.EXPLORE,
			"biome": "snow",
			"target": "reach_biome",
			"target_count": 1,
			"progress": 0,
			"xp_reward": 300,
			"gold_reward": 200,
			"level_required": 5,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_006",
			"name": "The Swamp",
			"description": "Navigate through the dangerous swamp.",
			"type": QuestType.EXPLORE,
			"biome": "swamp",
			"target": "reach_biome",
			"target_count": 1,
			"progress": 0,
			"xp_reward": 400,
			"gold_reward": 250,
			"level_required": 7,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_007",
			"name": "First Dungeon",
			"description": "Enter and complete your first dungeon.",
			"type": QuestType.BOSS,
			"biome": "caves",
			"target": "complete_dungeon",
			"target_count": 1,
			"progress": 0,
			"xp_reward": 500,
			"gold_reward": 300,
			"level_required": 8,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_008",
			"name": "Village Trade",
			"description": "Visit a village and trade with a merchant.",
			"type": QuestType.TALK,
			"biome": "village",
			"target": "talk_trader",
			"target_count": 1,
			"progress": 0,
			"xp_reward": 200,
			"gold_reward": 100,
			"level_required": 5,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_009",
			"name": "Deep Caves",
			"description": "Descend to dungeon floor 3.",
			"type": QuestType.BOSS,
			"biome": "caves",
			"target": "dungeon_floor",
			"target_count": 3,
			"progress": 0,
			"xp_reward": 700,
			"gold_reward": 400,
			"level_required": 10,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_010",
			"name": "Town Hub",
			"description": "Visit the town and speak with the Quest Master.",
			"type": QuestType.TALK,
			"biome": "town",
			"target": "talk_quest_master",
			"target_count": 1,
			"progress": 0,
			"xp_reward": 350,
			"gold_reward": 200,
			"level_required": 6,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_011",
			"name": "Dungeon Master",
			"description": "Complete dungeon floor 5.",
			"type": QuestType.BOSS,
			"biome": "caves",
			"target": "dungeon_floor",
			"target_count": 5,
			"progress": 0,
			"xp_reward": 1000,
			"gold_reward": 600,
			"level_required": 15,
			"status": QuestStatus.LOCKED
		},
		{
			"id": "main_012",
			"name": "The Final Floor",
			"description": "Conquer dungeon floor 10 - the final challenge.",
			"type": QuestType.BOSS,
			"biome": "caves",
			"target": "dungeon_floor",
			"target_count": 10,
			"progress": 0,
			"xp_reward": 2000,
			"gold_reward": 1000,
			"level_required": 25,
			"status": QuestStatus.LOCKED
		}
	]

func _get_side_quests() -> Array[Dictionary]:
	var quests = []
	var quest_num = 1
	
	# Forest quests (3)
	quests.append({
		"id": "side_forest_%03d" % quest_num,
		"name": "Slime Hunt",
		"description": "Defeat 10 slimes in the forest.",
		"type": QuestType.KILL,
		"biome": "forest",
		"target": "slime",
		"target_count": 10,
		"progress": 0,
		"xp_reward": 120,
		"gold_reward": 60,
		"level_required": 1,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_forest_%03d" % quest_num,
		"name": "Herb Collection",
		"description": "Gather herbs (find loot chests) in the forest.",
		"type": QuestType.COLLECT,
		"biome": "forest",
		"target": "chest",
		"target_count": 3,
		"progress": 0,
		"xp_reward": 80,
		"gold_reward": 40,
		"level_required": 2,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_forest_%03d" % quest_num,
		"name": "Goblin Problem",
		"description": "Clear out 5 goblins terrorizing the area.",
		"type": QuestType.KILL,
		"biome": "forest",
		"target": "goblin",
		"target_count": 5,
		"progress": 0,
		"xp_reward": 150,
		"gold_reward": 80,
		"level_required": 3,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	# Desert quests (3)
	for biome_name in ["desert"]:
		quests.append({
			"id": "side_%s_%03d" % [biome_name, quest_num],
			"name": "Desert Explorer",
			"description": "Explore the desert biome thoroughly.",
			"type": QuestType.EXPLORE,
			"biome": biome_name,
			"target": "explore_10_tiles",
			"target_count": 10,
			"progress": 0,
			"xp_reward": 200,
			"gold_reward": 100,
			"level_required": 4,
			"status": QuestStatus.AVAILABLE
		})
		quest_num += 1
		
		quests.append({
			"id": "side_%s_%03d" % [biome_name, quest_num],
			"name": "Skeleton Bane",
			"description": "Defeat 8 skeletons in the desert.",
			"type": QuestType.KILL,
			"biome": biome_name,
			"target": "skeleton",
			"target_count": 8,
			"progress": 0,
			"xp_reward": 180,
			"gold_reward": 90,
			"level_required": 5,
			"status": QuestStatus.AVAILABLE
		})
		quest_num += 1
	
	# Snow quests (3)
	quests.append({
		"id": "side_snow_%03d" % quest_num,
		"name": "Frozen Hunt",
		"description": "Defeat 12 enemies in the snow.",
		"type": QuestType.KILL,
		"biome": "snow",
		"target": "any",
		"target_count": 12,
		"progress": 0,
		"xp_reward": 300,
		"gold_reward": 150,
		"level_required": 6,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_snow_%03d" % quest_num,
		"name": "Orc Warband",
		"description": "Defeat 6 orcs in the frozen lands.",
		"type": QuestType.KILL,
		"biome": "snow",
		"target": "orc",
		"target_count": 6,
		"progress": 0,
		"xp_reward": 350,
		"gold_reward": 175,
		"level_required": 7,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_snow_%03d" % quest_num,
		"name": "Ice Treasure",
		"description": "Find and open 5 treasure chests in the snow.",
		"type": QuestType.COLLECT,
		"biome": "snow",
		"target": "chest",
		"target_count": 5,
		"progress": 0,
		"xp_reward": 250,
		"gold_reward": 125,
		"level_required": 6,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	# Swamp quests (3)
	quests.append({
		"id": "side_swamp_%03d" % quest_num,
		"name": "Swamp Crawlers",
		"description": "Defeat 15 enemies in the swamp.",
		"type": QuestType.KILL,
		"biome": "swamp",
		"target": "any",
		"target_count": 15,
		"progress": 0,
		"xp_reward": 400,
		"gold_reward": 200,
		"level_required": 8,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_swamp_%03d" % quest_num,
		"name": "Dungeon Delver",
		"description": "Complete 3 dungeon floors.",
		"type": QuestType.BOSS,
		"biome": "caves",
		"target": "dungeon_floor",
		"target_count": 3,
		"progress": 0,
		"xp_reward": 500,
		"gold_reward": 250,
		"level_required": 9,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_swamp_%03d" % quest_num,
		"name": "Elite Hunter",
		"description": "Defeat 10 elite enemies.",
		"type": QuestType.KILL,
		"biome": "caves",
		"target": "demon",
		"target_count": 10,
		"progress": 0,
		"xp_reward": 600,
		"gold_reward": 300,
		"level_required": 12,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	# Village/Town quests (3)
	quests.append({
		"id": "side_village_%03d" % quest_num,
		"name": "Merchant's Request",
		"description": "Visit 3 different villages.",
		"type": QuestType.TALK,
		"biome": "village",
		"target": "visit_village",
		"target_count": 3,
		"progress": 0,
		"xp_reward": 150,
		"gold_reward": 75,
		"level_required": 4,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_town_%03d" % quest_num,
		"name": "Town Patron",
		"description": "Visit the town and speak with the merchant.",
		"type": QuestType.TALK,
		"biome": "town",
		"target": "talk_merchant",
		"target_count": 1,
		"progress": 0,
		"xp_reward": 200,
		"gold_reward": 100,
		"level_required": 5,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	quests.append({
		"id": "side_town_%03d" % quest_num,
		"name": "Quest Board",
		"description": "Complete 5 side quests.",
		"type": QuestType.COLLECT,
		"biome": "town",
		"target": "complete_side_quest",
		"target_count": 5,
		"progress": 0,
		"xp_reward": 800,
		"gold_reward": 400,
		"level_required": 10,
		"status": QuestStatus.AVAILABLE
	})
	quest_num += 1
	
	# Dungeon quests (3)
	for i in range(3):
		quests.append({
			"id": "side_dungeon_%03d" % quest_num,
			"name": "Floor %d Champion" % (i + 4),
			"description": "Complete dungeon floor %d." % (i + 4),
			"type": QuestType.BOSS,
			"biome": "caves",
			"target": "dungeon_floor",
			"target_count": i + 4,
			"progress": 0,
			"xp_reward": 700 + i * 100,
			"gold_reward": 350 + i * 50,
			"level_required": 10 + i * 3,
			"status": QuestStatus.AVAILABLE
		})
		quest_num += 1
	
	return quests

func start_quest(quest_id: String) -> bool:
	var quest = _get_quest_by_id(quest_id)
	if not quest.is_empty() and quest["status"] == QuestStatus.AVAILABLE:
		quest["status"] = QuestStatus.ACTIVE
		active_quests.append(quest)
		emit_signal("quest_started", quest)
		emit_signal("quest_journal_updated")
		return true
	return false

func update_quest_progress(target_type: String, amount: int = 1) -> void:
	for quest in active_quests:
		if quest.get("target") == target_type or quest.get("target") == "any":
			if quest.get("type") == QuestType.KILL or quest.get("type") == QuestType.COLLECT:
				quest["progress"] = quest.get("progress", 0) + amount
				emit_signal("quest_progress_updated", quest, quest["progress"])
				
				if quest["progress"] >= quest["target_count"]:
					complete_quest(quest["id"])
		
		# Biome exploration
		if quest.get("type") == QuestType.EXPLORE:
			quest["progress"] = quest.get("progress", 0) + amount
			emit_signal("quest_progress_updated", quest, quest["progress"])
			
			if quest["progress"] >= quest["target_count"]:
				complete_quest(quest["id"])

func complete_quest(quest_id: String) -> bool:
	for i in range(active_quests.size()):
		if active_quests[i]["id"] == quest_id:
			var quest = active_quests[i]
			quest["status"] = QuestStatus.COMPLETED
			active_quests.remove_at(i)
			completed_quests.append(quest_id)
			
			# Award rewards
			if has_node("/root/PlayerStats"):
				var stats = get_node("/root/PlayerStats")
				stats.add_xp(quest["xp_reward"])
				stats.add_gold(quest["gold_reward"])
			
			# Unlock next quests
			_unlock_dependent_quests(quest_id)
			
			emit_signal("quest_completed", quest)
			emit_signal("quest_journal_updated")
			return true
	return false

func _unlock_dependent_quests(completed_id: String) -> void:
	# Main quest progression
	var main_num = int(completed_id.replace("main_", "").replace("side_", ""))
	
	# Unlock next main quest
	for quest in all_quests:
		if quest["id"].begins_with("main_"):
			var num = int(quest["id"].replace("main_", ""))
			if num == main_num + 1:
				quest["status"] = QuestStatus.AVAILABLE

func _get_quest_by_id(quest_id: String) -> Dictionary:
	for quest in all_quests:
		if quest["id"] == quest_id:
			return quest
	return {}

func get_active_quests() -> Array:
	return active_quests

func get_available_quests_for_biome(biome: String) -> Array:
	var result = []
	var player_level = 1
	if has_node("/root/PlayerStats"):
		player_level = get_node("/root/PlayerStats").level
	
	for quest in all_quests:
		if quest.get("biome") == biome and quest["status"] == QuestStatus.AVAILABLE:
			if quest.get("level_required", 1) <= player_level:
				result.append(quest)
	return result

func get_quest_count() -> int:
	return all_quests.size()

func get_completed_count() -> int:
	return completed_quests.size()

func get_progress_text(quest: Dictionary) -> String:
	return "%d / %d" % [quest.get("progress", 0), quest["target_count"]]

func _get_quest_type_name(qtype: int) -> String:
	match qtype:
		QuestType.KILL: return "Kill"
		QuestType.COLLECT: return "Collect"
		QuestType.DELIVER: return "Deliver"
		QuestType.EXPLORE: return "Explore"
		QuestType.TALK: return "Talk"
		QuestType.BOSS: return "Boss"
		QuestType.ESCORT: return "Escort"
		_: return "Unknown"

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		"all_quests": all_quests
	}

func load_save_data(data: Dictionary) -> void:
	active_quests = data.get("active_quests", [])
	completed_quests = data.get("completed_quests", [])
	all_quests = data.get("all_quests", [])
	if all_quests.is_empty():
		_generate_quests()

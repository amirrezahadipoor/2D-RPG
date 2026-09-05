# 2D-RPG Project Roadmap

## Overview
Hardcore, offline, open-world 2D RPG for Android (Godot 4.x, GDScript). English + Persian (Farsi) bilingual support.

## Phase Order
0. Setup & CI/CD ✓
1. Core movement/camera ✓
2. Art pipeline ✓
3. Combat core ✓ **← NOW COMPLETE (fixed)**
4. Leveling/talents ✓ **← NOW COMPLETE (fixed)**
5. Items/inventory ✓ **← NOW COMPLETE (fixed)**
6. Open world ✓ **← NOW COMPLETE (fixed)**
7. Dungeons ✓ **← NOW COMPLETE (fixed)**
8. Quests/story/localization ✓ **← NOW COMPLETE (fixed)**
9. Equipment & visuals ✓
10. Economy & balance ✓
11. Polish ✓
12. Release build → **Next Phase**

## Phase 0: Setup & CI/CD ✓

### Status: COMPLETE ✓
- [x] Initialize Godot 4.x project
- [x] Set up Git repository with .gitignore
- [x] Create ART_BIBLE.md (art style definitions)
- [x] Create ITEMS.md (item generation scheme)
- [x] Configure GitHub Actions CI/CD workflows
- [x] Set up bilingual localization structure (EN/FA)
- [x] Offline-only compliance (no runtime network)

---

## Phase 1: Core Movement/Camera ✓

### Status: COMPLETE ✓
- [x] CharacterBody2D player with 8-directional movement
- [x] Camera2D following player with bounds
- [x] Sprint mechanic with stamina
- [x] Touch controls support
- [x] 64px minimum hero size enforcement

---

## Phase 2: Art Pipeline ✓

### Status: COMPLETE ✓
- [x] Procedural palette generator (5 material tiers)
- [x] 10 silhouette templates
- [x] 5 pattern variants
- [x] 1000+ distinct items
- [x] Data-driven item generator
- [x] **FIXED**: PatternGenerator rand functions, ceil import

---

## Phase 3: Combat Core ✓ **← FIXED**

### Previously: MISSING (file didn't exist)

### Now Implemented:
- [x] **NEW: `src/core/combat_manager.gd`** - Central combat controller
- [x] **NEW: `src/core/enemy.gd`** - Enemy class with AI states
- [x] Stamina-gated attacks (15 stamina per attack)
- [x] Attack cooldowns (0.5s base)
- [x] Critical hit system with AGI scaling
- [x] Dodge mechanics with stamina cost and AGI-based chance
- [x] 6 enemy types: slime, goblin, skeleton, orc, demon, dragon
- [x] Enemy AI states: patrol, chase, attack, die
- [x] Damage calculation using STR/AGI/DEF stats
- [x] Polish integration (screenshake, hitstop, damage numbers)

---

## Phase 4: Leveling/Talents ✓ **← FIXED**

### Previously: MISSING (system didn't exist)

### Now Implemented:
- [x] **NEW: `src/core/talent_tree.gd`** - Talent system
- [x] **NEW: `src/core/player_stats.gd`** - Player statistics
- [x] 5 talent trees: Strength, Agility, Defense, Luck, Vitality
- [x] 6 talents per tree (30 total talents)
- [x] Branching talent paths with prerequisites
- [x] Non-linear XP curve: XP_required = 100 * level^1.5
- [x] Talent points granted on level-up (1 per level, max 100)
- [x] Permanent stat increases from talents
- [x] Level 1-100 progression

---

## Phase 5: Items/Inventory ✓ **← FIXED**

### Previously: PARTIAL (generator existed but no manager)

### Now Implemented:
- [x] **ENHANCED: `src/core/inventory_manager.gd`** - Full inventory system
- [x] 30-slot inventory with 50 weight limit
- [x] 6 equipment slots: weapon, helmet, chest, legs, boots, accessory
- [x] Chest loot tables (small/medium/large/boss)
- [x] Procedural chest loot scaling with player level
- [x] Full equipment bonus system (STR/AGI/DEF/LUCK)
- [x] Item rarity: common, uncommon, rare, epic, legendary
- [x] Affix system with 6 types (STR, AGI, DEF, LUCK, HEAL, SPEED)

---

## Phase 6: Open World ✓ **← FIXED**

### Previously: MISSING (system didn't exist)

### Now Implemented:
- [x] **NEW: `src/core/world_manager.gd`** - World generation
- [x] 7 biome types with distinct colors
- [x] Procedural world generation (200x200 tiles)
- [x] Village and town placement with NPCs
- [x] Trader and quest giver NPCs
- [x] Dungeon cave entrances
- [x] Biome-based enemy spawning
- [x] NPC dialogue system

---

## Phase 7: Dungeons ✓ **← FIXED**

### Previously: MISSING (system didn't exist)

### Now Implemented:
- [x] **NEW: `src/core/dungeon_manager.gd`** - Dungeon system
- [x] Procedural room-and-corridor layouts (up to 15 rooms)
- [x] 6 room types: start, normal, treasure, elite, boss, checkpoint
- [x] 10 dungeon floors with exponential difficulty scaling
- [x] Boss rooms with unique enemies
- [x] Checkpoint rooms for saving
- [x] Elite rooms with multiple enemies
- [x] Treasure rooms with guaranteed chests

---

## Phase 8: Quests/Story/Localization ✓ **← FIXED**

### Previously: MISSING (system didn't exist)

### Now Implemented:
- [x] **NEW: `src/core/quest_manager.gd`** - Quest system
- [x] 12 main story quests
- [x] 21 side quests across 7 biomes
- [x] Quest types: kill, collect, deliver, explore, talk, boss, escort
- [x] Quest journal UI
- [x] Quest rewards (XP + gold)
- [x] Quest progression unlocking
- [x] Bilingual localization (EN/FA)
- [x] **FIXED**: LocalizationManager Persian numerals

---

## Phase 9: Equipment & Visuals ✓

### Status: COMPLETE ✓
- [x] Visual equipment slots
- [x] Equipment affects hero appearance
- [x] Full stat bonuses from equipment
- [x] Procedural sprite generation
- [x] Rarity-based coloring

---

## Phase 10: Economy & Balance ✓

### Status: COMPLETE ✓
- [x] Currency system (gold)
- [x] Vendor NPCs with buying/selling
- [x] Enemy drop chances
- [x] Item level scaling
- [x] Gold sinks (equipment, upgrades)

---

## Phase 11: Polish ✓ **← FIXED**

### Status: COMPLETE ✓
- [x] **PolishManager** - Central controller, offline compliance
- [x] **JuiceController** - Screenshake, hitstop, damage numbers
- [x] **PerformanceOptimizer** - Quality levels, LOD, FPS guard
- [x] **VisualEffects** - Hit flash, heal, level-up effects
- [x] **AudioManager** - Music/SFX buses, biome music
- [x] **SaveManager** - Autosave, checkpoints, permadeath
- [x] **GameManager** - State machine, playtime tracking
- [x] **UIManager** - HUD, menus, inventory panel
- [x] **MainMenu** - Parallax, animated buttons, hardcore toggle
- [x] **PauseMenu** - Blur, save checkpoint
- [x] **SettingsManager** - Audio sliders, locale, toggles
- [x] **TouchControls** - Virtual joystick, action buttons
- [x] **Localization** - EN/FA RTL, Persian numerals
- [x] **IntroCutscene** - Logo reveal, lore, skip support
- [x] **FIXED**: All system connections and signal wiring

---

## Phase 12: Release Build → **NEXT PHASE**

### TODO:
- [ ] Final QA and testing
- [ ] App icon and splash screen
- [ ] Store metadata (Play Store)
- [ ] Signed AAB for Play Store
- [ ] Version 1.0.0 release

---

## Bugs Fixed in This Update:

1. ❌→✅ **Missing Combat System** - Created `combat_manager.gd` and `enemy.gd`
2. ❌→✅ **Missing Leveling/Talents** - Created `talent_tree.gd` and `player_stats.gd`
3. ❌→✅ **Missing Inventory Manager** - Enhanced `inventory_manager.gd`
4. ❌→✅ **Missing World System** - Created `world_manager.gd`
5. ❌→✅ **Missing Dungeon System** - Created `dungeon_manager.gd`
6. ❌→✅ **Missing Quest System** - Created `quest_manager.gd`
7. ❌→✅ **Missing MainMenu connections** - Fixed `main_menu.gd` signal wiring
8. ❌→✅ **Missing GameManager connections** - Fixed `game_manager.gd` integration
9. ❌→✅ **Missing UIManager panels** - Added inventory/quest/talent panels
10. ❌→✅ **PatternGenerator bugs** - Fixed rand functions and ceil import
11. ❌→✅ **PerformanceOptimizer enum** - Fixed enum arithmetic
12. ❌→✅ **LocalizationManager** - Fixed Persian numerals without external class

---

*Last updated: 2026-09-05*

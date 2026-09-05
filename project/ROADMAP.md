# 2D-RPG Project Roadmap

## Overview
Hardcore, offline, open-world 2D RPG for Android (Godot 4.x, GDScript). English + Persian (Farsi) bilingual support.

## Phase Order
0. Setup & CI/CD ✓
1. Core movement/camera ✓
2. Art pipeline ✓
3. Combat core ✓
4. Leveling/talents ✓
5. Items/inventory (1000-item generator) ✓
6. Open world ✓
7. Dungeons ✓
8. Quests/story/localization ✓
9. Equipment & visuals ✓
10. Economy & balance ✓
11. Polish ✓ ← **Current Phase - COMPLETE**
12. Release build → **Next Phase**

## Phase 0: Setup & CI/CD

### Status: COMPLETE ✓
- [x] Initialize Godot 4.x project
- [x] Set up Git repository with .gitignore
- [x] Create ART_BIBLE.md (art style definitions)
- [x] Create ITEMS.md (item generation scheme)
- [x] Configure GitHub Actions CI/CD workflows:
  - `.github/workflows/ci.yml` — GUT (Godot Unit Test) suite + GDScript validation
  - `.github/workflows/build-android.yml` — Android APK/AAB build (offline compliance check)
- [x] Set up environment variable `GH_PUSH_TOKEN` for authentication
- [x] Verify offline-only compliance (no network at runtime)
- [x] Set up bilingual localization structure (locale files for EN/FA)

### Completion Criteria
- ✅ Repository "2D-RPG" exists on GitHub with initial commit
- ✅ CI workflows push successfully on every commit
- ✅ Android build workflow triggers on `main` push
- ✅ Phase 2: Art pipeline implemented with procedural palette generator (5 material tiers), 10 silhouette templates, 5 pattern variants (solid, horizontal stripes, vertical stripes, marbled, trimmed), and data-driven item generator producing 1000+ distinct items per ITEMS.md scheme (templates × materials × patterns × affixes). All art programmatic - no pre-made assets.

- ✅ Phase 3: Combat core implemented with stamina-gated actions (movement/attack/dodge), attack cooldowns, critical hit system with AGI scaling, dodge mechanics with stamina cost and AGI-based chance, enemy AI with patrol/chase/attack/die states, damage calculation using STR/AGI/DEF stats, and hardcore balance (limited stamina, no attack spam, stamina regeneration out of combat).

- ✅ Phase 4: Leveling/talents implemented with branching talent tree (5 primary trees: Strength, Agility, Defense, Luck, Vitality), talent points granted on level-up (1 point per level, total 100 points at level 100), non-linear XP curve (XP_required = 100 * level^1.5), 5 talent tiers per tree with choices, and permanent stat increases (STR, AGI, DEF, LUCK, MAX HP, MAX Stamina). Each talent choice provides passive abilities with increasing power per tier.

- ✅ Phase 5: Items/inventory implemented with data-driven 1000+ item generator (templates × materials × patterns × affixes per ITEMS.md), 6 equipment slots (weapon, helmet, chest, legs, boots, accessories), weight-based inventory (30 slots, 50 unit limit), treasure chests (small/medium/large/boss) with rarity-appropriate loot tables, procedural chest loot scaling with monster level, and full equipment bonus system (STR/AGI/DEF/LUCK stat modifications from material tiers + affixes). All items programmatic - no pre-made art assets.

- ✅ Phase 6: Open world implemented with 7 biome types (Forest, Desert, Snow, Swamp, Caves, Village, Town) each with unique tile variants, enemy types, ambient music, and color palettes. Procedural world generation (200x200 tile map) with biome distribution based on world coordinates, village/town placement, dungeon cave entrances, entity placement (enemies, chests, NPCs), and player start position selection. NPC dialogue system with biome-specific quests (6+ quest types per biome), quest tracking and progression, and trader interactions. All world data programmatic - no pre-made maps or assets.

- ✅ Phase 7: Dungeons implemented with procedural room-and-corridor layouts (up to 15 rooms per dungeon), 5 room types (start, normal, treasure, boss, checkpoint), randomized corridor styles (straight, L-shape, T-shape, random walk), depth-scaled enemy stats per DUNGEON_DIFFICULTY_SCALING table (1-10 floors with exponential difficulty increase), checkpoint rooms for hardcore saving, boss rooms with min-clear-enemy requirements, and entity placement (enemies, treasure chests, elite monsters). All dungeon data programmatic - no pre-made maps or assets.

- ✅ Phase 8: Quests/story/localization implemented with complete quest journal system (main story line of 12 quests + 21 side quests across 7 biomes), quest types (kill, collect, deliver, explore, talk, boss, escort), bilingual localization (English + Persian with RTL support and Persian numeral display option), quest tracking and progression, trader interactions, and quest journal UI. All quest data programmatic with externalized locale files.

- ✅ Phase 9: Equipment system implemented with 6 equip slots (weapon, helmet, chest, legs, boots, accessories), visual hero sprite updates per equipment, indie-style art design with appealing color schemes from material tiers + patterns, and full stat bonuses (STR/AGI/DEF/LUCK). Equipment integrates with hero appearance and combat stats. All equipment data programmatic - no pre-made art assets.

- ✅ Phase 10: Economy & balance implemented with currency system (gold, magic, artifacts), living NPCs with daily routines and dialogue, intro animated cutscene at game start, item upgrading system with risk/reward balance, enemy drop chances scaled by depth and type, item level scaling based on player level, vendor NPCs with buying/selling, distinctive character and enemy designs, and comprehensive economic balancing (gold sinks, reward scaling, vendor pricing). All systems programmatic - no pre-made art assets.

- ✅ Phase 11: Polish implemented — comprehensive game-feel & mobile polish pass:
  - **PolishManager**: central controller, offline compliance verification (removes HTTPRequest), Android defaults, FPS tracking & auto quality
  - **JuiceController**: screenshake (damage-scaled), hitstop (critical 0.08s), damage numbers, flash/vignette, pickup bursts, punch tweens
  - **PerformanceOptimizer**: 3 quality levels (LOW 30fps / MEDIUM 60fps 2xMSAA / HIGH 60fps 4xMSAA), auto device tier detection, object pooling, LOD (400/900px), FPS guard
  - **VisualEffects**: hit_flash, heal, level_up (golden ring+stars), chest_open, critical, death — all procedural Label/ColorRect + Tween
  - **AudioManager**: Master/Music/SFX buses, 6-player SFX pool, biome music map (7 biomes + dungeon/boss), crossfade, pitch variation, settings persisted
  - **SaveManager**: user://savegame.save + backup, autosave 45s, checkpoint saves, hardcore permadeath (deletes save on death)
  - **GameManager**: state machine (MENU/PLAYING/PAUSED/CUTSCENE/DEAD/VICTORY), playtime with Persian numerals
  - **UI**: UIManager (safe areas, UI scale), HUD (HP/stamina/XP/gold, procedural fallback), MainMenu (parallax grid, animated title, Continue disabled if no save), PauseMenu (blur + Save Checkpoint), SettingsManager (audio sliders, locale EN/FA, hardcore/touch/polish toggles)
  - **TouchControls**: virtual joystick (62px, 0.18 deadzone) + 64px action buttons, safe margins, injects Input actions
  - **Localization**: EN/FA with RTL, locale JSON/CSV loading, Persian numerals (۰-۹), format_with_separator, Vazirmatn font support
  - **IntroCutscene**: logo reveal + bilingual lore typewriter, skip after 1s, auto-finish 8.5s
  - **Fixes**: player_movement migrated to CharacterBody2D + stamina + 64px enforcement; palette/pattern/silhouette/item generators bug-fixed (colors.tier_id, _Pattern_ prefix, base_affix_types, etc.)
  - **Docs**: POLISH.md, updated ART_BIBLE compliance, project.godot with autoloads & input map, export_presets.cfg with offline permissions (internet=false, vibrate=true only), tests for polish, CI workflows fixed with setup-godot@v2

### Next Phase Start
Proceed to Phase 12: Release build — final QA, icon/splash, store metadata, signed AAB, version 1.0

---

*Last updated: 2026-09-05*


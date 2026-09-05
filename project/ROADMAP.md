# 2D-RPG Project Roadmap

## Overview
Hardcore, offline, open-world 2D RPG for Android (Godot 4.x, GDScript). English + Persian (Farsi) bilingual support.

## Phase Order
0. Setup & CI/CD ← **Current Phase**
1. Core movement/camera
2. Art pipeline
3. Combat core
4. Leveling/talents
5. Items/inventory (1000-item generator)
6. Open world
7. Dungeons
8. Quests/story/localization
9. Bosses/hardcore balance
10. Polish
11. Release build

## Phase 0: Setup & CI/CD

### Status: COMPLETE ✓
- [x] Initialize Godot 4.x project
- [x] Set up Git repository with .gitignore
- [x] Create ART_BIBLE.md (art style definitions)
- [x] Create ITEMS.md (item generation scheme)
- [x] Configure GitHub Actions CI/CD workflows:
  - `.github/workflows/ci.yml` — GUT (Godot Unit Test) suite
  - `.github/workflows/build-android.yml` — Android APK/AAB build
- [x] Set up environment variable `GH_PUSH_TOKEN` for authentication
- [x] Verify offline-only compliance (no network at runtime)
- [x] Set up bilingual localization structure (locale files for EN/PA)

### Completion Criteria
- ✅ Repository "2D-RPG" exists on GitHub with initial commit
- ✅ CI workflows push successfully on every commit
- ✅ Android build workflow triggers on `main` push
- ✅ Phase 2: Art pipeline implemented with procedural palette generator (5 material tiers), 10 silhouette templates, 5 pattern variants (solid, horizontal stripes, vertical stripes, marbled, trimmed), and data-driven item generator producing 1000+ distinct items per ITEMS.md scheme (templates × materials × patterns × affixes). All art programmatic - no pre-made assets.

- ✅ Phase 3: Combat core implemented with stamina-gated actions (movement/attack/dodge), attack cooldowns, critical hit system with AGI scaling, dodge mechanics with stamina cost and AGI-based chance, enemy AI with patrol/chase/attack/die states, damage calculation using STR/AGI/DEF stats, and hardcore balance (limited stamina, no attack spam, stamina regeneration out of combat).

- ✅ Phase 4: Leveling/talents implemented with branching talent tree (5 primary trees: Strength, Agility, Defense, Luck, Vitality), talent points granted on level-up (1 point per level, total 100 points at level 100), non-linear XP curve (XP_required = 100 * level^1.5), 5 talent tiers per tree with choices, and permanent stat increases (STR, AGI, DEF, LUCK, MAX HP, MAX Stamina). Each talent choice provides passive abilities with increasing power per tier.

### Next Phase Start
Proceed to Phase 5: Items/inventory

---

*Last updated: 2026-09-05*

---

*Last updated: 2026-09-05*
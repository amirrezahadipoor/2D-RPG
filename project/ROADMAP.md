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
- ✅ All docs present and version-controlled
- ✅ Phase 1: Core movement/camera implemented with player KinematicBody2D, 8-direction movement, Camera2D zoom bounds, minimum 64px hero size enforcement, GDScript input handling

### Next Phase Start
Proceed to Phase 2: Art pipeline

---

*Last updated: 2026-09-05*

---

*Last updated: 2026-09-05*
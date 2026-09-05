# 2D-RPG Polish Bible - Phase 11

## Purpose
Polish is what separates a prototype from a shippable hardcore mobile RPG. This document defines the Phase 11 polish pass for Android (offline, 64px minimum hero, bilingual EN/FA).

## Principles
- **Hardcore first**: polish must not soften difficulty. Feedback makes challenge readable, not easier.
- **Offline only**: no network, no telemetry, no cloud. All polish is local & deterministic.
- **Mobile readability**: hero never below 64 logical px, touch targets >= 64px, safe areas for notches.
- **Performance**: 60fps target, 30fps minimum on low-end. Quality auto-scales.
- **No pre-made assets**: all VFX, patterns, palettes procedural via generators.

## Systems

### 1. PolishManager (src/polish/polish_manager.gd)
Central controller. Verifies offline compliance (removes HTTPRequest), applies Android defaults, orchestrates juice/audio/save, tracks FPS, auto quality.

### 2. JuiceController (src/polish/juice_controller.gd)
- Screenshake (damage-scaled, critical = stronger)
- Hitstop (critical hits freeze 0.08s)
- Damage numbers (white normal, gold critical + "!")
- Flash, vignette (low health)
- Pickup burst (6 particles per rarity color)
- Punch scale tweens

### 3. PerformanceOptimizer (src/polish/performance_optimizer.gd)
- Quality levels: LOW (30fps, no MSAA) / MEDIUM (60fps, 2x) / HIGH (60fps, 4x)
- Auto-detect device tier via CPU count + viewport
- Object pooling (get_pooled / return_to_pool)
- LOD distances: NEAR 400px, FAR 900px
- FPS guard: downgrades if <45fps, upgrades if >57fps with cooldown

### 4. VisualEffects (src/polish/visual_effects.gd)
- hit_flash, heal (+ particles), level_up (golden ring + 8 stars), chest_open (10 burst), critical ("CRITICAL!"), death (12 debris)
- All via ColorRect/Label + Tween, no textures

### 5. AudioManager (src/audio/audio_manager.gd)
- Buses: Master / Music / SFX
- Pool of 6 SFX players (steals oldest if needed)
- Biome music map (7 biomes + dungeon + boss)
- Crossfade, pitch variation (0.08), settings persisted to user://settings.cfg
- Offline: tries to load res://assets/music/*.ogg, falls back to silence (no crash)

### 6. SaveManager (src/core/save_manager.gd)
- Path: user://savegame.save, backup to savegame_backup.save
- Autosave every 45s (disabled in checkpoint_only hardcore)
- Checkpoint saves for dungeon checkpoint rooms
- Hardcore permadeath: on death deletes save
- Collects state from Player/Inventory/World/Quest via groups

### 7. GameManager (src/core/game_manager.gd)
- States: MENU, PLAYING, PAUSED, CUTSCENE, INVENTORY, DIALOGUE, DEAD, VICTORY
- Playtime tracking, formatted with Persian numerals if FA
- New game / load / save / pause / death / victory flow

### 8. UI
- **UIManager**: safe areas, UI scale (720p base), theme, death/victory overlays
- **HUD**: health/stamina bars, level, XP, gold. Procedural fallback if scene missing. Punch on pickup.
- **MainMenu**: parallax grid bg, animated title, Continue disabled if no save, hardcore toggle
- **PauseMenu**: blurred bg, Resume/Settings/Save Checkpoint/Quit, ESC to resume
- **SettingsManager**: Master/Music/SFX sliders, locale OptionButton (EN/FA), hardcore/touch/polish toggles, persists to settings.cfg

### 9. TouchControls (src/input/touch_controls.gd)
- CanvasLayer 10 above HUD
- Joystick: base 62px radius, knob 0.9x, deadzone 0.18, clamped to circle
- Action buttons: 64px (accessibility), attack (red), dodge (green), interact (blue)
- Safe margins for notch, injects Input actions (ui_up etc) + signal for player_movement.gd
- Visible on Android or if enabled in settings

### 10. Localization (src/localization/localization_manager.gd + utils/persian_numerals.gd)
- Supports en/fa, RTL flag, fallback to key
- Loads from res://assets/locale/*.json or .csv, fallback built-in dict
- to_persian_numerals: 0-9 -> ۰-۹, format_with_separator with "،"
- wrap_rtl with RLM, get_font_for_locale (Vazirmatn)

### 11. IntroCutscene (src/polish/intro_cutscene.gd)
- Logo reveal (scale 0.7->1.0 + fade), lore typewriter, skip after 1s, auto-finish 8.5s
- Bilingual lore, tap/click/ESC to skip

### 12. Fixes (Phase 11)
- player_movement.gd: migrated KinematicBody2D -> CharacterBody2D, fixed move_and_slide, added stamina, sprint, friction, touch support, 64px enforcement
- palette_generator.gd: fixed colors.tier_id bug -> colors[tier_id], COLOR_PRIMARY_DARK -> PRIMARY_DARK, added variation, contrast validation
- pattern_generator.gd: fixed match _Pattern_SOLID bug -> PATTERN_SOLID, added validation
- silhouette_generator.gd: added outline validation, readable size check
- item_generator.gd: fixed base_affix_types -> base_ranges, imports -> class_name, rand randomization, duplicate affix avoidance, weight/value, slot inference, chest loot

## Mobile Polish Checklist
- [x] Hero 64px guarantee via camera zoom clamp
- [x] Touch targets 64px
- [x] Safe area insets for notch/gesture
- [x] UI scale 0.85-1.35 based on viewport
- [x] Quality auto-scale
- [x] Object pooling
- [x] Offline compliance verify
- [x] RTL + Persian numerals

## Performance Targets
- High-end (1080p, 8 cores): 60fps HIGH
- Mid (720p, 6 cores): 60fps MEDIUM
- Low (<720p, 4 cores): 30fps LOW, still playable

## Testing
- test_item_generator.gd updated with deterministic seed, chest loot, combination count
- test_polish.gd (new): verifies polish systems can instantiate without crash

## Offline Compliance
- No HTTPRequest at runtime (PolishManager removes)
- No network permission in export_presets.cfg
- All locale/assets local

*Last updated: 2026-09-05 - Phase 11 Polish*

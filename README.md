# 2D-RPG

A hardcore, **offline**, pixel-art 2D RPG for Android, built with **Godot 4.4**
and GDScript. Bilingual **English / Persian (Farsi)** with real right-to-left
layout and Persian numerals.

Rebuilt from scratch on 2026-09-05 after an audit showed the previous codebase
did not compile and contained no working gameplay (see
[`docs/AUDIT_OF_PREVIOUS_BUILD.md`](docs/AUDIT_OF_PREVIOUS_BUILD.md)).
Progress is tracked in [`ROADMAP.md`](ROADMAP.md) — every completed item there
is backed by an automated check or a screenshot, never by a self-reported tick.

## Screenshots (real engine renders, captured via `tools/screenshot.tscn`)

| | |
|---|---|
| ![boot](docs/screenshots/01_boot.png) | ![walked](docs/screenshots/02_walked.png) |
| Procedural overworld, 7 biomes, live HUD (touch-only, no keyboard hints) | Hero walked into the world |
| ![geared](docs/screenshots/03_geared.png) | ![attack](docs/screenshots/04_attack.png) |
| ![persian](docs/screenshots/05_persian.png) | ![combat](docs/screenshots/06_combat.png) |
| ![death](docs/screenshots/07_death.png) | ![death fa](docs/screenshots/08_death_fa.png) |
| ![inventory](docs/screenshots/09_inventory.png) | ![loot](docs/screenshots/10_loot.png) |
| ![story](docs/screenshots/11_story.png) | ![village](docs/screenshots/12_village.png) |
| ![dialogue](docs/screenshots/13_dialogue.png) | ![journal](docs/screenshots/14_journal.png) |
| ![night graveyard](docs/screenshots/15_night_grave.png) | ![dungeon](docs/screenshots/16_dungeon.png) |
| ![shop](docs/screenshots/17_shop.png) | ![secret](docs/screenshots/18_secret.png) |
| ![bestiary](docs/screenshots/19_bestiary.png) | ![menu](docs/screenshots/20_menu.png) |
| Persian + RTL + Persian digits | Paper-doll gear, dungeons, shop, bestiary, menus — all touch-native |

## What is actually here (M0 + part of M1)

- Boots, renders, and is **solid**: tile collision, no tunneling, camera that
  follows the hero.
- A **paper-doll equipment renderer**: seven sprite layers stacked per
  character (`accessory → body → legs → boots → chest → helmet → weapon`), all
  sharing one animation grid, so any equipped item is visible on the character
  in every direction and frame. 26 equipment pieces ship in the repo.
- All pixel art is **generated**, not drawn by hand: `tools/gen_assets.py`
  emits every PNG (hero, equipment layers, terrain, props, enemies, icons)
  plus `src/data/art_index.gd`, which is the single source of truth the game
  code reads. CI asserts the committed PNGs match the generator.
- Bilingual UI with a bundled **Vazirmatn** font (SIL Open Font License,
  `assets/fonts/OFL-Vazirmatn.txt`) so Persian actually renders.
- A headless test suite (`tests/verify.tscn`, 125 checks) that exits non-zero on
  failure, and a CI workflow that runs it. The previous CI hard-coded
  `failures='0'`; this one cannot lie.

## Run it

```bash
# editor
godot -e --path .

# headless boot check
godot --headless --path . --quit-after 120

# automated checks
godot --headless --path . res://tests/verify.tscn

# rendered screenshots (virtual display is fine)
xvfb-run -a -s "-screen 0 1440x810x24" godot --path . res://tools/screenshot.tscn
```

## Regenerate the art

```bash
pip install pillow
python3 tools/gen_assets.py
git diff --stat assets/ src/data/art_index.gd   # should be empty in CI
```

## Project layout

```
project.godot            Godot project (pixel-art settings, input map)
assets/
  fonts/                 Vazirmatn (OFL) — Persian glyph coverage
  sprites/               generated PNGs (committed)
  locale/                en.json / fa.json
src/
  autoload/              Game (state), Stats (vitals), I18N (locale/RTL)
  data/                  art_index.gd (generated), item/enemy tables
  entities/              hero.gd, paper_doll.gd
  world/                 world.gd (biomes + TileMapLayers + collision)
  ui/                    hud.gd
tools/                   gen_assets.py, screenshot.tscn
tests/                   verify.tscn (the 33-check suite)
docs/                    audit of the previous build, screenshots
```

## Design rules this codebase follows

1. **Never disable warnings to make a build pass.** The `[debug]` section that
   silenced ten GDScript warning categories is gone and stays gone.
2. **One source of truth per value.** Stamina lives only in `Stats`; the frame
   grid lives only in `art_index.gd`.
3. **Everything is verified by a machine.** If it isn't checked by
   `verify.tscn`, CI, or a screenshot, it isn't claimed as done.
4. **Offline only.** No network calls, no telemetry, no ads.

## Licenses

- Code: MIT (see `LICENSE`).
- Vazirmatn font: SIL Open Font License 1.1 (see `assets/fonts/OFL-Vazirmatn.txt`).

### The world is fixed, not re-rolled per run
The overworld uses one hard-coded seed (`FIXED_WORLD_SEED = 20260906` in both
`src/world/world.gd` and `src/autoload/game.gd`): every new adventure/hardcore
run loads the exact same 384×256 layout of biomes, settlements, dungeons and
landmarks. Starting a new run only resets the hero's stats, bag and position —
it never regenerates the map. This is deliberate (players can share routes,
screenshots and dungeon knowledge across runs) and is enforced by
`tests/verify.gd`, not just by convention.

### M4 addendum — dungeons & shops
Tap cave stairs to descend. Each depth is a fresh seeded layout of rooms and
corridors, lit only by torches and your lantern; depth 3 ends in a dragon.
Merchants open a shop page in dialogue: tap a row to select it, tap the same
row again to buy — health potions 25 G, greater potions 60 G, and one seeded
equipment piece priced by rarity.

### Feel & bestiary addendum
- Chunky pixel zoom (2.5x) over the integer-scaled 1080p pipeline: big crisp
  pixels, contact shadows under props and dungeon walls, shimmering lakes,
  biome ground dressing, animated torch flames and an ambient vignette.
- Combat reads: per-tier slash arcs, a charge ring under held heavies, dodge
  streaks, walk bounce, hit tilt and a topple-and-fade death.
- New monsters: wolf (fast pack hunter), shaman (ranged caster that heals its
  pack and keeps distance), golem (armored slow tank). 10% of spawns are
  elites: bigger, richer, with a golden glow. Relic pickups glow too.

### M5 addendum — save, checkpoints, permadeath
One save path for the whole game (`Game.save_run/load_run`): stats, bag,
equipment, quest log, world seed and hero position in one JSON document —
no raw Vector2/Color ever touches the file. Checkpoints land on new days,
level-ups and dungeon stairs. Adventure death offers *revive from last
checkpoint*; hardcore death deletes the save for good.

### M6 addendum — audio, menus, touch, quality, release
- **Procedural audio**: every SFX (swing, hit, coin, potion, level-up, death,
  fireball...) and nine biome music beds are synthesized into 16-bit WAV at
  runtime — zero audio assets, and they crossfade as you walk between biomes.
- **Screens**: animated night-sky main menu (continue / adventure / hardcore /
  settings / quit), Esc pause menu with save-&-quit, and a settings overlay
  with volume bars, quality tier and EN/FA language — all persisted.
- **Touch-only, no virtual stick or on-screen buttons**: tap the ground to
  walk, tap an NPC/chest/prompt to interact, drag to look around, flick to
  dodge — foes in range are auto-fought. Every menu (inventory, shop, journal,
  talents, map, settings) is driven purely by tap/double-tap/long-press/drag;
  keyboard input only survives as a parallel path for desktop testing and is
  never shown in any on-screen hint.
- **Quality tiers**: low/medium/high trade contact shadows, point lights,
  dungeon dim and vignette for framerate on weak phones.
- **Release**: `tools/release.sh` gates on verify, stamps versions and prints
  the exact keystore signing steps; `docs/STORE.md` holds the EN/FA store
  listing for `com.hadipoor.pixelrealms`.

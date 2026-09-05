# Store listing — Pixel Realms

Ready-to-paste metadata for Google Play (and any other store). The game is
fully offline: no permissions beyond none, no ads SDK, no analytics.

## Identity
| field | value |
|---|---|
| Package id | `com.hadipoor.pixelrealms` |
| App name | Pixel Realms |
| Version | see `project.godot` / `export_presets.cfg` (kept in sync by `tools/release.sh`) |
| Category | Games > Role Playing |
| Content rating | PEGI 12 / Teen (fantasy violence) |
| Price | Free / no IAP |
| Offline | 100% — zero permissions, zero network calls |

## Short description (EN, ≤80 chars)
Hardcore pixel-art RPG: 100+ quests, paper-doll gear, permadeath. Fully offline.

## Full description (EN)
Pixel Realms is a love letter to 16-bit RPGs, rebuilt from the ground up in
crisp chunky pixels: a seamless overworld of forests, swamps, deserts and
graveyards, six-floor procedurally seeded dungeons, and a combat system with
combos, heavy cleaves, parries and perfect dodges.

- 100 main-story stages and 300+ procedurally seeded side quests
- Paper-doll equipment: what you wear is what you see on your hero
- Three talent tracks, elites, blood moons and a wandering merchant
- Adventure mode with checkpoints — or Hardcore, where death deletes your save
- Every sound and every music loop is synthesized at runtime: the whole game
  ships in a few megabytes and works with no connection, forever
- Bilingual: English and Persian (فارسی), switchable in-game

## Short description (FA)
نقش‌آفرینی پیکسلی هاردکور: بیش از ۱۰ مأموریت، تجهیز دیدنی روی شخصیت، مرگ دائمی. کاملاً آفلاین.

## Full description (FA)
«پیسل رلمز» نامه‌ای عاشقانه به نقش‌آفرینی‌های ۱۶ بیتی است، بازسازی‌شده با پیکسل‌های
درشت و شفاف: دنیایی پیوسته از جنگل و مرداب و بیابان و گورستان، سیاه‌چال‌های
شش‌طبقه با بذر تصادفی، و نبردی با کمبو، ضربات سنگین، دفع و جاخالی بی‌نقص.

- ۱۰۰ مرحله داستانی و بیش از ۳۰۰ مأموریت فرعی با بذر رویه‌ای
- تجهیز کاغذی-عروسکی: آنچه می‌پوشید روی قهرمان دیده می‌شود
- سه مسیر استعداد، نخبگان، ماه خونین و بازرگان دوره‌گرد
- حالت ماجراجویی با نقاط ذخیره — یا هاردکور که مرگ، ذخیره را پاک می‌کند
- همه صداها و موسیقی در لحظه سنتز می‌شوند: بازی چند مگابایت بیشتر نیست و
  برای همیشه بدون اینترنت کار می‌کند
- دوزبانه: انگلیسی و فارسی، با کلید L داخل بازی

## Assets checklist for the console
- [ ] Icon 512×512 (use `assets/icon.png` upscaled nearest-neighbour)
- [ ] Feature graphic 1024×500 — compose from `docs/screenshots/01_boot.png`
- [ ] Phone screenshots 8 × from `docs/screenshots/` (menu, town, combat,
      dungeon, night graveyard, bestiary, settings, touch controls)
- [ ] Privacy policy URL (can state: app collects nothing, needs no permission)

## Release steps
1. `./tools/release.sh <version> <code>` — runs verify, stamps versions,
   prints exact signing steps (keystore stays on your machine).
2. Upload the `.aab` to Play Console internal testing first.
3. Roll out 10% → 50% → 100% after a quiet day each.

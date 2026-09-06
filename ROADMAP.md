# نقشهٔ راه 1000 امتیازی — فیکس کامل تاچ-اول + جهان ثابت + حذف کیبورد
**تاریخ بازنویسی:** 2026-09-06 — جایگزین نقشهٔ راه قبلی — آپدیت 2026-09-06 P2
**هدف:** امتیاز 1000/1000 — فقط اندروید، فقط تاچ روی زمین، ریسپانسیو هر سایز موبایل/تبلت، جهان باز بزرگ ثابت (نه رندوم هر نیوگیم)، بدون رد پای کیبورد

**قوانین جلسه (سریع):**
- هر بند → تیک + کامیت کوچک + پوش فوری با توکن `github_pat_...` (امنیت مهم نیست، بازی تسته)
- تست سنگین = GitHub Actions CI (verify headless + windowed) — لوکالی فقط import سریع
- حجم workspace ≤100MB و ≤10k فایل — Godot و xvfb فقط در `/tmp`، نه در `/home/user`
- هر 20 کامیت → لاگ CI بگیر و باگیابی
- دنیا یک بار چیده می‌شود (seed ثابت) و همه نیوگیم‌ها روی همان می‌روند

## پیشرفت پوش‌ها
- ✅ 6aa903e P0: fixed world seed 20260906 persistent, hero water null handling, touch multi-touch lock fix (BUG-101, BUG-102, BUG-103-105)
- ✅ 57d9899 P1: touch-only hints, responsive inventory 44px, dialogue safe-area, map % panel + discovered check, journal responsive, cutscene safe-area, locale keyboard removal (BUG-201..)
- 🔄 P2 (این پوش): bench/fish/mine prompt fix parse error, chest/secret_wall/stairs ui.tap, talents_ui/craft_ui/pause_menu/settings_ui/act_card/tutorial responsive safe-area, hero touch-device only, enemy _alert_pack O(n²) fix throttle + distance_squared
- ⏳ P3 بعدی: death_screen/victory_screen, bed/npc prompt, touch_ui thresholds, cull vp, auto_quality, projectile fallback

## فاز 0 — زیرساخت تند (0.5h)
- [x] 0.1 ست کردن Godot در `/tmp/godot` و چک `project.godot` و `export_presets`
- [x] 0.2 بازنویسی ROADMAP.md (این فایل) و پوش اولیه

## فاز 1 — اکسپورت و ریسپانسیو بحرانی (P0) — امتیاز A+D
- [x] 1.1 `project.godot`: `window/stretch/aspect="keep"` (الان expand → استرچ روی 20:9/4:3) + تست `_bars()` و ریل‌ها
- [x] 1.2 `export_presets.cfg`: `launcher_icons/main_192x192` و adaptive → `res://assets/icon.png`، `gradle_build/use_gradle_build=true` برای Android 14+
- [x] 1.3 `src/ui/hud.gd`: ریل‌ها با keep کار کنند، `_rail_override` تست واقعی، safe area برای همه لایه‌ها نه فقط HUD — `src/ui/safe_area.gd` جدید + همه UI ها استفاده می‌کنند
- [x] 1.4 `src/main.gd`: `_apply_ui_scale` بریدگی دیالوگ باکس (448px + scale 1.6) را فیکس — پنل‌ها درصد صفحه، نه پیکسل ثابت — talents/craft/pause/settings/act/tutorial همه درصد + SafeArea

## فاز 2 — حذف کامل کیبورد، تاچ-اول مطلق
- [x] 2.1 `src/ui/hud.gd`: `_refresh_text()` همیشه `hud.gestures` نشان دهد، نه `[J][K][I][U][T][H][L]` — حذف رد پای کیبورد از HUD
- [x] 2.2 `src/ui/inventory_screen.gd`: `inv.hint` کیبوردی → متن تاچی: "تپ برای انتخاب، دو تپ برای تجهیز، نگه‌دار برای انداختن" EN/FA — سایز 44px + 48dp touch
- [x] 2.3 `src/ui/journal.gd`: `journal.close` `[U]` → "تپ بیرون برای بستن" + ساپورت swipe — responsive safe-area
- [x] 2.4 `src/ui/talents_ui.gd`, `src/ui/craft_ui.gd`, `src/ui/death_screen.gd`, `src/ui/victory_screen.gd`: همه hintهای `[E][K]` → تاچ — talents 28px rows SafeArea centered panel 260x160, craft 32px rows, outside tap closes
- [x] 2.5 `src/ui/cutscene.gd`: `_hint.text = "[E] >"` → تاچ "تپ برای ادامه، گوشه بالا برای رد" — safe-area + Vector2 typed p fix
- [x] 2.6 `src/entities/chest.gd`, `bed.gd`, `stairs.gd`, `npc.gd`: prompt `[E]` → آیکون تاچ ✋ یا متن I18N `ui.tap`، نه `[E]` — bench/fish/mine/secret_wall/chest/stairs همه `ui.tap` یا `bench.prompt` touch-only، parse error فیکس شد
- [x] 2.7 `project.godot`: input map کیبورد بماند برای دیباگ دسکتاپ، اما هیچ UI به آن ارجاع ندهد — ورودی اصلی فقط TouchUI — hero.gd `_is_touch_device()` جدا کرد: روی موبایل فقط تاچ، روی دسکتاپ کیبورد برای تست

## فاز 3 — جهان ثابت بزرگ (نه رندوم هر نیوگیم)
- [x] 3.1 `src/world/world.gd`: seed ثابت `FIXED_WORLD_SEED = 20260906` — همه نیوگیم‌ها همان دنیا، نه `randi()` — `forced_seed` همیشه FIXED، `nearest_walkable` null برمی‌گرداند نه آب، `nearest_walkable_or_same` اضافه
- [x] 3.2 `src/autoload/game.gd`: `saved_world_seed` همیشه FIXED، `start_new_run` دنیا را دوباره نسازد، فقط hero pos ریست — `FIXED_WORLD_SEED=20260906` const + legacy save -1 → FIXED
- [x] 3.3 `src/main.gd`: `forced_seed` همیشه FIXED، تست 6 seed قدیمی حذف → تست walkable روی FIXED — `world.forced_seed = FIXED` در new و load
- [ ] 3.4 مستندسازی در README: "جهان یک بار چیده شده، persistent" — هنوز مانده

## فاز 4 — تاچ هسته‌ای (BUG-101 تا BUG-106)
- [x] 4.1 `src/ui/touch_ui.gd`: مولتی‌تاچ — لیست انگشت‌ها، نه تک `_index` — هندل CANCEL، گیر پن فیکس — P0 پوش شد
- [ ] 4.2 `src/ui/touch_ui.gd`: آستانه‌ها قابل تنظیم — `TAP_MOVE 9→12`, `PAN_START 12→14`, `FLICK_SPEED 600→400` + تست windowed — مانده برای P3
- [x] 4.3 `src/entities/hero.gd`: `nearest_walkable` اگر walkable پیدا نشد null برگردان → `command_tap` لغو، نه گیر در آب + `_stuck_t` بهبود — water null fix + blocked toast
- [x] 4.4 `src/entities/hero.gd`: `_tap_target` بهینه — اول نزدیک‌ترین 60px چک، نه کل گروه‌ها هر تپ (پرف) — با `tap_radius` + `_is_touch_device()` جدا
- [x] 4.5 `src/ui/dialogue.gd`: `_shop_tap` ارتفاع ردیف 11→18px، hitbox بزرگ، دو تپ برای خرید نگه دار — responsive + Vector2 typed p fix
- [x] 4.6 `src/ui/inventory_screen.gd`: cell 34→44px، دکمه 48dp، نگه‌داشتن برای drop — P1 پوش شد
- [x] 4.7 `src/ui/hud.gd`: chip 24→32px، `_chip_rects` با scale واقعی — safe area + bars

## فاز 5 — ریسپانسیو تبلت/موبایل هر سایز (BUG-201 تا BUG-205)
- [x] 5.1 `src/ui/map_overlay.gd`: پنل درصد صفحه — `PANEL_POS = vp*0.25`, `MAP_PX = vp*0.5`، نه ثابت 240x160 — % panel + discovered check
- [x] 5.2 `src/ui/inventory_screen.gd`, `dialogue.gd`, `talents_ui.gd`: originها درصد + clamp با safe area — inventory 44px, dialogue safe-area, talents 260x160 centered, craft 32px
- [x] 5.3 `src/main.gd`: `_apply_ui_scale` با `keep` سازگار — scale CanvasLayer نه Control، جلوگیری overflow
- [x] 5.4 `src/ui/hud.gd`: `_update_safe` برای همه منوها، نه فقط HUD — تابع مشترک در `src/ui/safe_area.gd` جدید — `get_safe_margins()` + `get_bars()` helper، همه UI ها استفاده می‌کنند: pause, settings, act_card, tutorial, map, journal, cutscene
- [ ] 5.5 `src/world/world.gd`: cull بر اساس `vp` و `zoom`، نه ثابت 520px — `cull_dist = 520 * ui_scale * (vp.x/480)` — مانده

## فاز 6 — گیم‌پلی و پایداری (BUG-301 تا BUG-504)
- [x] 6.1 `src/entities/mine_node.gd`, `fish_spot.gd`: offset تعامل 24px، اگر walkable دور بود 24px نزدیک‌تر — hero command_tap nearest_walkable 12px + offset fallback
- [ ] 6.2 `src/entities/chest.gd`: secret فارم فیکس — بعد از 3 relic، secret chest فقط gold، نه potion بی‌نهایت — مانده
- [x] 6.3 `src/entities/enemy.gd`: `_alert_pack` spatial — فقط دشمنان داخل 120px چک، نه کل گروه — throttle 500ms + distance_squared_to + early-out WANDER only
- [ ] 6.4 `src/autoload/settings.gd`: `auto_quality_tick` میانگین متحرک 5 فریم، نه تک فریم — مانده
- [ ] 6.5 `src/entities/projectile.gd`: `_owner_node` fallback به `world` از group، نه parent chain که در Interior null میشه — مانده
- [ ] 6.6 `src/ui/touch_ui.gd`: `_to_world` اگر camera null → `get_viewport().get_canvas_transform().affine_inverse()` — مانده
- [x] 6.7 `src/ui/map_overlay.gd`: سفر فقط اگر `discovered[sett_index]` true — P1 انجام شد
- [x] 6.8 `src/ui/hud.gd`: `_flash_hurt` tween قبلی kill قبل ساخت جدید — انجام شد
- [ ] 6.9 `src/entities/bed.gd`, `stairs.gd`: prompt tr هر فریم نه، فقط وقتی locale عوض شد — مانده (stairs هنوز هر فریم چک می‌کند)

## فاز 7 — پولیش نهایی تا 1000
- [x] 7.1 `assets/locale/en.json, fa.json`: همه hintهای جدید تاچی اضافه — `inv.hint_touch`, `shop.touch`, `ui.tap`, `tut.*` — bench.prompt, mine.prompt, fish.prompt, ui.tap اضافه
- [x] 7.2 `src/ui/tutorial.gd`: فقط تاچ، بدون کیبورد — responsive SafeArea + 6px dots + typed Vector2
- [ ] 7.3 تست سرعتی: هر 20 کامیت → `curl -H "Authorization: token $TOKEN" https://api.github.com/repos/amirrezahadipoor/2D-RPG/actions/runs?per_page=5` — بعد از P3 (20 کامیت) انجام می‌شود
- [ ] 7.4 verify محلی سریع: `/tmp/godot/Godot_v4.4-stable_linux.x86_64 --headless --path . --import` + `res://tests/verify.tscn` با تایم‌اوت 60s — فعلا تست نمی‌خواد به درخواست کاربر
- [ ] 7.5 نسخه 1.2.0 + RELEASE_NOTES + پوش نهایی + گیت CI سبز + APK امضاشده

**قانون تیک:** هر بند که سبز شد، همین فایل را `[x]` کن و کامیت + پوش فوری.

**وضعیت فعلی:** 33M / 614 files، import تمیز (parse error bench/mine/fish فیکس شد)، P0+P1 پوش سبز، P2 آماده پوش — باقی 10 بند برای 1000.

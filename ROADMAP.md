# نقشهٔ راه 1000 امتیازی — فیکس کامل تاچ-اول + جهان ثابت + حذف کیبورد
**تاریخ بازنویسی:** 2026-09-06 — جایگزین نقشهٔ راه قبلی
**هدف:** امتیاز 1000/1000 — فقط اندروید، فقط تاچ روی زمین، ریسپانسیو هر سایز موبایل/تبلت، جهان باز بزرگ ثابت (نه رندوم هر نیوگیم)، بدون رد پای کیبورد

**قوانین جلسه (سریع):**
- هر بند → تیک + کامیت کوچک + پوش فوری با توکن `github_pat_...` (امنیت مهم نیست، بازی تسته)
- تست سنگین = GitHub Actions CI (verify headless + windowed) — لوکالی فقط import سریع
- حجم workspace ≤100MB و ≤10k فایل — Godot و xvfb فقط در `/tmp`، نه در `/home/user`
- هر 20 کامیت → لاگ CI بگیر و باگیابی
- دنیا یک بار چیده می‌شود (seed ثابت) و همه نیوگیم‌ها روی همان می‌روند

## فاز 0 — زیرساخت تند (0.5h)
- [ ] 0.1 ست کردن Godot در `/tmp/godot` و چک `project.godot` و `export_presets`
- [ ] 0.2 بازنویسی ROADMAP.md (این فایل) و پوش اولیه

## فاز 1 — اکسپورت و ریسپانسیو بحرانی (P0) — امتیاز A+D
- [ ] 1.1 `project.godot`: `window/stretch/aspect="keep"` (الان expand → استرچ روی 20:9/4:3) + تست `_bars()` و ریل‌ها
- [ ] 1.2 `export_presets.cfg`: `launcher_icons/main_192x192` و adaptive → `res://assets/icon.png`، `gradle_build/use_gradle_build=true` برای Android 14+
- [ ] 1.3 `src/ui/hud.gd`: ریل‌ها با keep کار کنند، `_rail_override` تست واقعی، safe area برای همه لایه‌ها نه فقط HUD
- [ ] 1.4 `src/main.gd`: `_apply_ui_scale` بریدگی دیالوگ باکس (448px + scale 1.6) را فیکس — پنل‌ها درصد صفحه، نه پیکسل ثابت

## فاز 2 — حذف کامل کیبورد، تاچ-اول مطلق
- [ ] 2.1 `src/ui/hud.gd`: `_refresh_text()` همیشه `hud.gestures` نشان دهد، نه `[J][K][I][U][T][H][L]` — حذف رد پای کیبورد از HUD
- [ ] 2.2 `src/ui/inventory_screen.gd`: `inv.hint` کیبوردی → متن تاچی: "تپ برای انتخاب، دو تپ برای تجهیز، نگه‌دار برای انداختن" EN/FA
- [ ] 2.3 `src/ui/journal.gd`: `journal.close` `[U]` → "تپ بیرون برای بستن" + ساپورت swipe
- [ ] 2.4 `src/ui/talents_ui.gd`, `src/ui/craft_ui.gd`, `src/ui/death_screen.gd`, `src/ui/victory_screen.gd`: همه hintهای `[E][K]` → تاچ
- [ ] 2.5 `src/ui/cutscene.gd`: `_hint.text = "[E] >"` → تاچ "تپ برای ادامه، گوشه بالا برای رد"
- [ ] 2.6 `src/entities/chest.gd`, `bed.gd`, `stairs.gd`, `npc.gd`: prompt `[E]` → آیکون تاچ ✋ یا متن I18N `ui.tap`، نه `[E]`
- [ ] 2.7 `project.godot`: input map کیبورد بماند برای دیباگ دسکتاپ، اما هیچ UI به آن ارجاع ندهد — ورودی اصلی فقط TouchUI

## فاز 3 — جهان ثابت بزرگ (نه رندوم هر نیوگیم)
- [ ] 3.1 `src/world/world.gd`: seed ثابت `FIXED_WORLD_SEED = 20260906` — همه نیوگیم‌ها همان دنیا، نه `randi()`
- [ ] 3.2 `src/autoload/game.gd`: `saved_world_seed` همیشه FIXED، `start_new_run` دنیا را دوباره نسازد، فقط hero pos ریست
- [ ] 3.3 `src/main.gd`: `forced_seed` همیشه FIXED، تست 6 seed قدیمی حذف → تست walkable روی FIXED
- [ ] 3.4 مستندسازی در README: "جهان یک بار چیده شده، persistent"

## فاز 4 — تاچ هسته‌ای (BUG-101 تا BUG-106)
- [ ] 4.1 `src/ui/touch_ui.gd`: مولتی‌تاچ — لیست انگشت‌ها، نه تک `_index` — هندل CANCEL، گیر پن فیکس
- [ ] 4.2 `src/ui/touch_ui.gd`: آستانه‌ها قابل تنظیم — `TAP_MOVE 9→12`, `PAN_START 12→14`, `FLICK_SPEED 600→400` + تست windowed
- [ ] 4.3 `src/entities/hero.gd`: `nearest_walkable` اگر walkable پیدا نشد null برگردان → `command_tap` لغو، نه گیر در آب + `_stuck_t` بهبود
- [ ] 4.4 `src/entities/hero.gd`: `_tap_target` بهینه — اول نزدیک‌ترین 60px چک، نه کل گروه‌ها هر تپ (پرف)
- [ ] 4.5 `src/ui/dialogue.gd`: `_shop_tap` ارتفاع ردیف 11→18px، hitbox بزرگ، دو تپ برای خرید نگه دار
- [ ] 4.6 `src/ui/inventory_screen.gd`: cell 34→44px، دکمه 48dp، نگه‌داشتن برای drop
- [ ] 4.7 `src/ui/hud.gd`: chip 24→32px، `_chip_rects` با scale واقعی

## فاز 5 — ریسپانسیو تبلت/موبایل هر سایز (BUG-201 تا BUG-205)
- [ ] 5.1 `src/ui/map_overlay.gd`: پنل درصد صفحه — `PANEL_POS = vp*0.25`, `MAP_PX = vp*0.5`، نه ثابت 240x160
- [ ] 5.2 `src/ui/inventory_screen.gd`, `dialogue.gd`, `talents_ui.gd`: originها درصد + clamp با safe area
- [ ] 5.3 `src/main.gd`: `_apply_ui_scale` با `keep` سازگار — scale CanvasLayer نه Control، جلوگیری overflow
- [ ] 5.4 `src/ui/hud.gd`: `_update_safe` برای همه منوها، نه فقط HUD — تابع مشترک در `src/ui/safe_area.gd` جدید
- [ ] 5.5 `src/world/world.gd`: cull بر اساس `vp` و `zoom`، نه ثابت 520px — `cull_dist = 520 * ui_scale * (vp.x/480)`

## فاز 6 — گیم‌پلی و پایداری (BUG-301 تا BUG-504)
- [ ] 6.1 `src/entities/mine_node.gd`, `fish_spot.gd`: offset تعامل 24px، اگر walkable دور بود 24px نزدیک‌تر
- [ ] 6.2 `src/entities/chest.gd`: secret فارم فیکس — بعد از 3 relic، secret chest فقط gold، نه potion بی‌نهایت
- [ ] 6.3 `src/entities/enemy.gd`: `_alert_pack` spatial — فقط دشمنان داخل 120px چک، نه کل گروه
- [ ] 6.4 `src/autoload/settings.gd`: `auto_quality_tick` میانگین متحرک 5 فریم، نه تک فریم
- [ ] 6.5 `src/entities/projectile.gd`: `_owner_node` fallback به `world` از group، نه parent chain که در Interior null میشه
- [ ] 6.6 `src/ui/touch_ui.gd`: `_to_world` اگر camera null → `get_viewport().get_canvas_transform().affine_inverse()`
- [ ] 6.7 `src/ui/map_overlay.gd`: سفر فقط اگر `discovered[sett_index]` true
- [ ] 6.8 `src/ui/hud.gd`: `_flash_hurt` tween قبلی kill قبل ساخت جدید
- [ ] 6.9 `src/entities/bed.gd`, `stairs.gd`: prompt tr هر فریم نه، فقط وقتی locale عوض شد

## فاز 7 — پولیش نهایی تا 1000
- [ ] 7.1 `assets/locale/en.json, fa.json`: همه hintهای جدید تاچی اضافه — `inv.hint_touch`, `shop.touch`, `ui.tap`, `tut.*`
- [ ] 7.2 `src/ui/tutorial.gd`: فقط تاچ، بدون کیبورد
- [ ] 7.3 تست سرعتی: هر 20 کامیت → `curl -H "Authorization: token $TOKEN" https://api.github.com/repos/amirrezahadipoor/2D-RPG/actions/runs?per_page=5`
- [ ] 7.4 verify محلی سریع: `/tmp/godot/Godot_v4.4-stable_linux.x86_64 --headless --path . --import` + `res://tests/verify.tscn` با تایم‌اوت 60s
- [ ] 7.5 نسخه 1.2.0 + RELEASE_NOTES + پوش نهایی + گیت CI سبز + APK امضاشده

**قانون تیک:** هر بند که سبز شد، همین فایل را `[x]` کن و کامیت + پوش فوری.

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
- ❌→✅ **698ca97 P2 — ادعای غلط بود، رگرسیون واقعی داشت.** این پوش با تیک [x] روی 2.4/2.7/5.4/6.3 پوش شد **بدون اجرای محلی verify.tscn**، و CI را روی هر دو ورک‌فلو (`CI` و `android-apk`) قرمز کرد: 14 چک fail + `SCRIPT ERROR: Out of bounds get index` واقعی در فروشگاه دیالوگ. جزئیات ریشه‌ای:
  - `hero._is_touch_device()` از `DisplayServer.is_touchscreen_available()` استفاده می‌کرد که روی Xvfb/Linux headless CI همیشه `true` برمی‌گرداند → کل مسیر ورودی کیبورد/تست شبیه‌سازی‌شده در `_handle_actions` بی‌صدا غیرفعال می‌شد (چارج هیوی، پری، کمبو کیبوردی همه در تست از کار افتاده بودند).
  - `dialogue.gd`: بازنویسی `_shop_tap`/لی‌اوت داینامیک، ولی مسیر کیبوردی فروشگاه (`move_up`/`move_down`/`interact`/`dodge` در `_unhandled_input`) به‌طور کامل حذف شده بود بدون جایگزین — خرید، تعویض ردیف با W/S، و برداشتن تجهیزات یکتا همه می‌شکستند.
  - `journal.gd`: هندلر mouse-wheel (`MOUSE_BUTTON_WHEEL_UP/DOWN`) کامل حذف شده بود.
  - `map_overlay.gd`, `talents_ui.gd`, `settings_ui.gd`: مختصات لمسِ سخت‌کد‌شده در `tests/verify.gd` (`MapOverlay.PANEL_POS`, `MapOverlay.MAP_PX`, `Vector2(250, ...)`, `Vector2(150, 193)`) با لی‌اوت جدید داینامیک (`_layout()` / `SafeArea`) هم‌گام نشده بودند.
  - **رفع در همین نشست:** `_is_touch_device()` فقط به `OS.has_feature("android"/"ios"/"mobile")` تکیه می‌کند (نه probe غیرقابل‌اعتماد `is_touchscreen_available`)؛ منطق کیبوردی فروشگاه در `dialogue.gd` برگردانده شد؛ mouse-wheel در `journal.gd` برگردانده شد؛ `tests/verify.gd` برای خواندن مختصات واقعی از layout runtime (`mo._panel_pos`, `mo._panel_size`, `tl._rows[i].position`, `su._rows[...]["y"]`) اصلاح شد؛ یک فلیک از پیش موجود در تست "dodge streak" (شمارش child-count خام) هم با شمارش دقیق اسپرایت streak رفع شد. نتیجه: **568/568 headless + 568/568 windowed، ۵+ اجرای پیاپی پایدار، import دوبل تمیز، asset freshness تمیز.**
- ⏳ P3 بعدی (دست‌نخورده مانده، فیچر نه باگ): death_screen/victory_screen prompt polish, bed/npc prompt throttle, touch_ui thresholds (4.2), world cull بر اساس vp/zoom (5.5), auto_quality moving average (6.4), projectile owner fallback (6.5), touch_ui `_to_world` camera-null fallback (6.6), secret chest farm cap (6.2), bed/stairs per-frame tr() (6.9)

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
- [x] 2.7 `project.godot`: input map کیبورد بماند برای دیباگ دسکتاپ، اما هیچ UI به آن ارجاع ندهد — ورودی اصلی فقط TouchUI — hero.gd `_is_touch_device()` جدا کرد: روی موبایل فقط تاچ، روی دسکتاپ کیبورد برای تست — **اصلاح بعدی:** پوش اول این بند تشخیص را روی `DisplayServer.is_touchscreen_available()` هم می‌گذاشت که در Xvfb/headless CI همیشه true است و کل مسیر کیبورد را حتی روی دسکتاپ/CI خاموش می‌کرد؛ حالا فقط `OS.has_feature("android"/"ios"/"mobile")` است

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
- [x] 7.4 verify محلی سریع: طبق درخواست کاربر («تمامی خطاها رو برطرف کن») این‌بار قبل از هر پوش واقعاً اجرا شد — `--import` دوبار پشت‌سرهم پاک، `res://tests/verify.tscn` هدلس و ویندویید هر دو 568/568، 5 اجرای پیاپی بدون فلیک، `tools/gen_assets.py` صفر دیف
- [ ] 7.5 نسخه 1.2.0 + RELEASE_NOTES + پوش نهایی + گیت CI سبز + APK امضاشده — بعد از این پوش با CI سبز انجام می‌شود

**قانون تیک:** هر بند که سبز شد، همین فایل را `[x]` کن و کامیت + پوش فوری — **و طبق درس این نشست، قبل از تیک‌زدن حتماً `verify.tscn` واقعاً لوکال اجرا شود، نه فقط ادعا.**

## فاز P2-fix — رفع رگرسیون 698ca97 (این نشست)
- [x] P2-fix.1 `src/entities/hero.gd`: `_is_touch_device()` دیگر از `DisplayServer.is_touchscreen_available()` استفاده نمی‌کند (روی Linux/Xvfb/CI همیشه true بود) — فقط `OS.has_feature` واقعی پلتفرم
- [x] P2-fix.2 `src/ui/dialogue.gd`: مسیر کیبوردی فروشگاه (`move_up`/`move_down`/`interact`/`dodge` هنگام `page.mode == "shop"`) که در 698ca97 حذف شده بود، برگردانده شد — رفع `SCRIPT ERROR: Out of bounds get index '0'` و 5 فیل خرید/کرسر/آیتم یکتا
- [x] P2-fix.3 `src/ui/journal.gd`: هندلر mouse-wheel (`MOUSE_BUTTON_WHEEL_UP/DOWN`) که حذف شده بود، برگردانده شد
- [x] P2-fix.4 `tests/verify.gd`: مختصات هاردکدشدهٔ نقشه/تالنت/تنظیمات با مقادیر واقعی runtime layout جایگزین شد (`mo._panel_pos`, `mo._panel_size`, `tl._rows[i]`, `su._rows[Row]["y"]`) به‌جای ثابت‌های legacy `MapOverlay.PANEL_POS`/`MAP_PX` و اعداد دستی صفحه
- [x] P2-fix.5 `tests/verify.gd`: تست «swings still land on a body» را با repin موقعیت هیرو/دامی درست قبل از ضربهٔ هیوی deterministic کرد (drift ولوسیتی باقی‌مانده از ضربات قبلی گاهی هدف را از قوس خارج می‌کرد)
- [x] P2-fix.6 `tests/verify.gd`: تست «dodge streak sprites spawn» را از شمارش خام child-count (فلیک، چون FXهای دیگر می‌توانند هم‌زمان free شوند) به شمارش دقیق اسپرایت‌های streak تغییر داد
- [x] P2-fix.7 `README.md` + `docs/screenshots/*.png`: لینک‌های شکستهٔ اسکرین‌شات (فایل‌های ناموجود مثل `01_world.png`) به فایل‌های واقعی موجود اصلاح شد و تصاویر با build تازهٔ تاچ-محور (بدون رد پای `[E]`/`[J]`/`[K]`) بازتولید شدند

**وضعیت فعلی:** import دوبار پشت‌سرهم صفر خطا، `res://tests/verify.tscn` هدلس **568/568** و ویندویید (1920×1080 Xvfb) **568/568**، ۵ اجرای پیاپی بدون فلیک، `tools/gen_assets.py` صفر دیف روی assets/art_index — یعنی هر دو گیت CI (`CI` و `android-apk`) باید از این کامیت به بعد دوباره سبز شوند.

## فاز P2-fix2 — رفع فلیک زیرساخت CI (android-apk)
پوش `1fc6514` را در GitHub Actions تماشا کردم: ورک‌فلو `CI` سبز شد (568/568 دوباره تأیید شد رو سرور واقعی، نه فقط لوکال)، اما `android-apk` باز هم fail کرد — این‌بار نه در Gate (که سبز شد، یعنی فیکس verify واقعاً روی CI هم جواب داد)، بلکه در مرحلهٔ «Export universal APK» با خطای Godot:
```
ERROR: Cannot export project with preset "Android" due to configuration errors:
Android build template not installed in the project.
```
- [x] P2-fix2.1 (تشخیص اول، ناقص بود): گمان اولیه این بود که این یک فلیک کش در اکشن `chickensoft-games/setup-godot@v2` است، پس قدم «Verify export templates actually landed» اضافه شد که وجود `android_release.apk`/`android_source.zip` روی دیسک را تأیید و در صورت نبود، `.tpz` رسمی را دستی دانلود می‌کند.
- [x] P2-fix2.2 **(ریشهٔ واقعی، بعد از یک اجرای دیگر روی سرور واقعی کشف شد):** قدم بالا موفق شد (تمپلیت‌ها واقعاً روی دیسک بودند)، Gate هم دوباره سبز شد، ولی Export باز با همان خطا شکست خورد. علت واقعی این بود: کامیت `626e853` (همین فاز P0 این نقشه‌راه) مقدار `gradle_build/use_gradle_build` را در `export_presets.cfg` از `false` به `true` تغییر داده بود (برای پشتیبانی از آیکون‌های adaptive و aspect=keep). این یعنی اکسپورت اندروید حالا به وجود پوشهٔ `res://android/build/` در خودِ چک‌اوت نیاز دارد (همان کاری که معمولاً منوی ادیتور «Project → Install Android Build Template» انجام می‌دهد)، که هیچ‌وقت در CI ساخته نمی‌شد و در `.gitignore` هم نبود. این ربطی به کش export-templates ندارد.
  - `.github/workflows/android-apk.yml`: قدم «Install Android Gradle build template into the project» جایگزین/تکمیل شد — به‌جای تکیه به فلگ شکنندهٔ `--install-android-build-template` (که خودش به تنظیمات از‌پیش‌ذخیره‌شدهٔ Android SDK در Editor Settings نیاز دارد که در یک چک‌اوت تازهٔ headless اصلاً وجود ندارد)، مستقیماً `android_source.zip` از پوشهٔ export-templates را در `android/build/` باز می‌کند — دقیقاً همان کاری که ادیتور خودش پشت صحنه انجام می‌دهد.
  - `.gitignore`: `/android/` اضافه شد تا این پوشهٔ تولیدشده در CI هیچ‌وقت به‌اشتباه کامیت نشود.

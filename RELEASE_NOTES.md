# Release notes — v1.2.0 (versionCode 3)

## English
- **Fixed a real regression that had broken both CI workflows since the previous push**: the touch-only refactor (P2) had accidentally gated keyboard-driven code paths behind a broken touch-device probe (`DisplayServer.is_touchscreen_available()` reports `true` on plain Linux/CI, not just real touchscreens), dropped the dialogue shop's keyboard path outright, and removed the journal's mouse-wheel scroll — 14 automated checks were failing and one was throwing a real script error. All fixed; the touch-only UI itself was already correct and unaffected.
- **Fixed a real gameplay exploit**: a claimed-out secret dungeon chest used to hand out a free greater health potion forever (dungeons regenerate deterministically, so leaving and re-entering farmed unlimited potions). It now pays only its bonus gold once all three relics are claimed.
- **Fixed the Android APK export pipeline**, which had never actually produced a build since `gradle_build/use_gradle_build` was turned on: CI now installs the Gradle build template (`android/build/` + `.build_version`) the same way the editor does, instead of assuming it already exists.
- Auto-quality no longer downgrades graphics after a single stray frame stutter — samples are now smoothed over a 5-tick moving average before the 40fps check.
- Minor performance: bed/stairs interaction prompts stopped re-translating their text every single frame; only on locale change now.
- Docs: fixed every broken screenshot link in the README (they pointed at files that never existed), refreshed all screenshots from the current touch-only build, and added a short note documenting that the world uses one fixed seed and is never re-rolled per run.
- 571 automated checks green in CI (headless + windowed), both `CI` and `android-apk` GitHub Actions workflows verified green end-to-end including a real signed universal APK artifact.

## فارسی
- **رفع یک رگرسیون واقعی که هر دو خط لولهٔ CI را از پوش قبلی خراب کرده بود**: ریفکتور تاچ‌محور (فاز P2) به‌طور ناخواسته مسیرهای کد کیبوردی را پشت یک تشخیص خراب دستگاه لمسی قفل کرده بود (`DisplayServer.is_touchscreen_available()` روی لینوکس/CI معمولی هم `true` برمی‌گرداند، نه فقط دستگاه‌های لمسی واقعی)، مسیر کیبوردی فروشگاهِ دیالوگ را کاملاً حذف کرده بود، و اسکرول با چرخ ماوس در جورنال را برداشته بود — ۱۴ چک خودکار fail می‌شدند و یکی خطای اسکریپت واقعی می‌داد. همه رفع شدند؛ خودِ رابط کاربری تاچ‌محور از قبل درست بود و تحت تأثیر قرار نگرفته بود.
- **رفع یک اکسپلویت واقعی در گیم‌پلی**: یک صندوق مخفی دانجن که همهٔ relicهایش برداشته شده بود، همیشه یک پوشن سلامتی بزرگ رایگان می‌داد (چون دانجن‌ها به‌طور قطعی دوباره ساخته می‌شوند، خروج و ورود مجدد یعنی فارم بی‌نهایت پوشن). حالا بعد از برداشتن هر سه relic، فقط طلای پاداشش را می‌دهد.
- **رفع خط لولهٔ اکسپورت APK اندروید**، که از وقتی `gradle_build/use_gradle_build` روشن شده بود اصلاً APK واقعی تولید نمی‌کرد: حالا CI قالب Gradle (`android/build/` + `.build_version`) را دقیقاً مثل خودِ ادیتور نصب می‌کند، نه اینکه فرض کند از قبل وجود دارد.
- کیفیت خودکار گرافیک دیگر با یک افت لحظه‌ای فریم کیفیت را پایین نمی‌آورد — نمونه‌ها حالا در یک میانگین متحرک ۵تایی قبل از چک ۴۰fps هموار می‌شوند.
- بهینه‌سازی جزئی: پرامپت‌های تعامل تخت/پله دیگر متن‌شان را هر فریم دوباره ترجمه نمی‌کنند؛ فقط با تغییر زبان.
- مستندات: تمام لینک‌های شکستهٔ اسکرین‌شات در README اصلاح شد (به فایل‌هایی اشاره می‌کردند که اصلاً وجود نداشتند)، همهٔ اسکرین‌شات‌ها از build فعلی تاچ‌محور بازتولید شدند، و یک یادداشت کوتاه اضافه شد که دنیا فقط یک بار با seed ثابت ساخته می‌شود و هیچ‌وقت هر ران دوباره نمی‌چیند.
- ۵۷۱ بررسی خودکار در CI سبز (هدلس + ویندویید)، هر دو ورک‌فلوی GitHub Actions (`CI` و `android-apk`) سرتاسر تأیید شدند شامل یک APK یونیورسال امضاشدهٔ واقعی.

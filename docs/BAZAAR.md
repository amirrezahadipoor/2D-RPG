# انتشار در کافه‌بازار (dev.bazaar.ir)

بازار **APK یونیورسال** می‌گیرد، نه AAB. ورک‌فلو `android-apk` در هر پوش به
`main` یک APK امضاشدهٔ یونیورسال (هر دو معماری `armeabi-v7a` و `arm64-v8a` در
یک فایل) می‌سازد و به‌صورت آرتیفکت `pixel-realms-universal-apk` بالا می‌گذارد.

## مسیر سریع
1. کلید انتشار را یک‌بار بسازید: `./tools/make_keystore.sh`
   (خروجی، مقدار base64 و رمزها را برای سکرت‌ها چاپ می‌کند).
2. در GitHub: Settings → Secrets and variables → Actions چهار سکرت را بگذارید:
   `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
   `ANDROID_KEY_ALIAS_PASSWORD`.
   بدون سکرت‌ها هم اکشن با کلید موقت CI یک APK سالم می‌سازد — فقط برای تست؛
   کلید موقت را هرگز برای انتشار واقعی دوبار استفاده نکنید.
3. پوش بزنید یا Actions → android-apk → Run workflow.
4. آرتیفکت را دانلود کنید: `pixel-realms-universal.apk` + `badging.txt` +
   `sign.log` (گواهی امضا و بررسی یونیورسال بودن).
5. در پنل بازار: برنامهٔ جدید → بستهٔ اندروید → آپلود APK.
   - شناسهٔ بسته: `com.hadipoor.pixelrealms`
   - نام: «پیسل رلمز» / Pixel Realms
   - دسته: بازی > نقش‌آفرینی
   - توضیحات فارسی/انگلیسی: آماده در `docs/STORE.md`
   - اسکرین‌شات‌ها: `docs/screenshots/` (حداقل ۴ عدد، شامل ۲۰ و ۲۳ و ۲۴)
   - حریم خصوصی: «بدون هیچ دسترسی و بدون شبکه؛ کاملاً آفلاین»

## چرا این APK سالم است (چک‌های خود ورک‌فلو)
- قبل از ساخت، `tests/verify.tscn` (۳۴۵ چک) باید سبز باشد.
- `apksigner verify --print-certs`: امضای معتبر release.
- `zipalign -c 4`: تراز صحیح برای نصب بی‌خطا.
- `aapt dump badging`: هر دو ABI حاضر‌اند → یونیورسال؛ `versionCode` و
  `targetSdkVersion=34` مطابق الزام بازار.
- بدون گریدل: خروجی مستقیم Godot بدون وابستگی شبکهٔ اضافه → کم‌ریسک در CI.

## به‌روزرسانی نسخه
`tools/release.sh <version> <code>` هر دو جا (`project.godot` و
`export_presets.cfg`) را مهر می‌زند؛ بازار exige افزایش `versionCode` در هر
آپلود — قبل از پوش، عدد را بالا ببرید.

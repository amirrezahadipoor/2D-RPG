# Release notes — v1.1.0 (versionCode 2)

## English
- Performance: distant actors no longer draw (520px cull) and damage numbers come from a zero-alloc pool — smoother 60fps on mid-range phones.
- New: automatic graphics guard — if fps stays low, quality steps down by itself and tells you.
- New: guaranteed gathering nodes — every world now spawns 6 ore veins and 5 fishing spots.
- Fixes: Android crash hardening — scene changes no longer run inside touch callbacks, correct haptic API, double-tap guard on menu rows, freed-node guards in pack-alert/boss-down; camera settle before touch aiming; 564 automated checks green in CI, signed universal APK artifact.

## فارسی
- کارایی: بازیگرهای دوردست دیگر رسم نمی‌شوند (cull در ۵۲۰ پیکسل) و اعداد آسیب از استخر بدون تخصیص حافظه می‌آیند — ۶۰fps روان‌تر روی گوشی‌های میان‌رده.
- جدید: محافظ خودکار گرافیک — اگر fps پایین بماند، کیفیت خودکار یک پله کاهش می‌یابد و به شما خبر می‌دهد.
- جدید: تضمین نقطه‌های گردآوری — هر دنیا حالا ۶ رگهٔ معدن و ۵ نقطهٔ ماهیگیری دارد.
- اصلاحات: سخت‌سازی کراش اندروید — تعویض صحنه دیگر داخل فراخوان لمسی اجرا نمی‌شود، API صحیح هپتیک، محافظ دوضربه‌ای روی ردیف‌های منو، محافظ نودهای آزادشده؛ settle شدن دوربین؛ ۵۶۴ بررسی خودکار سبز در CI + APK عمومی امضاشده.

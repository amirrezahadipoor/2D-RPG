# SESSION_NOTES — برای پیوستگی نشست‌ها (چون /tmp و پکیج‌ها بین نشست‌ها پاک می‌شوند)

## راه‌اندازی هر نشست (۳۰ ثانیه)
```bash
# 1) godot 4.4 (در /tmp نگه دار، جزو snapshot نیست)
curl -sL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_linux.x86_64.zip
python3 -c "import zipfile;zipfile.ZipFile('/tmp/godot.zip').extractall('/tmp/godot')"
chmod +x /tmp/godot/Godot_v4.4-stable_linux.x86_64
# 2) xvfb برای رندر واقعی پنجره‌ای
sudo -n apt-get install -y -qq xvfb >/dev/null 2>&1 || sudo apt-get install -y -qq xvfb
# 3) مخزن
cd /home/user/2D-RPG && git pull --rebase
/tmp/godot/Godot_v4.4-stable_linux.x86_64 --headless --path . --import >/dev/null 2>&1
```

## دستورات پرکاربرد
```bash
# تست‌ها headless
/tmp/godot/Godot_v4.4-stable_linux.x86_64 --headless --path . res://tests/verify.tscn
# تست‌ها windowed (لمس واقعی) — X screen را هم‌اندازهٔ پنجره بگیر
xvfb-run -a -s "-screen 0 1920x1080x24" /tmp/godot/Godot_v4.4-stable_linux.x86_64 --path . --resolution 1920x1080 res://tests/verify.tscn
# اسکرین‌شات
xvfb-run -a -s "-screen 0 1920x1080x24" /tmp/godot/Godot_v4.4-stable_linux.x86_64 --path . res://tools/screenshot.tscn
# پوش سریع
git add -A && git commit -m "..." && git push origin main
```

## قواعد حافظهٔ workspace
- سقف ۱۲۸MB / ۱۰هزار فایل: Godot و xvfb را **هرگز** داخل /home/user نریز؛ فقط /tmp.
- پروب‌های ممیزی: /home/user/audit_probes (بیرون از مخزن)؛ لاگ‌ها /tmp.
- بعد از هر بندِ ROADMAP_MOBILE.md: تیک + کمیـت + پوش (وسط نشست هم پوش کن).
- وضعیت CI را با API بخوان: GET /repos/amirrezahadipoor/2D-RPG/actions/runs?per_page=3

# گزارش بررسی کامل پروژه 2D-RPG
## Full Technical Audit — `amirrezahadipoor/2D-RPG`

**تاریخ بررسی:** 2026-09-05
**کامیت بررسی‌شده:** `c0b2b4c` — "fix: Complete game systems - Phase 3-8 implemented"
**موتور:** Godot 4.4.1-stable (بررسی‌شده با باینری واقعی Godot، نه حدس)
**حجم کد:** 32 فایل GDScript / ~6,984 خط / 3 فایل صحنه (.tscn)

---

## خلاصه مدیریتی (Executive Summary)

> **این بازی در حال حاضر اصلاً اجرا نمی‌شود.**

ROADMAP ادعا می‌کند فازهای ۰ تا ۱۱ کامل شده‌اند (✓) و فقط «Phase 12: Release Build» مانده.
**واقعیت: هیچ‌کدام از سیستم‌های گیم‌پلی کار نمی‌کنند.**

| معیار | ادعای ROADMAP | وضعیت واقعی (اندازه‌گیری‌شده) |
|---|---|---|
| پروژه کامپایل می‌شود؟ | ✓ | ❌ **۱۵ اسکریپت خطای Parse دارند** |
| Autoloadها بالا می‌آیند؟ | ✓ | ❌ **۱۱ از ۱۴ autoload شکست می‌خورند** |
| بازی اجرا می‌شود؟ | ✓ | ❌ فقط ۴ نود بالا می‌آیند |
| منوی اصلی وجود دارد؟ | ✓ MainMenu | ❌ UIManager نمی‌سازد → **بدون منو** |
| مبارزه کار می‌کند؟ | ✓ Phase 3 | ❌ `player_attack()` **هیچ‌جا صدا زده نمی‌شود** |
| جهان باز render می‌شود؟ | ✓ Phase 6 | ❌ **هیچ رندرینگ دنیا وجود ندارد** |
| سیاه‌چاله قابل ورود است؟ | ✓ Phase 7 | ❌ `generate_dungeon()` **هیچ‌جا صدا زده نمی‌شود** |
| ماموریت‌ها پیشرفت می‌کنند؟ | ✓ Phase 8 | ❌ `update_quest_progress()` **هرگز متصل نیست** |
| صدا دارد؟ | ✓ AudioManager | ❌ **صفر فایل صوتی، صفر تولید procedural** |
| فارسی نمایش داده می‌شود؟ | ✓ EN/FA RTL | ❌ **صفر فایل فونت → همه متن فارسی □□□** |
| CI تست می‌کند؟ | ✓ | ❌ **CI جعلی است (پایین توضیح داده شده)** |

**نتیجه‌گیری:** این مخزن یک *اسکلت کد تولیدشده توسط هوش مصنوعی* است که هرگز یک بار هم واقعاً اجرا نشده. ROADMAP یک سند آرزو است، نه گزارش وضعیت.

---

## 🔴 بخش ۱: خطاهای بحرانی (بازی اصلاً بالا نمی‌آید)

### 1.1 — `class_name` روی Autoloadها → ۱۱ مدیر از کار می‌افتند

**مهم‌ترین باگ کل پروژه.** در Godot 4، اگر اسکریپتی که به عنوان Autoload ثبت شده `class_name` هم‌نام داشته باشد، خطای Parse می‌دهد:

```
SCRIPT ERROR: Parse Error: Class "GameManager" hides an autoload singleton.
          at: res://src/core/game_manager.gd:6
ERROR: Failed to create an autoload, script 'res://src/core/game_manager.gd' is not compiling.
```

کامیت `45c4230` ادعا می‌کند «remove class_name hiding autoload» — **ولی انجام نشده.** فقط در `audio_manager.gd` کامنت شده (`# class_name AudioManager`). ۱۱ فایل دیگر دست‌نخورده مانده‌اند:

| فایل | خط | class_name مشکل‌ساز |
|---|---|---|
| `src/core/game_manager.gd` | 6 | `GameManager` |
| `src/core/save_manager.gd` | 6 | `SaveManager` |
| `src/ui/ui_manager.gd` | 6 | `UIManager` |
| `src/localization/localization_manager.gd` | 6 | `LocalizationManager` |
| `src/core/player_stats.gd` | 6 | `PlayerStats` |
| `src/core/combat_manager.gd` | 6 | `CombatManager` |
| `src/core/inventory_manager.gd` | 7 | `InventoryManager` |
| `src/core/world_manager.gd` | 6 | `WorldManager` |
| `src/core/dungeon_manager.gd` | 6 | `DungeonManager` |
| `src/core/quest_manager.gd` | 6 | `QuestManager` |
| `src/core/talent_tree.gd` | 6 | `TalentTree` |

### 1.2 — سه خطای Parse مستقل دیگر

```
res://src/polish/juice_controller.gd:25   Cannot infer the type of "intensity"
res://src/polish/intro_cutscene.gd:70     Cannot infer the type of "use_fa"
res://tests/test_polish.gd:54             Identifier "persian" not declared in the current scope
```

`test_polish.gd:53-54` — مقدار تابع دور ریخته شده و بعد متغیر وجود‌نداشته چاپ می‌شود:
```gdscript
PersianNumerals.to_persian("Level 5 - 123 gold")   # نتیجه ذخیره نمی‌شود
print("  persian numerals: %s" % persian)          # ← "persian" وجود ندارد
```

`intro_cutscene.gd` خراب → `intro_scene_controller.gd` هم آبشاری fails to compile.

### 1.3 — خروجی واقعی اجرای بازی

```
[PolishManager] Phase 11 Polish initialized
[AudioManager] initialized, offline SFX pool=6
[TouchControls] visible=true joystick_radius=62.0
[HUD] ready
```

**فقط همین.** نه GameManager، نه SaveManager، نه UIManager، نه منوی اصلی، نه دنیا، نه دشمن.

---

## 🔴 بخش ۲: `main_scene.tscn` — صحنه اصلی از اساس خراب است

```
[node name="Player" type="CharacterBody2D" parent="."]     position = Vector2(360, 640)
[node name="Sprite" type="Sprite2D" parent="Player"]       ← بدون texture
[node name="CollisionShape2D" parent="Player"]             ← بدون shape
[node name="Camera2D" type="Camera2D" parent="."]          ← برادر Player، نه فرزندش!
[node name="WorldContainer" type="Node2D" parent="."]      ← خالی، هیچ‌وقت پر نمی‌شود
[node name="Enemies" type="Node2D" parent="."]             ← خالی، هیچ‌وقت پر نمی‌شود
```

1. **بازیکن نامرئی است** — `Sprite2D` هیچ `texture` ندارد. هیچ کد تولید sprite هم برای بازیکن وجود ندارد (`SilhouetteGenerator` فقط برای آیتم‌هاست).
2. **بازیکن برخورد ندارد** — `CollisionShape2D` بدون `shape` resource. `move_and_slide()` هیچ اثری ندارد؛ بازیکن از همه‌چیز رد می‌شود.
3. **دوربین بازیکن را دنبال نمی‌کند** — `Camera2D` در `parent="."` است نه `parent="Player"`. ثابت در (0,0) می‌ماند در حالی که بازیکن در (360,640) است. **بازیکن از کادر دوربین بیرون است.**
4. `player.tscn` یک صحنه جدا و **کاملاً بلااستفاده** است (main_scene بازیکن را inline تعریف کرده).
5. UIDهای دست‌ساز و جعلی: `uid://c0main0000001`, `uid://c0player000001`, `uid://c0cam00000001`.

---

## 🔴 بخش ۳: همه‌ی سیستم‌های گیم‌پلی «کد مرده» هستند

مهم‌ترین یافته: توابع نوشته شده‌اند ولی **هیچ‌وقت صدا زده نمی‌شوند**. من با `grep` روی کل `src/` و `scenes/` بررسی کردم:

| تابع | تعداد فراخوانی در پروژه | نتیجه |
|---|---|---|
| `CombatManager.player_attack()` | **۰** | بازیکن هرگز نمی‌تواند حمله کند |
| `CombatManager.player_dodge()` | **۰** | بازیکن هرگز نمی‌تواند جا خالی بدهد |
| `DungeonManager.generate_dungeon()` | **۰** | هیچ سیاه‌چاله‌ای هرگز تولید نمی‌شود |
| `DungeonManager.enter_room()` | **۰** | اتاق‌ها هرگز فعال نمی‌شوند |
| `DungeonManager.reach_checkpoint()` | **۰** | چک‌پوینت هرگز کار نمی‌کند |
| `QuestManager.start_quest()` | **۰** | هیچ ماموریتی هرگز شروع نمی‌شود |
| `QuestManager.update_quest_progress()` | **۰** | هیچ ماموریتی هرگز پیشرفت/تمام نمی‌شود |
| `WorldManager.update_biome_at()` | **۰** | بیوم هرگز عوض نمی‌شود، دشمن هرگز spawn نمی‌شود |
| `WorldManager.interact_with_npc()` | **۰** | هیچ گفتگویی با NPC ممکن نیست |
| `InventoryManager.open_chest()` | **۰** | صندوق‌ها هرگز باز نمی‌شوند |
| `InventoryManager.equip_item()` | **۰** | تجهیز دستی ممکن نیست |
| `UIManager.show_talent_panel()` | **۰** | درخت استعداد غیرقابل دسترسی |
| `PlayerStats.die()` → signal `player_died` | emit می‌شود ولی **هیچ‌جا connect نشده** | مرگ بازیکن هیچ اثری ندارد |
| `CombatManager.enemy_killed` → `DungeonManager.on_enemy_killed` | **هرگز connect نشده** | اتاق‌ها هیچ‌وقت «پاک» نمی‌شوند |
| `HUD.update_health/stamina/gold/level` | **۰ فراخوانی خارجی** | HUD تا ابد 100/100/Lv.1/0 نشان می‌دهد |

### اکشن‌های ورودی تعریف‌شده ولی هرگز خوانده‌نشده

`grep 'is_action_just_pressed\|is_action_pressed'` روی کل `src/` فقط این‌ها را پیدا می‌کند: `ui_up/down/left/right`, `sprint`, `ui_accept`, `ui_cancel`, `pause`.

| اکشن | وضعیت |
|---|---|
| `attack` | دکمه لمسی `Input.action_press("attack")` می‌زند، ولی **هیچ اسکریپتی آن را نمی‌خواند** |
| `dodge` | **هرگز خوانده نمی‌شود** |
| `interact` | **هرگز خوانده نمی‌شود** |
| `inventory` | **هرگز خوانده نمی‌شود** |
| `quest` | **۰ ارجاع در کل پروژه** |
| `talent` | **۰ ارجاع در کل پروژه** |

---

## 🔴 بخش ۴: کمبودهای کامل (چیزهایی که اصلاً وجود ندارند)

### 4.1 — صفر فایل فونت → متن فارسی غیرقابل نمایش
```
$ find . -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff*'
NO FONT FILES AT ALL
```
فونت پیش‌فرض Godot **پوشش گلیف عربی/فارسی ندارد**. تمام رشته‌های فارسی (`"مردی"`, `"بازی"`, `"تنظیمات"`, `"کوله‌پشتی"` و …) به صورت جعبه‌های خالی □□□ رندر می‌شوند. ROADMAP می‌گوید «✓ Bilingual localization (EN/FA)» و «✓ EN/FA RTL» — **عملاً غیرممکن است.**

علاوه بر این، هیچ‌جا `Control.text_direction` یا `Control.language` تنظیم نشده → حتی با فونت درست، RTL کار نمی‌کند.

### 4.2 — صفر فایل صوتی → بازی کاملاً بی‌صدا
```
$ find . -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3'
NO AUDIO FILES AT ALL
```
تنها فایل صوتی `assets/audio/bus_layout.tres` است (تعریف bus، نه صدا).

`audio_manager.gd` مدعی «procedural SFX with AudioStreamGenerator» است، ولی:
```gdscript
func _get_sfx_stream(name: String) -> AudioStream:
    for p in paths:
        if ResourceLoader.exists(p): return load(p)
    # Procedural fallback: tiny generator tone (if no assets, don't crash)
    return null          # ← کامنت می‌گوید tone تولید می‌کند، ولی null برمی‌گرداند
```
**۶ `AudioStreamPlayer` ساخته می‌شوند و هیچ‌وقت stream نمی‌گیرند.** لاگ `offline SFX pool=6` گمراه‌کننده است.

`_get_music_stream()` هم به `res://assets/music/%s.ogg` اشاره می‌کند که **پوشه‌اش وجود ندارد**. ۹ 트랙 موزیک تعریف شده (`BIOME_MUSIC`)، صفر فایل.

### 4.3 — صفر رندرینگ جهان
`WorldManager.generate_world()` فقط آرایه‌های داده می‌سازد (`biome_map`, `npcs`, `chests`, `dungeon_entrances`). **هیچ کدی این داده‌ها را رسم نمی‌کند.**
- `var tile_map: TileMap = null` — هرگز مقداردهی نمی‌شود (و `TileMap` در Godot 4.3+ منسوخ شده، باید `TileMapLayer` باشد).
- نود `WorldContainer` در صحنه خالی می‌ماند.
- ROADMAP می‌گوید «✓ 7 biome types with distinct colors» — رنگ‌ها در `BIOME_COLORS` تعریف شده‌اند ولی **هرگز روی صفحه کشیده نمی‌شوند**.

### 4.4 — الگوریتم بیوم «نویز» نیست
```gdscript
func _get_biome_at(x: int, y: int) -> String:
    var noise = rng.randf() * 0.5 + sin(nx*2.1)*cos(ny*1.7)*0.3 + sin(nx*0.5+ny*0.3)*0.2
```
`rng.randf()` برای **هر کاشی مستقل** صدا زده می‌شود → نتیجه «برف تلویزیونی» است نه بیوم‌های پیوسته. باید `FastNoiseLite` باشد. همچنین ۴۰,۰۰۰ بار `rng.randf()` در هر بار تولید دنیا.

### 4.5 — رابط کاربری‌های ادعاشده وجود ندارند
`UIManager` ادعای ساخت پنل‌ها را دارد:
```gdscript
func _build_quest_panel() -> void:
    _quest_panel = Control.new()      # ← یک Control خالی! هیچ محتوایی ندارد
    _quest_panel.name = "QuestPanel"
    add_child(_quest_panel)

func _build_talent_panel() -> void:
    _talent_panel = Control.new()     # ← خالی
    add_child(_talent_panel)

func show_trade_panel(npc: Dictionary) -> void:
    pass                              # ← کل تجارت: pass

func _apply_theme() -> void:
    for child in get_children():
        if child is Control:
            pass                      # ← هیچ کاری نمی‌کند
```
- **Quest Journal UI:** وجود ندارد (ROADMAP: «✓ Quest journal UI»)
- **Talent Tree UI:** وجود ندارد (ROADMAP: «✓ 5 talent trees… Branching paths»)
- **Trade/Vendor UI:** وجود ندارد (ROADMAP: «✓ Vendor NPCs with buying/selling»)
- **Inventory UI:** فقط ۶ برچسب با نام اسلات (`slot.to_upper()`). هیچ آیتمی نمایش داده نمی‌شود، هیچ تعاملی ممکن نیست.
- **Dialogue UI:** وجود ندارد (ROADMAP: «✓ NPC dialogue system»)
- **Death Screen / Victory Screen:** کد دارند، ولی چون `player_died` هرگز connect نشده، غیرقابل دسترس‌اند.

### 4.6 — کریدورهای سیاه‌چاله پیاده‌سازی نشده
```gdscript
func _create_corridor(from, to, room_from, room_to) -> void:
    # Simple L-shape corridor
    pass  # Visual corridors are handled by rendering
```
و «rendering» مورد اشاره وجود ندارد. ROADMAP: «✓ Procedural room-and-corridor layouts» → **کریدور `pass` است.**

همچنین `_is_position_valid()` فاصله حداقل ۲ واحد شبکه‌ای بین اتاق‌ها اجباری می‌کند، و `_grid_to_world` هر واحد را ۲۰۰ پیکسل می‌کند در حالی که اتاق ۹۶ پیکسل است → **اتاق‌ها هرگز به هم نمی‌رسند.**

---

## 🟠 بخش ۵: باگ‌های منطقی (حتی بعد از رفع کامپایل)

### 5.1 — `CombatManager.player_stats` همیشه `null` است
```gdscript
@onready var player_stats: PlayerStats = $PlayerStats   # combat_manager.gd:16
```
`CombatManager` یک autoload در `/root/CombatManager` است و **هیچ نود فرزندی به نام `PlayerStats` ندارد** (باید `/root/PlayerStats` باشد).
نتیجه: `player_attack()` در خط ۷۱ (`if not player_stats: return false`) **همیشه false برمی‌گرداند**. حتی اگر صدا زده شود، مبارزه کار نمی‌کند.

### 5.2 — هدف‌گیری دشمن از مبدأ مختصات جهان!
```gdscript
func _find_nearest_enemy_in_range(range: float) -> Node:
    for enemy in active_enemies:
        var dist = enemy.global_position.distance_to(Vector2.ZERO)  # TODO: use player pos
```
**خود کد `TODO` دارد.** فاصله از `(0,0)` جهان حساب می‌شود نه از بازیکن. بازیکن فقط دشمنانی را می‌زند که تصادفاً نزدیک مبدأ جهان باشند.

### 5.3 — `take_damage()` با `await` مقدار را برنمی‌گرداند
```gdscript
# enemy.gd:240
func take_damage(amount: int) -> int:
    hp -= amount
    ...
    await get_tree().create_timer(0.1).timeout   # ← تابع را coroutine می‌کند
    sprite.modulate = orig
    ...
    return amount

# combat_manager.gd:107
final_damage = target.take_damage(damage)        # ← یک GDScriptFunctionState می‌گیرد، نه int!
emit_signal("damage_dealt", target, final_damage, is_crit)
```
`final_damage` یک coroutine object می‌شود → سیگنال با نوع غلط منتشر می‌شود → شماره آسیب و screenshake خراب.

### 5.4 — جا خالی دادن: اول استقامت کم می‌شود، بعد شانس آزموده می‌شود
```gdscript
func player_dodge() -> bool:
    if not player_stats.consume_stamina(25.0): return false   # ۲۵ استقامت رفت
    if player_stats.roll_dodge():                             # حالا شانسی
        ...
        return true
    return false                                              # ← ۲۵ استقامت سوخت، هیچ نشد
```
بعلاوه شرط مرده:
```gdscript
if player_stats.has_method("set_invulnerable"):   # این متد وجود ندارد
    player_stats.invulnerable = true              # پس این بلوک هرگز اجرا نمی‌شود
```

### 5.5 — `active_enemies.filter()` روی آرایه نوع‌دار
```gdscript
var active_enemies: Array[Node] = []
...
active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))  # :62
```
`Array.filter()` یک `Array` بدون نوع برمی‌گرداند؛ انتساب آن به `Array[Node]` در زمان اجرا خطا می‌دهد.

### 5.6 — دشمن‌ها به `root` اضافه می‌شوند، نه به نود `Enemies`
```gdscript
get_tree().root.add_child(enemy)      # combat_manager.gd:164
```
نود `Enemies` که در صحنه ساخته شده بی‌استفاده می‌ماند؛ Z-order و مدیریت صحنه به‌هم می‌ریزد.
همچنین `enemy.global_position = position` **قبل از** `add_child` تنظیم می‌شود.

### 5.7 — ذخیره‌سازی با JSON و نوع‌های Godot → crash
`GameManager._save_game_data()` از `JSON.stringify` استفاده می‌کند، ولی داده‌های ذخیره شامل نوع‌های Godot هستند:
```gdscript
# world_manager.gd
var dungeon_entrances: Array[Vector2i] = []
"position": Vector2i(x, y) * TILE_SIZE      # در npcs و chests
"world_pos": _grid_to_world(pos)           # Vector2 در dungeon rooms
# item_generator.gd → palette شامل Color
```
`JSON.stringify` این‌ها را به رشته تبدیل می‌کند. موقع load:
- `dungeon_entrances = data.get(...)` → انتساب `Array` از `String` به `Array[Vector2i]` → **خطای نوع**
- `npc.get("position", Vector2.ZERO)` → رشته برمی‌گرداند → `pos.distance_to(String)` → **crash**

**ذخیره/بارگذاری در بهترین حالت خراب است و در بدترین حالت بازی را می‌بندد.**

### 5.8 — دو سیستم ذخیره‌سازی موازی و ناسازگار
- `SaveManager.save_game(data, is_checkpoint)`
- `GameManager.save_game(is_checkpoint)` + `_save_game_data()` — **پیاده‌سازی کاملاً جداگانه**

`GameManager` هرگز از `SaveManager` استفاده نمی‌کند (فقط `_delete_save` مستقل). `SaveManager.autosave()` برعکس `gm._collect_game_state()` را صدا می‌زند. دو مسیر نوشتن روی یک فایل.

### 5.9 — چک‌پوینت سیاه‌چاله همیشه شکست می‌خورد
```gdscript
# dungeon_manager.gd:249
if has_node("/root/SaveManager"):
    get_node("/root/PlayerStats").full_restore()      # ← گارد SaveManager است، دسترسی PlayerStats!
    get_node("/root/SaveManager").save_checkpoint({}) # ← دیکشنری خالی

# save_manager.gd:45
func save_game(data: Dictionary, is_checkpoint: bool = false) -> bool:
    if not data.has("player"):
        push_warning("[SaveManager] save data missing player key")
        return false                                  # ← همیشه اینجا برمی‌گردد
```
`save_checkpoint({})` → `{}` کلید `player` ندارد → **ذخیره هرگز نوشته نمی‌شود.**

### 5.10 — آزاد کردن کوئست‌های وابسته با `int()` روی رشته
```gdscript
# quest_manager.gd:514
var main_num = int(completed_id.replace("main_", "").replace("side_", ""))
```
برای `"side_snow_004"` → `int("snow_004")` → **۰** (با خطا). زنجیره ماموریت‌های اصلی هرگز باز نمی‌شود.

### 5.11 — آرگومان با نوع غلط
```gdscript
# world_manager.gd:214
ui.show_quest_panel(npc)          # npc یک Dictionary است
# ui_manager.gd:227
func show_quest_panel(show: bool) -> void:    # ← انتظار bool دارد
```

### 5.12 — `UIManager._hud` همیشه `null` → crash
```gdscript
# ui_manager.gd:51
_hud = get_node_or_null("HUD")     # HUD باید فرزند UIManager باشد
```
ولی در `main_scene.tscn` نود `HUD` فرزند `Main` است، و `UIManager` یک autoload در `/root/UIManager` **بدون هیچ فرزندی**. پس `_hud == null`:
```gdscript
# ui_manager.gd:113-114
if show:
    _hud.visible = false           # ← null instance → خطای زمان اجرا
```
(`_apply_ui_scale` گارد `if _hud:` دارد ولی `_show_main_menu` ندارد.)

### 5.13 — صندوق‌ها با کلید زمانی قفل می‌شوند، نه با هویت
```gdscript
# inventory_manager.gd:193
var key = "%s_%s" % [chest_type, int(Time.get_unix_time_from_system() / 60)]
```
«یک صندوق در دقیقه برای هر نوع». یعنی در یک اتاق گنج با ۳ صندوق `medium` فقط یکی کار می‌کند، و بعد از ۶۰ ثانیه **همه صندوق‌های دنیا دوباره قابل لوت شدن‌اند** → فارم بی‌نهایت. `recently_looted_chests` هم هرگز پاک نمی‌شود → نشتی حافظه.

### 5.14 — `_apply_equipment_bonus` بونوس را انباشته/نشتی می‌دهد
```gdscript
func add_item(item):
    ...
    if item.get("slot") in EQUIP_SLOTS:
        _unequip_current_in_slot(item.get("slot"))   # فقط بونوس قبلی را برمی‌دارد
        equipment[item.get("slot")] = item
        _apply_equipment_bonus(item)
```
ولی آیتم **همزمان در `inventory` هم می‌ماند** (حذف نمی‌شود). پس وزن دو بار حساب می‌شود و آیتم هم در لیست و هم تجهیز است. `equip_item()` درست انجام می‌دهد ولی هیچ‌جا صدا زده نمی‌شود.
`_remove_equipment_bonus` هم `stats.max_hp -= int(value)` می‌کند بدون تنظیم `hp` → `hp` می‌تواند از `max_hp` بیشتر بماند.

### 5.15 — `total_talent_points_used` در واقع «کسب‌شده» است
```gdscript
# player_stats.gd:105
func level_up() -> void:
    talent_points += 1
    total_talent_points_used += 1     # ← نام اشتباه؛ این points_earned است
```
و `TalentTree.talent_points_available` یک شمارنده **جدا** است که هرگز با `PlayerStats.talent_points` همگام نمی‌شود. `add_talent_points()` هیچ‌جا صدا زده نمی‌شود → **بازیکن هرگز امتیاز استعداد دریافت نمی‌کند.**

### 5.16 — `PlayerStats.regenerate_stamina()` هرگز صدا زده نمی‌شود
`player_movement.gd` منطق استقامت **خودش را** دارد و مستقیم `stats.stamina = stamina` می‌نویسد (خط ۸۲). دو منبع حقیقت برای استقامت وجود دارد که با هم می‌جنگند.

### 5.17 — `project.godot`
```ini
[locale]
translation/remaps=[]
test_width=720      # ← کلید بی‌معنی
test_height=1280    # ← کلید بی‌معنی
```
بخش درست `[internationalization]` است نه `[locale]`. هیچ `.translation` ثبت نشده → `tr()` داخلی Godot کار نمی‌کند.

`assets/locale/translations.csv` توسط Godot به عنوان Translation ایمپورت می‌شود ولی **ثبت نشده** → بی‌استفاده. ضمناً فقط ۶ کلید دارد در حالی که `en.json` ۲۴ کلید دارد (تناقض).

### 5.18 — تمام هشدارهای GDScript خاموش شده‌اند
```ini
[debug]
gdscript/warnings/untyped_declaration=0
gdscript/warnings/inferred_declaration=0
gdscript/warnings/unsafe_property_access=0
gdscript/warnings/unsafe_method_access=0
gdscript/warnings/unused_variable=0
gdscript/warnings/unused_private_class_variable=0
gdscript/warnings/unused_local_variable=0
gdscript/warnings/shadowed_variable=0
gdscript/warnings/unreachable_code=0
gdscript/warnings/unassigned_variable=0
```
**۱۰ نوع هشدار خاموش شده.** این دقیقاً همان چیزی است که باگ‌های بالا (مثل `Cannot infer the type`) را پنهان می‌کرد. نشانه یک پروژه «سبز نگه‌داشته‌شده با پاک‌کردن صورت‌مسئله».

---

## 🟠 بخش ۶: ساختار مخزن و CI/CD

### 6.1 — CI جعلی است
`.github/workflows/ci.yml` هیچ تستی اجرا نمی‌کند:
```yaml
- name: Run tests (headless)
  run: |
    if [ -f "project/tests/test_polish.gd" ]; then echo "✓ test_polish.gd found"; cat ... | head -n 20; fi
    ...
    # Create dummy test results for artifact
    echo "<testsuite name='polish' tests='8' failures='0'>..." > project/test-results/polish.xml
```
- «اجرای تست» = `cat` کردن فایل‌ها
- **XML نتیجه تست هاردکد شده با `failures='0'`** ← گزارش موفقیت ساختگی
- `godot --headless --check-only --path project` بدون `--script` هیچ معنایی ندارد، و با `|| echo "not critical"` خطاها بلعیده می‌شوند
- `continue-on-error: true` روی نصب Godot

**نتیجه: CI همیشه سبز است، حتی وقتی پروژه کامپایل نمی‌شود.** این دقیقاً همان چیزی است که اتفاق افتاده.

### 6.2 — ساختار پوشه تودرتو و تکراری
```
2D-RPG/
├── .github/workflows/{ci,build-android}.yml   ← اینها اجرا می‌شوند
└── project/
    ├── .github/workflows/{ci,build-android}.yml  ← کپی دقیق، هرگز اجرا نمی‌شود (مرده)
    ├── project.godot
    ├── export_presets.cfg
    └── project/godot-project.json   ← فایل بی‌معنی، Godot چنین چیزی ندارد
```
`diff` تأیید کرد هر دو جفت workflow **کاملاً یکسان‌اند**. نسخه `project/.github/` مرده است.

### 6.3 — `build-android.yml` نمی‌تواند APK بسازد
- `chickensoft-games/setup-godot@v2` با `continue-on-error: true`
- مسیر fallback برای نصب export templates: `~/.local/share/godot/export_templates/4.4.1.stable` — ولی اگر step اول موفق شود، templates نصب نمی‌شوند (چون فقط در `if: failure` است)
- keystore موقت debug داخل workflow ساخته می‌شود و در `~/.config/godot/editor_settings-4.tres` نوشته می‌شود — نام فایل درست `editor_settings-4.x.tres` است (بستگی به نسخه)
- `|| echo "export-debug attempt finished"` → شکست export بلعیده می‌شود
- `package/unique_name="com.example.rpg2d"` → **نام پکیج placeholder، توسط Play Store رد می‌شود**
- هیچ keystore امضای release تعریف نشده → نمی‌توان AAB برای فروشگاه ساخت (Phase 12 ادعا شده)

### 6.4 — `.gitignore`
```
export_*                 # ← export_presets.cfg را هم ignore می‌کند
!export_presets.cfg      # ← negation
```
کار می‌کند ولی شکننده است. ضمناً `.gitignore` در دو سطح تکراری و **متفاوت** است (`project/` نسخه `!project/assets/icon.png` را ندارد).

---

## 🟡 بخش ۷: ROADMAP در برابر واقعیت

هر ادعای ROADMAP که با کد مطابقت ندارد:

| ادعا | واقعیت |
|---|---|
| «✓ CharacterBody2D player with 8-directional movement» | کد هست، ولی بدون collision shape و بدون sprite → عملاً بی‌اثر |
| «✓ Camera2D following player with bounds» | دوربین فرزند بازیکن نیست → دنبال نمی‌کند |
| «✓ 1000+ distinct items» | `ItemGenerator` کار می‌کند، ولی **هیچ UI برای دیدن آیتم‌ها نیست** و هیچ آیتمی هرگز به بازیکن داده نمی‌شود |
| «✓ 6 enemy types … Enemy AI states: patrol, chase, attack, die» | `enemy.gd` نوشته شده، ولی هرگز spawn نمی‌شود (`update_biome_at` صدا زده نمی‌شود). دشمن `CollisionShape2D` ندارد. sprite دشمن texture ندارد. |
| «✓ 5 talent trees … 30 total talents» | داده‌ها هستند، **UI وجود ندارد**، `add_talent_points` هرگز صدا زده نمی‌شود |
| «✓ 30-slot inventory with 50 weight limit» | کد هست، **UI فقط ۶ برچسب خالی است** |
| «✓ Chest loot tables» | `open_chest()` هرگز صدا زده نمی‌شود |
| «✓ 7 biome types with distinct colors» | رنگ‌ها تعریف شده‌اند، **هرگز رسم نمی‌شوند** |
| «✓ Procedural world generation (200x200 tiles)» | آرایه ساخته می‌شود، **هیچ TileMap/rendering نیست** |
| «✓ Village and town placement with NPCs» | NPCها فقط دیکشنری‌اند؛ **هیچ نود، sprite یا برخوردی ندارند** |
| «✓ NPC dialogue system» | **وجود ندارد** |
| «✓ Procedural room-and-corridor layouts» | کریدور `pass` است |
| «✓ 12 main story quests, 21 side quests» | داده‌ها هستند؛ **هیچ‌وقت شروع یا تمام نمی‌شوند** |
| «✓ Quest journal UI» | **یک `Control` خالی** |
| «✓ Vendor NPCs with buying/selling» | `show_trade_panel()` → `pass` |
| «✓ Currency system (gold)» | طلا فقط در `PlayerStats` هست؛ HUD هرگز به‌روز نمی‌شود |
| «✓ AudioManager - Music/SFX buses, biome music» | صفر فایل صوتی، fallback هم `null` |
| «✓ Localization - EN/FA RTL, Persian numerals» | صفر فونت → فارسی □□□ |
| «✓ SaveManager - Autosave, checkpoints, permadeath» | autosave به دلیل نبود PlayerStats کار نمی‌کند؛ checkpoint همیشه fail می‌شود؛ JSON با Vector2i crash می‌کند |
| «✓ UIManager - HUD, menus, inventory panel» | UIManager اصلاً load نمی‌شود |
| «✓ IntroCutscene - Logo reveal, lore, skip support» | خطای parse در خط ۷۰ |
| «✓ **FIXED**: All system connections and signal wiring» | **تقریباً هیچ سیگنالی connect نشده است** |
| «✓ Offline-only compliance (no runtime network)» | این یکی درست است ✓ |

---

## جمع‌بندی: چه چیزی واقعاً کار می‌کند؟

**کار می‌کند:**
1. `PolishManager` / `JuiceController`* / `PerformanceOptimizer` / `VisualEffects` — load می‌شوند (*`juice_controller.gd` خطای parse دارد، پس عملاً نه)
2. `AudioManager` — load می‌شود ولی بی‌صدا
3. `TouchControls` — load می‌شود، joystick می‌سازد
4. `HUD` — load می‌شود، procedurally ساخته می‌شود، ولی هرگز داده واقعی نمی‌گیرد
5. `player_movement.gd` — منطق درست است ولی روی نود نامرئی بدون collision با دوربین ثابت
6. `ItemGenerator` + `PaletteGenerator` + `SilhouetteGenerator` + `PatternGenerator` — احتمالاً سالم (تنها بخشی که واقعاً کامل به نظر می‌رسد)

**کار نمی‌کند:** همه‌چیز دیگر.

---

## اولویت‌بندی پیشنهادی برای تعمیر

**P0 — راه‌اندازی (بدون این‌ها هیچ‌چیز تست نمی‌شود):**
1. حذف ۱۱ `class_name` از autoloadها (یا تغییر نام autoloadها)
2. رفع ۳ خطای parse (`juice_controller:25`, `intro_cutscene:70`, `test_polish:54`)
3. روشن‌کردن دوباره هشدارهای GDScript

**P1 — قابل بازی شدن حداقلی:**
4. بازسازی `main_scene.tscn`: دوربین به عنوان فرزند بازیکن، `CollisionShape2D` با shape واقعی، sprite پروسیجرال برای قهرمان
5. اتصال ورودی: `attack`, `dodge`, `interact`, `inventory`, `quest`, `talent`, `pause`
6. رفع `CombatManager.player_stats` و `_find_nearest_enemy_in_range` (موقعیت واقعی بازیکن)
7. رفع `take_damage` coroutine
8. اتصال سیگنال‌های `PlayerStats` → `HUD`

**P2 — سیستم‌های مرده را زنده کن:**
9. رندرینگ جهان (TileMapLayer یا `Node2D._draw`) + بیوم با `FastNoiseLite`
10. spawn دشمن‌ها با sprite و collision
11. جریان ورود به سیاه‌چاله + کریدورهای واقعی
12. اتصال `enemy_killed` → `QuestManager` و `DungeonManager`
13. UI واقعی: Inventory / Quest Journal / Talent Tree / Trade / Dialogue
14. فونت فارسی (مثل Vazirmatn) + RTL واقعی

**P3 — زیرساخت:**
15. ذخیره‌سازی سازگار (یک `SaveManager`؛ نوع‌های Godot را قبل از JSON تبدیل کن)
16. تولید صدای procedural واقعی یا افزودن فایل‌های صوتی
17. CI واقعی که `godot --headless --check-only --script` روی هر فایل اجرا کند و در صورت خطا **fail شود**
18. حذف `project/.github/` تکراری و `project/project/godot-project.json`
19. اصلاح `export_presets.cfg` (نام پکیج واقعی، keystore)

---

*این گزارش با اجرای واقعی باینری Godot 4.4.1-stable روی مخزن تولید شده است، نه با بازبینی چشمی.*

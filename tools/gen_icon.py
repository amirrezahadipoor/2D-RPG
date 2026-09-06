"""Store icon: wizard hat + crossed sword on a night shield, 512px nearest."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import gen_assets as G

S = 32
c = G.Canvas(S, S)
# shield background
for y in range(S):
    for x in range(S):
        if 3 <= x <= 28 and 2 <= y <= 29 and not (x + y > 55 or (28 - x) + y > 55):
            c.px(x, y, (24, 26, 38))
for y in range(S):
    for x in range(S):
        if 4 <= x <= 27 and 3 <= y <= 28 and not (x + y > 53 or (27 - x) + y > 53):
            c.px(x, y, (38, 42, 62))
# wizard hat (purple triangle + brim)
for y in range(6, 20):
    w = max(0, (y - 5) // 1)
    for x in range(16 - w, 17 + w):
        if 4 <= x <= 27:
            c.px(x, y, (122, 84, 200))
    c.px(16 - w, y, (160, 120, 235))
for x in range(9, 24):
    c.px(x, 20, (96, 64, 168))
    c.px(x, 21, (70, 46, 128))
c.px(15, 8, (255, 240, 190)); c.px(14, 11, (255, 240, 190)); c.px(17, 14, (255, 240, 190))
# crossed sword (diagonal gold blade)
for i in range(14):
    c.px(8 + i, 26 - i, (235, 200, 110))
    c.px(9 + i, 26 - i, (180, 148, 70))
c.px(7, 27, (140, 110, 50)); c.px(6, 28, (140, 110, 50))
big = G.Canvas(S * 16, S * 16)
for (x, y), col in c.buf.items():
    for dy in range(16):
        for dx in range(16):
            big.px(x * 16 + dx, y * 16 + dy, col)
G.save(big, "assets/icon.png")
print("icon written")

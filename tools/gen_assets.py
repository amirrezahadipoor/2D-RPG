#!/usr/bin/env python3
"""
Pixel-art asset generator for 2D-RPG.

Produces REAL committed PNG assets (no runtime generation) so the art is
inspectable, diffable and versionable.

Layout contract (important — the paper-doll system depends on it):
    Every hero/equipment layer sheet uses the SAME grid:
        cell   = 24 x 32 px
        cols   = 8   -> [idle0, idle1, walk0, walk1, walk2, walk3, atk0, atk1]
        rows   = 4   -> [down, up, left, right]
        sheet  = 192 x 128 px
    Because every layer shares the grid, all layers can be driven by a single
    frame index -> equipment animates in sync with the body.

Usage:  python3 tools/gen_assets.py
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")

# ---------------------------------------------------------------- palette ---
# A deliberately small, cohesive palette. Limited palettes are what make
# pixel art read as pixel art instead of as shrunken digital painting.
PAL = {
    "outline":   (24, 26, 44),
    # skin
    "skin_l":    (240, 208, 176),
    "skin_m":    (216, 160, 104),
    "skin_d":    (164, 104, 72),
    # hair
    "hair_l":    (150, 84, 52),
    "hair_m":    (102, 54, 48),
    "hair_d":    (58, 34, 40),
    # cloth (default tunic)
    "cloth_l":   (86, 156, 224),
    "cloth_m":   (58, 100, 190),
    "cloth_d":   (44, 58, 110),
    # metal
    "metal_l":   (206, 218, 234),
    "metal_m":   (150, 172, 196),
    "metal_d":   (88, 108, 136),
    # leather
    "leath_l":   (206, 138, 96),
    "leath_m":   (162, 96, 62),
    "leath_d":   (112, 60, 40),
    # gold
    "gold_l":    (255, 214, 130),
    "gold_m":    (240, 168, 88),
    "gold_d":    (178, 108, 46),
    # greens
    "leaf_l":    (126, 224, 148),
    "leaf_m":    (58, 178, 100),
    "leaf_d":    (34, 112, 118),
    # earth / stone
    "stone_l":   (176, 178, 190),
    "stone_m":   (126, 128, 146),
    "stone_d":   (78, 80, 100),
    "dirt_l":    (170, 124, 84),
    "dirt_m":    (128, 88, 58),
    "dirt_d":    (86, 56, 38),
    # misc
    "red_l":     (240, 130, 96),
    "red_m":     (186, 66, 84),
    "red_d":     (112, 40, 62),
    "purple_l":  (180, 130, 240),
    "purple_m":  (124, 78, 200),
    "purple_d":  (74, 46, 132),
    "water_l":   (110, 190, 240),
    "water_m":   (58, 130, 210),
    "water_d":   (36, 84, 160),
    "snow_l":    (246, 250, 255),
    "snow_m":    (212, 226, 244),
    "snow_d":    (166, 186, 214),
    "white":     (246, 246, 246),
    "gray":      (140, 142, 156),
    "black":     (16, 18, 30),
    "ember":     (255, 176, 64),
}

CELL_W, CELL_H = 24, 32
COLS, ROWS = 8, 4
DIRS = ["down", "up", "left", "right"]

# Character anchors inside the 24x32 cell (feet at y=30 -> 2px bottom margin,
# 9px headroom above the skull for tall hats / plumes / weapon swings).
HEAD_X, HEAD_Y = 7, 8          # head is 10x9  -> x 7..16, y 8..16
TORSO_X, TORSO_Y = 8, 17       # torso is 8x7  -> x 8..15, y 17..23
ARM_L_X, ARM_R_X = 6, 16       # arms are 2 wide -> x 6..7 / x 16..17
LEG_L_X, LEG_R_X = 9, 13       # legs are 3 wide -> y 24..28, feet y 29..30
LEG_Y = 24


class Canvas:
    """RGBA pixel buffer with a few pixel-art-friendly primitives."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.buf = {}

    def px(self, x, y, col):
        if col is None:
            return
        if 0 <= x < self.w and 0 <= y < self.h:
            self.buf[(int(x), int(y))] = tuple(col)

    def rect(self, x, y, w, h, col):
        for j in range(h):
            for i in range(w):
                self.px(x + i, y + j, col)

    def hline(self, x, y, w, col):
        self.rect(x, y, w, 1, col)

    def vline(self, x, y, h, col):
        self.rect(x, y, 1, h, col)

    def get(self, x, y):
        return self.buf.get((int(x), int(y)))

    def mask_pixels(self):
        """Copy of the alpha mask (True where drawn)."""
        return {(x, y) for (x, y) in self.buf}

    def outline(self, col=None, diag=True):
        """Add a 1px outside outline around everything currently drawn.

        Done as a separate pass (rather than baked into each shape) so every
        asset gets a consistent silhouette, which is rule #1 of the art bible.
        """
        col = col or PAL["outline"]
        filled = set(self.buf.keys())
        nbrs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if diag:
            nbrs += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        added = []
        for (x, y) in filled:
            for dx, dy in nbrs:
                nx, ny = x + dx, y + dy
                if (nx, ny) not in filled and 0 <= nx < self.w and 0 <= ny < self.h:
                    added.append((nx, ny))
        for (x, y) in set(added):
            self.px(x, y, col)

    def shade(self, key_map, dy=1, dx=0):
        """Cheap directional shading: darken the pixel below/right of a fill."""
        for (x, y), c in list(self.buf.items()):
            t = (x + dx, y + dy)
            if t in self.buf and self.buf[t] == c:
                self.px(t, darken(c))

    def to_image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.buf.items():
            img.putpixel((x, y), (c[0], c[1], c[2], 255))
        return img


def darken(c, f=0.68):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f))


def lighten(c, f=1.28):
    return (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)))


def mirror_canvas(c, w):
    out = Canvas(c.w, c.h)
    for (x, y), col in c.buf.items():
        out.px(w - 1 - x, y, col)
    return out


# ------------------------------------------------------------------ poses ---
class Pose:
    """Shared skeleton state. Body AND equipment read the same pose, which is
    exactly what keeps the paper-doll layers in sync."""

    def __init__(self, bob=0, leg="neutral", arm="neutral", attack=0):
        self.bob = bob          # vertical shift (0 or -1)
        self.leg = leg          # neutral | left | right  (which leg leads)
        self.arm = arm          # neutral | back | forward
        self.attack = attack    # 0 none, 1 windup, 2 swing


def frame_pose(col):
    """Column index -> Pose. Single source of truth for the animation grid."""
    return {
        0: Pose(bob=0, leg="neutral", arm="neutral"),
        1: Pose(bob=-1, leg="neutral", arm="neutral"),
        2: Pose(bob=0, leg="left", arm="forward"),
        3: Pose(bob=-1, leg="pass", arm="neutral"),
        4: Pose(bob=0, leg="right", arm="back"),
        5: Pose(bob=-1, leg="pass", arm="neutral"),
        6: Pose(bob=0, leg="right", arm="back", attack=1),
        7: Pose(bob=-1, leg="left", arm="forward", attack=2),
    }[col]


# ------------------------------------------------------------- hero body ---
HEAD_FRONT = [
    "...hhhh...",
    "..hhhhhh..",
    ".hhhhhhhh.",
    "hhhhhhhhhh",
    "hhsssssshh",
    ".ssssssss.",
    ".ssssssss.",
    "..ssssss..",
    "...ssss...",
]
HEAD_BACK = [
    "...hhhh...",
    "..hhhhhh..",
    ".hhhhhhhh.",
    "hhhhhhhhhh",
    "hhhhhhhhhh",
    ".hhhhhhhh.",
    ".hhhhhhhh.",
    "..hhhhhh..",
    "...hhhh...",
]
HEAD_SIDE = [
    "...hhhh...",
    "..hhhhhh..",
    ".hhhhhhhh.",
    "hhhhhhhhhh",
    "hhhsssssss",
    ".hhsssssss",
    ".hhssssss.",
    "..hhssss..",
    "...hhss...",
]
TORSO = [
    ".cccccc.",
    "cccccccc",
    "cccccccc",
    "cccccccc",
    "cccccccc",
    ".cccccc.",
    "..cccc..",
]


def _stamp(c, art, ox, oy, mapping):
    for j, row in enumerate(art):
        for i, ch in enumerate(row):
            if ch == "." or ch == " ":
                continue
            col = mapping.get(ch)
            if col is not None:
                c.px(ox + i, oy + j, col)


def draw_hero_body(direction, pose):
    c = Canvas(CELL_W, CELL_H)
    b = pose.bob

    skin = {"l": PAL["skin_l"], "m": PAL["skin_m"], "d": PAL["skin_d"]}
    hair = {"l": PAL["hair_l"], "m": PAL["hair_m"], "d": PAL["hair_d"]}
    cloth = {"l": PAL["cloth_l"], "m": PAL["cloth_m"], "d": PAL["cloth_d"]}
    pants = {"l": lighten(PAL["leath_m"], 1.15), "m": PAL["leath_m"], "d": PAL["leath_d"]}

    # ---------------- head ----------------
    if direction == "down":
        _stamp(c, HEAD_FRONT, HEAD_X, HEAD_Y + b, {"h": hair["m"], "s": skin["m"]})
        c.hline(HEAD_X + 3, HEAD_Y + 1 + b, 4, hair["l"])          # hair sheen
        c.px(HEAD_X + 2, HEAD_Y + 2 + b, hair["l"])
        c.px(HEAD_X + 3, HEAD_Y + 5 + b, PAL["outline"])          # eyes
        c.px(HEAD_X + 6, HEAD_Y + 5 + b, PAL["outline"])
        c.px(HEAD_X + 3, HEAD_Y + 4 + b, PAL["white"])
        c.px(HEAD_X + 6, HEAD_Y + 4 + b, PAL["white"])
        c.hline(HEAD_X + 2, HEAD_Y + 4 + b - 0, 8, skin["l"])      # forehead light
        c.hline(HEAD_X + 3, HEAD_Y + 4 + b, 6, skin["m"])
        c.px(HEAD_X + 4, HEAD_Y + 7 + b, skin["d"])               # mouth
        c.px(HEAD_X + 5, HEAD_Y + 7 + b, skin["d"])
        c.px(HEAD_X + 1, HEAD_Y + 6 + b, skin["d"])               # cheek shade
        c.px(HEAD_X + 8, HEAD_Y + 6 + b, skin["d"])
    elif direction == "up":
        _stamp(c, HEAD_BACK, HEAD_X, HEAD_Y + b, {"h": hair["m"]})
        c.hline(HEAD_X + 3, HEAD_Y + 1 + b, 4, hair["l"])
        c.px(HEAD_X + 2, HEAD_Y + 2 + b, hair["l"])
        c.rect(HEAD_X + 2, HEAD_Y + 5 + b, 6, 3, hair["d"])        # nape mass
        c.hline(HEAD_X + 3, HEAD_Y + 8 + b, 4, hair["d"])
    else:
        _stamp(c, HEAD_SIDE, HEAD_X, HEAD_Y + b, {"h": hair["m"], "s": skin["m"]})
        c.hline(HEAD_X + 3, HEAD_Y + 1 + b, 4, hair["l"])
        c.px(HEAD_X + 6, HEAD_Y + 5 + b, PAL["outline"])          # single eye
        c.px(HEAD_X + 6, HEAD_Y + 4 + b, PAL["white"])
        c.px(HEAD_X + 9, HEAD_Y + 6 + b, skin["d"])               # nose/mouth line
        c.vline(HEAD_X + 2, HEAD_Y + 4 + b, 4, hair["d"])         # sideburn

    # ---------------- torso ----------------
    _stamp(c, TORSO, TORSO_X, TORSO_Y + b, {"c": cloth["m"]})
    c.hline(TORSO_X + 1, TORSO_Y + b, 6, cloth["l"])              # shoulder light
    c.px(TORSO_X, TORSO_Y + 1 + b, cloth["l"])
    c.px(TORSO_X + 1, TORSO_Y + 1 + b, cloth["l"])
    c.vline(TORSO_X + 6, TORSO_Y + 1 + b, 5, cloth["d"])          # right shade
    c.hline(TORSO_X + 1, TORSO_Y + 5 + b, 6, cloth["d"])          # waist shade
    if direction == "down":
        c.vline(TORSO_X + 3, TORSO_Y + 1 + b, 4, cloth["d"])      # tunic opening
        c.px(TORSO_X + 4, TORSO_Y + 1 + b, cloth["d"])
        c.px(TORSO_X + 3, TORSO_Y + 4 + b, PAL["gold_m"])         # belt buckle
        c.px(TORSO_X + 4, TORSO_Y + 4 + b, PAL["gold_l"])
    elif direction == "up":
        c.rect(TORSO_X + 2, TORSO_Y + 1 + b, 4, 4, cloth["d"])    # back strap X
        c.px(TORSO_X + 3, TORSO_Y + 2 + b, cloth["m"])
        c.px(TORSO_X + 4, TORSO_Y + 3 + b, cloth["m"])
        c.px(TORSO_X + 4, TORSO_Y + 2 + b, cloth["m"])
        c.px(TORSO_X + 3, TORSO_Y + 3 + b, cloth["m"])
    else:
        c.vline(TORSO_X + 2, TORSO_Y + 1 + b, 4, cloth["d"])
        c.px(TORSO_X + 3, TORSO_Y + 4 + b, PAL["gold_m"])

    # ---------------- arms ----------------
    arm_dy = {"neutral": 0, "back": -1, "forward": 1, "pass": 0}[pose.arm]
    # on attack frames the leading arm is raised / extended
    lead_dy = arm_dy - (2 if pose.attack == 1 else 0) + (1 if pose.attack == 2 else 0)
    for ax, is_lead in ((ARM_L_X, False), (ARM_R_X, True)):
        dy = (lead_dy if is_lead else arm_dy)
        if direction == "left":
            ax = ARM_L_X + 1 if not is_lead else ARM_L_X - 1
        if direction == "up":
            ax = ax  # same columns
        c.rect(ax, TORSO_Y + b + dy, 2, 4, cloth["d"])            # sleeve
        c.px(ax, TORSO_Y + b + dy, cloth["m"])
        c.rect(ax, TORSO_Y + 4 + b + dy, 2, 2, skin["m"])         # hand
        c.px(ax, TORSO_Y + 4 + b + dy, skin["l"])

    # ---------------- legs + feet ----------------
    (ldx, lext), (rdx, rext) = _leg_stride(pose, direction)
    for x0, dx, ext in ((LEG_L_X, ldx, lext), (LEG_R_X, rdx, rext)):
        top = LEG_Y + b
        h = 5 + ext
        c.rect(x0 + dx, top, 3, h, pants["m"])
        c.vline(x0 + dx, top, h, pants["l"])
        c.vline(x0 + dx + 2, top, h, pants["d"])
        c.rect(x0 + dx, top + h - 1, 3, 2, pants["d"])            # foot
        c.hline(x0 + dx, top + h - 1, 3, pants["m"])

    c.outline()
    return c


# ------------------------------------------------------------- equipment ---
# Each piece is drawn from a 3-tone material ramp + an optional trim colour.
# Because pieces fully cover the region they replace, no body pixels bleed
# through the armour (a common paper-doll artefact).

def _ramp(base_key):
    return {"l": PAL[base_key + "_l"], "m": PAL[base_key + "_m"], "d": PAL[base_key + "_d"]}


def _leg_stride(pose, direction):
    """Mirror the exact stride the body uses, so pants/boots stay glued on.

    Returns ((ldx, lext), (rdx, rext)).  ext lengthens/shortens the leg from a
    FIXED hip (so no gap ever opens at the waist); dx slides it for side views.
    """
    lext = rext = 0
    ldx = rdx = 0
    if pose.leg == "left":
        lext, rext = 1, -1
    elif pose.leg == "right":
        lext, rext = -1, 1
    if direction == "left":
        if pose.leg == "left":
            ldx, rdx = -2, 1
        elif pose.leg == "right":
            ldx, rdx = 1, -2
    return (ldx, lext), (rdx, rext)


CHEST_ART = [
    ".cccccc.",
    "cccccccc",
    "cccccccc",
    "cccccccc",
    "cccccccc",
    ".cccccc.",
    "..cccc..",
]


def draw_chest(direction, pose, mat, trim=None):
    c = Canvas(CELL_W, CELL_H)
    r = _ramp(mat)
    b = pose.bob
    _stamp(c, CHEST_ART, TORSO_X, TORSO_Y + b, {"c": r["m"]})
    c.hline(TORSO_X + 1, TORSO_Y + b, 6, r["l"])                  # shoulder light
    c.px(TORSO_X, TORSO_Y + 1 + b, r["l"])
    c.px(TORSO_X + 1, TORSO_Y + 1 + b, r["l"])
    c.vline(TORSO_X + 6, TORSO_Y + 1 + b, 5, r["d"])              # side shade
    c.hline(TORSO_X + 1, TORSO_Y + 5 + b, 6, r["d"])              # waist shade
    if trim:
        t = _ramp(trim)
        c.hline(TORSO_X + 2, TORSO_Y + 4 + b, 4, t["m"])          # belt
        c.px(TORSO_X + 3, TORSO_Y + 4 + b, t["l"])
        c.px(TORSO_X + 4, TORSO_Y + 4 + b, t["l"])
        c.px(TORSO_X + 2, TORSO_Y + 1 + b, t["m"])                # studs
        c.px(TORSO_X + 5, TORSO_Y + 1 + b, t["m"])
    if direction == "down":
        c.vline(TORSO_X + 3, TORSO_Y + 1 + b, 3, r["d"])
        c.px(TORSO_X + 4, TORSO_Y + 1 + b, r["d"])
    elif direction == "up":
        c.rect(TORSO_X + 2, TORSO_Y + 1 + b, 4, 4, r["d"])
        c.px(TORSO_X + 3, TORSO_Y + 2 + b, r["m"]); c.px(TORSO_X + 4, TORSO_Y + 3 + b, r["m"])
        c.px(TORSO_X + 4, TORSO_Y + 2 + b, r["m"]); c.px(TORSO_X + 3, TORSO_Y + 3 + b, r["m"])
    else:
        c.vline(TORSO_X + 2, TORSO_Y + 1 + b, 4, r["d"])
    # pauldrons follow the arm swing
    arm_dy = {"neutral": 0, "back": -1, "forward": 1, "pass": 0}[pose.arm]
    for ax in (ARM_L_X, ARM_R_X):
        if direction == "left":
            ax = ARM_L_X
        c.rect(ax, TORSO_Y + b + arm_dy, 2, 3, r["m"])
        c.px(ax, TORSO_Y + b + arm_dy, r["l"])
        c.px(ax + 1, TORSO_Y + 2 + b + arm_dy, r["d"])
    c.outline()
    return c


def draw_helmet(direction, pose, mat, style, trim=None):
    c = Canvas(CELL_W, CELL_H)
    r = _ramp(mat)
    b = pose.bob
    hx, hy = HEAD_X, HEAD_Y + b

    if style == "cap":
        art = ["...mmmm...", "..mmmmmm..", ".mmmmmmmm.", "mmmmmmmmmm", "mm......mm"]
        _stamp(c, art, hx, hy, {"m": r["m"]})
        c.hline(hx + 3, hy, 4, r["l"])
        c.px(hx + 2, hy + 1, r["l"])
        c.hline(hx, hy + 3, 10, r["d"])                            # brim
    elif style == "helm":
        art = ["...mmmm...", "..mmmmmm..", ".mmmmmmmm.", "mmmmmmmmmm",
               "mmmmmmmmmm", "mm.dddd.mm", "mm......mm"]
        _stamp(c, art, hx, hy, {"m": r["m"], "d": r["d"]})
        c.hline(hx + 3, hy, 4, r["l"])
        c.px(hx + 2, hy + 1, r["l"]); c.px(hx + 2, hy + 2, r["l"])
        c.vline(hx + 8, hy + 1, 5, r["d"])
        if direction == "down":
            c.hline(hx + 3, hy + 5, 4, PAL["black"])              # visor slit
            c.px(hx + 3, hy + 5, PAL["red_m"]); c.px(hx + 6, hy + 5, PAL["red_m"])
            c.vline(hx + 4, hy + 3, 3, r["l"])                    # nasal bar
        elif direction == "up":
            c.rect(hx + 2, hy + 2, 6, 4, r["d"])
            c.vline(hx + 4, hy + 1, 5, r["m"])
        if trim:
            t = _ramp(trim)
            c.rect(hx + 4, hy - 4, 2, 4, t["m"])                  # crest
            c.px(hx + 4, hy - 4, t["l"]); c.px(hx + 5, hy - 4, t["l"])
            c.px(hx + 4, hy - 3, t["l"])
    elif style == "hat":
        art = [
            ".....mm.....",
            "....mmmm....",
            "....mmmm....",
            "...mmmmmm...",
            "...mmmmmm...",
            "..mmmmmmmm..",
            "..mmmmmmmm..",
            ".mmmmmmmmmm.",
            "mmmmmmmmmmmm",
            "mmmmmmmmmmmm",
        ]
        _stamp(c, art, hx - 1, hy - 4, {"m": r["m"]})
        c.vline(hx + 4, hy - 4, 3, r["l"])
        c.hline(hx + 1, hy + 3, 6, r["l"])
        c.hline(hx - 1, hy + 5, 12, r["d"])                       # brim underside
        if trim:
            t = _ramp(trim)
            c.hline(hx - 1, hy + 4, 12, t["m"])
            c.px(hx + 3, hy + 4, t["l"]); c.px(hx + 4, hy + 4, t["l"])
    elif style == "hood":
        art = ["...mmmm...", "..mmmmmm..", ".mmmmmmmm.", "mmmmmmmmmm",
               "mm.dddd.mm", ".m.dddd.m.", "..dddddd.."]
        _stamp(c, art, hx, hy, {"m": r["m"], "d": r["d"]})
        c.hline(hx + 3, hy, 4, r["l"])
        if direction != "up":
            c.rect(hx + 2, hy + 4, 6, 3, PAL["black"])            # face in shadow
            c.px(hx + 3, hy + 5, PAL["ember"])
            c.px(hx + 6, hy + 5, PAL["ember"])
    c.outline()
    return c


def draw_legs(direction, pose, mat):
    c = Canvas(CELL_W, CELL_H)
    r = _ramp(mat)
    b = pose.bob
    (ldx, lext), (rdx, rext) = _leg_stride(pose, direction)
    for x0, dx, ext in ((LEG_L_X, ldx, lext), (LEG_R_X, rdx, rext)):
        top = LEG_Y + b
        h = 5 + ext
        c.rect(x0 + dx, top, 3, h, r["m"])
        c.vline(x0 + dx, top, h, r["l"])
        c.vline(x0 + dx + 2, top, h, r["d"])
        c.hline(x0 + dx, top + h - 1, 3, r["d"])                  # cuff
    c.outline()
    return c


def draw_boots(direction, pose, mat):
    c = Canvas(CELL_W, CELL_H)
    r = _ramp(mat)
    b = pose.bob
    (ldx, lext), (rdx, rext) = _leg_stride(pose, direction)
    for x0, dx, ext in ((LEG_L_X, ldx, lext), (LEG_R_X, rdx, rext)):
        top = LEG_Y + b
        h = 5 + ext
        c.rect(x0 + dx, top + h - 3, 3, 2, r["m"])                # ankle
        c.hline(x0 + dx, top + h - 3, 3, r["l"])
        c.rect(x0 + dx, top + h - 1, 3, 2, r["d"])                # sole
        c.px(x0 + dx, top + h - 1, r["m"])
    c.outline()
    return c


def _hand(direction, pose):
    """Leading-hand grip point; weapon is anchored here so it never floats."""
    b = pose.bob
    arm_dy = {"neutral": 0, "back": -1, "forward": 1, "pass": 0}[pose.arm]
    lead_dy = arm_dy - (2 if pose.attack == 1 else 0) + (1 if pose.attack == 2 else 0)
    hy = TORSO_Y + 4 + b + lead_dy
    if direction == "down":
        return ARM_R_X, hy
    if direction == "up":
        return ARM_L_X, hy
    return ARM_L_X - 1, hy


def draw_weapon(direction, pose, kind, mat):
    c = Canvas(CELL_W, CELL_H)
    r = _ramp(mat)
    hx, hy = _hand(direction, pose)
    wood = PAL["leath_m"]
    wood_d = PAL["leath_d"]
    swing = pose.attack

    if kind in ("sword", "dagger"):
        length = 11 if kind == "sword" else 7
        if swing == 2:
            c.hline(hx - 2, hy - 1, length + 2, r["m"])
            c.hline(hx - 2, hy - 2, length + 2, r["l"])
            c.hline(hx - 2, hy, length + 2, r["d"])
            c.px(hx + length - 1, hy - 1, PAL["white"])
            c.vline(hx - 3, hy - 3, 5, wood_d)
        else:
            top = hy - length + (1 if swing == 1 else 0)
            c.vline(hx, top, length, r["m"])
            c.vline(hx + 1, top + 1, length - 1, r["l"])
            c.px(hx, top, PAL["white"])
            c.hline(hx - 2, hy, 4, wood_d)                        # crossguard
        c.rect(hx, hy, 2, 3, wood)                                # grip in hand
        c.px(hx, hy + 3, PAL["gold_m"])
    elif kind == "axe":
        if swing == 2:
            c.hline(hx - 2, hy - 1, 12, wood)
            head = [".mmm", "mmmm", "mmmm", ".mmm"]
            _stamp(c, head, hx + 7, hy - 3, {"m": r["m"]})
            c.hline(hx + 8, hy - 3, 2, r["l"])
        else:
            top = hy - 11 + (1 if swing == 1 else 0)
            c.vline(hx, top, 14, wood)
            c.vline(hx + 1, top, 14, wood_d)
            head = [".mmm", "mmmm", "mmmm", ".mmm"]
            _stamp(c, head, hx + 1, top + 1, {"m": r["m"]})
            c.hline(hx + 2, top + 1, 2, r["l"])
            c.vline(hx + 4, top + 1, 4, r["d"])
    elif kind == "staff":
        top = hy - 14 + (1 if swing == 1 else 0)
        c.vline(hx, top, 18, wood)
        c.vline(hx + 1, top, 18, wood_d)
        c.rect(hx - 1, top - 3, 4, 4, PAL["purple_m"])
        c.px(hx - 1, top - 3, PAL["purple_l"]); c.px(hx, top - 3, PAL["purple_l"])
        c.px(hx + 2, top, PAL["purple_d"])
        c.px(hx, top - 1, PAL["ember"])
    elif kind == "bow":
        import math
        top = hy - 8
        for i in range(13):
            t = i / 12.0
            ox = int(round(math.sin(t * math.pi) * 3))
            c.px(hx + ox, top + i, wood)
            c.px(hx + ox + 1, top + i, wood_d)
        c.vline(hx, top + 1, 11, PAL["white"])
    c.outline()
    return c


def draw_accessory(direction, pose, style, mat):
    """Cloaks sit BEHIND the body in the paper-doll stack, so from the front
    only the edges + collar show, and from behind it fully covers the back."""
    c = Canvas(CELL_W, CELL_H)
    r = _ramp(mat)
    b = pose.bob
    top = TORSO_Y - 1 + b
    if style == "cloak":
        if direction == "up":
            art = [
                ".mmmmmmmm.",
                "mmmmmmmmmm",
                "mmmmmmmmmm",
                "mmmmmmmmmm",
                "mmmmmmmmmm",
                "mmmmmmmmmm",
                ".mmmmmmmm.",
                ".mmm..mmm.",
                "..mm..mm..",
            ]
            _stamp(c, art, TORSO_X - 1, top, {"m": r["m"]})
            c.vline(TORSO_X - 1, top + 1, 6, r["l"])
            c.vline(TORSO_X + 8, top + 1, 6, r["d"])
            c.hline(TORSO_X, top + 8, 6, r["d"])
        elif direction == "down":
            for x in (ARM_L_X - 1, ARM_R_X + 2):
                c.rect(x, top, 2, 9, r["m"])
                c.vline(x, top, 9, r["l"] if x < 12 else r["d"])
            c.hline(TORSO_X, top, 8, r["m"])                      # collar
            c.hline(TORSO_X + 1, top, 6, r["l"])
        else:
            x0 = TORSO_X + 6                                     # trails behind
            c.rect(x0, top, 4, 10, r["m"])
            c.vline(x0, top, 10, r["l"])
            c.vline(x0 + 3, top, 10, r["d"])
            c.rect(x0 + 1, top + 8, 3, 2, r["d"])
            c.hline(TORSO_X, top, 8, r["m"])                      # collar
        # clasp
        c.px(TORSO_X + 2, top, PAL["gold_m"])
        c.px(TORSO_X + 5, top, PAL["gold_m"])
    c.outline()
    return c


# ------------------------------------------------------------------ sheet ---
def build_sheet(draw_fn, mirror_left_for_right=True):
    """Compose a 4x8 sheet from a per-(direction,pose) draw callback."""
    sheet = Canvas(COLS * CELL_W, ROWS * CELL_H)
    for row, d in enumerate(DIRS):
        for col in range(COLS):
            pose = frame_pose(col)
            src_dir = d
            if d == "right" and mirror_left_for_right:
                src_dir = "left"
            cell = draw_fn(src_dir, pose)
            if d == "right" and mirror_left_for_right:
                cell = mirror_canvas(cell, CELL_W)
            for (x, y), cc in cell.buf.items():
                sheet.px(col * CELL_W + x, row * CELL_H + y, cc)
    return sheet


def save(canvas, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    canvas.to_image().save(path)
    print("  wrote", rel, f"({canvas.w}x{canvas.h})")


# ------------------------------------------------------------------ tiles ---
TILE = 16
TILE_COLS = 8

TILE_DEFS = [
    # (name, base, speckle, speckle2)
    ("grass",    "leaf_m", "leaf_d", "leaf_l"),
    ("grass2",   "leaf_m", "leaf_l", "leaf_d"),
    ("sand",     "gold_m", "gold_d", "gold_l"),
    ("sand2",    "gold_m", "gold_l", "gold_d"),
    ("snow",     "snow_m", "snow_d", "snow_l"),
    ("swamp",    "leaf_d", "dirt_d", "leaf_m"),
    ("stone",    "stone_m", "stone_d", "stone_l"),
    ("water",    "water_m", "water_d", "water_l"),
    ("dirt",     "dirt_m", "dirt_d", "dirt_l"),
    ("cobble",   "stone_m", "stone_l", "stone_d"),
    ("wood",     "leath_m", "leath_l", "leath_d"),
    ("cave",     "stone_d", "black", "stone_m"),
    ("roof",     "red_m", "red_d", "red_l"),
]


def _noise(x, y, seed=1):
    """Deterministic tiny hash -> 0..1. Keeps tiles stable across runs."""
    n = (x * 374761393 + y * 668265263 + seed * 1442695040888963407) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n & 0xFFFF) / 65535.0


def _tile_base(idx):
    return TILE_DEFS[idx][1]


def _detail(name, x, y, r, c, bc):
    """Per-biome structural detail. Kept LOW-contrast and SPARSE on purpose:
    heavy speckle is what made the first pass look like TV static."""
    if name in ("grass", "grass2"):
        if r > 0.90:
            c.px(x, y, PAL["leaf_d"])
            c.px(x, y - 1, PAL["leaf_d"])
        elif r < 0.06:
            c.px(x, y, PAL["leaf_l"])
    elif name == "roof":
        # overlapping shingle rows
        if y % 4 == 3:
            c.px(x, y, darken(bc, 0.82))
        elif (x + (y // 4) % 2) % 4 == 0:
            c.px(x, y, PAL["red_l"])
    elif name in ("sand", "sand2"):
        if (y % 4 == 2) and (x + y // 4) % 6 < 3:
            c.px(x, y, darken(bc, 0.94))
        elif r > 0.94:
            c.px(x, y, PAL["gold_l"])
    elif name == "snow":
        if r > 0.93:
            c.px(x, y, PAL["snow_l"])
        elif r < 0.05:
            c.px(x, y, PAL["snow_d"])
    elif name == "swamp":
        if 4 <= y <= 7 and 3 <= x <= 11 and ((x + y) % 3):
            c.px(x, y, PAL["water_d"])
        elif r > 0.9:
            c.px(x, y, PAL["leaf_m"])
    elif name == "stone":
        if _noise(x // 4, y // 4, 31) > 0.62 and (x % 4 == 0 or y % 4 == 0):
            c.px(x, y, PAL["stone_d"])
        elif r > 0.94:
            c.px(x, y, PAL["stone_l"])
        elif r < 0.04:
            c.px(x, y, darken(bc, 0.93))
    elif name == "water":
        if y in (3, 9) and (x + (y // 6)) % 8 < 4:
            c.px(x, y, PAL["water_l"])
        elif y in (6, 13) and (x + 3) % 8 < 3:
            c.px(x, y, PAL["water_d"])
    elif name == "dirt":
        if r > 0.9:
            c.px(x, y, PAL["dirt_d"])
        elif r < 0.07:
            c.px(x, y, PAL["dirt_l"])
    elif name == "cobble":
        # irregular flagstones: offset every other row, thin dark mortar
        sx = (x + (4 if y % 8 >= 4 else 0)) % 8
        sy = y % 8
        if sx == 0 or sy == 0:
            c.px(x, y, darken(bc, 0.86))
        elif sy == 1:
            c.px(x, y, lighten(bc, 1.08))
        else:
            c.px(x, y, bc)
    elif name == "wood":
        if x % 4 == 0:
            c.px(x, y, PAL["leath_d"])
        elif x % 4 == 1:
            c.px(x, y, PAL["leath_l"])
        elif r > 0.95:
            c.px(x, y, PAL["leath_d"])
    elif name == "cave":
        if _noise(x // 3, y // 3, 47) > 0.8 and (x % 3 == 0 or y % 3 == 0):
            c.px(x, y, PAL["black"])
        elif r > 0.94:
            c.px(x, y, PAL["stone_m"])


def make_tileset():
    n = len(TILE_DEFS)
    rows = (n + TILE_COLS - 1) // TILE_COLS
    sheet = Canvas(TILE_COLS * TILE, rows * TILE)
    for idx, (name, base, _s1, _s2) in enumerate(TILE_DEFS):
        bx, by = (idx % TILE_COLS) * TILE, (idx // TILE_COLS) * TILE
        bc = PAL[base]
        c = Canvas(TILE, TILE)
        c.rect(0, 0, TILE, TILE, bc)
        for y in range(TILE):
            for x in range(TILE):
                _detail(name, x, y, _noise(x, y, idx + 1), c, bc)
        for (x, y), col in c.buf.items():
            sheet.px(bx + x, by + y, col)
    return sheet, [d[0] for d in TILE_DEFS]


def make_props():
    """Overlay props drawn on top of terrain."""
    names = ["tree", "rock", "bush", "flower", "chest", "stairs", "sign", "torch",
             "tomb", "fence", "well"]
    sheet = Canvas(len(names) * TILE, TILE)
    for i, name in enumerate(names):
        ox = i * TILE
        c = Canvas(TILE, TILE)
        if name == "tree":
            # trunk
            c.rect(7, 10, 2, 6, PAL["leath_d"])
            c.vline(7, 10, 6, PAL["leath_m"])
            c.px(6, 15, PAL["leath_d"]); c.px(9, 15, PAL["leath_d"])
            # layered canopy, widest at the bottom
            for row, (w, col) in enumerate([
                (6, PAL["leaf_m"]), (8, PAL["leaf_m"]), (10, PAL["leaf_m"]),
                (12, PAL["leaf_m"]), (12, PAL["leaf_d"]), (10, PAL["leaf_d"]),
                (8, PAL["leaf_d"]), (4, PAL["leaf_d"])]):
                x0 = 8 - w // 2
                c.hline(x0, 1 + row, w, col)
            c.hline(5, 2, 5, PAL["leaf_l"])                       # lit crown
            c.px(4, 3, PAL["leaf_l"]); c.px(6, 1, PAL["leaf_l"])
            c.hline(3, 5, 3, PAL["leaf_d"])                       # shade side
            c.px(11, 4, PAL["leaf_d"])
        elif name == "rock":
            art = ["....ss....",
                   "...ssss...",
                   "..ssssss..",
                   ".ssssssss.",
                   "ssssssssss",
                   "ssssssssss",
                   ".ssssssss.",
                   "..ssssss.."]
            _stamp(c, art, 3, 6, {"s": PAL["stone_m"]})
            c.hline(6, 7, 4, PAL["stone_l"])
            c.px(5, 8, PAL["stone_l"]); c.px(6, 8, PAL["stone_l"])
            c.hline(5, 12, 7, PAL["stone_d"])
            c.px(9, 10, PAL["stone_d"]); c.px(10, 9, PAL["stone_d"])
        elif name == "bush":
            art = ["..bbb..",
                   ".bbbbb.",
                   "bbbbbbb",
                   "bbbbbbb",
                   ".bbbbb.",
                   "..bbb.."]
            _stamp(c, art, 4, 8, {"b": PAL["leaf_d"]})
            c.hline(6, 9, 4, PAL["leaf_m"])
            c.px(5, 10, PAL["leaf_m"]); c.px(9, 11, PAL["leaf_m"])
            c.px(6, 11, PAL["red_m"]); c.px(10, 10, PAL["red_m"])
            c.px(8, 12, PAL["red_m"])
        elif name == "flower":
            c.vline(8, 10, 5, PAL["leaf_d"])
            c.px(6, 12, PAL["leaf_m"]); c.px(10, 13, PAL["leaf_m"])
            c.px(7, 13, PAL["leaf_m"])
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                c.px(8 + dx, 9 + dy, PAL["white"])
            c.px(8, 9, PAL["gold_l"])
        elif name == "chest":
            c.rect(2, 7, 12, 8, PAL["leath_m"])
            c.rect(2, 7, 12, 3, PAL["leath_l"])
            c.hline(2, 10, 12, PAL["leath_d"])
            c.hline(2, 14, 12, PAL["leath_d"])
            c.rect(7, 9, 2, 4, PAL["gold_m"])
            c.px(7, 11, PAL["gold_d"]); c.px(8, 11, PAL["gold_d"])
            c.vline(2, 7, 8, PAL["leath_d"]); c.vline(13, 7, 8, PAL["leath_d"])
            c.px(3, 8, PAL["leath_l"]); c.px(4, 8, PAL["leath_l"])
        elif name == "stairs":
            # descending steps, 4 treads
            for srow in range(4):
                y0 = 2 + srow * 3
                w = 14 - srow * 2
                x0 = 8 - w // 2
                c.rect(x0, y0, w, 1, PAL["stone_l"])              # tread highlight
                c.rect(x0, y0 + 1, w, 2, PAL["stone_m"])          # riser
                c.hline(x0, y0 + 2, w, PAL["stone_d"])
        elif name == "sign":
            c.rect(7, 9, 2, 6, PAL["leath_d"])
            c.vline(7, 9, 6, PAL["leath_m"])
            c.rect(3, 3, 10, 6, PAL["leath_m"])
            c.hline(3, 3, 10, PAL["leath_l"])
            c.hline(3, 8, 10, PAL["leath_d"])
            c.vline(3, 3, 6, PAL["leath_l"]); c.vline(12, 3, 6, PAL["leath_d"])
            c.hline(5, 5, 6, PAL["leath_d"]); c.hline(5, 7, 4, PAL["leath_d"])
        elif name == "torch":
            c.rect(7, 8, 2, 7, PAL["leath_d"])
            c.vline(7, 8, 7, PAL["leath_m"])
            c.rect(6, 9, 4, 1, PAL["stone_d"])
            c.rect(6, 3, 4, 5, PAL["ember"])
            c.rect(7, 2, 2, 3, PAL["gold_l"])
            c.px(7, 4, PAL["white"]); c.px(8, 3, PAL["white"])
        elif name == "tomb":
            # rounded headstone with a carved cross, cracked base
            _stamp(c, ["..ssss..", ".ssssss.", ".ssssss.", ".ss.sss.", ".ssssss.", ".ssssss."],
                   4, 5, {"s": PAL["stone_m"]})
            c.hline(6, 5, 4, PAL["stone_l"])
            c.vline(5, 6, 5, PAL["stone_d"]); c.vline(10, 6, 5, PAL["stone_d"])
            c.vline(8, 7, 3, PAL["stone_d"]); c.hline(7, 8, 3, PAL["stone_d"])
            c.rect(3, 11, 10, 3, PAL["stone_d"])
            c.hline(3, 11, 10, PAL["stone_m"])
            c.px(4, 12, PAL["stone_l"]); c.px(11, 13, PAL["black"])
        elif name == "fence":
            c.vline(3, 6, 9, PAL["leath_m"]); c.vline(4, 6, 9, PAL["leath_d"])
            c.vline(11, 6, 9, PAL["leath_m"]); c.vline(12, 6, 9, PAL["leath_d"])
            c.hline(3, 8, 10, PAL["leath_m"]); c.hline(3, 9, 10, PAL["leath_d"])
            c.hline(3, 12, 10, PAL["leath_m"]); c.hline(3, 13, 10, PAL["leath_d"])
            c.px(3, 5, PAL["leath_l"]); c.px(11, 5, PAL["leath_l"])
        elif name == "well":
            c.rect(4, 9, 8, 5, PAL["stone_m"])
            c.hline(4, 9, 8, PAL["stone_l"]); c.hline(4, 13, 8, PAL["stone_d"])
            c.px(5, 11, PAL["stone_d"]); c.px(9, 10, PAL["stone_d"])
            c.rect(5, 8, 6, 1, PAL["black"])
            c.vline(4, 3, 6, PAL["leath_d"]); c.vline(11, 3, 6, PAL["leath_d"])
            c.hline(4, 3, 8, PAL["leath_m"])
            c.rect(6, 4, 4, 3, PAL["leath_m"])
            c.hline(6, 4, 4, PAL["leath_l"])
        for (x, y), col in c.buf.items():
            sheet.px(ox + x, y, col)
    return sheet, names


# ----------------------------------------------------------------- enemies ---
def enemy_slime(mat="leaf"):
    r = _ramp(mat)
    frames = []
    for f in range(4):
        c = Canvas(24, 24)
        squash = [0, -1, 0, 1][f]
        w = [14, 16, 14, 12][f]
        h = [10, 9, 10, 11][f]
        x0 = 12 - w // 2
        y0 = 20 - h
        for y in range(h):
            ww = w - (1 if y < 2 or y > h - 3 else 0)
            c.rect(x0 + (w - ww) // 2, y0 + y, ww, 1, r["m"])
        c.rect(x0 + 2, y0 + 1, w - 6, 2, r["l"])
        c.hline(x0 + 1, y0 + h - 2, w - 2, r["d"])
        c.px(x0 + w // 2 - 3, y0 + 4, PAL["black"])
        c.px(x0 + w // 2 + 2, y0 + 4, PAL["black"])
        c.px(x0 + w // 2 - 3, y0 + 3, PAL["white"])
        c.outline()
        frames.append(c)
    return frames


def enemy_humanoid(mat_cloth, mat_skin, horns=False, skeleton=False, size=1.0):
    frames = []
    r = _ramp(mat_cloth)
    s = _ramp(mat_skin)
    for f in range(4):
        c = Canvas(24, 24)
        bob = [0, -1, 0, -1][f]
        # head
        c.rect(8, 4 + bob, 8, 7, s["m"] if not skeleton else PAL["white"])
        c.hline(9, 4 + bob, 6, s["l"] if not skeleton else PAL["white"])
        # eyes
        if skeleton:
            c.rect(9, 7 + bob, 2, 2, PAL["black"])
            c.rect(13, 7 + bob, 2, 2, PAL["black"])
            c.px(9, 7 + bob, PAL["red_m"]); c.px(13, 7 + bob, PAL["red_m"])
            c.hline(10, 10 + bob, 4, PAL["stone_d"])
        else:
            c.px(9, 7 + bob, PAL["red_m"]); c.px(14, 7 + bob, PAL["red_m"])
            c.px(9, 6 + bob, PAL["black"]); c.px(14, 6 + bob, PAL["black"])
        # torso
        c.rect(7, 11 + bob, 10, 7, r["m"])
        c.hline(7, 11 + bob, 10, r["l"])
        c.hline(7, 17 + bob, 10, r["d"])
        # arms
        ady = [0, 1, 0, -1][f]
        c.rect(4, 12 + bob + ady, 3, 5, s["m"] if not skeleton else PAL["white"])
        c.rect(17, 12 + bob - ady, 3, 5, s["m"] if not skeleton else PAL["white"])
        # legs
        ldy = [1, 0, -1, 0][f]
        c.rect(8, 18 + bob, 3, 4 + ldy, r["d"])
        c.rect(13, 18 + bob, 3, 4 - ldy, r["d"])
        if horns:
            c.px(7, 3 + bob, PAL["bone"] if "bone" in PAL else PAL["white"])
            c.px(16, 3 + bob, PAL["white"])
            c.px(7, 2 + bob, PAL["white"]); c.px(16, 2 + bob, PAL["white"])
        c.outline()
        frames.append(c)
    return frames


def enemy_dragon():
    frames = []
    for f in range(4):
        c = Canvas(32, 32)
        flap = [0, -2, 0, 2][f]
        r = _ramp("red")
        # wings
        c.rect(2, 8 + flap, 8, 10, r["d"])
        c.rect(22, 8 + flap, 8, 10, r["d"])
        c.hline(2, 8 + flap, 8, r["m"])
        c.hline(22, 8 + flap, 8, r["m"])
        # body
        c.rect(10, 10, 12, 14, r["m"])
        c.hline(11, 11, 10, r["l"])
        c.rect(12, 20, 8, 4, PAL["gold_d"])
        # head
        c.rect(12, 4, 8, 7, r["m"])
        c.hline(13, 4, 6, r["l"])
        c.px(13, 7, PAL["ember"]); c.px(18, 7, PAL["ember"])
        c.px(13, 6, PAL["black"]); c.px(18, 6, PAL["black"])
        # horns
        c.px(11, 2, PAL["white"]); c.px(20, 2, PAL["white"])
        c.px(11, 3, PAL["white"]); c.px(20, 3, PAL["white"])
        # tail
        c.rect(14, 24, 4, 3, r["d"])
        c.px(15, 27, r["d"])
        c.outline()
        frames.append(c)
    return frames


def build_enemy_sheet(frames, cols=4):
    w = max(f.w for f in frames)
    h = max(f.h for f in frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Canvas(cols * w, rows * h)
    for i, f in enumerate(frames):
        ox, oy = (i % cols) * w, (i // cols) * h
        for (x, y), cc in f.buf.items():
            sheet.px(ox + x, oy + y + (h - f.h), cc)
    return sheet, w, h


# ------------------------------------------------------------------- icons ---
def item_icon(kind, mat, trim=None):
    c = Canvas(16, 16)
    r = _ramp(mat)
    t = _ramp(trim) if trim else None
    if kind == "sword":
        for i in range(9):
            c.px(4 + i, 11 - i, r["m"])
            c.px(5 + i, 11 - i, r["l"])
            c.px(4 + i, 12 - i, r["d"])
        c.hline(3, 11, 5, PAL["leath_d"])
        c.vline(4, 11, 4, PAL["leath_m"])
        c.px(5, 14, PAL["gold_m"])
    elif kind == "axe":
        c.vline(7, 3, 11, PAL["leath_m"])
        c.vline(8, 3, 11, PAL["leath_d"])
        _stamp(c, [".mmm", "mmmm", "mmmm", ".mmm"], 8, 3, {"m": r["m"]})
        c.hline(9, 3, 2, r["l"])
    elif kind == "staff":
        c.vline(7, 4, 11, PAL["leath_m"])
        c.rect(5, 1, 5, 4, PAL["purple_m"])
        c.px(5, 1, PAL["purple_l"]); c.px(6, 1, PAL["purple_l"])
        c.px(7, 3, PAL["ember"])
    elif kind == "bow":
        import math
        for i in range(12):
            tt = i / 11.0
            ox = int(round(math.sin(tt * math.pi) * 4))
            c.px(5 + ox, 2 + i, PAL["leath_m"])
        c.vline(5, 3, 10, PAL["white"])
    elif kind == "potion":
        # corked flask with glowing liquid; trim = gold band for greater brews
        c.px(7, 2, PAL["leath_m"]); c.px(8, 2, PAL["leath_m"])
        c.vline(7, 3, 2, PAL["white"]); c.vline(8, 3, 2, PAL["white"])
        _stamp(c, [".mmmm.", "mmmmmm", "mmmmmm", "mmmmmm", ".mmmm."], 5, 6,
               {"m": r["m"]})
        c.px(6, 7, r["l"]); c.px(7, 7, r["l"]); c.px(6, 8, r["l"])
        c.hline(5, 11, 6, r["d"])
        if t:
            c.hline(6, 5, 4, t["m"])
    elif kind == "helm":
        _stamp(c, ["..mmmm..", ".mmmmmm.", "mmmmmmmm", "mmmmmmmm", "m.dddd.m", "mm....mm"],
               4, 4, {"m": r["m"], "d": r["d"]})
        c.hline(6, 4, 4, r["l"])
    elif kind == "hat":
        _stamp(c, ["....mm....", "...mmmm...", "..mmmmmm..", ".mmmmmmmm.", "mmmmmmmmmm"],
               3, 5, {"m": r["m"]})
        if t:
            c.hline(3, 8, 10, t["m"])
    elif kind == "hood":
        _stamp(c, ["..mmmm..", ".mmmmmm.", "mmmmmmmm", "mmddddmm", ".dddddd."],
               4, 4, {"m": r["m"], "d": r["d"]})
    elif kind == "chest":
        _stamp(c, [".mmmmmm.", "mmmmmmmm", "mmmmmmmm", "mmmmmmmm", "mmmmmmmm", ".mmmmmm.", "..mmmm.."],
               4, 4, {"m": r["m"]})
        c.hline(5, 4, 6, r["l"])
        c.vline(10, 5, 6, r["d"])
        if t:
            c.hline(5, 8, 6, t["m"])
    elif kind == "legs":
        _stamp(c, ["mm..mm", "mm..mm", "mm..mm", "mm..mm", "mm..mm"], 5, 5, {"m": r["m"]})
        c.vline(5, 5, 5, r["l"]); c.vline(10, 5, 5, r["d"])
    elif kind == "boots":
        _stamp(c, ["mm.mm", "mm.mm", "mm.mm", "mmmmm", "mmmmm"], 5, 6, {"m": r["m"]})
        c.hline(5, 10, 5, r["l"]); c.hline(5, 11, 5, r["d"])
    elif kind == "cloak":
        _stamp(c, [".mmmmmm.", "mmmmmmmm", "mmmmmmmm", "mmmmmmmm", ".mmmmmm.", ".mm..mm."],
               4, 4, {"m": r["m"]})
        c.vline(4, 5, 5, r["l"]); c.vline(11, 5, 5, r["d"])
        c.px(7, 4, PAL["gold_m"]); c.px(8, 4, PAL["gold_l"])
    c.outline()
    return c


def build_icon_sheet(specs):
    cols = 8
    rows = (len(specs) + cols - 1) // cols
    sheet = Canvas(cols * 16, rows * 16)
    for i, (name, kind, mat, trim) in enumerate(specs):
        ic = item_icon(kind, mat, trim)
        ox, oy = (i % cols) * 16, (i // cols) * 16
        for (x, y), cc in ic.buf.items():
            sheet.px(ox + x, oy + y, cc)
    return sheet, [s[0] for s in specs]


# ------------------------------------------------------------------- main ---
def main():
    print("Generating pixel-art assets ->", OUT)

    # --- hero body -----------------------------------------------------
    print("[hero]")
    save(build_sheet(draw_hero_body), "hero/body.png")

    # --- equipment layers ---------------------------------------------
    # (id, slot, draw-callable)
    print("[equipment]")
    equip = {
        "chest": [
            ("tunic_cloth",   lambda d, p: draw_chest(d, p, "cloth")),
            ("leather_vest",  lambda d, p: draw_chest(d, p, "leath", "gold")),
            ("iron_plate",    lambda d, p: draw_chest(d, p, "metal", "metal")),
            ("royal_plate",   lambda d, p: draw_chest(d, p, "metal", "gold")),
            ("mage_robe",     lambda d, p: draw_chest(d, p, "purple", "gold")),
        ],
        "helmet": [
            ("leather_cap",   lambda d, p: draw_helmet(d, p, "leath", "cap")),
            ("iron_helm",     lambda d, p: draw_helmet(d, p, "metal", "helm", "red")),
            ("golden_crown",  lambda d, p: draw_helmet(d, p, "gold", "helm", "gold")),
            ("wizard_hat",    lambda d, p: draw_helmet(d, p, "purple", "hat", "gold")),
            ("shadow_hood",   lambda d, p: draw_helmet(d, p, "cloth", "hood")),
        ],
        "legs": [
            ("cloth_pants",   lambda d, p: draw_legs(d, p, "cloth")),
            ("leather_pants", lambda d, p: draw_legs(d, p, "leath")),
            ("iron_greaves",  lambda d, p: draw_legs(d, p, "metal")),
        ],
        "boots": [
            ("cloth_shoes",   lambda d, p: draw_boots(d, p, "cloth")),
            ("leather_boots", lambda d, p: draw_boots(d, p, "leath")),
            ("iron_boots",    lambda d, p: draw_boots(d, p, "metal")),
        ],
        "weapon": [
            ("iron_sword",    lambda d, p: draw_weapon(d, p, "sword", "metal")),
            ("steel_blade",   lambda d, p: draw_weapon(d, p, "sword", "stone")),
            ("golden_sword",  lambda d, p: draw_weapon(d, p, "sword", "gold")),
            ("rusty_dagger",  lambda d, p: draw_weapon(d, p, "dagger", "metal")),
            ("battle_axe",    lambda d, p: draw_weapon(d, p, "axe", "metal")),
            ("oak_staff",     lambda d, p: draw_weapon(d, p, "staff", "leath")),
            ("hunter_bow",    lambda d, p: draw_weapon(d, p, "bow", "leath")),
        ],
        "accessory": [
            ("red_cloak",     lambda d, p: draw_accessory(d, p, "cloak", "red")),
            ("royal_cloak",   lambda d, p: draw_accessory(d, p, "cloak", "purple")),
            ("forest_cloak",  lambda d, p: draw_accessory(d, p, "cloak", "leaf")),
        ],
    }
    equip_index = {}
    for slot, items in equip.items():
        for name, fn in items:
            save(build_sheet(fn), f"equipment/{slot}/{name}.png")
            equip_index.setdefault(slot, []).append(name)

    # --- tiles ---------------------------------------------------------
    print("[tiles]")
    ts, ts_names = make_tileset()
    save(ts, "tiles/terrain.png")
    props, prop_names = make_props()
    save(props, "tiles/props.png")

    # --- enemies -------------------------------------------------------
    print("[enemies]")
    enemy_specs = [
        ("slime",    enemy_slime("leaf"), 24, 24),
        ("bat",      enemy_slime("purple"), 24, 24),
        ("goblin",   enemy_humanoid("leaf", "leaf"), 24, 24),
        ("skeleton", enemy_humanoid("stone", "stone", skeleton=True), 24, 24),
        ("orc",      enemy_humanoid("red", "leath", horns=True), 24, 24),
        ("demon",    enemy_humanoid("purple", "red", horns=True), 24, 24),
        ("dragon",   enemy_dragon(), 32, 32),
    ]
    enemy_index = {}
    for name, frames, fw, fh in enemy_specs:
        sh, w, h = build_enemy_sheet(frames)
        save(sh, f"enemies/{name}.png")
        enemy_index[name] = {"w": w, "h": h, "frames": len(frames), "cols": 4}

    # --- item icons ----------------------------------------------------
    print("[icons]")
    icon_specs = []
    for name, _ in equip["weapon"]:
        kind = ("sword" if "sword" in name or "blade" in name else
                "axe" if "axe" in name else
                "staff" if "staff" in name else
                "bow" if "bow" in name else "sword")
        mat = ("gold" if "golden" in name else "stone" if "steel" in name else
               "metal" if "iron" in name else "leath")
        icon_specs.append((name, kind, mat, None))
    for name, _ in equip["chest"]:
        mat = ("cloth" if "cloth" in name else "leath" if "leather" in name else
               "purple" if "mage" in name else "metal")
        icon_specs.append((name, "chest", mat, "gold" if "royal" in name or "mage" in name else None))
    for name, _ in equip["helmet"]:
        kind = ("hat" if "wizard" in name else "hood" if "hood" in name else "helm")
        mat = ("leath" if "leather" in name else "gold" if "crown" in name else
               "purple" if "wizard" in name else "cloth" if "hood" in name else "metal")
        icon_specs.append((name, kind, mat, "gold" if "wizard" in name else None))
    for name, _ in equip["legs"]:
        mat = "cloth" if "cloth" in name else "leath" if "leather" in name else "metal"
        icon_specs.append((name, "legs", mat, None))
    for name, _ in equip["boots"]:
        mat = "cloth" if "cloth" in name else "leath" if "leather" in name else "metal"
        icon_specs.append((name, "boots", mat, None))
    for name, _ in equip["accessory"]:
        icon_specs.append((name, "cloak", "red" if "red" in name else "purple" if "royal" in name else "leaf", None))
    icon_specs += [
        ("health_potion", "potion", "red", None),
        ("greater_health_potion", "potion", "red", "gold"),
        ("stamina_potion", "potion", "leaf", None),
    ]
    isheet, icon_names = build_icon_sheet(icon_specs)
    save(isheet, "items/equipment_icons.png")

    # --- icon.png (app icon) -------------------------------------------
    print("[app icon]")
    app = Canvas(64, 64)
    app.rect(0, 0, 64, 64, PAL["cloth_d"])
    for y in range(64):
        for x in range(64):
            if _noise(x // 4, y // 4, 9) > 0.7:
                app.px(x, y, PAL["cloth_m"])
    big = build_sheet(draw_hero_body)
    # paste the "down / idle0" cell scaled x2
    for (x, y), col in big.buf.items():
        if x < CELL_W and y < CELL_H:
            for sx in range(2):
                for sy in range(2):
                    app.px(20 + x * 2 + sx - 4, 12 + y * 2 + sy - 16, col)
    app.to_image().save(os.path.join(ROOT, "assets", "icon.png"))
    print("  wrote assets/icon.png (64x64)")

    # --- machine-readable index for GDScript ---------------------------
    import json
    idx = {
        "hero_cell": [CELL_W, CELL_H],
        "hero_grid": [COLS, ROWS],
        "hero_dirs": DIRS,
        "frame_map": {
            "idle": [0, 1], "walk": [2, 3, 4, 5], "attack": [6, 7],
        },
        "equipment": equip_index,
        "terrain": ts_names,
        "props": prop_names,
        "enemies": enemy_index,
        "icons": icon_names,
        "icon_grid": [8, 16],
    }
    with open(os.path.join(OUT, "asset_index.json"), "w", encoding="utf-8") as f:
        json.dump(idx, f, indent=2)
    print("  wrote asset_index.json")

    # --- GDScript mirror of the index (single source of truth) ----------
    gd = ["# AUTO-GENERATED by tools/gen_assets.py - DO NOT EDIT BY HAND.",
          "class_name ArtIndex",
          "",
          "const CELL := Vector2i(%d, %d)" % (CELL_W, CELL_H),
          "const COLS := %d" % COLS,
          "const DIRS := %s" % json.dumps(DIRS).replace('"', '"'),
          "const FRAMES := %s" % json.dumps(idx["frame_map"]),
          "const ICON_INDEX := %s" % json.dumps({n: i for i, n in enumerate(icon_names)}),
          "const ICON_GRID := Vector2i(%d, %d)" % (idx["icon_grid"][0], idx["icon_grid"][1]),
          "const TERRAIN_INDEX := %s" % json.dumps({n: i for i, n in enumerate(ts_names)}),
          "const PROP_INDEX := %s" % json.dumps({n: i for i, n in enumerate(prop_names)}),
          "const ENEMIES := %s" % json.dumps(enemy_index),
          "const EQUIPMENT_SLOTS := %s" % json.dumps(list(equip_index.keys())),
          "const EQUIPMENT_IDS := %s" % json.dumps(equip_index),
          ""]
    gd_path = os.path.join(ROOT, "src", "data", "art_index.gd")
    os.makedirs(os.path.dirname(gd_path), exist_ok=True)
    with open(gd_path, "w", encoding="utf-8") as f:
        f.write("\n".join(gd))
    print("  wrote src/data/art_index.gd")
    print("Done.")


if __name__ == "__main__":
    sys.exit(main())

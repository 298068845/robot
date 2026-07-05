from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "skins" / "red_mecha"
DESIGNS = ROOT / "assets" / "designs"

SIZES = {
    "head": (266, 259),
    "torso": (248, 279),
    "outer_upper_arm": (305, 77),
    "inner_upper_arm": (305, 77),
    "outer_forearm": (343, 80),
    "inner_forearm": (343, 80),
    "outer_hand": (296, 163),
    "inner_hand": (296, 163),
    "outer_thigh": (78, 261),
    "inner_thigh": (78, 261),
    "outer_shin": (76, 268),
    "inner_shin": (76, 268),
    "outer_foot": (290, 221),
    "inner_foot": (290, 221),
}

RED_DARK = "#8f1014"
RED = "#c51b24"
RED_LIGHT = "#f1463f"
GRAPHITE = "#24262b"
GRAPHITE_2 = "#383b42"
WHITE = "#f3f0e7"
AMBER = "#ffc34d"
SHADOW = "#651014"
LINE = "#18191d"


def poly(draw: ImageDraw.ImageDraw, points, fill, outline=LINE, width=3):
    draw.polygon(points, fill=fill, outline=outline)
    if width > 1:
        draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def panel(draw, points, fill=RED, trim=True):
    poly(draw, points, fill)
    if trim:
        inset = []
        cx = sum(x for x, _ in points) / len(points)
        cy = sum(y for _, y in points) / len(points)
        for x, y in points:
            inset.append((cx + (x - cx) * 0.78, cy + (y - cy) * 0.78))
        draw.line(inset + [inset[0]], fill=RED_LIGHT, width=2)


def slot(size):
    return Image.new("RGBA", size, (0, 0, 0, 0)), ImageDraw.Draw(Image.new("RGBA", size, (0, 0, 0, 0)))


def make_canvas(name):
    im = Image.new("RGBA", SIZES[name], (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def add_bolts(draw, pts, r=3):
    for x, y in pts:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=GRAPHITE, outline=LINE, width=1)


def head():
    im, d = make_canvas("head")
    panel(d, [(78, 58), (188, 58), (220, 108), (200, 198), (132, 226), (66, 198), (46, 108)], RED)
    panel(d, [(92, 78), (174, 78), (196, 112), (181, 166), (133, 184), (85, 166), (70, 112)], RED_DARK)
    panel(d, [(99, 118), (167, 118), (156, 148), (110, 148)], GRAPHITE_2, False)
    d.rectangle((112, 124, 154, 134), fill=AMBER, outline=LINE, width=2)
    panel(d, [(54, 104), (24, 124), (42, 158), (66, 152)], WHITE, False)
    panel(d, [(212, 104), (242, 124), (224, 158), (200, 152)], WHITE, False)
    d.line((92, 190, 174, 190), fill=LINE, width=4)
    add_bolts(d, [(78, 104), (188, 104), (91, 175), (175, 175)])
    return im


def torso():
    im, d = make_canvas("torso")
    panel(d, [(52, 24), (196, 24), (226, 94), (205, 238), (124, 262), (43, 238), (22, 94)], RED)
    panel(d, [(76, 50), (172, 50), (196, 108), (176, 190), (124, 214), (72, 190), (52, 108)], RED_DARK)
    panel(d, [(94, 84), (154, 84), (166, 118), (154, 152), (94, 152), (82, 118)], GRAPHITE_2)
    d.rectangle((105, 101, 143, 115), fill=AMBER, outline=LINE, width=2)
    panel(d, [(34, 88), (4, 117), (22, 158), (51, 139)], WHITE, False)
    panel(d, [(214, 88), (244, 117), (226, 158), (197, 139)], WHITE, False)
    panel(d, [(74, 211), (174, 211), (158, 245), (90, 245)], GRAPHITE, False)
    add_bolts(d, [(56, 81), (192, 81), (62, 219), (186, 219)])
    return im


def limb_horizontal(name, long=False, flip=False):
    im, d = make_canvas(name)
    w, h = SIZES[name]
    left = 18
    right = w - 18
    mid = h // 2
    if long:
        body = [(48, 13), (284, 8), (324, 31), (309, 67), (70, 71), (20, 48)]
    else:
        body = [(40, 12), (236, 7), (287, 29), (270, 63), (62, 68), (17, 47)]
    if flip:
        body = [(w - x, y) for x, y in body]
    panel(d, body, RED)
    cap1 = [(left, mid - 22), (left + 34, mid - 31), (left + 48, mid), (left + 34, mid + 31), (left, mid + 22)]
    cap2 = [(right, mid - 22), (right - 34, mid - 31), (right - 48, mid), (right - 34, mid + 31), (right, mid + 22)]
    if flip:
        cap1, cap2 = cap2, cap1
    panel(d, cap1, GRAPHITE, False)
    panel(d, cap2, GRAPHITE, False)
    stripe = [(88, 24), (w - 88, 20), (w - 74, 34), (96, 40)]
    if flip:
        stripe = [(w - x, y) for x, y in stripe]
    panel(d, stripe, WHITE, False)
    d.line((78, mid + 16, w - 82, mid + 7), fill=SHADOW, width=4)
    add_bolts(d, [(left + 23, mid), (right - 23, mid)], 4)
    return im


def hand(name, flip=False):
    if flip:
        return hand(name, False).transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    im, d = make_canvas(name)
    w, h = SIZES[name]

    def x(v):
        return v

    panel(d, [(40, 62), (112, 44), (172, 59), (188, 104), (132, 134), (62, 122)], RED)
    palm = [(x(68), 69), (x(139), 56), (x(178), 82), (x(164), 123), (x(92), 127), (x(52), 104)]
    panel(d, palm, RED_DARK)
    d.arc((x(88) - 30, 80, x(88) + 44, 126), 205, 310, fill=RED_LIGHT, width=3)
    for yy in (86, 99, 112):
        d.line((x(86), yy, x(151), yy - 6), fill=RED_LIGHT, width=2)
    for i, base in enumerate([154, 178, 202, 226]):
        y = 55 + (i % 2) * 4
        pts = [(x(base), y), (x(base + 42), y + 6), (x(base + 46), y + 29), (x(base + 7), y + 35)]
        panel(d, pts, RED)
        d.line((x(base + 14), y + 11, x(base + 38), y + 14), fill=SHADOW, width=3)
    thumb = [(x(142), 119), (x(188), 132), (x(184), 154), (x(126), 139)]
    panel(d, thumb, RED)
    panel(d, [(x(28), 75), (x(59), 65), (x(68), 119), (x(34), 129)], GRAPHITE, False)
    return im


def limb_vertical(name, shin=False, flip=False):
    im, d = make_canvas(name)
    w, h = SIZES[name]
    cx = w // 2
    body = [(cx - 27, 18), (cx + 27, 18), (cx + 34, h - 40), (cx + 12, h - 16), (cx - 15, h - 16), (cx - 34, h - 40)]
    if shin:
        body = [(cx - 25, 15), (cx + 24, 15), (cx + 32, h - 60), (cx + 20, h - 16), (cx - 22, h - 16), (cx - 32, h - 60)]
    panel(d, body, RED)
    inset = [(cx - 16, 45), (cx + 15, 45), (cx + 18, h - 74), (cx, h - 52), (cx - 18, h - 74)]
    panel(d, inset, RED_DARK)
    side = [(cx + 19, 70), (cx + 31, 91), (cx + 24, h - 85), (cx + 10, h - 66)]
    if flip:
        side = [(w - x, y) for x, y in side]
    panel(d, side, WHITE, False)
    panel(d, [(cx - 24, 9), (cx + 24, 9), (cx + 30, 28), (cx - 30, 28)], GRAPHITE, False)
    panel(d, [(cx - 22, h - 34), (cx + 22, h - 34), (cx + 26, h - 12), (cx - 26, h - 12)], GRAPHITE, False)
    add_bolts(d, [(cx, 22), (cx, h - 23)], 3)
    return im


def foot(name, flip=False):
    im, d = make_canvas(name)
    w, h = SIZES[name]
    pts = [(38, 105), (104, 74), (207, 82), (266, 115), (248, 153), (82, 158), (28, 139)]
    panel(d, pts, RED)
    panel(d, [(92, 92), (184, 92), (223, 116), (207, 136), (104, 137), (66, 119)], RED_DARK)
    panel(d, [(211, 94), (275, 113), (249, 132), (205, 124)], WHITE, False)
    panel(d, [(42, 126), (246, 126), (231, 164), (76, 168)], GRAPHITE, False)
    d.line((72, 145, 224, 145), fill=LINE, width=3)
    add_bolts(d, [(92, 113), (180, 113), (232, 119)], 3)
    if flip:
        im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return im


def save_all():
    OUT.mkdir(parents=True, exist_ok=True)
    DESIGNS.mkdir(parents=True, exist_ok=True)
    parts = {
        "head": head(),
        "torso": torso(),
        "outer_upper_arm": limb_horizontal("outer_upper_arm", False, False),
        "inner_upper_arm": limb_horizontal("inner_upper_arm", False, True),
        "outer_forearm": limb_horizontal("outer_forearm", True, False),
        "inner_forearm": limb_horizontal("inner_forearm", True, True),
        "outer_hand": hand("outer_hand", False),
        "inner_hand": hand("inner_hand", True),
        "outer_thigh": limb_vertical("outer_thigh", False, False),
        "inner_thigh": limb_vertical("inner_thigh", False, True),
        "outer_shin": limb_vertical("outer_shin", True, False),
        "inner_shin": limb_vertical("inner_shin", True, True),
        "outer_foot": foot("outer_foot", False),
        "inner_foot": foot("inner_foot", False),
    }
    for name, im in parts.items():
        im.save(OUT / f"{name}.png")

    sheet_w, sheet_h = 1120, 1040
    sheet = Image.new("RGBA", (sheet_w, sheet_h), "#f2f2ef")
    sd = ImageDraw.Draw(sheet)
    positions = {
        "head": (128, 42),
        "torso": (137, 340),
        "outer_upper_arm": (438, 62),
        "inner_upper_arm": (438, 162),
        "outer_forearm": (418, 262),
        "inner_forearm": (418, 372),
        "outer_hand": (442, 486),
        "inner_hand": (442, 662),
        "outer_thigh": (852, 52),
        "inner_thigh": (954, 52),
        "outer_shin": (854, 360),
        "inner_shin": (956, 360),
        "outer_foot": (786, 670),
        "inner_foot": (786, 790),
    }
    for name, pos in positions.items():
        sheet.alpha_composite(parts[name], pos)
        x, y = pos
        w, h = SIZES[name]
        sd.rectangle((x, y, x + w, y + h), outline="#c9c9c4", width=1)
    sheet.convert("RGB").save(DESIGNS / "robot_design_red_mecha_parts_sheet_v1.png", quality=95)


if __name__ == "__main__":
    save_all()

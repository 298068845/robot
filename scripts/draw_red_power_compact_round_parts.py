from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "skins" / "red_power_compact_round_drawn"
DEFAULT_SKIN_JSON = ROOT / "assets" / "skins" / "default_skin.json"
SHEET = ROOT / "assets" / "designs" / "robot_design_red_power_compact_round_drawn_parts_v1.png"
SOURCE = ROOT / "assets" / "designs" / "robot_design_red_power_from_compact_round_head_front_side_v1.png"

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

WHITE = "#f3f1eb"
WHITE_SHADE = "#d8d8d3"
RED = "#d91d18"
RED_DARK = "#a70f0e"
RED_HI = "#ff4a3f"
GRAPHITE = "#25282e"
GRAPHITE_2 = "#3a3f46"
BLACK = "#111317"
AMBER = "#ff9f19"
LINE = "#0c0e11"


def make(name: str):
    im = Image.new("RGBA", SIZES[name], (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def poly(d: ImageDraw.ImageDraw, pts, fill, outline=LINE, width=3):
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def panel(d: ImageDraw.ImageDraw, pts, fill=WHITE, hi=True):
    poly(d, pts, fill)
    if hi:
        cx = sum(x for x, _ in pts) / len(pts)
        cy = sum(y for _, y in pts) / len(pts)
        inner = [(cx + (x - cx) * 0.78, cy + (y - cy) * 0.78) for x, y in pts]
        d.line(inner + [inner[0]], fill=RED_HI if fill == RED else "#ffffff", width=2)


def rounded(d: ImageDraw.ImageDraw, box, radius, fill, outline=LINE, width=3):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def ellipse(d: ImageDraw.ImageDraw, box, fill, outline=LINE, width=3):
    d.ellipse(box, fill=fill, outline=outline, width=width)


def slot_save(parts: dict[str, Image.Image]):
    OUT.mkdir(parents=True, exist_ok=True)
    for name, im in parts.items():
        im.save(OUT / f"{name}.png")
    if SOURCE.exists():
        (OUT / "source_design.png").write_bytes(SOURCE.read_bytes())


def head():
    im, d = make("head")
    # Pure side-view compact rounded head based on the confirmed rounded head design.
    panel(d, [(54, 77), (85, 37), (168, 24), (220, 54), (232, 116), (204, 184), (118, 209), (58, 174), (36, 112)], WHITE)
    rounded(d, (76, 21, 168, 48), 14, RED)
    d.line((88, 39, 158, 37), fill=RED_HI, width=2)
    panel(d, [(44, 96), (83, 67), (119, 75), (112, 129), (70, 151), (40, 133)], BLACK, False)
    rounded(d, (72, 94, 114, 108), 5, AMBER, width=2)
    panel(d, [(68, 143), (127, 128), (151, 156), (115, 190), (58, 174)], WHITE)
    panel(d, [(126, 125), (180, 108), (189, 151), (142, 185), (112, 167)], RED)
    ellipse(d, (140, 58, 220, 139), RED)
    ellipse(d, (155, 72, 205, 124), GRAPHITE)
    ellipse(d, (166, 82, 195, 112), AMBER, width=3)
    ellipse(d, (175, 91, 188, 104), GRAPHITE, width=2)
    # Rounded curl plates close to the helmet silhouette.
    for box in [(169, 36, 236, 106), (181, 47, 226, 96), (190, 58, 215, 86)]:
        d.arc(box, start=258, end=96, fill=LINE, width=10)
        d.arc(box, start=258, end=96, fill=WHITE_SHADE, width=7)
    rounded(d, (101, 189, 202, 230), 10, GRAPHITE)
    d.line((114, 203, 190, 203), fill="#565b62", width=2)
    return im


def torso():
    im, d = make("torso")
    panel(d, [(42, 34), (158, 24), (218, 76), (223, 157), (180, 239), (86, 250), (30, 188), (24, 92)], WHITE)
    panel(d, [(131, 52), (208, 86), (207, 145), (162, 191), (126, 171), (127, 98)], RED)
    panel(d, [(43, 92), (95, 70), (128, 98), (121, 171), (70, 212), (35, 172)], WHITE_SHADE)
    panel(d, [(94, 105), (151, 104), (180, 134), (161, 194), (99, 194), (78, 135)], GRAPHITE)
    for y in (126, 150, 174):
        d.line((91, y, 166, y + 1), fill=BLACK, width=3)
    rounded(d, (76, 46, 105, 61), 5, AMBER, width=2)
    rounded(d, (94, 223, 154, 258), 9, GRAPHITE, width=3)
    return im


def arm_upper(inner=False):
    im, d = make("outer_upper_arm")
    panel(d, [(20, 38), (57, 13), (150, 9), (246, 18), (287, 35), (270, 63), (143, 68), (55, 62)], WHITE)
    panel(d, [(164, 18), (247, 21), (281, 35), (258, 55), (169, 55)], WHITE_SHADE if inner else RED)
    panel(d, [(22, 23), (61, 9), (70, 67), (25, 56)], GRAPHITE, False)
    panel(d, [(246, 18), (287, 31), (274, 66), (236, 58)], GRAPHITE, False)
    rounded(d, (101, 24, 145, 48), 8, WHITE_SHADE, width=2)
    return im


def forearm(inner=False):
    im, d = make("outer_forearm")
    panel(d, [(22, 40), (77, 11), (228, 10), (316, 27), (327, 51), (270, 70), (82, 69), (25, 56)], WHITE)
    panel(d, [(204, 17), (313, 31), (318, 50), (215, 60)], WHITE_SHADE if inner else RED)
    panel(d, [(52, 35), (119, 20), (151, 34), (119, 56), (52, 58)], WHITE_SHADE)
    rounded(d, (278, 20, 329, 63), 12, RED, width=3)
    rounded(d, (288, 33, 307, 52), 4, AMBER, width=2)
    panel(d, [(20, 28), (60, 14), (68, 68), (24, 58)], GRAPHITE, False)
    return im


def hand(palm=False):
    im, d = make("outer_hand")
    rounded(d, (28, 57, 72, 122), 13, RED, width=3)
    panel(d, [(63, 70), (124, 50), (180, 64), (197, 105), (143, 134), (80, 124)], WHITE)
    panel(d, [(90, 74), (145, 61), (180, 79), (166, 116), (102, 120)], WHITE if palm else RED)
    for i, x in enumerate([163, 187, 211, 234]):
        y = 58 + (i % 2) * 4
        rounded(d, (x, y, x + 31, y + 39), 8, GRAPHITE_2, width=3)
        d.line((x + 8, y + 20, x + 27, y + 20), fill=BLACK, width=2)
    rounded(d, (142, 116, 203, 148), 9, GRAPHITE_2, width=3)
    if palm:
        d.arc((87, 80, 154, 124), 205, 315, fill="#aaa9a4", width=3)
        for yy in (91, 103, 114):
            d.line((105, yy, 151, yy - 5), fill="#aaa9a4", width=2)
    rounded(d, (45, 76, 61, 105), 5, AMBER, width=2)
    return im


def thigh(inner=False):
    im, d = make("outer_thigh")
    cx = 39
    panel(d, [(17, 16), (58, 16), (70, 78), (63, 196), (50, 246), (25, 246), (12, 196), (7, 78)], WHITE)
    panel(d, [(43, 55), (67, 83), (60, 190), (42, 222)], WHITE_SHADE if inner else RED)
    rounded(d, (13, 18, 64, 53), 8, GRAPHITE, width=3)
    rounded(d, (20, 219, 58, 253), 8, GRAPHITE_2, width=3)
    return im


def shin(inner=False):
    im, d = make("outer_shin")
    panel(d, [(16, 14), (57, 14), (69, 92), (63, 216), (50, 257), (24, 257), (10, 216), (7, 92)], WHITE)
    panel(d, [(40, 58), (66, 88), (60, 199), (42, 236)], WHITE_SHADE if inner else RED)
    rounded(d, (20, 15, 56, 43), 8, GRAPHITE, width=3)
    rounded(d, (20, 232, 57, 263), 8, GRAPHITE_2, width=3)
    rounded(d, (45, 127, 57, 160), 4, AMBER, width=2)
    return im


def foot():
    im, d = make("outer_foot")
    panel(d, [(27, 119), (87, 77), (185, 80), (256, 112), (271, 147), (232, 177), (72, 174), (21, 151)], WHITE)
    panel(d, [(150, 89), (252, 113), (267, 143), (218, 162), (139, 145)], RED)
    panel(d, [(50, 133), (230, 136), (252, 158), (228, 188), (54, 187), (22, 156)], GRAPHITE)
    rounded(d, (62, 101, 112, 124), 8, WHITE_SHADE, width=2)
    rounded(d, (85, 92, 110, 108), 4, AMBER, width=2)
    d.line((55, 165, 226, 166), fill=BLACK, width=4)
    return im


def skin_json():
    data = json.loads(DEFAULT_SKIN_JSON.read_text(encoding="utf-8"))
    data["name"] = "red_power_compact_round_drawn"
    data["display_name"] = "Red Power Compact Round Drawn"
    data["base_dir"] = "res://assets/skins/red_power_compact_round_drawn"
    (OUT / "skin.json").write_text(json.dumps(data, ensure_ascii=False, indent="\t"), encoding="utf-8")


def sheet(parts: dict[str, Image.Image]):
    sheet_im = Image.new("RGBA", (1120, 1040), "#f4f4f1")
    d = ImageDraw.Draw(sheet_im)
    positions = {
        "head": (120, 40),
        "torso": (130, 345),
        "outer_upper_arm": (430, 60),
        "inner_upper_arm": (430, 160),
        "outer_forearm": (410, 260),
        "inner_forearm": (410, 370),
        "outer_hand": (440, 492),
        "inner_hand": (440, 670),
        "outer_thigh": (852, 55),
        "inner_thigh": (954, 55),
        "outer_shin": (853, 360),
        "inner_shin": (955, 360),
        "outer_foot": (785, 672),
        "inner_foot": (785, 802),
    }
    for name, pos in positions.items():
        sheet_im.alpha_composite(parts[name], pos)
        x, y = pos
        w, h = SIZES[name]
        d.rectangle((x, y, x + w, y + h), outline="#c8c8c4", width=1)
    sheet_im.convert("RGB").save(SHEET, quality=95)


def main():
    parts = {
        "head": head(),
        "torso": torso(),
        "outer_upper_arm": arm_upper(inner=False),
        "inner_upper_arm": arm_upper(inner=True),
        "outer_forearm": forearm(inner=False),
        "inner_forearm": forearm(inner=True),
        "outer_hand": hand(palm=False),
        "inner_hand": hand(palm=True),
        "outer_thigh": thigh(inner=False),
        "inner_thigh": thigh(inner=True),
        "outer_shin": shin(inner=False),
        "inner_shin": shin(inner=True),
        "outer_foot": foot(),
        "inner_foot": foot(),
    }
    slot_save(parts)
    skin_json()
    sheet(parts)


if __name__ == "__main__":
    main()

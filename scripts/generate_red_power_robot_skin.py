from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "skins" / "red_power_robot"
DESIGN_OUT = ROOT / "assets" / "designs" / "robot_design_red_power_parts_sheet_v1.png"
HEAD_SOURCE = ROOT / "assets" / "designs" / "robot_design_red_power_head_rounded_compact_v1.png"

SIZES = {
    "head": (266, 259),
    "torso": (248, 279),
    "left_upper_arm": (305, 77),
    "right_upper_arm": (305, 77),
    "left_forearm": (343, 80),
    "right_forearm": (343, 80),
    "left_hand": (296, 163),
    "right_hand": (296, 163),
    "left_thigh": (78, 261),
    "right_thigh": (78, 261),
    "left_shin": (76, 268),
    "right_shin": (76, 268),
    "left_foot": (290, 221),
    "right_foot": (290, 221),
}

WHITE = "#f2f0ea"
WHITE_2 = "#d9d9d4"
RED = "#d91d18"
RED_DARK = "#9d1110"
RED_LIGHT = "#ff4438"
GRAPHITE = "#24272c"
GRAPHITE_2 = "#3a3e45"
BLACK = "#111317"
AMBER = "#ff9f19"
LINE = "#0d0f12"


def canvas(name: str):
    im = Image.new("RGBA", SIZES[name], (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def poly(draw: ImageDraw.ImageDraw, pts, fill, outline=LINE, width=3):
    draw.polygon(pts, fill=fill)
    draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def panel(draw: ImageDraw.ImageDraw, pts, fill=WHITE, trim=True):
    poly(draw, pts, fill)
    if trim:
        cx = sum(x for x, _ in pts) / len(pts)
        cy = sum(y for _, y in pts) / len(pts)
        inner = [(cx + (x - cx) * 0.78, cy + (y - cy) * 0.78) for x, y in pts]
        draw.line(inner + [inner[0]], fill="#ffffff" if fill != RED else RED_LIGHT, width=2)


def rounded(draw: ImageDraw.ImageDraw, xy, r, fill, outline=LINE, width=3):
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)


def bolt(draw: ImageDraw.ImageDraw, x, y, r=3):
    draw.ellipse((x - r, y - r, x + r, y + r), fill=GRAPHITE, outline=LINE, width=1)


def extract_side_head() -> Image.Image:
    src = Image.open(HEAD_SOURCE).convert("RGBA")
    w, h = src.size
    right_half = src.crop((w // 2, 0, w, h))
    pix = right_half.load()
    alpha = Image.new("L", right_half.size, 0)
    apix = alpha.load()
    for y in range(right_half.height):
        for x in range(right_half.width):
            r, g, b, _ = pix[x, y]
            # The design sheet background is near-white; keep all painted pixels.
            if not (r > 242 and g > 242 and b > 242):
                apix[x, y] = 255
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.35))
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("Could not find side head in source image")
    crop = right_half.crop(bbox)
    crop_alpha = alpha.crop(bbox)
    crop.putalpha(crop_alpha)

    slot = Image.new("RGBA", SIZES["head"], (0, 0, 0, 0))
    scale = min(226 / crop.width, 224 / crop.height)
    resized = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.LANCZOS)
    x = (slot.width - resized.width) // 2 + 4
    y = (slot.height - resized.height) // 2 - 2
    slot.alpha_composite(resized, (x, y))
    return slot


def torso():
    im, d = canvas("torso")
    panel(d, [(54, 21), (167, 25), (219, 88), (215, 184), (169, 252), (74, 251), (28, 181), (25, 89)], WHITE)
    panel(d, [(120, 44), (205, 91), (198, 169), (146, 210), (110, 188), (118, 104)], RED)
    panel(d, [(53, 94), (103, 72), (126, 104), (118, 190), (72, 218), (38, 172)], WHITE_2)
    panel(d, [(103, 93), (153, 94), (179, 130), (159, 186), (103, 186), (82, 130)], GRAPHITE)
    for yy in (115, 139, 163):
        d.line((94, yy, 168, yy + 2), fill=BLACK, width=3)
    panel(d, [(70, 35), (104, 42), (95, 70), (55, 77)], RED, False)
    rounded(d, (81, 51, 100, 65), 4, AMBER, width=2)
    rounded(d, (105, 226, 156, 257), 8, GRAPHITE, width=3)
    return im


def upper_arm(name: str, inner=False):
    im, d = canvas(name)
    w, h = SIZES[name]
    panel(d, [(22, 36), (54, 12), (130, 10), (233, 17), (283, 35), (267, 62), (128, 66), (54, 61)], WHITE)
    panel(d, [(150, 18), (238, 22), (271, 36), (255, 54), (158, 55)], RED if not inner else WHITE_2)
    panel(d, [(22, 23), (58, 8), (67, 67), (25, 55)], GRAPHITE, False)
    panel(d, [(248, 18), (286, 31), (274, 65), (239, 58)], GRAPHITE, False)
    rounded(d, (104, 23, 151, 49), 9, WHITE_2, width=2)
    bolt(d, 46, 39, 4)
    bolt(d, 263, 40, 4)
    return im


def forearm(name: str, inner=False):
    im, d = canvas(name)
    w, h = SIZES[name]
    panel(d, [(20, 40), (73, 12), (229, 10), (319, 28), (326, 53), (260, 70), (82, 68), (26, 56)], WHITE)
    panel(d, [(198, 17), (313, 31), (318, 50), (211, 59)], RED if not inner else WHITE_2)
    panel(d, [(49, 34), (119, 19), (151, 33), (120, 55), (52, 58)], WHITE_2)
    rounded(d, (279, 22, 328, 62), 12, RED, width=3)
    rounded(d, (286, 32, 306, 51), 4, AMBER, width=2)
    panel(d, [(19, 28), (59, 14), (67, 68), (24, 58)], GRAPHITE, False)
    return im


def hand(name: str, palm=False):
    im, d = canvas(name)
    # Wrist cuff on the left, knuckles to the right: side-view fist.
    rounded(d, (23, 58, 70, 121), 14, RED, width=3)
    panel(d, [(60, 69), (123, 49), (179, 63), (195, 105), (142, 132), (78, 124)], WHITE)
    palm_fill = WHITE if palm else RED
    panel(d, [(87, 74), (144, 60), (179, 78), (165, 115), (101, 119)], palm_fill)
    for i, x in enumerate([164, 188, 211, 232]):
        y = 57 + (i % 2) * 4
        rounded(d, (x, y, x + 31, y + 39), 8, GRAPHITE_2, width=3)
        d.line((x + 8, y + 20, x + 27, y + 20), fill=BLACK, width=2)
    rounded(d, (142, 116, 201, 147), 9, GRAPHITE_2, width=3)
    if palm:
        d.arc((88, 80, 153, 123), 205, 315, fill="#bbb9b4", width=3)
        for yy in (90, 102, 113):
            d.line((105, yy, 151, yy - 5), fill="#bbb9b4", width=2)
    rounded(d, (42, 75, 62, 104), 6, AMBER, width=2)
    return im


def thigh(name: str, inner=False):
    im, d = canvas(name)
    w, h = SIZES[name]
    panel(d, [(19, 17), (58, 17), (69, 78), (61, 198), (49, 245), (24, 245), (12, 198), (8, 78)], WHITE)
    panel(d, [(43, 52), (66, 80), (59, 188), (43, 220)], RED if not inner else WHITE_2)
    panel(d, [(15, 29), (60, 29), (64, 60), (12, 60)], GRAPHITE, False)
    rounded(d, (20, 219, 58, 253), 8, GRAPHITE_2, width=3)
    return im


def shin(name: str, inner=False):
    im, d = canvas(name)
    w, h = SIZES[name]
    panel(d, [(16, 15), (57, 15), (68, 94), (62, 216), (50, 256), (24, 256), (10, 216), (7, 94)], WHITE)
    panel(d, [(40, 56), (65, 87), (59, 198), (42, 235)], RED if not inner else WHITE_2)
    rounded(d, (21, 14, 55, 42), 8, GRAPHITE, width=3)
    rounded(d, (20, 232, 57, 263), 8, GRAPHITE_2, width=3)
    rounded(d, (45, 126, 57, 160), 4, AMBER, width=2)
    return im


def foot(name: str):
    im, d = canvas(name)
    panel(d, [(28, 119), (86, 77), (185, 80), (257, 112), (271, 147), (232, 177), (72, 174), (21, 151)], WHITE)
    panel(d, [(150, 89), (252, 113), (267, 143), (218, 162), (139, 145)], RED)
    panel(d, [(50, 133), (230, 136), (252, 158), (228, 188), (54, 187), (22, 156)], GRAPHITE)
    rounded(d, (62, 101, 112, 124), 8, WHITE_2, width=2)
    rounded(d, (85, 92, 110, 108), 4, AMBER, width=2)
    d.line((55, 165, 226, 166), fill=BLACK, width=4)
    return im


def save_skin_json():
    src = ROOT / "assets" / "skins" / "sport_robot" / "skin.json"
    data = json.loads(src.read_text(encoding="utf-8"))
    data["name"] = "red_power_robot"
    data["display_name"] = "Red Power Robot"
    data["base_dir"] = "res://assets/skins/red_power_robot"
    (OUT / "skin.json").write_text(json.dumps(data, ensure_ascii=False, indent="\t"), encoding="utf-8")


def make_sheet(parts: dict[str, Image.Image]):
    sheet = Image.new("RGBA", (1120, 1040), "#f4f4f1")
    d = ImageDraw.Draw(sheet)
    positions = {
        "head": (120, 40),
        "torso": (130, 345),
        "left_upper_arm": (430, 60),
        "right_upper_arm": (430, 160),
        "left_forearm": (410, 260),
        "right_forearm": (410, 370),
        "left_hand": (440, 492),
        "right_hand": (440, 670),
        "left_thigh": (852, 55),
        "right_thigh": (954, 55),
        "left_shin": (853, 360),
        "right_shin": (955, 360),
        "left_foot": (785, 672),
        "right_foot": (785, 802),
    }
    for name, pos in positions.items():
        sheet.alpha_composite(parts[name], pos)
        x, y = pos
        w, h = SIZES[name]
        d.rectangle((x, y, x + w, y + h), outline="#c8c8c4", width=1)
    sheet.convert("RGB").save(DESIGN_OUT, quality=95)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    parts = {
        "head": extract_side_head(),
        "torso": torso(),
        "left_upper_arm": upper_arm("left_upper_arm", inner=False),
        "right_upper_arm": upper_arm("right_upper_arm", inner=True),
        "left_forearm": forearm("left_forearm", inner=False),
        "right_forearm": forearm("right_forearm", inner=True),
        "left_hand": hand("left_hand", palm=False),
        "right_hand": hand("right_hand", palm=True),
        "left_thigh": thigh("left_thigh", inner=False),
        "right_thigh": thigh("right_thigh", inner=True),
        "left_shin": shin("left_shin", inner=False),
        "right_shin": shin("right_shin", inner=True),
        "left_foot": foot("left_foot"),
        "right_foot": foot("right_foot"),
    }
    for name, im in parts.items():
        im.save(OUT / f"{name}.png")
    save_skin_json()
    (OUT / "head_source.png").write_bytes(HEAD_SOURCE.read_bytes())
    make_sheet(parts)


if __name__ == "__main__":
    main()

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "designs" / "robot_design_red_power_from_compact_round_head_front_side_v1.png"
OUT = ROOT / "assets" / "skins" / "red_power_compact_round"
DEFAULT_SKIN_JSON = ROOT / "assets" / "skins" / "default_skin.json"
SHEET = ROOT / "assets" / "designs" / "robot_design_red_power_compact_round_parts_sheet_v1.png"

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

# Crop boxes are from the confirmed side-view character in SOURCE.
# They intentionally include a little surrounding whitespace; background is removed after crop.
CROPS = {
    "head": (990, 28, 1180, 170),
    "torso": (945, 165, 1128, 410),
    "upper_arm": (1098, 236, 1170, 355),
    "forearm": (1070, 345, 1185, 492),
    "hand": (1075, 485, 1162, 575),
    "thigh": (990, 470, 1092, 642),
    "shin": (990, 600, 1132, 842),
    "foot": (910, 835, 1160, 970),
}


def remove_background(im: Image.Image) -> Image.Image:
    rgba = im.convert("RGBA")
    rgb = rgba.convert("RGB")
    bg = Image.new("RGB", rgb.size, (250, 250, 250))
    diff = ImageChops.difference(rgb, bg).convert("L")
    # The source background is near-white with subtle gradient. This keeps painted antialiasing.
    alpha = diff.point(lambda p: 0 if p < 18 else min(255, int((p - 18) * 4)))
    alpha = alpha.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.45))
    rgba.putalpha(alpha)
    return rgba


def trim(im: Image.Image) -> Image.Image:
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        return im
    return im.crop(bbox)


def fit_to_slot(im: Image.Image, size: tuple[int, int], max_fill=(0.9, 0.82), offset=(0, 0)) -> Image.Image:
    im = trim(im)
    slot = Image.new("RGBA", size, (0, 0, 0, 0))
    target_w = size[0] * max_fill[0]
    target_h = size[1] * max_fill[1]
    scale = min(target_w / im.width, target_h / im.height)
    resized = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.Resampling.LANCZOS)
    x = (size[0] - resized.width) // 2 + offset[0]
    y = (size[1] - resized.height) // 2 + offset[1]
    slot.alpha_composite(resized, (x, y))
    return slot


def crop_part(src: Image.Image, key: str) -> Image.Image:
    return remove_background(src.crop(CROPS[key]))


def rotate_limb_to_horizontal(im: Image.Image) -> Image.Image:
    # Side-view arms hang vertically in the design. Rotate so proximal/top end reads left.
    return im.transpose(Image.Transpose.ROTATE_90)


def build_parts() -> dict[str, Image.Image]:
    src = Image.open(SOURCE)
    head = fit_to_slot(crop_part(src, "head"), SIZES["head"], max_fill=(0.9, 0.84), offset=(3, -2))
    torso = fit_to_slot(crop_part(src, "torso"), SIZES["torso"], max_fill=(0.86, 0.9), offset=(0, 4))

    upper = rotate_limb_to_horizontal(crop_part(src, "upper_arm"))
    forearm = rotate_limb_to_horizontal(crop_part(src, "forearm"))
    hand = rotate_limb_to_horizontal(crop_part(src, "hand"))
    thigh = crop_part(src, "thigh")
    shin = crop_part(src, "shin")
    foot = crop_part(src, "foot")

    parts = {
        "head": head,
        "torso": torso,
        "outer_upper_arm": fit_to_slot(upper, SIZES["outer_upper_arm"], max_fill=(0.9, 0.84)),
        "inner_upper_arm": fit_to_slot(upper, SIZES["inner_upper_arm"], max_fill=(0.9, 0.84)),
        "outer_forearm": fit_to_slot(forearm, SIZES["outer_forearm"], max_fill=(0.9, 0.84)),
        "inner_forearm": fit_to_slot(forearm, SIZES["inner_forearm"], max_fill=(0.9, 0.84)),
        "outer_hand": fit_to_slot(hand, SIZES["outer_hand"], max_fill=(0.62, 0.76), offset=(-8, 0)),
        "inner_hand": fit_to_slot(hand, SIZES["inner_hand"], max_fill=(0.62, 0.76), offset=(-8, 0)),
        "outer_thigh": fit_to_slot(thigh, SIZES["outer_thigh"], max_fill=(0.88, 0.9)),
        "inner_thigh": fit_to_slot(thigh, SIZES["inner_thigh"], max_fill=(0.88, 0.9)),
        "outer_shin": fit_to_slot(shin, SIZES["outer_shin"], max_fill=(0.88, 0.92)),
        "inner_shin": fit_to_slot(shin, SIZES["inner_shin"], max_fill=(0.88, 0.92)),
        "outer_foot": fit_to_slot(foot, SIZES["outer_foot"], max_fill=(0.88, 0.76), offset=(-4, 8)),
        "inner_foot": fit_to_slot(foot, SIZES["inner_foot"], max_fill=(0.88, 0.76), offset=(-4, 8)),
    }
    return parts


def write_skin_json():
    data = json.loads(DEFAULT_SKIN_JSON.read_text(encoding="utf-8"))
    data["name"] = "red_power_compact_round"
    data["display_name"] = "Red Power Compact Round"
    data["base_dir"] = "res://assets/skins/red_power_compact_round"
    (OUT / "skin.json").write_text(json.dumps(data, ensure_ascii=False, indent="\t"), encoding="utf-8")


def make_sheet(parts: dict[str, Image.Image]):
    sheet = Image.new("RGBA", (1120, 1040), "#f4f4f1")
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
    from PIL import ImageDraw

    d = ImageDraw.Draw(sheet)
    for name, pos in positions.items():
        sheet.alpha_composite(parts[name], pos)
        x, y = pos
        w, h = SIZES[name]
        d.rectangle((x, y, x + w, y + h), outline="#c8c8c4", width=1)
    sheet.convert("RGB").save(SHEET, quality=95)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    parts = build_parts()
    for name, im in parts.items():
        im.save(OUT / f"{name}.png")
    (OUT / "source_design.png").write_bytes(SOURCE.read_bytes())
    write_skin_json()
    make_sheet(parts)


if __name__ == "__main__":
    main()

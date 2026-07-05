from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SKILL_PATH = ROOT / "robot_design.skill"
GATEWAY_DIR = ROOT / ".tmp" / "robot_skin_gateway"
SKINS_DIR = ROOT / "assets" / "skins"
DESIGNS_DIR = ROOT / "assets" / "designs"

SLOT_SIZES: dict[str, tuple[int, int]] = {
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

HARD_CONSTRAINTS = [
    "skill_must_be_loaded",
    "new_user_request_only_adds_constraints",
    "no_direct_crop",
    "no_mixed_sources",
    "reference_design_is_only_visual_source",
    "no_unapproved_new_colors",
    "must_preserve_reference_shapes",
    "sport_robot_endpoint_baseline",
    "outer_inner_distinction",
    "palm_back_hand_distinction",
    "top_down_joint_ownership",
    "fixed_slot_canvas_sizes",
    "no_final_png_before_approved_binding_sheet",
    "failed_candidate_must_not_enter_assets_skins",
]

STAGES = ("design", "binding_parts_confirmation", "final_parts")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path.resolve())


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def require_existing_file(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    if not path.is_file():
        raise argparse.ArgumentTypeError(f"file does not exist: {path}")
    return path


def require_existing_path(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    if not path.exists():
        raise argparse.ArgumentTypeError(f"path does not exist: {path}")
    return path


def validate_references(reference_paths: list[Path]) -> list[dict[str, str]]:
    if not reference_paths:
        raise SystemExit("ERROR: at least one reference image is required")
    refs = []
    for path in reference_paths:
        refs.append(
            {
                "path": rel(path),
                "sha256": sha256(path),
            }
        )
    return refs


def slot_source_rows(stage: str, slots: list[str], approved_sheet: Path | None) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    for slot in slots:
        rows[slot] = {
            "side_view_reference": "pending",
            "outer_inner_reference": "pending" if slot.startswith(("outer_", "inner_")) else "n/a",
            "palm_back_reference": "pending" if slot.endswith("_hand") else "n/a",
            "endpoint_reference": "Sport Robot baseline",
            "top_down_joint_owner_checked": False,
            "notes": "",
        }
    if stage == "final_parts" and approved_sheet:
        for row in rows.values():
            row["side_view_reference"] = rel(approved_sheet)
            row["outer_inner_reference"] = rel(approved_sheet) if row["outer_inner_reference"] == "pending" else row["outer_inner_reference"]
            row["palm_back_reference"] = rel(approved_sheet) if row["palm_back_reference"] == "pending" else row["palm_back_reference"]
    return rows


def cmd_preflight(args: argparse.Namespace) -> int:
    if not SKILL_PATH.is_file():
        raise SystemExit(f"ERROR: missing skill file: {SKILL_PATH}")

    stage: str = args.stage
    slots = args.slots or list(SLOT_SIZES)
    unknown = sorted(set(slots) - set(SLOT_SIZES))
    if unknown:
        raise SystemExit(f"ERROR: unknown slot(s): {', '.join(unknown)}")

    approved_sheet = args.approved_binding_sheet
    approved_audit = args.approved_binding_audit
    blockers: list[str] = []
    if stage == "final_parts":
        if approved_sheet is None:
            blockers.append("final_parts requires --approved-binding-sheet")
        if approved_audit is None:
            blockers.append("final_parts requires --approved-binding-audit")
        if not args.user_confirmed:
            blockers.append("final_parts requires --user-confirmed")
        if approved_sheet is not None and approved_audit is not None:
            audit = load_json(approved_audit)
            if audit.get("schema") != "robot-skin-gateway-audit-v1":
                blockers.append("--approved-binding-audit is not a gateway audit file")
            if audit.get("status") != "approved":
                blockers.append("--approved-binding-audit must have status approved")
            if audit.get("stage") != "binding_parts_confirmation":
                blockers.append("--approved-binding-audit must be for binding_parts_confirmation")
            audited_candidate = audit.get("candidate")
            if audited_candidate and (ROOT / audited_candidate).resolve() != approved_sheet.resolve():
                blockers.append("--approved-binding-audit candidate does not match --approved-binding-sheet")

    preflight = {
        "schema": "robot-skin-gateway-preflight-v1",
        "created_at": now_iso(),
        "name": args.name,
        "stage": stage,
        "skill": {
            "path": rel(SKILL_PATH),
            "sha256": sha256(SKILL_PATH),
        },
        "reference_images": validate_references(args.reference),
        "approved_binding_sheet": rel(approved_sheet) if approved_sheet else None,
        "approved_binding_audit": rel(approved_audit) if approved_audit else None,
        "user_confirmed": bool(args.user_confirmed),
        "direct_crop_allowed": False,
        "mixed_sources_allowed": False,
        "hard_constraints_acknowledged": HARD_CONSTRAINTS,
        "slots": slots,
        "slot_source_eligibility": slot_source_rows(stage, slots, approved_sheet),
        "manual_pre_generation_checklist": [
            "Read robot_design.skill before any image generation prompt.",
            "State whether the output is design, binding_parts_confirmation, or final_parts.",
            "List the single visual source and reject any unapproved new colors.",
            "For every hand, state palm/back side and wrist/finger direction.",
            "For every limb, state proximal/distal endpoint direction.",
            "For every joint, state parent/child ownership under the top-down rule.",
            "If any source reference is missing, stop instead of generating final PNGs.",
        ],
        "blockers": blockers,
        "status": "blocked" if blockers else "ready",
    }

    out = GATEWAY_DIR / f"{args.name}_preflight.json"
    write_json(out, preflight)
    print(f"WROTE {rel(out)}")
    if blockers:
        print("STATUS blocked")
        for blocker in blockers:
            print(f"- {blocker}")
        return 2
    print("STATUS ready")
    return 0


def image_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as fh:
        header = fh.read(24)
    if (
        len(header) >= 24
        and header[:8] == b"\x89PNG\r\n\x1a\n"
        and header[12:16] == b"IHDR"
    ):
        return (
            int.from_bytes(header[16:20], "big"),
            int.from_bytes(header[20:24], "big"),
        )

    try:
        from PIL import Image
    except ImportError as exc:
        raise SystemExit("ERROR: Pillow is required for non-PNG final_parts audit image size checks") from exc
    with Image.open(path) as im:
        return im.size


def audit_final_parts(candidate: Path) -> list[str]:
    failures: list[str] = []
    if not candidate.is_dir():
        return [f"final_parts candidate must be a directory: {candidate}"]

    for slot, expected in SLOT_SIZES.items():
        image_path = candidate / f"{slot}.png"
        if not image_path.is_file():
            failures.append(f"missing slot image: {slot}.png")
            continue
        actual = image_size(image_path)
        if actual != expected:
            failures.append(f"{slot}.png has size {actual[0]}x{actual[1]}, expected {expected[0]}x{expected[1]}")

    if not (candidate / "skin.json").is_file():
        failures.append("missing skin.json")
    return failures


def path_is_under(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def cmd_audit(args: argparse.Namespace) -> int:
    preflight_path = args.preflight
    preflight = load_json(preflight_path)
    if preflight.get("schema") != "robot-skin-gateway-preflight-v1":
        raise SystemExit("ERROR: not a robot skin gateway preflight file")
    if preflight.get("status") != "ready":
        raise SystemExit("ERROR: preflight is not ready; resolve blockers first")
    if preflight.get("skill", {}).get("sha256") != sha256(SKILL_PATH):
        raise SystemExit("ERROR: robot_design.skill changed after preflight; run preflight again")

    stage = preflight["stage"]
    candidate = args.candidate.resolve()
    failures: list[str] = []

    if path_is_under(candidate, SKINS_DIR) and stage != "final_parts":
        failures.append("only final_parts output may be audited under assets/skins")
    if stage != "final_parts" and not path_is_under(candidate, DESIGNS_DIR):
        failures.append("design and binding confirmation candidates must be saved under assets/designs")
    if stage == "final_parts":
        failures.extend(audit_final_parts(candidate))

    manual_failures = [item for item in args.fail if item.strip()]
    failures.extend(manual_failures)

    audit = {
        "schema": "robot-skin-gateway-audit-v1",
        "created_at": now_iso(),
        "preflight": rel(preflight_path),
        "candidate": rel(candidate),
        "stage": stage,
        "automatic_failures": failures,
        "manual_pass_items": args.pass_item,
        "manual_fail_items": manual_failures,
        "required_manual_audit": [
            "No unapproved colors were introduced.",
            "Shapes and armor segmentation still match the reference design.",
            "No direct crop or pasted source fragment is used.",
            "All endpoint directions match Sport Robot baseline.",
            "Outer/inner surfaces are visually distinct and reference-supported.",
            "Hands use correct palm/back side and wrist/finger direction.",
            "Top-down joint ownership is obeyed.",
        ],
        "status": "failed" if failures or not args.approve else "approved",
        "approved_for_assets_skins": bool(stage == "final_parts" and args.approve and not failures),
    }

    out = GATEWAY_DIR / f"{preflight['name']}_audit_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    write_json(out, audit)
    print(f"WROTE {rel(out)}")
    print(f"STATUS {audit['status']}")
    if failures:
        for failure in failures:
            print(f"- {failure}")
        return 2
    if not args.approve:
        print("- audit recorded, but not approved; pass --approve only after manual checks are clean")
        return 2
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Gateway for robot skin image generation and saving.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    preflight = sub.add_parser("preflight", help="create a required generation preflight record")
    preflight.add_argument("--name", required=True, help="stable task/output name")
    preflight.add_argument("--stage", required=True, choices=STAGES)
    preflight.add_argument("--reference", action="append", type=require_existing_file, required=True)
    preflight.add_argument("--approved-binding-sheet", type=require_existing_file)
    preflight.add_argument("--approved-binding-audit", type=require_existing_file)
    preflight.add_argument("--user-confirmed", action="store_true")
    preflight.add_argument("--slots", nargs="+", choices=sorted(SLOT_SIZES))
    preflight.set_defaults(func=cmd_preflight)

    audit = sub.add_parser("audit", help="audit a generated candidate before it can be treated as usable")
    audit.add_argument("--preflight", required=True, type=require_existing_file)
    audit.add_argument("--candidate", required=True, type=require_existing_path)
    audit.add_argument("--pass-item", action="append", default=[], help="manual check passed")
    audit.add_argument("--fail", action="append", default=[], help="manual failure; any value fails the audit")
    audit.add_argument("--approve", action="store_true", help="mark approved when automatic and manual checks are clean")
    audit.set_defaults(func=cmd_audit)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

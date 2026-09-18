"""Prepare the Demo 0.3 T2 capture contract without inventing visual evidence."""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from typing import Any


sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
TOOLING_ROOT = ROOT / ".codex" / "skills" / "asset-qa" / "scripts"
sys.path.insert(0, str(TOOLING_ROOT))

from qa_tooling import (  # noqa: E402
    HashCache,
    expand_roi,
    hash_metadata,
    keyframe_indices,
)


PENDING_CAPTURE = "PENDING_CAPTURE"
REQUIRED_DIMENSIONS = {
    "wheel_separation",
    "player_readability",
    "combat_presence",
    "ground_vfx_conflict",
    "attack_state_recognition",
}
REQUIRED_TARGETS = {"A-11", "A-12", "A-13"}


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _copy(value: Any) -> Any:
    return copy.deepcopy(value)


def _project_relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def _resolve_asset(root: Path, asset_root: Path, relative_path: str) -> Path:
    resolved = (asset_root / relative_path).resolve()
    try:
        resolved.relative_to(asset_root.resolve())
    except ValueError as error:
        raise ValueError(f"asset escapes asset root: {relative_path}") from error
    if not resolved.is_file():
        raise FileNotFoundError(resolved)
    return resolved


def _validate_source(source: dict[str, Any]) -> None:
    if source.get("demo") != "0.3" or source.get("qa_stage") != "T2":
        raise ValueError("T2 source must target Demo 0.3")
    if source.get("status") != PENDING_CAPTURE:
        raise ValueError("T2 source status must remain PENDING_CAPTURE")
    if source.get("evidence_policy", {}).get("real_maker_motion_screenshots_available"):
        raise ValueError("real Maker Motion evidence must not be asserted by this preparation")
    if source.get("evidence_policy", {}).get("scores_allowed"):
        raise ValueError("scores are not allowed before Motion capture")
    contract = source["capture_contract"]
    if contract["seed"] != 20260911 or contract["freeze"] is not True:
        raise ValueError("fixed seed/freeze contract changed")
    camera = contract["camera"]
    if camera != {"space": "design_1920x1080", "x": 960, "y": 540, "zoom": 1.0}:
        raise ValueError("fixed camera contract changed")
    budget = source["screenshot_budget"]
    if budget["per_motion_max"] != 3 or budget["per_motion_min"] < 0:
        raise ValueError("invalid T2 screenshot budget")
    roi = source["roi_policy"]
    if not 1.5 <= roi["requested_scale"] <= 2.0:
        raise ValueError("requested ROI scale must be between 1.5x and 2.0x")
    if roi["min_scale"] != 1.5 or roi["max_scale"] != 2.0:
        raise ValueError("ROI bounds must be 1.5x-2.0x")
    sampling = source["keyframe_sampling"]
    if sampling["max_per_motion"] != 3 or sampling["indices"] != [0, 1, 2]:
        raise ValueError("T2 keyframe sampling contract must be three evenly spaced frames")

    dimensions = {item["key"] for item in source["dimensions"]}
    if dimensions != REQUIRED_DIMENSIONS:
        raise ValueError(f"unexpected T2 dimensions: {sorted(dimensions)}")
    targets = {item["asset_id"] for item in source["targets"]}
    if targets != REQUIRED_TARGETS:
        raise ValueError(f"unexpected T2 targets: {sorted(targets)}")
    case_ids = [item["case_id"] for item in source["cases"]]
    if len(case_ids) != len(set(case_ids)) or len(case_ids) != 15:
        raise ValueError("T2 must contain exactly one case per dimension and target")


def _manifest_assets(root: Path, manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    asset_root = (root / manifest["asset_root"]).resolve()
    result: dict[str, dict[str, Any]] = {}
    for asset in manifest["assets"]:
        asset_copy = _copy(asset)
        asset_copy["resolved_path"] = _resolve_asset(root, asset_root, asset["path"])
        result[asset["asset_id"]] = asset_copy
    return result


def _case_definition(
    source: dict[str, Any],
    manifest_assets: dict[str, dict[str, Any]],
    dimensions: dict[str, dict[str, Any]],
    targets: dict[str, dict[str, Any]],
    case_source: dict[str, Any],
) -> dict[str, Any]:
    contract = source["capture_contract"]
    dimension = dimensions[case_source["dimension_key"]]
    target = targets[case_source["asset_id"]]
    animation = _copy(contract["animation_states"][case_source["motion"]])
    asset_refs = sorted(set(dimension["asset_refs"] + [case_source["asset_id"]]))
    for asset_id in asset_refs:
        if asset_id not in manifest_assets:
            raise ValueError(f"case references asset missing from manifest: {asset_id}")

    target_position = _copy(contract["entity_positions"][case_source["enemy_id"]])
    state = {
        "playerAnimationState": animation["player_animation_state"],
        "enemyAnimationState": animation["enemy_animation_state"],
        "wheelState": animation["wheel_state"],
        "wheelAttackPulse": animation.get("wheel_attack_pulse"),
        "attackState": animation["attack_state"],
        "enemyKind": target["enemy_id"],
        "enemyMotionKeyframe": target["attack_keyframe"] if animation["attack_state"] == "attack" else animation["attack_state"],
        "playerFacing": "right",
        "enemyFacing": "left",
    }
    sampling = source["keyframe_sampling"]
    budget = source["screenshot_budget"]
    roi_policy = source["roi_policy"]
    return {
        "case_id": case_source["case_id"],
        "stage": "T2",
        "status": PENDING_CAPTURE,
        "mode": contract["mode"],
        "ratio": case_source["ratio"],
        "dimension_key": case_source["dimension_key"],
        "dimension": dimension["name"],
        "asset_id": target["asset_id"],
        "enemy_id": target["enemy_id"],
        "target_name": target["name"],
        "motion": case_source["motion"],
        "seed": contract["seed"],
        "freeze": contract["freeze"],
        "camera": _copy(contract["camera"]),
        "entity_positions": {
            "player": _copy(contract["entity_positions"]["player"]),
            "enemy": {"id": target["enemy_id"], "x": target_position["x"], "y": target_position["y"]},
        },
        "animation_state": animation,
        "state": state,
        "asset_refs": asset_refs,
        "asset_paths": [_project_relative(manifest_assets[item]["resolved_path"], ROOT) for item in asset_refs],
        "scene_config_ref": source["scene_config_ref"],
        "screenshot_budget": {
            "min_per_motion": budget["per_motion_min"],
            "max_per_motion": budget["per_motion_max"],
        },
        "roi": {
            "roi": None,
            "roi_scale": roi_policy["requested_scale"],
            "roi_scale_min": roi_policy["min_scale"],
            "roi_scale_max": roi_policy["max_scale"],
            "roi_source": roi_policy["source"],
            "t1_eligible": False,
            "status": PENDING_CAPTURE,
        },
        "keyframe_sampling": {
            "tool": sampling["tool"],
            "strategy": sampling["strategy"],
            "planned_frame_count": sampling["planned_frame_count"],
            "max_per_motion": sampling["max_per_motion"],
            "indices": _copy(sampling["indices"]),
            "captured_frames": [],
            "status": PENDING_CAPTURE,
        },
        "contact_sheet": {
            "tool": source["contact_sheet"]["tool"],
            "purpose": source["contact_sheet"]["purpose"],
            "source_frames": [],
            "output": None,
            "status": PENDING_CAPTURE,
        },
        "captured_frames": [],
    }


def _cache_entries(
    cache: HashCache,
    original_files: dict[str, Any],
    asset_hashes: dict[str, str],
    root: Path,
) -> list[dict[str, Any]]:
    entries = []
    for key in sorted(asset_hashes):
        path = (root / key).resolve()
        stat = path.stat()
        absolute_key = path.as_posix()
        original = original_files.get(absolute_key)
        cache_hit = bool(
            original
            and original.get("size") == stat.st_size
            and original.get("mtime_ns") == stat.st_mtime_ns
            and original.get("sha256") == asset_hashes[key]
        )
        entries.append(
            {
                "path": _project_relative(path, root),
                "cache_key": _project_relative(path, root),
                "size": stat.st_size,
                "mtime_ns": stat.st_mtime_ns,
                "sha256": asset_hashes[key],
                "cache_hit": cache_hit,
                "hash_source": "existing_cache" if cache_hit else "computed_in_memory",
            }
        )
    return entries


def prepare_report(root: Path = ROOT, output: Path | None = None) -> dict[str, Any]:
    case_path = root / "qa" / "cases" / "T2" / "demo-0.3_t2_cases.json"
    manifest_path = root / "qa" / "asset_manifest.json"
    scene_config_path = root / "scenes" / "qa" / "AssetReadabilityTestScene.lua"
    cache_path = root / "qa" / "reports" / "latest" / "hash_cache.json"
    source = _read_json(case_path)
    manifest = _read_json(manifest_path)
    _validate_source(source)
    if not scene_config_path.is_file():
        raise FileNotFoundError(scene_config_path)

    manifest_assets = _manifest_assets(root, manifest)
    dimensions = {item["key"]: item for item in source["dimensions"]}
    targets = {item["asset_id"]: item for item in source["targets"]}
    cache = HashCache(cache_path if cache_path.exists() else None)
    original_files = _copy(cache.data.get("files", {}))

    cases = []
    for case_source in source["cases"]:
        case = _case_definition(source, manifest_assets, dimensions, targets, case_source)
        asset_paths = [manifest_assets[item]["resolved_path"] for item in case["asset_refs"]]
        hashes = hash_metadata(asset_paths, scene_config_path, case, cache)
        hashes["asset_hash"] = {
            _project_relative(Path(path), root): digest
            for path, digest in hashes["asset_hash"].items()
        }
        case_output = _copy(case)
        case_output["qa_case"] = _copy(case)
        case_output.update(hashes)
        case_output.update(
            {
                "vision_score": None,
                "metric_score": None,
                "final_score": None,
                "grade": None,
                "confidence": None,
                "hard_fail": None,
                "hard_fail_codes": [],
                "action": "ESCALATE",
                "next_gate": PENDING_CAPTURE,
                "visual_review_status": PENDING_CAPTURE,
            }
        )
        cases.append(case_output)

    unique_asset_hashes: dict[str, str] = {}
    for case in cases:
        unique_asset_hashes.update(case["asset_hash"])
    cache_entries = _cache_entries(cache, original_files, unique_asset_hashes, root)
    case_hashes = {case["case_id"]: case["qa_case_hash"] for case in cases}
    all_asset_hashes = dict(sorted(unique_asset_hashes.items()))

    # Validate the deterministic helper contract without treating the result as evidence.
    planned_roi = expand_roi((100, 100, 100, 100), source["roi_policy"]["requested_scale"])
    if planned_roi[2] != 176 or planned_roi[3] != 176:
        raise AssertionError("qa_tooling ROI expansion changed")
    if keyframe_indices(source["keyframe_sampling"]["planned_frame_count"], 3) != [0, 1, 2]:
        raise AssertionError("qa_tooling keyframe sampling changed")

    report = {
        "schema_version": "1.0",
        "demo": "0.3",
        "qa_stage": "T2",
        "asset_qa_skill_version": source["asset_qa_skill_version"],
        "planner_version": source["planner_version"],
        "deterministic": True,
        "status": PENDING_CAPTURE,
        "evidence": _copy(source["evidence_policy"]),
        "capture_contract": {
            "mode": source["capture_contract"]["mode"],
            "seed": source["capture_contract"]["seed"],
            "freeze": source["capture_contract"]["freeze"],
            "camera": _copy(source["capture_contract"]["camera"]),
            "entity_positions": _copy(source["capture_contract"]["entity_positions"]),
            "animation_states": _copy(source["capture_contract"]["animation_states"]),
        },
        "screenshot_budget": _copy(source["screenshot_budget"]),
        "roi_policy": _copy(source["roi_policy"]),
        "contact_sheet": {
            "tool": source["contact_sheet"]["tool"],
            "purpose": source["contact_sheet"]["purpose"],
            "source_count": 0,
            "source_frames": [],
            "output": None,
            "status": PENDING_CAPTURE,
        },
        "keyframe_sampling": _copy(source["keyframe_sampling"]),
        "scene_config_ref": _project_relative(scene_config_path, root),
        "scene_config_hash": cases[0]["scene_config_hash"],
        "hash_cache": {
            "tool": source["hash_cache"]["tool"],
            "path": source["hash_cache"]["path"],
            "version": cache.data.get("version"),
            "read_only": True,
            "invalidation_fields": _copy(source["hash_cache"]["invalidation_fields"]),
            "persist_planned_hashes": False,
            "entries": cache_entries,
        },
        "asset_hash": all_asset_hashes,
        "qa_case_hashes": case_hashes,
        "coverage": {
            "target_asset_ids": sorted(REQUIRED_TARGETS),
            "dimensions": sorted(REQUIRED_DIMENSIONS),
            "case_count": len(cases),
        },
        "cases": cases,
        "summary": {
            "total_cases": len(cases),
            "pending_capture": len(cases),
            "captured": 0,
            "score_available": False,
            "pass_count": 0,
        },
        "next_gate": PENDING_CAPTURE,
        "evidence_note": "未取得新的真实 Maker Motion 截图；所有视觉评分、Hard Fail 判定和 PASS 均保持未执行。",
    }
    if output is not None:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "qa" / "reports" / "latest" / "t2_preparation.json",
    )
    args = parser.parse_args(argv)
    report = prepare_report(ROOT, args.output)
    print(
        json.dumps(
            {
                "status": report["status"],
                "cases": report["summary"]["total_cases"],
                "pending_capture": report["summary"]["pending_capture"],
                "output": args.output.resolve().as_posix(),
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

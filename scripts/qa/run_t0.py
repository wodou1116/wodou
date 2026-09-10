"""Run the minimal deterministic T0 check without modifying source assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
GAME_ROOT = HERE.parents[2]
SKILL_ROOT = GAME_ROOT / ".codex" / "skills" / "asset-qa"
SCRIPT_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPT_ROOT))

from alpha_bounds import alpha_bounds  # noqa: E402
from image_metrics import image_metrics  # noqa: E402


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_asset(asset: dict) -> dict:
    path = GAME_ROOT / asset["asset_root"] / asset["path"]
    issues: list[str] = []
    fixes: list[str] = []
    bounds = alpha_bounds(path)
    metrics = image_metrics(path)
    ordinary_subject = asset["type"] not in {"telegraph", "vfx", "wheel"}
    hard_fail_codes: list[str] = []
    if asset["alpha_required"] and (not bounds["has_alpha"] or bounds["empty"]):
        issues.append("需要 Alpha 的资产缺少有效主体，触发 HF-10")
        hard_fail_codes.append("HF-10")
    occupancy = bounds["subject_occupancy"]
    if not bounds["empty"] and ordinary_subject and occupancy < 0.35:
        issues.append("主体占画布比例低于 0.35（Warning）")
    if not bounds["empty"] and ordinary_subject and occupancy < 0.20:
        issues.append("普通主体占画布比例低于 0.20")
        fixes.append("检查透明边与裁切")
    regenerate = ordinary_subject and occupancy < 0.20
    if regenerate:
        status, action, next_gate = "T0_REGENERATE", "REGENERATE", "T0_RETEST"
    elif hard_fail_codes:
        status, action, next_gate = "T0_REGENERATE", "REGENERATE", "T0_RETEST"
    else:
        status, action, next_gate = "T0_PASS", "PASS", "T1"
    metric_score = 100 if not issues else (65 if regenerate or hard_fail_codes else 95)
    return {
        "asset_id": asset["asset_id"],
        "asset_name": asset["name"],
        "asset_type": asset["type"],
        "season": asset["season"],
        "qa_stage": "T0",
        "status": status,
        "action": action,
        "vision_score": None,
        "metric_score": metric_score,
        "final_score": metric_score,
        "grade": "S" if metric_score >= 90 else "D" if metric_score >= 60 else "F",
        "confidence": 1.0,
        "hard_fail": bool(hard_fail_codes),
        "hard_fail_codes": hard_fail_codes,
        "source_sha256": sha256(path),
        "metrics": {**bounds, **metrics},
        "issues": issues,
        "recommended_fixes": fixes,
        "next_gate": next_gate,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=GAME_ROOT / "qa" / "asset_manifest.json")
    parser.add_argument("--output", type=Path, default=GAME_ROOT / "qa" / "reports" / "latest" / "t0_results.json")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    results = [check_asset({**asset, "asset_root": manifest["asset_root"]}) for asset in manifest["assets"]]
    summary = {"total": len(results), "T0_PASS": 0, "T0_FIX": 0, "T0_REGENERATE": 0}
    for result in results:
        summary[result["status"]] += 1
    report = {
        "schema_version": "1.0",
        "asset_qa_skill_version": "1.0",
        "rubric_version": "1.0",
        "qa_stage": "T0",
        "deterministic": True,
        "manifest_asset_count": len(manifest["assets"]),
        "results": results,
        "summary": summary,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0 if summary["T0_REGENERATE"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

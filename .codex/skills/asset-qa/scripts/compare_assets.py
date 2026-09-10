"""计算同批资产的确定性混淆辅助分数；不替代 Vision 判断。"""

from __future__ import annotations

import argparse
import itertools
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parent))
from alpha_bounds import alpha_bounds  # noqa: E402
from image_metrics import image_metrics  # noqa: E402


def compare(left: Path, right: Path) -> dict:
    a, b = image_metrics(left), image_metrics(right)
    ba, bb = alpha_bounds(left), alpha_bounds(right)
    luma_similarity = max(0.0, 1.0 - abs(a["mean_luminance"] - b["mean_luminance"]) / 0.5)
    sat_similarity = max(0.0, 1.0 - abs(a["mean_saturation"] - b["mean_saturation"]))
    edge_similarity = max(0.0, 1.0 - abs(a["edge_density"] - b["edge_density"]) / 0.5)
    occupancy_similarity = max(0.0, 1.0 - abs(ba["subject_occupancy"] - bb["subject_occupancy"]) / 0.5)
    score = round(100 * (0.35 * luma_similarity + 0.30 * sat_similarity + 0.20 * edge_similarity + 0.15 * occupancy_similarity), 2)
    risk_band = "low" if score <= 30 else "medium" if score <= 55 else "high"
    return {"left": str(left), "right": str(right), "metric_similarity_score": score,
            "risk_band": risk_band, "requires_vision_review": score > 40,
            "vision_confusion_score": None, "decision": "PENDING_VISION_REVIEW",
            "evidence": {"luminance_similarity": round(luma_similarity, 4), "saturation_similarity": round(sat_similarity, 4),
                         "edge_similarity": round(edge_similarity, 4), "occupancy_similarity": round(occupancy_similarity, 4)}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    pairs = [compare(a, b) for a, b in itertools.combinations(sorted(args.paths, key=lambda p: str(p)), 2)]
    result = {"deterministic": True, "metric_only": True, "asset_count": len(args.paths), "pairs": pairs,
              "note": "机器相似度只用于筛选视觉复核，不得直接决定返工或 PASS。"}
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")

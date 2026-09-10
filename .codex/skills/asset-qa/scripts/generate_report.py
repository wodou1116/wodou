"""从结构化 QA JSON 生成确定性汇总 JSON 与 Markdown。"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def report(data: dict) -> tuple[dict, str]:
    results = data.get("results", [])
    actions = Counter(result.get("action", "UNKNOWN") for result in results)
    statuses = Counter(result.get("status", "UNKNOWN") for result in results)
    hard_fails = [result for result in results if result.get("hard_fail")]
    scored = sorted((result for result in results if result.get("final_score") is not None), key=lambda r: (r["final_score"], r["asset_id"]))
    summary = {"qa_stage": data.get("qa_stage"), "total": len(results), "statuses": dict(sorted(statuses.items())),
               "actions": dict(sorted(actions.items())), "hard_fail_count": len(hard_fails),
               "hard_fail_asset_ids": [r["asset_id"] for r in hard_fails],
               "lowest_scores": [{"asset_id": r["asset_id"], "final_score": r["final_score"]} for r in scored[:5]],
               "spring_confusion_matrix": data.get("spring_confusion_matrix", [])}
    lines = [f"# Asset QA {summary['qa_stage'] or 'Unknown'}", "", f"- Total: {summary['total']}", f"- Hard Fail Count: {summary['hard_fail_count']}", "", "## Actions", ""]
    for key, value in summary["actions"].items():
        lines.append(f"- {key}: {value}")
    lines += ["", "## Lowest Scores", "", "| Asset | Final Score |", "|---|---:|"]
    lines += [f"| {row['asset_id']} | {row['final_score']} |" for row in summary["lowest_scores"]] or ["| - | - |"]
    lines += ["", "## Spring Confusion Matrix", "", "```json", json.dumps(summary["spring_confusion_matrix"], ensure_ascii=False, indent=2), "```", ""]
    return summary, "\n".join(lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--json-output", required=True, type=Path)
    parser.add_argument("--markdown-output", required=True, type=Path)
    args = parser.parse_args()
    summary, markdown = report(json.loads(args.input.read_text(encoding="utf-8")))
    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    args.markdown_output.write_text(markdown, encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, sort_keys=True))


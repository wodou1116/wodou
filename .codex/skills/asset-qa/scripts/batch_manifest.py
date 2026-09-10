"""扫描图片目录，生成需要人工确认映射的确定性 manifest。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


TYPE_BY_DIR = {"characters": "character", "enemies": "monster", "bosses": "boss", "environments": "scene",
               "icons": "icon", "ui": "ui", "vfx": "vfx", "wheel": "wheel"}


def build_manifest(root: Path) -> dict:
    files = sorted(root.rglob("*.png"), key=lambda p: p.relative_to(root).as_posix())
    assets = []
    for index, path in enumerate(files, 1):
        relative = path.relative_to(root).as_posix()
        category = relative.split("/", 1)[0]
        asset_type = TYPE_BY_DIR.get(category, "unknown")
        assets.append({"asset_id": f"AUTO-{index:03d}", "name": path.stem, "path": relative,
                       "type": asset_type, "season": "unknown", "alpha_required": asset_type != "scene",
                       "mapping_required": asset_type == "unknown"})
    return {"manifest_version": "1.0", "asset_root": root.name, "read_only": True,
            "mapping_required": any(a["mapping_required"] for a in assets), "assets": assets}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(build_manifest(args.root), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"assets": len(build_manifest(args.root)["assets"]), "output": str(args.output)}, ensure_ascii=False))


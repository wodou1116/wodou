"""Deterministic QA evidence helpers: ROI, contact sheets, keyframes and hashes."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

from PIL import Image, ImageDraw


ROI_SCALE_MIN = 1.5
ROI_SCALE_MAX = 2.0
HASH_CACHE_VERSION = 1
SKIP_CAPTURE = "SKIP_CAPTURE"
SKIP_VISION_REVIEW = "SKIP_VISION_REVIEW"


def _canonicalize(value: Any) -> Any:
    if isinstance(value, Path):
        return value.as_posix()
    if isinstance(value, Mapping):
        return {str(key): _canonicalize(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_canonicalize(item) for item in value]
    return value


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        _canonicalize(value),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _path_key(path: Path) -> str:
    return path.resolve().as_posix()


class HashCache:
    """Optional on-disk cache for content hashes; no cache is written by default."""

    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path) if path is not None else None
        self.data = {"version": HASH_CACHE_VERSION, "files": {}}
        if self.path is not None and self.path.exists():
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            if loaded.get("version") == HASH_CACHE_VERSION and isinstance(loaded.get("files"), dict):
                self.data = loaded

    def asset_hash(self, path: str | Path) -> str:
        source = Path(path)
        stat = source.stat()
        key = _path_key(source)
        cached = self.data["files"].get(key)
        if (
            cached
            and cached.get("size") == stat.st_size
            and cached.get("mtime_ns") == stat.st_mtime_ns
            and isinstance(cached.get("sha256"), str)
        ):
            return cached["sha256"]

        digest = _file_sha256(source)
        self.data["files"][key] = {
            "size": stat.st_size,
            "mtime_ns": stat.st_mtime_ns,
            "sha256": digest,
        }
        return digest

    def save(self) -> None:
        if self.path is None:
            raise ValueError("HashCache.save requires a cache path")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self.data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def asset_hash(path: str | Path, cache: HashCache | None = None) -> str:
    return cache.asset_hash(path) if cache is not None else _file_sha256(Path(path))


def _config_hash_input(config: Any) -> bytes:
    if not isinstance(config, (str, Path)):
        return canonical_json_bytes(config)

    path = Path(config)
    raw = path.read_bytes()
    if path.suffix.lower() == ".json":
        try:
            return canonical_json_bytes(json.loads(raw.decode("utf-8")))
        except (UnicodeDecodeError, json.JSONDecodeError):
            pass
    return raw


def scene_config_hash(config: Any) -> str:
    return hashlib.sha256(_config_hash_input(config)).hexdigest()


def qa_case_hash(case: Mapping[str, Any]) -> str:
    return canonical_hash(case)


def hash_metadata(
    asset_paths: Iterable[str | Path],
    scene_config: Any,
    qa_case: Mapping[str, Any],
    cache: HashCache | None = None,
) -> dict[str, Any]:
    assets = {}
    for path in sorted((Path(item) for item in asset_paths), key=_path_key):
        assets[_path_key(path)] = asset_hash(path, cache)
    return {
        "asset_hash": assets,
        "scene_config_hash": scene_config_hash(scene_config),
        "qa_case_hash": qa_case_hash(qa_case),
    }


def _validate_roi_scale(scale: float) -> None:
    if not ROI_SCALE_MIN <= scale <= ROI_SCALE_MAX:
        raise ValueError(f"ROI scale must be between {ROI_SCALE_MIN} and {ROI_SCALE_MAX}")


def expand_roi(
    bbox: Sequence[float],
    scale: float = ROI_SCALE_MIN,
    canvas_size: Sequence[int] | None = None,
) -> tuple[int, int, int, int]:
    """Expand an x, y, width, height box by 1.5–2.0x around its center."""

    _validate_roi_scale(scale)
    if len(bbox) != 4:
        raise ValueError("bbox must be x,y,width,height")
    x, y, width, height = (float(value) for value in bbox)
    if width <= 0 or height <= 0:
        raise ValueError("bbox width and height must be positive")

    expanded_width = width * scale
    expanded_height = height * scale
    left = x + (width - expanded_width) / 2
    top = y + (height - expanded_height) / 2
    right = left + expanded_width
    bottom = top + expanded_height

    if canvas_size is not None:
        if len(canvas_size) != 2 or canvas_size[0] <= 0 or canvas_size[1] <= 0:
            raise ValueError("canvas_size must be width,height")
        canvas_width, canvas_height = (int(value) for value in canvas_size)
        right = min(right, canvas_width)
        bottom = min(bottom, canvas_height)
        left = max(0.0, min(left, float(canvas_width)))
        top = max(0.0, min(top, float(canvas_height)))

    left_i = max(0, int(math.floor(left)))
    top_i = max(0, int(math.floor(top)))
    right_i = max(left_i + 1, int(math.ceil(right)))
    bottom_i = max(top_i + 1, int(math.ceil(bottom)))
    if canvas_size is not None:
        right_i = min(right_i, int(canvas_size[0]))
        bottom_i = min(bottom_i, int(canvas_size[1]))
    return left_i, top_i, right_i - left_i, bottom_i - top_i


def alpha_roi(path: str | Path, scale: float = ROI_SCALE_MIN, threshold: int = 8) -> dict[str, Any]:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > threshold else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"image has no alpha subject: {path}")
    x0, y0, x1, y1 = bounds
    bbox = (x0, y0, x1 - x0, y1 - y0)
    roi = expand_roi(bbox, scale, image.size)
    effective_scale = (roi[2] / bbox[2], roi[3] / bbox[3])
    clipped = effective_scale[0] + 1e-9 < scale or effective_scale[1] + 1e-9 < scale
    return {
        "source_bbox": list(bbox),
        "roi": list(roi),
        "roi_scale": scale,
        "effective_scale": [round(effective_scale[0], 4), round(effective_scale[1], 4)],
        "clipped_to_canvas": clipped,
        "roi_scale_min": ROI_SCALE_MIN,
        "roi_scale_max": ROI_SCALE_MAX,
        "roi_source": "source_alpha_bounds",
        "t1_eligible": False,
    }


def keyframe_indices(frame_count: int, max_frames: int = 3) -> list[int]:
    if frame_count < 0 or max_frames < 0:
        raise ValueError("frame_count and max_frames must be non-negative")
    if frame_count == 0 or max_frames == 0:
        return []
    count = min(frame_count, max_frames)
    if count == 1:
        return [0]
    return [int((index * (frame_count - 1) + (count - 1) // 2) // (count - 1)) for index in range(count)]


def sample_keyframes(items: Sequence[Any], max_frames: int = 3) -> list[Any]:
    return [items[index] for index in keyframe_indices(len(items), max_frames)]


def create_contact_sheet(
    paths: Iterable[str | Path],
    output: str | Path,
    columns: int = 4,
    tile_size: tuple[int, int] = (256, 256),
    padding: int = 16,
) -> dict[str, Any]:
    sources = sorted((Path(path) for path in paths), key=_path_key)
    if not sources:
        raise ValueError("contact sheet requires at least one image")
    if columns <= 0 or padding < 0:
        raise ValueError("columns must be positive and padding must be non-negative")

    tile_width, tile_height = tile_size
    label_height = 24
    rows = math.ceil(len(sources) / columns)
    sheet = Image.new(
        "RGB",
        (
            padding + columns * (tile_width + padding),
            padding + rows * (tile_height + label_height + padding),
        ),
        (24, 28, 27),
    )
    draw = ImageDraw.Draw(sheet)
    for index, source in enumerate(sources):
        image = Image.open(source).convert("RGBA")
        image.thumbnail((tile_width, tile_height), Image.Resampling.LANCZOS)
        column, row = index % columns, index // columns
        cell_x = padding + column * (tile_width + padding)
        cell_y = padding + row * (tile_height + label_height + padding)
        draw.rectangle((cell_x, cell_y, cell_x + tile_width, cell_y + tile_height), fill=(48, 55, 52))
        image_x = cell_x + (tile_width - image.width) // 2
        image_y = cell_y + (tile_height - image.height) // 2
        sheet.paste(image, (image_x, image_y), image)
        draw.text((cell_x, cell_y + tile_height + 3), source.stem, fill=(235, 235, 225))

    destination = Path(output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, format="PNG")
    return {"output": destination.as_posix(), "count": len(sources), "columns": columns, "rows": rows}


def _parse_csv_ints(value: str, expected: int) -> tuple[int, ...]:
    result = tuple(int(item) for item in value.split(","))
    if len(result) != expected:
        raise argparse.ArgumentTypeError(f"expected {expected} comma-separated integers")
    return result


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    roi_parser = subparsers.add_parser("roi")
    roi_parser.add_argument("--image", type=Path)
    roi_parser.add_argument("--bbox", type=lambda value: _parse_csv_ints(value, 4))
    roi_parser.add_argument("--canvas", type=lambda value: _parse_csv_ints(value, 2))
    roi_parser.add_argument("--scale", type=float, default=ROI_SCALE_MIN)

    sheet_parser = subparsers.add_parser("contact-sheet")
    sheet_parser.add_argument("paths", nargs="+", type=Path)
    sheet_parser.add_argument("--output", required=True, type=Path)
    sheet_parser.add_argument("--columns", type=int, default=4)

    keyframe_parser = subparsers.add_parser("keyframes")
    keyframe_parser.add_argument("items", nargs="+", type=str)
    keyframe_parser.add_argument("--max-frames", type=int, default=3)

    hash_parser = subparsers.add_parser("hash")
    hash_parser.add_argument("--asset", action="append", default=[], type=Path)
    hash_parser.add_argument("--scene-config", type=Path)
    hash_parser.add_argument("--qa-case-json", type=Path)
    hash_parser.add_argument("--cache", type=Path)
    hash_parser.add_argument("--save-cache", action="store_true")

    args = parser.parse_args(argv)
    if args.command == "roi":
        if args.image is not None and args.bbox is not None:
            parser.error("roi accepts --image or --bbox, not both")
        if args.image is not None:
            result = alpha_roi(args.image, args.scale)
        elif args.bbox is not None:
            result = {"roi": list(expand_roi(args.bbox, args.scale, args.canvas)), "roi_scale": args.scale}
        else:
            parser.error("roi requires --image or --bbox")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    if args.command == "contact-sheet":
        print(json.dumps(create_contact_sheet(args.paths, args.output, args.columns), ensure_ascii=False, indent=2))
        return 0
    if args.command == "keyframes":
        print(json.dumps({"indices": keyframe_indices(len(args.items), args.max_frames),
                          "items": sample_keyframes(args.items, args.max_frames)}, ensure_ascii=False, indent=2))
        return 0

    if args.scene_config is None or args.qa_case_json is None:
        parser.error("hash requires --scene-config and --qa-case-json")
    cache = HashCache(args.cache)
    case = json.loads(args.qa_case_json.read_text(encoding="utf-8"))
    result = hash_metadata(args.asset, args.scene_config, case, cache)
    if args.save_cache:
        cache.save()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

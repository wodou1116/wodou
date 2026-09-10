"""只读计算基础 RGB/HSV 近似指标与缩小边缘保留率。"""

from pathlib import Path

from PIL import Image, ImageFilter
import numpy as np


def luminance(rgb: np.ndarray) -> np.ndarray:
    rgb = rgb / 255.0
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def edge_density(gray: np.ndarray) -> float:
    image = Image.fromarray(np.uint8(np.clip(gray, 0, 1) * 255))
    edges = np.asarray(image.filter(ImageFilter.FIND_EDGES), dtype=np.float32) / 255.0
    return float((edges > 0.12).mean())


def image_metrics(path: str | Path, small_size: int = 96) -> dict:
    image = Image.open(path).convert("RGBA")
    array = np.asarray(image, dtype=np.float32)
    mask = array[..., 3] > 8
    pixels = array[..., :3][mask] if mask.any() else array[..., :3].reshape(-1, 3)
    maximum, minimum = pixels.max(axis=1), pixels.min(axis=1)
    saturation = np.divide(maximum - minimum, maximum, out=np.zeros_like(maximum), where=maximum > 0).mean()
    base_edge = edge_density(luminance(array[..., :3]))
    small = image.resize((small_size, small_size), Image.Resampling.LANCZOS)
    small_edge = edge_density(luminance(np.asarray(small, dtype=np.float32)[..., :3]))
    retention = 0.0 if base_edge <= 1e-6 else min(1.0, small_edge / base_edge)
    return {"mean_luminance": round(float(luminance(pixels).mean()), 4),
            "mean_saturation": round(float(saturation), 4), "edge_density": round(base_edge, 4),
            "small_scale_edge_retention": round(float(retention), 4)}


if __name__ == "__main__":
    import argparse
    import json
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    parser.add_argument("--small-size", type=int, default=96)
    args = parser.parse_args()
    print(json.dumps(image_metrics(args.path, args.small_size), ensure_ascii=False, indent=2))


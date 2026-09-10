"""只读计算 PNG 的 Alpha 主体边界。"""

from pathlib import Path

from PIL import Image
import numpy as np


def alpha_bounds(path: str | Path, threshold: int = 8) -> dict:
    source = Image.open(path)
    has_alpha = "A" in source.getbands()
    image = source.convert("RGBA")
    alpha = np.asarray(image)[:, :, 3]
    mask = alpha > threshold
    width, height = image.size
    if not mask.any():
        return {"width": width, "height": height, "has_alpha": has_alpha, "empty": True,
                "subject_bbox": None, "subject_occupancy": 0.0, "transparent_padding_ratio": 1.0}
    ys, xs = np.where(mask)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    occupancy = ((x1 - x0) * (y1 - y0)) / (width * height)
    return {"width": width, "height": height, "has_alpha": has_alpha, "empty": False,
            "subject_bbox": [x0, y0, x1, y1], "subject_occupancy": round(occupancy, 4),
            "transparent_padding_ratio": round(1.0 - occupancy, 4)}


if __name__ == "__main__":
    import argparse
    import json
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    parser.add_argument("--threshold", type=int, default=8)
    args = parser.parse_args()
    print(json.dumps(alpha_bounds(args.path, args.threshold), ensure_ascii=False, indent=2))


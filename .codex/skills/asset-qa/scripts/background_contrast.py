"""比较主体 PNG 与场景/背景 PNG 的确定性分离指标。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image
import numpy as np


def _pixels(path: str | Path, subject: bool) -> np.ndarray:
    array = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
    if subject and (array[..., 3] > 8).any():
        return array[..., :3][array[..., 3] > 8]
    return array[..., :3].reshape(-1, 3)


def _luma(pixels: np.ndarray) -> np.ndarray:
    return (0.2126 * pixels[:, 0] + 0.7152 * pixels[:, 1] + 0.0722 * pixels[:, 2]) / 255.0


def _histogram(pixels: np.ndarray) -> np.ndarray:
    rgb = pixels / 255.0
    maximum, minimum = rgb.max(axis=1), rgb.min(axis=1)
    value = maximum
    saturation = np.divide(maximum - minimum, maximum, out=np.zeros_like(maximum), where=maximum > 0)
    hue = np.zeros_like(value)
    delta = maximum - minimum
    nonzero = delta > 1e-6
    red, green, blue = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    hue[nonzero & (maximum == red)] = ((green - blue)[nonzero & (maximum == red)] / delta[nonzero & (maximum == red)]) % 6
    hue[nonzero & (maximum == green)] = (blue - red)[nonzero & (maximum == green)] / delta[nonzero & (maximum == green)] + 2
    hue[nonzero & (maximum == blue)] = (red - green)[nonzero & (maximum == blue)] / delta[nonzero & (maximum == blue)] + 4
    hue = (hue / 6.0) % 1.0
    return np.histogramdd((hue, saturation, value), bins=(12, 4, 4), range=((0, 1), (0, 1), (0, 1)))[0].ravel() / len(pixels)


def background_contrast(subject_path: str | Path, background_path: str | Path) -> dict:
    subject, background = _pixels(subject_path, True), _pixels(background_path, False)
    subject_luma, background_luma = _luma(subject), _luma(background)
    overlap = float(np.minimum(_histogram(subject), _histogram(background)).sum())
    delta = abs(float(subject_luma.mean()) - float(background_luma.mean()))
    return {"mean_luminance_delta": round(delta, 4),
            "local_contrast": round(float(subject_luma.std()), 4),
            "hsv_histogram_overlap": round(overlap, 4),
            "background_separation_risk": bool(delta < 0.10 and overlap > 0.65)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--subject", required=True, type=Path)
    parser.add_argument("--background", required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(background_contrast(args.subject, args.background), ensure_ascii=False, indent=2))


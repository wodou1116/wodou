"""Self-check for the reusable deterministic QA tooling."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


SCRIPT_ROOT = Path(__file__).resolve().parents[2] / ".codex" / "skills" / "asset-qa" / "scripts"
sys.path.insert(0, str(SCRIPT_ROOT))

from qa_tooling import (  # noqa: E402
    HashCache,
    alpha_roi,
    create_contact_sheet,
    expand_roi,
    hash_metadata,
    keyframe_indices,
    qa_case_hash,
    scene_config_hash,
)


class QaToolingTest(unittest.TestCase):
    def test_roi_policy_and_alpha_bounds(self) -> None:
        self.assertEqual(expand_roi((10, 10, 20, 20), 1.5, (64, 64)), (5, 5, 30, 30))
        with self.assertRaises(ValueError):
            expand_roi((0, 0, 10, 10), 1.4)

        with tempfile.TemporaryDirectory() as temporary:
            image_path = Path(temporary) / "subject.png"
            image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            for x in range(16, 48):
                for y in range(20, 44):
                    image.putpixel((x, y), (255, 255, 255, 255))
            image.save(image_path)
            roi = alpha_roi(image_path, 1.5)
            self.assertEqual(roi["source_bbox"], [16, 20, 32, 24])
            self.assertEqual(roi["roi_scale"], 1.5)
            self.assertEqual(roi["effective_scale"], [1.5, 1.5])
            self.assertFalse(roi["t1_eligible"])

    def test_keyframe_sampling_is_deterministic(self) -> None:
        self.assertEqual(keyframe_indices(10, 3), [0, 5, 9])
        self.assertEqual(keyframe_indices(2, 3), [0, 1])
        self.assertEqual(keyframe_indices(0, 3), [])

    def test_hashes_cache_and_contact_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = root / "a.png"
            second = root / "b.png"
            Image.new("RGBA", (8, 8), (255, 0, 0, 255)).save(first)
            Image.new("RGBA", (8, 8), (0, 255, 0, 255)).save(second)

            cache_path = root / "hash-cache.json"
            cache = HashCache(cache_path)
            metadata = hash_metadata([first, second], {"b": 2, "a": 1}, {"mode": "single"}, cache)
            cache.save()
            reloaded = HashCache(cache_path)
            self.assertEqual(metadata["asset_hash"][first.resolve().as_posix()], reloaded.asset_hash(first))
            self.assertEqual(scene_config_hash({"a": 1, "b": 2}), scene_config_hash({"b": 2, "a": 1}))
            self.assertEqual(qa_case_hash({"mode": "single"}), metadata["qa_case_hash"])

            sheet = root / "contact.png"
            result = create_contact_sheet([second, first], sheet, columns=2)
            self.assertEqual(result["count"], 2)
            self.assertTrue(sheet.exists())
            with Image.open(sheet) as rendered:
                self.assertGreater(rendered.width, 0)

    def test_planner_exposes_v13_metadata_only(self) -> None:
        planner = Path(__file__).resolve().parent / "capture_asset_test_scene.lua"
        text = planner.read_text(encoding="utf-8")
        for field in ("PLANNER_VERSION", "SCREENSHOT_BUDGET", "ROI_POLICY", "SKIP_STATUSES",
                      "asset_hash", "scene_config_hash", "qa_case_hash", "qa_case", "state",
                      "asset_refs", "scene_config_ref"):
            self.assertIn(field, text)


if __name__ == "__main__":
    unittest.main(verbosity=2)

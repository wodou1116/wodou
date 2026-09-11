"""Tests for the Demo 0.3 T2 deterministic capture preparation."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".codex" / "skills" / "asset-qa" / "scripts"))
sys.path.insert(0, str(ROOT / "scripts" / "qa"))

from prepare_t2 import prepare_report  # noqa: E402
from qa_tooling import HashCache, expand_roi, keyframe_indices, qa_case_hash, scene_config_hash  # noqa: E402


class T2PreparationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.case_path = ROOT / "qa" / "cases" / "T2" / "demo-0.3_t2_cases.json"
        cls.cache_path = ROOT / "qa" / "reports" / "latest" / "hash_cache.json"
        cls.scene_path = ROOT / "scenes" / "qa" / "AssetReadabilityTestScene.lua"
        with tempfile.TemporaryDirectory() as temporary:
            cls.report = prepare_report(ROOT, Path(temporary) / "t2_preparation.json")

    def test_all_cases_are_pending_and_cover_required_matrix(self) -> None:
        report = self.report
        self.assertEqual(report["status"], "PENDING_CAPTURE")
        self.assertEqual(report["summary"]["total_cases"], 15)
        self.assertEqual(report["summary"]["pending_capture"], 15)
        self.assertEqual(report["summary"]["captured"], 0)
        self.assertFalse(report["summary"]["score_available"])
        self.assertEqual(report["summary"]["pass_count"], 0)
        self.assertEqual(
            set(report["coverage"]["target_asset_ids"]),
            {"A-11", "A-12", "A-13"},
        )
        self.assertEqual(
            set(report["coverage"]["dimensions"]),
            {
                "attack_state_recognition",
                "combat_presence",
                "ground_vfx_conflict",
                "player_readability",
                "wheel_separation",
            },
        )

        for case in report["cases"]:
            self.assertEqual(case["status"], "PENDING_CAPTURE")
            self.assertEqual(case["visual_review_status"], "PENDING_CAPTURE")
            self.assertEqual(case["next_gate"], "PENDING_CAPTURE")
            self.assertEqual(case["seed"], 20260911)
            self.assertTrue(case["freeze"])
            self.assertEqual(case["camera"], {
                "space": "design_1920x1080",
                "x": 960,
                "y": 540,
                "zoom": 1.0,
            })
            self.assertEqual(case["entity_positions"]["player"], {"x": 960, "y": 640})
            self.assertIn(case["enemy_id"], {"jiuweihu", "bifang", "kui"})
            self.assertEqual(case["screenshot_budget"]["max_per_motion"], 3)
            self.assertEqual(case["keyframe_sampling"]["indices"], [0, 1, 2])
            self.assertLessEqual(len(case["keyframe_sampling"]["captured_frames"]), 3)
            self.assertEqual(case["roi"]["roi"], None)
            self.assertGreaterEqual(case["roi"]["roi_scale"], 1.5)
            self.assertLessEqual(case["roi"]["roi_scale"], 2.0)
            self.assertEqual(case["contact_sheet"]["source_frames"], [])
            self.assertIsNone(case["contact_sheet"]["output"])
            self.assertEqual(case["captured_frames"], [])
            for score_field in ("vision_score", "metric_score", "final_score", "grade", "confidence"):
                self.assertIsNone(case[score_field], score_field)
            self.assertEqual(case["qa_case_hash"], qa_case_hash(case["qa_case"]))
            self.assertTrue(case["asset_hash"])

    def test_scene_and_hash_cache_provenance_are_recorded_without_writes(self) -> None:
        before_bytes = self.cache_path.read_bytes()
        before_mtime = self.cache_path.stat().st_mtime_ns
        with tempfile.TemporaryDirectory() as temporary:
            prepare_report(ROOT, Path(temporary) / "t2_preparation.json")
        self.assertEqual(self.cache_path.read_bytes(), before_bytes)
        self.assertEqual(self.cache_path.stat().st_mtime_ns, before_mtime)
        self.assertEqual(
            self.report["scene_config_hash"],
            scene_config_hash(self.scene_path),
        )
        self.assertTrue(self.report["hash_cache"]["read_only"])
        self.assertEqual(self.report["hash_cache"]["invalidation_fields"], ["size", "mtime_ns"])
        self.assertTrue(self.report["hash_cache"]["entries"])
        self.assertTrue(all("sha256" in item and "size" in item and "mtime_ns" in item
                            for item in self.report["hash_cache"]["entries"]))
        serialized = json.dumps(self.report, ensure_ascii=False)
        self.assertNotIn("E:/", serialized)
        self.assertNotIn("C:/", serialized)

    def test_existing_qa_tooling_contracts_are_used(self) -> None:
        self.assertEqual(keyframe_indices(3, 3), [0, 1, 2])
        self.assertEqual(keyframe_indices(10, 3), [0, 5, 9])
        self.assertEqual(expand_roi((100, 100, 100, 100), 1.5), (75, 75, 150, 150))
        self.assertEqual(expand_roi((100, 100, 100, 100), 2.0), (50, 50, 200, 200))
        with self.assertRaises(ValueError):
            expand_roi((100, 100, 100, 100), 1.49)

    def test_hash_cache_invalidates_on_mtime_or_size_change(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.bin"
            cache_path = root / "hash-cache.json"
            source.write_bytes(b"aaa")
            cache = HashCache(cache_path)
            first = cache.asset_hash(source)
            cache.save()

            source.write_bytes(b"bbb")
            stat = source.stat()
            os.utime(source, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1_000_000))
            reloaded = HashCache(cache_path)
            second = reloaded.asset_hash(source)
            self.assertNotEqual(first, second)

    def test_case_source_is_pending_before_generation(self) -> None:
        source = json.loads(self.case_path.read_text(encoding="utf-8"))
        self.assertEqual(source["status"], "PENDING_CAPTURE")
        self.assertFalse(source["evidence_policy"]["real_maker_motion_screenshots_available"])
        self.assertFalse(source["evidence_policy"]["scores_allowed"])
        self.assertFalse(source["evidence_policy"]["pass_allowed"])


if __name__ == "__main__":
    unittest.main(verbosity=2)

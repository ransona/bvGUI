from __future__ import annotations

import tempfile
import time
import unittest
from pathlib import Path

import h5py

from bvgui.timeline import TimelineConfig, TimelineRecorder


class TimelineTests(unittest.TestCase):
    def test_simulated_timeline_writes_hdf5(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            recorder = TimelineRecorder(TimelineConfig(chunk_size=200, sample_rate_hz=1000))
            status = recorder.start(exp_id="2026-04-01_01_TEST", output_dir=Path(tmpdir), backend_mode="simulated")
            self.assertTrue(status.running)
            time.sleep(0.5)
            status = recorder.stop()
            self.assertFalse(status.running)
            summary = recorder.summary()
            self.assertIsNotNone(summary)
            assert summary is not None
            with h5py.File(summary.file_path, "r") as handle:
                self.assertIn("data", handle)
                self.assertIn("time_s", handle)
                self.assertEqual(handle["data"].shape[1], 6)
                self.assertGreater(handle["data"].shape[0], 0)


if __name__ == "__main__":
    unittest.main()

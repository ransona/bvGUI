from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from bvgui.app import parse_build_feature_indexes, parse_build_values
from bvgui.config import load_machine_config
from bvgui.daq import DaqController
from bvgui.legacy_matlab import load_feature_catalog, load_protocol_from_mat
from bvgui.models import FeatureInstance, Protocol, Stimulus
from bvgui.protocol_io import load_protocol_json, save_protocol_json
from bvgui.runtime import (
    ExperimentRunner,
    build_complete_sequence,
    build_opto_experiment_params,
    parse_variables,
    resolve_protocol_variables,
    save_protocol_exports,
)


ROOT = Path("/home/adamranson/code/bvGUI")


class CoreTests(unittest.TestCase):
    def test_feature_catalog_loads(self) -> None:
        catalog = load_feature_catalog(ROOT / "configs" / "ar-lab-tl1" / "features")
        names = {item.name for item in catalog}
        self.assertIn("grating", names)
        self.assertIn("opto_2p", names)

    def test_legacy_mat_protocol_conversion_round_trip(self) -> None:
        protocol = load_protocol_from_mat(ROOT / "configs" / "ar-lab-tl1" / "stimsets" / "eye_cam_test.mat")
        self.assertEqual(len(protocol.stimuli), 1)
        self.assertEqual(len(protocol.stimuli[0].features), 2)
        with tempfile.TemporaryDirectory() as tmpdir:
            json_path = Path(tmpdir) / "converted.json"
            save_protocol_json(protocol, json_path)
            reloaded = load_protocol_json(json_path)
        self.assertEqual(len(reloaded.stimuli), 1)
        self.assertEqual(reloaded.stimuli[0].features[0].type, protocol.stimuli[0].features[0].type)

    def test_variable_resolution_and_sequence(self) -> None:
        protocol = load_protocol_from_mat(ROOT / "configs" / "ar-lab-tl1" / "stimsets" / "teststim.mat")
        protocol.variables = "xpos=25;ypos=10"
        protocol.stimuli[0].features[0].params["x"] = "xpos"
        protocol.stimuli[0].features[0].params["y"] = "ypos"
        protocol.sequence_repeats = "3"
        resolved = resolve_protocol_variables(protocol)
        self.assertEqual(resolved.stimuli[0].features[0].params["x"], "25")
        self.assertEqual(resolved.stimuli[0].features[0].params["y"], "10")
        self.assertEqual(build_complete_sequence(resolved), [1, 1, 1])

    def test_exports_are_written(self) -> None:
        protocol = load_protocol_from_mat(ROOT / "configs" / "ar-lab-tl1" / "stimsets" / "teststim.mat")
        with tempfile.TemporaryDirectory() as tmpdir:
            artifacts = save_protocol_exports(protocol, Path(tmpdir), "2026-04-01_01_TEST", [1, 1], [1.0, 1.0])
            self.assertTrue(artifacts.stim_mat_path.exists())
            self.assertTrue(artifacts.stim_order_csv_path.exists())
            self.assertTrue(artifacts.stim_csv_path.exists())
            self.assertTrue(artifacts.all_trials_csv_path.exists())

    def test_parse_variables(self) -> None:
        parsed = parse_variables("a=1;b = hello ; ignoreme")
        self.assertEqual(parsed["a"], "1")
        self.assertEqual(parsed["b"], "hello")

    def test_runner_honors_abort_check(self) -> None:
        config = load_machine_config()
        catalog = load_feature_catalog(config.features_dir)
        protocol = load_protocol_from_mat(ROOT / "configs" / "ar-lab-tl1" / "stimsets" / "teststim.mat")
        runner = ExperimentRunner(config, catalog, lambda message: None)
        runner.bonvision_backend_mode = "simulated"
        runner.timeline_backend_mode = "simulated"
        runner.abort_check = lambda: True
        with self.assertRaisesRegex(RuntimeError, "Run aborted by user."):
            runner.run(protocol, "TEST", [], test_mode=True)

    def test_parse_build_helpers(self) -> None:
        self.assertEqual(parse_build_feature_indexes("[1, 2]"), [1, 2])
        self.assertEqual(parse_build_values("1,2,3"), [1.0, 2.0, 3.0])
        self.assertEqual(parse_build_values("1:0.5:2"), [1.0, 1.5, 2.0])

    def test_daq_stop_entries_uses_reverse_order(self) -> None:
        config = load_machine_config()
        calls: list[tuple[str, str]] = []

        class RecordingDaqController(DaqController):
            def _discover_entries(self):
                from bvgui.models import DaqEntry

                return [
                    DaqEntry(name="daq01_EYEPY", start_script=Path("a"), stop_script=Path("a")),
                    DaqEntry(name="daq02_SI1", start_script=Path("b"), stop_script=Path("b")),
                    DaqEntry(name="daq03_SI2", start_script=Path("c"), stop_script=Path("c")),
                ]

            def _run_entry(self, entry, action: str, exp_id: str) -> None:
                calls.append((action, entry.name))

        controller = RecordingDaqController(config, lambda message: None)
        controller.stop_entries(controller.entries, "2026-04-01_00_TEST")
        self.assertEqual(
            calls,
            [
                ("stop", "daq03_SI2"),
                ("stop", "daq02_SI1"),
                ("stop", "daq01_EYEPY"),
            ],
        )

    def test_build_opto_experiment_params(self) -> None:
        protocol = Protocol(
            stimuli=[
                Stimulus(
                    reps=10,
                    features=[FeatureInstance(type="opto_2p", params={"schema_name": "default2", "seq_number": "0"})],
                ),
                Stimulus(
                    reps=10,
                    features=[FeatureInstance(type="opto_2p", params={"schema_name": "default2", "seq_number": "1"})],
                ),
            ]
        )
        payload = build_opto_experiment_params("2026-05-07_06_TEST", protocol)
        self.assertIsNotNone(payload)
        assert payload is not None
        self.assertEqual(payload["action"], "update_experiment_params")
        self.assertEqual(payload["expID"], "2026-05-07_06_TEST")
        self.assertEqual(len(payload["stimulus_conditions"]), 2)
        self.assertEqual(payload["stimulus_conditions"][0]["stimulus_id"], 1)
        self.assertEqual(payload["stimulus_conditions"][0]["reps"], 10)
        self.assertEqual(payload["stimulus_conditions"][0]["features"][0]["params"]["seq_num"], 0)
        self.assertEqual(payload["stimulus_conditions"][1]["features"][0]["params"]["seq_num"], 1)

    def test_build_opto_experiment_params_requires_opto_for_all_conditions(self) -> None:
        protocol = Protocol(
            stimuli=[
                Stimulus(
                    reps=1,
                    features=[FeatureInstance(type="opto_2p", params={"schema_name": "default2", "seq_number": "0"})],
                ),
                Stimulus(
                    reps=1,
                    features=[FeatureInstance(type="grating", params={"duration": "1", "onset": "0"})],
                ),
            ]
        )
        with self.assertRaisesRegex(ValueError, "Online Analysis v1 requires every stimulus condition"):
            build_opto_experiment_params("2026-05-07_06_TEST", protocol)


if __name__ == "__main__":
    unittest.main()

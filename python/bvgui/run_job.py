from __future__ import annotations

import argparse
import json
import signal
import sys
from pathlib import Path

from .config import load_machine_config
from .legacy_matlab import load_feature_catalog
from .protocol_io import load_protocol_json
from .runtime import ExperimentRunner


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run a bvGUI experiment job in a subprocess.")
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--animal-id", required=True)
    parser.add_argument("--comment", default="")
    parser.add_argument("--bv-server", default="")
    parser.add_argument("--timeline-backend", default="simulated")
    parser.add_argument("--bonvision-backend", default="real")
    parser.add_argument("--timeline-output-override", default="")
    parser.add_argument("--pre-blank-s", default="0")
    parser.add_argument("--pause-after-preload-s", default="0.5")
    parser.add_argument("--test-mode", action="store_true")
    parser.add_argument("--selected-stimuli", default="")
    parser.add_argument("--enabled-daqs", default="")
    parser.add_argument("--abort-file", default="")
    args = parser.parse_args(argv)

    config = load_machine_config()
    catalog = load_feature_catalog(config.features_dir)
    protocol = load_protocol_json(args.protocol)
    log_lines: list[str] = []

    def logger(message: str) -> None:
        log_lines.append(message)
        print(message, flush=True)

    runner = ExperimentRunner(config, catalog, logger)
    if args.bv_server.strip():
        runner.config.bv_server = args.bv_server.strip()
    runner.timeline_backend_mode = args.timeline_backend
    runner.bonvision_backend_mode = args.bonvision_backend
    runner.timeline_output_override = args.timeline_output_override
    abort_path = Path(args.abort_file) if args.abort_file else None
    runner.abort_check = (lambda: abort_path is not None and abort_path.exists())
    enabled_daqs = [item for item in args.enabled_daqs.split(",") if item]
    selected_stimuli = [int(item) for item in args.selected_stimuli.split(",") if item]

    def _handle_signal(signum, frame) -> None:  # pragma: no cover - signal delivery is platform dependent
        runner.request_abort()

    for signum in (signal.SIGTERM, signal.SIGINT):
        try:
            signal.signal(signum, _handle_signal)
        except Exception:
            pass

    try:
        artifacts = runner.run(
            protocol,
            args.animal_id,
            enabled_daqs,
            comment=args.comment,
            pre_blank_s=float(args.pre_blank_s),
            pause_after_preload_s=float(args.pause_after_preload_s),
            test_mode=args.test_mode,
            selected_stimuli=selected_stimuli or None,
        )
        payload = {
            "ok": True,
            "exp_dir": str(artifacts.exp_dir),
            "exp_id": artifacts.exp_id,
            "test_mode": args.test_mode,
            "logs": log_lines,
        }
        print(json.dumps(payload), flush=True)
        return 0
    except Exception as exc:
        aborted = str(exc) == "Run aborted by user."
        payload = {
            "ok": False,
            "aborted": aborted,
            "error_type": type(exc).__name__,
            "error": str(exc),
            "exp_dir": str(runner.last_exp_dir) if runner.last_exp_dir else "",
            "exp_id": runner.last_exp_id,
            "test_mode": args.test_mode,
            "logs": log_lines,
        }
        print(json.dumps(payload), flush=True)
        return 0 if aborted else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

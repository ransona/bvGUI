from __future__ import annotations

import ast
import csv
import json
import random
import socket
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path, PureWindowsPath
from typing import Callable

from scipy.io import savemat

from .config import load_machine_config
from .daq import DaqController
from .models import FeatureDefinition, MachineConfig, Protocol, RunArtifacts, Stimulus
from .osc import OscClient, RigClient


LogFn = Callable[[str], None]


def new_exp_id(animal_id: str) -> str:
    safe_animal = "".join(ch if ch.isalnum() or ch in ("_", "-") else "_" for ch in animal_id.strip() or "TEST")
    return time.strftime("%Y-%m-%d_%H_") + safe_animal


def parse_variables(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_item in text.split(";"):
        item = raw_item.strip()
        if not item:
            continue
        if "=" not in item:
            continue
        name, raw_value = item.split("=", 1)
        values[name.strip()] = raw_value.strip()
    return values


def _safe_eval_numeric(expr: str) -> list[float]:
    parsed = ast.literal_eval(expr)
    if isinstance(parsed, (int, float)):
        return [float(parsed)]
    if isinstance(parsed, (list, tuple)):
        return [float(item) for item in parsed]
    raise ValueError(f"Unsupported numeric expression: {expr}")


def build_complete_sequence(protocol: Protocol) -> list[int]:
    seq_reps = int(float(protocol.sequence_repeats or "1"))
    sequence: list[int] = []
    for _ in range(seq_reps):
        single_rep: list[int] = []
        for index, stim in enumerate(protocol.stimuli, start=1):
            single_rep.extend([index] * max(1, int(stim.reps)))
        if protocol.randomize:
            random.shuffle(single_rep)
        sequence.extend(single_rep)
    return sequence


def build_iti_sequence(protocol: Protocol, trial_count: int) -> list[float]:
    values = _safe_eval_numeric(protocol.iti)
    if len(values) == 1:
        return [values[0]] * trial_count
    lo = min(values)
    hi = max(values)
    result = [lo + (hi - lo) * index / max(trial_count - 1, 1) for index in range(trial_count)]
    random.shuffle(result)
    return result


def resolve_protocol_variables(protocol: Protocol) -> Protocol:
    # Variable substitution mirrors the MATLAB workflow where parameter cell values
    # can reference names defined in the semicolon-delimited variables field.
    resolved = protocol.clone()
    variables = parse_variables(protocol.variables)
    for stim in resolved.stimuli:
        for feature in stim.features:
            for key, value in list(feature.params.items()):
                if value in variables:
                    feature.params[key] = variables[value]
    return resolved


def protocol_to_legacy_struct(protocol: Protocol, stim_order: list[int], iti_seq: list[float], exp_id: str) -> dict:
    stims_payload = []
    for stimulus in protocol.stimuli:
        features_payload = []
        for feature in stimulus.features:
            params = list(feature.params.keys())
            vals = [feature.params[param] for param in params]
            features_payload.append({"vals": vals, "params": params, "name": feature.type})
        stims_payload.append({"features": features_payload, "reps": stimulus.reps})
    return {
        "expDat": {
            "expID": exp_id,
            "stimOrder": stim_order,
            "stims": stims_payload,
            "itiSeq": iti_seq,
        }
    }


def save_protocol_exports(protocol: Protocol, output_dir: Path, exp_id: str, stim_order: list[int], iti_seq: list[float]) -> RunArtifacts:
    output_dir.mkdir(parents=True, exist_ok=True)
    stim_mat_path = output_dir / f"{exp_id}_stim.mat"
    savemat(stim_mat_path, protocol_to_legacy_struct(protocol, stim_order, iti_seq, exp_id), do_compression=False)

    max_features = max((len(stim.features) for stim in protocol.stimuli), default=0)
    feature_headers: list[str] = []
    grouped_headers: list[list[str]] = []
    for feature_index in range(max_features):
        headers = {"type"}
        for stim in protocol.stimuli:
            if len(stim.features) > feature_index:
                headers.update(stim.features[feature_index].params.keys())
        ordered = sorted(headers)
        grouped_headers.append(ordered)
        feature_headers.extend([f"F{feature_index + 1}_{name}" for name in ordered])

    stim_rows: list[list[str]] = []
    durations: list[str] = []
    for stim in protocol.stimuli:
        durations.append(str(stim.max_duration_s()))
        row: list[str] = []
        for feature_index in range(max_features):
            if len(stim.features) <= feature_index:
                row.extend(["NaN"] * len(grouped_headers[feature_index]))
                continue
            feature = stim.features[feature_index]
            for header in grouped_headers[feature_index]:
                row.append(feature.type if header == "type" else feature.params.get(header, "NaN"))
        stim_rows.append(row)

    stim_order_csv_path = output_dir / f"{exp_id}_stim_order.csv"
    with stim_order_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        for stim_index in stim_order:
            writer.writerow([stim_index])

    stim_csv_path = output_dir / f"{exp_id}_stim.csv"
    with stim_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["duration", *feature_headers])
        for duration, row in zip(durations, stim_rows):
            writer.writerow([duration, *row])

    all_trials_csv_path = output_dir / f"{exp_id}_all_trials.csv"
    with all_trials_csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["stim", "duration", *feature_headers])
        for stim_index in stim_order:
            zero_based = stim_index - 1
            writer.writerow([stim_index, durations[zero_based], *stim_rows[zero_based]])

    return RunArtifacts(
        exp_id=exp_id,
        exp_dir=output_dir,
        stim_mat_path=stim_mat_path,
        stim_order_csv_path=stim_order_csv_path,
        stim_csv_path=stim_csv_path,
        all_trials_csv_path=all_trials_csv_path,
    )


def send_udp_command(host: str, port: int, message: str, timeout_s: float = 10.0) -> str:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(timeout_s)
        sock.sendto(message.encode("utf-8"), (host, port))
        data, _ = sock.recvfrom(65535)
        return data.decode("utf-8", errors="replace")


def send_udp_json(host: str, port: int, payload: dict, timeout_s: float = 600.0) -> dict:
    encoded = json.dumps(payload).encode("utf-8")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(timeout_s)
        sock.sendto(encoded, (host, port))
        data, _ = sock.recvfrom(65535)
    return json.loads(data.decode("utf-8", errors="replace"))


def _bonvision_path(root: str, *parts: str) -> str:
    """Build a Bonvision-facing path string without leaking Linux local test paths."""
    cleaned_root = (root or "").strip()
    if not cleaned_root:
        return "/".join(parts)
    if cleaned_root.startswith("\\\\") or ":" in cleaned_root[:3]:
        path = PureWindowsPath(cleaned_root)
        for part in parts:
            path /= part
        return str(path).replace("\\", "/")
    base = Path(cleaned_root)
    for part in parts:
        base /= part
    return str(base).replace("\\", "/")


@dataclass
class OptoTrial:
    schema_name: str
    seq_num: int


@dataclass
class OptoCondition:
    stimulus_id: int
    reps: int
    schema_name: str
    seq_num: int


def collect_opto_trial(stimulus: Stimulus) -> OptoTrial | None:
    enabled: OptoTrial | None = None
    for feature in stimulus.features:
        if feature.type != "opto_2p":
            continue
        if feature.params.get("enable", "1").strip() not in ("", "1", "true", "True"):
            continue
        schema = feature.params.get("schema_name", "").strip()
        seq_num_text = feature.params.get("seq_number", "").strip()
        if not schema:
            raise ValueError("Missing schema_name in opto_2p feature.")
        if not seq_num_text:
            raise ValueError("Missing seq_number in opto_2p feature.")
        seq_num = int(float(seq_num_text))
        if enabled is not None and (enabled.schema_name != schema or enabled.seq_num != seq_num):
            raise ValueError("Only one enabled opto_2p configuration is allowed per stimulus.")
        enabled = OptoTrial(schema_name=schema, seq_num=seq_num)
    return enabled


def collect_opto_prep(sequence: list[int], protocol: Protocol) -> tuple[str, list[int]] | None:
    # The legacy app prepares all unique photostim sequences up front so trial-time
    # triggering is just a lightweight "ready/execute" command.
    schema_name: str | None = None
    seq_nums: list[int] = []
    for stim_index in sequence:
        opto = collect_opto_trial(protocol.stimuli[stim_index - 1])
        if opto is None:
            continue
        if schema_name is None:
            schema_name = opto.schema_name
        elif schema_name != opto.schema_name:
            raise ValueError(f"Conflicting opto_2p schema_name values: {schema_name} vs {opto.schema_name}")
        if opto.seq_num not in seq_nums:
            seq_nums.append(opto.seq_num)
    if schema_name is None:
        return None
    return schema_name, seq_nums


def collect_opto_conditions(protocol: Protocol) -> list[OptoCondition]:
    conditions: list[OptoCondition] = []
    any_opto = False
    for stim_index, stimulus in enumerate(protocol.stimuli, start=1):
        opto = collect_opto_trial(stimulus)
        if opto is None:
            continue
        any_opto = True
        conditions.append(
            OptoCondition(
                stimulus_id=stim_index,
                reps=int(stimulus.reps),
                schema_name=opto.schema_name,
                seq_num=opto.seq_num,
            )
        )
    if not any_opto:
        return []
    if len(conditions) != len(protocol.stimuli):
        raise ValueError("Online Analysis v1 requires every stimulus condition to contain exactly one enabled opto_2p feature.")
    return conditions


def build_opto_experiment_params(exp_id: str, protocol: Protocol) -> dict | None:
    conditions = collect_opto_conditions(protocol)
    if not conditions:
        return None
    return {
        "action": "update_experiment_params",
        "expID": exp_id,
        "stimulus_conditions": [
            {
                "stimulus_id": condition.stimulus_id,
                "reps": condition.reps,
                "features": [
                    {
                        "name": "opto_2p",
                        "params": {
                            "schema_name": condition.schema_name,
                            "seq_num": condition.seq_num,
                        },
                    }
                ],
            }
            for condition in conditions
        ],
    }


class ExperimentRunner:
    def __init__(self, config: MachineConfig, feature_catalog: list[FeatureDefinition], log: LogFn):
        self.config = config
        self.feature_catalog = feature_catalog
        self.log = log
        self._abort_requested = False
        self.abort_check: Callable[[], bool] | None = None
        self.last_exp_id = ""
        self.last_exp_dir: Path | None = None
        self.timeline_backend_mode = "nidaqmx"
        self.timeline_output_override = ""
        self.bonvision_backend_mode = "real"

    def request_abort(self) -> None:
        self._abort_requested = True

    def _check_abort(self) -> None:
        if self._abort_requested:
            raise RuntimeError("Run aborted by user.")
        if self.abort_check is not None and self.abort_check():
            self._abort_requested = True
            raise RuntimeError("Run aborted by user.")

    def _sleep_with_abort(self, duration_s: float, poll_s: float = 0.05) -> None:
        remaining = max(0.0, duration_s)
        while remaining > 0:
            self._check_abort()
            sleep_s = min(poll_s, remaining)
            time.sleep(sleep_s)
            remaining -= sleep_s

    def validate_protocol(self, protocol: Protocol) -> None:
        if not protocol.stimuli:
            raise ValueError("Protocol has no stimuli.")
        if int(float(protocol.sequence_repeats or "0")) <= 0:
            raise ValueError("Sequence repeats must be greater than zero.")
        for stim_index, stim in enumerate(protocol.stimuli, start=1):
            if stim.reps <= 0:
                raise ValueError(f"Stimulus {stim_index} has invalid reps value {stim.reps}.")
            collect_opto_trial(stim)
        collect_opto_prep(build_complete_sequence(protocol), protocol)

    def convert_protocol(self, protocol: Protocol) -> Protocol:
        self.validate_protocol(protocol)
        return resolve_protocol_variables(protocol)

    def run(self, protocol: Protocol, animal_id: str, enabled_daqs: list[str], comment: str = "", pre_blank_s: float = 0.0, pause_after_preload_s: float = 0.5, test_mode: bool = False, selected_stimuli: list[int] | None = None) -> RunArtifacts:
        resolved = self.convert_protocol(protocol)
        sequence = build_complete_sequence(resolved)
        if selected_stimuli is not None:
            sequence = list(selected_stimuli)
        if not sequence:
            raise ValueError("No trials selected to run.")
        iti_seq = build_iti_sequence(resolved, len(sequence))
        exp_id = new_exp_id("STIMTEST" if test_mode else animal_id)
        animal = exp_id[14:]
        local_exp_dir = self.config.local_save_root / animal / exp_id
        self.last_exp_id = exp_id
        self.last_exp_dir = local_exp_dir
        bonvision_exp_dir = _bonvision_path(self.config.local_save_root_raw, animal, exp_id)
        bonvision_local_root = _bonvision_path(self.config.local_save_root_raw)
        local_exp_dir.mkdir(parents=True, exist_ok=True)
        self.log(f"Starting experiment {exp_id}")
        self._check_abort()
        use_real_bonvision = self.bonvision_backend_mode == "real"
        if use_real_bonvision:
            response = send_udp_command(self.config.bv_server, 64645, f"mkdir {bonvision_exp_dir}")
            if response.strip() != "1":
                raise RuntimeError(f"Bonvision mkdir failed: {response}")
        else:
            self.log("Bonvision backend: simulated")

        started_daqs: list = []
        timeline_dir = Path(self.timeline_output_override) if self.timeline_output_override.strip() else None
        if timeline_dir is None:
            remote_root = Path(self.config.remote_save_root)
            if str(remote_root).startswith("\\\\") and not remote_root.exists():
                timeline_dir = local_exp_dir
            else:
                timeline_dir = remote_root / animal / exp_id
        daq_controller = DaqController(
            self.config,
            self.log,
            timeline_backend_mode=self.timeline_backend_mode,
            timeline_output_dir=timeline_dir,
        )
        opto_active = False
        osc = OscClient(self.config.bv_server, 4002, timeout_s=30) if use_real_bonvision else None
        rig = RigClient(osc) if osc is not None else SimulatedRigClient(self.log)
        try:
            rig.clear()
            rig.experiment("")
            if pre_blank_s > 0:
                self.log(f"Pre-blank pause {pre_blank_s:.2f}s")
                self._sleep_with_abort(pre_blank_s)

            opto_experiment_params = build_opto_experiment_params(exp_id, resolved)
            if opto_experiment_params is not None:
                self._update_experiment_params(opto_experiment_params)

            opto_prep = collect_opto_prep(sequence, resolved)
            if opto_prep:
                self._prepare_opto(exp_id, opto_prep[0], opto_prep[1])

            started_daqs = daq_controller.start_enabled(exp_id, enabled_daqs)
            rig.dataset(bonvision_local_root)
            if test_mode:
                all_resources = self._collect_all_resources(resolved)
                for resource in all_resources:
                    rig.resource(resource)
                rig.preload()
                self._sleep_with_abort(max(0.0, pause_after_preload_s))

            for trial_index, stim_index in enumerate(sequence, start=1):
                self._check_abort()
                stimulus = resolved.stimuli[stim_index - 1]
                self.log(f"Trial {trial_index}/{len(sequence)} stimulus {stim_index}")
                rig.clear()
                rig.experiment(exp_id)
                resources: list[str] = []

                opto = collect_opto_trial(stimulus)
                if opto:
                    self.log(
                        "Opto_2p trial routing: "
                        f"stim_index={stim_index} "
                        f"listener={self.config.opto2p_listener or '<unset>'} "
                        f"port={self.config.opto2p_port!s}"
                    )
                    self._start_opto_trial(stim_index - 1)
                    self._trigger_opto(exp_id, opto)
                    opto_active = True

                needs_default_grating = True
                go_nogo_payload: dict[str, str] | None = None
                vr_payload: dict[str, str] | None = None
                for feature in stimulus.features:
                    if feature.type in {"grating", "movie", "go_nogo"}:
                        needs_default_grating = False
                    if feature.type == "grating":
                        rig.grating(feature.params)
                    elif feature.type == "movie":
                        rig.video(feature.params)
                        resources.append(feature.params.get("name", ""))
                    elif feature.type == "go_nogo":
                        go_nogo_payload = feature.params
                    elif feature.type == "vr":
                        vr_payload = feature.params
                    elif feature.type == "opto":
                        self._trigger_opto_1p(feature.params)

                if needs_default_grating and opto:
                    rig.grating(
                        {
                            "angle": "0",
                            "width": "10",
                            "height": "10",
                            "x": "0",
                            "y": "-30",
                            "contrast": "0",
                            "opacity": "1",
                            "phase": "0",
                            "freq": "0.01",
                            "speed": "0",
                            "dcycle": "1",
                            "onset": "0",
                            "duration": "0.5",
                        }
                    )

                for resource in sorted(set(resources)):
                    rig.resource(resource)
                if not test_mode or resources:
                    rig.preload()
                    self._sleep_with_abort(max(0.0, pause_after_preload_s))

                if go_nogo_payload:
                    rig.success()
                    if go_nogo_payload.get("go", "0") in ("1", "true", "True"):
                        rig.pulse_valve()
                        rig.go(
                            float(go_nogo_payload.get("suppress_duration", "0")),
                            float(go_nogo_payload.get("response_start", "0")),
                            float(go_nogo_payload.get("response_duration", "0")),
                            int(float(go_nogo_payload.get("lick_threshold", "0"))),
                        )
                    else:
                        rig.nogo(
                            float(go_nogo_payload.get("suppress_duration", "0")),
                            float(go_nogo_payload.get("response_start", "0")),
                            float(go_nogo_payload.get("response_duration", "0")),
                            int(float(go_nogo_payload.get("lick_threshold", "0"))),
                        )
                elif vr_payload:
                    self._run_vr_command(vr_payload)
                else:
                    rig.start()

                if use_real_bonvision and osc is not None:
                    try:
                        osc.receive()
                    except Exception:
                        # The original MATLAB app blocks until a datagram arrives. For bench testing without a live
                        # Bonvision endpoint, a timeout should not prevent saving the protocol outputs.
                        self.log("No Bonvision completion datagram received before timeout.")
                else:
                    self._sleep_with_abort(max(stimulus.max_duration_s(), 0.1))

                if opto:
                    self._wait_for_opto_idle()
                self._sleep_with_abort(max(0.0, iti_seq[trial_index - 1]))

            if use_real_bonvision:
                remote_path = f"{self.config.remote_save_root}\\{animal}\\{exp_id}".replace("\\", "/")
                response = send_udp_command(self.config.bv_server, 64645, f"sync {bonvision_exp_dir} {remote_path}")
                if response.strip() != "1":
                    self.log(f"Bonvision sync failed: {response}")

            artifacts = save_protocol_exports(resolved, local_exp_dir, exp_id, sequence, iti_seq)
            self._write_log(local_exp_dir / "exp_log.txt", exp_id, comment)
            self._hash_outputs(local_exp_dir)
            return artifacts
        finally:
            try:
                rig.clear()
                rig.experiment("")
            except Exception:
                pass
            if opto_active:
                try:
                    self._abort_opto()
                except Exception as exc:
                    self.log(f"abort_photo_stim failed: {exc}")
            if started_daqs:
                daq_controller.stop_entries(started_daqs, exp_id)
            if osc is not None:
                osc.close()
            self._abort_requested = False

    def _collect_all_resources(self, protocol: Protocol) -> list[str]:
        resources: list[str] = []
        for stimulus in protocol.stimuli:
            for feature in stimulus.features:
                if feature.type == "movie":
                    resource = feature.params.get("name", "").strip()
                    if resource:
                        resources.append(resource)
        return sorted(set(resources))

    def _update_experiment_params(self, payload: dict) -> None:
        if not self.config.opto2p_listener or not self.config.opto2p_port:
            raise RuntimeError("Opto_2p is referenced by the protocol but not configured in bvGUI.ini.")
        reply = send_udp_json(self.config.opto2p_listener, self.config.opto2p_port, payload)
        if reply.get("status") != "ready":
            raise RuntimeError(f"update_experiment_params failed: {reply}")
        self.log(f"Updated opto_2p experiment params for {len(payload.get('stimulus_conditions', []))} stimulus conditions")

    def _start_opto_trial(self, trial_index: int) -> None:
        if not self.config.opto2p_listener or not self.config.opto2p_port:
            raise RuntimeError("Opto_2p is referenced by the protocol but not configured in bvGUI.ini.")
        payload = {"action": "start_trial", "trial_index": trial_index}
        self.log(
            "Sending opto_2p start_trial: "
            f"listener={self.config.opto2p_listener} "
            f"port={self.config.opto2p_port} "
            f"payload={payload}"
        )
        reply = send_udp_json(
            self.config.opto2p_listener,
            self.config.opto2p_port,
            payload,
        )
        self.log(f"Opto_2p start_trial reply: {reply}")
        if reply.get("status") != "ready":
            raise RuntimeError(f"start_trial failed: {reply}")

    def _trigger_opto(self, exp_id: str, opto: OptoTrial) -> None:
        if not self.config.opto2p_listener or not self.config.opto2p_port:
            raise RuntimeError("Opto_2p is referenced by the protocol but not configured in bvGUI.ini.")
        reply = send_udp_json(
            self.config.opto2p_listener,
            self.config.opto2p_port,
            {"action": "trigger_photo_stim", "schema_name": opto.schema_name, "expID": exp_id, "seq_num": opto.seq_num},
        )
        if reply.get("status") != "ready":
            raise RuntimeError(f"Opto_2p trigger failed: {reply}")

    def _prepare_opto(self, exp_id: str, schema_name: str, seq_nums: list[int]) -> None:
        if not self.config.opto2p_listener or not self.config.opto2p_port:
            raise RuntimeError("Opto_2p is referenced by the protocol but not configured in bvGUI.ini.")
        reply = send_udp_json(
            self.config.opto2p_listener,
            self.config.opto2p_port,
            {"action": "prep_patterns", "schema_name": schema_name, "expID": exp_id, "seq_nums": seq_nums},
        )
        if reply.get("status") != "ready":
            raise RuntimeError(f"Opto_2p prep failed: {reply}")
        self.log(f"Prepared opto_2p schema {schema_name} for seq_nums {seq_nums}")

    def _wait_for_opto_idle(self) -> None:
        if not self.config.opto2p_listener or not self.config.opto2p_port:
            return
        while True:
            self._check_abort()
            reply = send_udp_json(self.config.opto2p_listener, self.config.opto2p_port, {"action": "check_idle"})
            if reply.get("status") != "ready":
                raise RuntimeError(f"check_idle failed: {reply}")
            if reply.get("idle"):
                return
            self._sleep_with_abort(float(reply.get("expected_idle_after_s", 0.25)) + 0.05)

    def _abort_opto(self) -> None:
        if not self.config.opto2p_listener or not self.config.opto2p_port:
            return
        reply = send_udp_json(self.config.opto2p_listener, self.config.opto2p_port, {"action": "abort_photo_stim"})
        if reply.get("status") != "ready":
            raise RuntimeError(f"abort_photo_stim failed: {reply}")

    def _trigger_opto_1p(self, params: dict[str, str]) -> None:
        if params.get("enable", "1") not in ("1", "true", "True"):
            return
        command = params.get("opto_command", "")
        if not command:
            return
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(5)
            sock.sendto(command.encode("utf-8"), ("158.109.210.169", 8888))

    def _run_vr_command(self, params: dict[str, str]) -> None:
        command = params.get("vr_command", "").strip()
        vr_name = params.get("vr_name", "").strip()
        if not command:
            self.log("VR trial requested but vr_command is empty.")
            return
        self.log(f"Starting VR: {vr_name}")
        try:
            subprocess.run(command, shell=True, check=True)
        except Exception as exc:
            raise RuntimeError(f"VR command failed: {exc}") from exc

    def _hash_outputs(self, exp_dir: Path) -> None:
        if not self.config.python_exe or not self.config.hash_script:
            self.log("Hashing skipped: python_exe or hash_script is not configured.")
            return
        if not Path(self.config.python_exe).exists():
            self.log(f"Hashing skipped: configured python_exe does not exist: {self.config.python_exe}")
            return
        if not Path(self.config.hash_script).exists():
            self.log(f"Hashing skipped: configured hash_script does not exist: {self.config.hash_script}")
            return
        try:
            subprocess.run(
                [self.config.python_exe, self.config.hash_script, str(exp_dir), "nas", "False"],
                check=True,
                capture_output=True,
                text=True,
            )
            self.log("Hashing complete.")
        except Exception as exc:
            self.log(f"Hashing failed: {exc}")

    def _write_log(self, path: Path, exp_id: str, comment: str) -> None:
        lines = [time.strftime("%Y-%m-%d %H:%M:%S"), exp_id]
        if comment:
            lines.append(comment)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")


class SimulatedRigClient:
    def __init__(self, log: LogFn):
        self.log = log

    def dataset(self, path: str) -> None:
        self.log(f"[sim-bv] dataset {path}")

    def experiment(self, exp_id: str) -> None:
        self.log(f"[sim-bv] experiment {exp_id}")

    def resource(self, path: str) -> None:
        self.log(f"[sim-bv] resource {path}")

    def preload(self) -> None:
        self.log("[sim-bv] preload")

    def clear(self) -> None:
        self.log("[sim-bv] clear")

    def start(self) -> None:
        self.log("[sim-bv] start")

    def success(self) -> None:
        self.log("[sim-bv] success")

    def pulse_valve(self) -> None:
        self.log("[sim-bv] pulseValve")

    def go(self, suppress: float, start: float, duration: float, threshold: int) -> None:
        self.log(f"[sim-bv] go suppress={suppress} start={start} duration={duration} threshold={threshold}")

    def nogo(self, suppress: float, start: float, duration: float, threshold: int) -> None:
        self.log(f"[sim-bv] nogo suppress={suppress} start={start} duration={duration} threshold={threshold}")

    def grating(self, params: dict[str, str]) -> None:
        self.log(f"[sim-bv] grating {params}")

    def video(self, params: dict[str, str]) -> None:
        self.log(f"[sim-bv] video {params}")


def load_default_context() -> tuple[MachineConfig, list[FeatureDefinition]]:
    config = load_machine_config()
    from .legacy_matlab import load_feature_catalog

    catalog = load_feature_catalog(config.features_dir)
    return config, catalog

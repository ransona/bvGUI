from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


def _stringify(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "1" if value else "0"
    return str(value)


@dataclass
class FeatureDefinition:
    name: str
    params: list[str]
    defaults: list[str]

    def make_feature(self) -> "FeatureInstance":
        values = {param: default for param, default in zip(self.params, self.defaults)}
        return FeatureInstance(type=self.name, params=values)


@dataclass
class FeatureInstance:
    type: str
    params: dict[str, str] = field(default_factory=dict)

    def clone(self) -> "FeatureInstance":
        return FeatureInstance(type=self.type, params=dict(self.params))

    def duration_s(self) -> float:
        onset = self.params.get("onset")
        duration = self.params.get("duration")
        if onset is None or duration is None:
            return 0.0
        try:
            return float(onset) + float(duration)
        except (TypeError, ValueError):
            return 0.0


@dataclass
class Stimulus:
    reps: int = 1
    features: list[FeatureInstance] = field(default_factory=list)

    def clone(self) -> "Stimulus":
        return Stimulus(reps=self.reps, features=[feature.clone() for feature in self.features])

    def max_duration_s(self) -> float:
        return max((feature.duration_s() for feature in self.features), default=0.0)


@dataclass
class Protocol:
    schema_version: int = 1
    variables: str = ""
    iti: str = "1"
    sequence_repeats: str = "10"
    randomize: bool = True
    stimuli: list[Stimulus] = field(default_factory=list)
    source_path: str = ""

    def clone(self) -> "Protocol":
        return Protocol(
            schema_version=self.schema_version,
            variables=self.variables,
            iti=self.iti,
            sequence_repeats=self.sequence_repeats,
            randomize=self.randomize,
            stimuli=[stim.clone() for stim in self.stimuli],
            source_path=self.source_path,
        )

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        return payload

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "Protocol":
        stimuli = []
        for stim_payload in payload.get("stimuli", []):
            features = []
            for feature_payload in stim_payload.get("features", []):
                feature_type = feature_payload.get("type")
                if not feature_type:
                    raise ValueError("Feature is missing required field 'type'.")
                params = {str(key): _stringify(value) for key, value in feature_payload.get("params", {}).items()}
                features.append(FeatureInstance(type=str(feature_type), params=params))
            reps = int(stim_payload.get("reps", 1))
            stimuli.append(Stimulus(reps=reps, features=features))
        return cls(
            schema_version=int(payload.get("schema_version", 1)),
            variables=_stringify(payload.get("variables", "")),
            iti=_stringify(payload.get("iti", "1")),
            sequence_repeats=_stringify(payload.get("sequence_repeats", "10")),
            randomize=bool(payload.get("randomize", False)),
            stimuli=stimuli,
            source_path=_stringify(payload.get("source_path", "")),
        )


@dataclass
class MachineConfig:
    repo_root: Path
    machine_name: str
    machine_root: Path
    ini_path: Path
    features_dir: Path
    stimsets_dir: Path
    daq_start_dir: Path
    daq_stop_dir: Path
    bv_server: str
    local_save_root_raw: str
    local_save_root: Path
    remote_save_root: str
    python_exe: str
    hash_script: str
    opto2p_listener: str
    opto2p_port: int | None


@dataclass
class DaqEntry:
    name: str
    start_script: Path
    stop_script: Path | None
    enabled: bool = True


@dataclass
class TrialSpec:
    stimulus_index: int
    stimulus: Stimulus
    iti_s: float


@dataclass
class RunArtifacts:
    exp_id: str
    exp_dir: Path
    stim_mat_path: Path
    stim_order_csv_path: Path
    stim_csv_path: Path
    all_trials_csv_path: Path

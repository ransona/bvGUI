from __future__ import annotations

from pathlib import Path
from typing import Any

from scipy.io import loadmat

from .models import FeatureDefinition, FeatureInstance, Protocol, Stimulus


def _to_sequence(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return list(value)
    if hasattr(value, "tolist"):
        maybe = value.tolist()
        if isinstance(maybe, list):
            return maybe
    if getattr(value, "__class__", None).__name__ == "ndarray":
        return list(value.flat)
    return [value]


def _to_text(value: Any) -> str:
    if value is None:
        return ""
    if getattr(value, "size", None) == 0:
        return ""
    if hasattr(value, "item"):
        try:
            value = value.item()
        except Exception:
            pass
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def load_feature_definition(mat_path: str | Path) -> FeatureDefinition:
    data = loadmat(mat_path, squeeze_me=True, struct_as_record=False)
    feature_type = data["featureType"]
    path = Path(mat_path)
    params = [_to_text(item) for item in _to_sequence(getattr(feature_type, "params", []))]
    defaults = [_to_text(item) for item in _to_sequence(getattr(feature_type, "vals", []))]
    if len(defaults) < len(params):
        defaults.extend([""] * (len(params) - len(defaults)))
    return FeatureDefinition(name=path.stem, params=params, defaults=defaults)


def load_feature_catalog(features_dir: str | Path) -> list[FeatureDefinition]:
    catalog = []
    for mat_path in sorted(Path(features_dir).glob("*.mat")):
        catalog.append(load_feature_definition(mat_path))
    return catalog


def load_protocol_from_mat(mat_path: str | Path) -> Protocol:
    data = loadmat(mat_path, squeeze_me=True, struct_as_record=False)
    exp_data = data["expData"]
    protocol = Protocol(
        variables=_to_text(getattr(exp_data, "vars", "")),
        iti=_to_text(getattr(exp_data, "iti", "1")),
        sequence_repeats=_to_text(getattr(exp_data, "seqreps", "10")),
        randomize=False,
        source_path=str(mat_path),
    )
    stimuli = []
    for stim_raw in _to_sequence(getattr(exp_data, "stims", [])):
        reps = int(float(_to_text(getattr(stim_raw, "reps", 1)) or "1"))
        stimulus = Stimulus(reps=reps)
        for feature_raw in _to_sequence(getattr(stim_raw, "features", [])):
            feature_type = _to_text(getattr(feature_raw, "name", ""))
            params = [_to_text(item) for item in _to_sequence(getattr(feature_raw, "params", []))]
            values = [_to_text(item) for item in _to_sequence(getattr(feature_raw, "vals", []))]
            stimulus.features.append(
                FeatureInstance(
                    type=feature_type,
                    params={param: value for param, value in zip(params, values)},
                )
            )
        stimuli.append(stimulus)
    protocol.stimuli = stimuli
    return protocol

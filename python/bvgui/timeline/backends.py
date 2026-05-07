from __future__ import annotations

import math
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Protocol

import numpy as np

from .config import TimelineConfig


class AcquisitionBackend(Protocol):
    def start(self) -> None: ...
    def read_chunk(self, timeout_s: float) -> np.ndarray: ...
    def stop(self) -> None: ...
    def close(self) -> None: ...


def _import_nidaqmx():
    try:  # pragma: no cover - optional dependency in test/dev environments
        import nidaqmx
        from nidaqmx.constants import AcquisitionType, TerminalConfiguration

        return nidaqmx, AcquisitionType, TerminalConfiguration
    except Exception as exc:  # pragma: no cover - optional dependency in test/dev environments
        raise RuntimeError(f"Unable to import nidaqmx: {exc}") from exc


def nidaqmx_runtime_available() -> tuple[bool, str]:
    """Probe NI-DAQmx support in a subprocess so the GUI process never hard-crashes on import/init."""
    if os.name != "nt":
        return False, "NI-DAQmx hardware mode is only supported on Windows hosts."
    try:
        _import_nidaqmx()
    except RuntimeError as exc:
        return False, str(exc)
    probe = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import nidaqmx;"
                "task=nidaqmx.Task();"
                "task.close();"
                "print('OK')"
            ),
        ],
        capture_output=True,
        text=True,
        timeout=10,
    )
    if probe.returncode != 0:
        stderr = (probe.stderr or "").strip()
        stdout = (probe.stdout or "").strip()
        detail = stderr or stdout or f"probe failed with code {probe.returncode}"
        return False, f"NI-DAQmx runtime check failed: {detail}"
    return True, ""


@dataclass
class SimulatedBackend:
    config: TimelineConfig
    _sample_index: int = 0

    def start(self) -> None:
        self._sample_index = 0

    def read_chunk(self, timeout_s: float) -> np.ndarray:
        del timeout_s
        rate = float(self.config.sample_rate_hz)
        idx = np.arange(self.config.chunk_size, dtype=np.float64) + self._sample_index
        t = idx / rate
        chunk = np.column_stack(
            [
                ((np.sin(2 * math.pi * 2 * t) > 0).astype(np.float64) * 5.0),
                2.5 + 2.5 * np.sin(2 * math.pi * 1 * t),
                ((np.sin(2 * math.pi * 20 * t) > 0).astype(np.float64) * 3.0),
                ((np.sin(2 * math.pi * 4 * t) > 0).astype(np.float64) * 5.0),
                np.sin(2 * math.pi * 8 * t),
                np.sin(2 * math.pi * 12 * t),
            ]
        )
        self._sample_index += self.config.chunk_size
        time.sleep(self.config.chunk_size / rate)
        return chunk

    def stop(self) -> None:
        return

    def close(self) -> None:
        return


class NidaqmxBackend:
    def __init__(self, config: TimelineConfig):
        nidaqmx, AcquisitionType, TerminalConfiguration = _import_nidaqmx()
        self.config = config
        self.task = nidaqmx.Task()
        for channel in config.channels:
            physical = f"{config.device_name}/{channel.physical_channel}"
            ai = self.task.ai_channels.add_ai_voltage_chan(
                physical,
                min_val=channel.min_val,
                max_val=channel.max_val,
            )
            if channel.terminal_config and TerminalConfiguration is not None:
                ai.ai_term_cfg = getattr(TerminalConfiguration, channel.terminal_config)
        self.task.timing.cfg_samp_clk_timing(
            rate=config.sample_rate_hz,
            sample_mode=AcquisitionType.CONTINUOUS,
            samps_per_chan=config.chunk_size,
        )

    def start(self) -> None:
        self.task.start()

    def read_chunk(self, timeout_s: float) -> np.ndarray:
        data = self.task.read(
            number_of_samples_per_channel=self.config.chunk_size,
            timeout=timeout_s,
        )
        return np.asarray(data, dtype=np.float64).T

    def stop(self) -> None:
        try:
            self.task.stop()
        except Exception:
            pass

    def close(self) -> None:
        try:
            self.task.close()
        except Exception:
            pass


def create_backend(config: TimelineConfig, mode: str) -> AcquisitionBackend:
    selected = mode.lower()
    if selected == "simulated":
        return SimulatedBackend(config)
    if selected == "nidaqmx":
        available, reason = nidaqmx_runtime_available()
        if not available:
            raise RuntimeError(reason)
        return NidaqmxBackend(config)
    raise ValueError(f"Unsupported Timeline backend mode: {mode}")

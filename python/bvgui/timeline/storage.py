from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path

import h5py
import numpy as np

from .config import TimelineConfig


@dataclass
class TimelineRecordingSummary:
    exp_id: str
    file_path: Path
    sample_count: int
    duration_s: float
    channel_names: list[str]
    start_time_iso: str
    end_time_iso: str


class TimelineWriter:
    """Store Timeline samples incrementally in HDF5 instead of MATLAB structs."""

    def __init__(self, file_path: Path, config: TimelineConfig, exp_id: str):
        self.file_path = file_path
        self.config = config
        self.exp_id = exp_id
        self.file_path.parent.mkdir(parents=True, exist_ok=True)
        self.handle = h5py.File(self.file_path, "w")
        self.sample_count = 0
        self.start_time = datetime.now()
        self.data = self.handle.create_dataset(
            "data",
            shape=(0, len(config.channels)),
            maxshape=(None, len(config.channels)),
            dtype="f8",
            chunks=(config.chunk_size, len(config.channels)),
        )
        self.handle.attrs["exp_id"] = exp_id
        self.handle.attrs["sample_rate_hz"] = config.sample_rate_hz
        self.handle.attrs["channel_names_json"] = json.dumps(config.channel_names)
        self.handle.attrs["timeline_config_json"] = json.dumps(
            {
                "sample_rate_hz": config.sample_rate_hz,
                "chunk_size": config.chunk_size,
                "max_duration_minutes": config.max_duration_minutes,
                "device_name": config.device_name,
                "channels": [asdict(channel) for channel in config.channels],
            }
        )
        self.handle.attrs["start_time_iso"] = self.start_time.isoformat()

    def append(self, chunk: np.ndarray) -> None:
        rows = int(chunk.shape[0])
        end = self.sample_count + rows
        self.data.resize((end, chunk.shape[1]))
        self.data[self.sample_count:end, :] = chunk
        self.sample_count = end

    def finalize(self) -> TimelineRecordingSummary:
        end_time = datetime.now()
        time_axis = np.arange(self.sample_count, dtype=np.float64) / float(self.config.sample_rate_hz)
        self.handle.create_dataset("time_s", data=time_axis, dtype="f8")
        self.handle.attrs["end_time_iso"] = end_time.isoformat()
        self.handle.attrs["duration_s"] = float(self.sample_count) / float(self.config.sample_rate_hz)
        self.handle.flush()
        self.handle.close()
        return TimelineRecordingSummary(
            exp_id=self.exp_id,
            file_path=self.file_path,
            sample_count=self.sample_count,
            duration_s=float(self.sample_count) / float(self.config.sample_rate_hz),
            channel_names=self.config.channel_names,
            start_time_iso=self.start_time.isoformat(),
            end_time_iso=end_time.isoformat(),
        )

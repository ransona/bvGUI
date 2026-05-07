from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class ChannelSpec:
    name: str
    physical_channel: str
    min_val: float = -10.0
    max_val: float = 10.0
    terminal_config: str | None = "RSE"


@dataclass(frozen=True)
class TimelineConfig:
    sample_rate_hz: int = 1000
    chunk_size: int = 200
    max_duration_minutes: int = 180
    device_name: str = "Dev1"
    channels: tuple[ChannelSpec, ...] = field(
        default_factory=lambda: (
            ChannelSpec("MicroscopeFrames", "ai0"),
            ChannelSpec("Photodiode", "ai4"),
            ChannelSpec("EyeCamera", "ai1"),
            ChannelSpec("Bonvision", "ai5"),
            ChannelSpec("EPhys1", "ai2", terminal_config=None),
            ChannelSpec("EPhys2", "ai3", terminal_config=None),
        )
    )

    @property
    def channel_names(self) -> list[str]:
        return [channel.name for channel in self.channels]

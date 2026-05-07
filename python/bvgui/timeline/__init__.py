"""Integrated Timeline recorder for bvGUI."""

from .config import TimelineConfig
from .recorder import TimelineRecorder, TimelineStatus

_shared_timeline_recorder = TimelineRecorder(TimelineConfig())


def get_shared_timeline_recorder() -> TimelineRecorder:
    return _shared_timeline_recorder


__all__ = ["TimelineConfig", "TimelineRecorder", "TimelineStatus", "get_shared_timeline_recorder"]

from __future__ import annotations

import threading
import time
from dataclasses import dataclass
from pathlib import Path
from collections import deque

import numpy as np

from .backends import AcquisitionBackend, create_backend
from .config import TimelineConfig
from .storage import TimelineRecordingSummary, TimelineWriter


@dataclass
class TimelineStatus:
    running: bool
    exp_id: str = ""
    backend_mode: str = ""
    file_path: str = ""
    sample_count: int = 0
    sample_rate_hz: int = 0
    channel_names: list[str] | None = None
    started_at: float | None = None
    error: str = ""


class TimelineRecorder:
    """Threaded recorder that can be embedded directly inside bvGUI."""

    def __init__(self, config: TimelineConfig):
        self.config = config
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()
        self._lock = threading.Lock()
        self._backend: AcquisitionBackend | None = None
        self._writer: TimelineWriter | None = None
        self._summary: TimelineRecordingSummary | None = None
        self._recent_chunks: deque[np.ndarray] = deque()
        self._recent_max_samples = config.sample_rate_hz * 10
        self._status = TimelineStatus(running=False, sample_rate_hz=config.sample_rate_hz, channel_names=config.channel_names)

    def start(self, *, exp_id: str, output_dir: Path, backend_mode: str) -> TimelineStatus:
        with self._lock:
            if self._status.running:
                raise RuntimeError(f"Timeline is already running for {self._status.exp_id}")
            output_dir.mkdir(parents=True, exist_ok=True)
            file_path = output_dir / f"{exp_id}_Timeline.h5"
            self._backend = create_backend(self.config, backend_mode)
            self._writer = TimelineWriter(file_path, self.config, exp_id)
            self._summary = None
            self._stop_event.clear()
            self._status = TimelineStatus(
                running=True,
                exp_id=exp_id,
                backend_mode=backend_mode,
                file_path=str(file_path),
                sample_count=0,
                sample_rate_hz=self.config.sample_rate_hz,
                channel_names=self.config.channel_names,
                started_at=time.time(),
            )
            self._thread = threading.Thread(target=self._run_loop, daemon=True, name="bvgui-timeline")
            self._thread.start()
        return self.status()

    def _run_loop(self) -> None:
        assert self._backend is not None
        assert self._writer is not None
        try:
            self._backend.start()
            max_samples = self.config.max_duration_minutes * 60 * self.config.sample_rate_hz
            while not self._stop_event.is_set():
                chunk = self._backend.read_chunk(timeout_s=max(2.0, self.config.chunk_size / self.config.sample_rate_hz * 2))
                self._writer.append(chunk)
                with self._lock:
                    self._status.sample_count = self._writer.sample_count
                    self._recent_chunks.append(chunk.copy())
                    total = sum(part.shape[0] for part in self._recent_chunks)
                    while total > self._recent_max_samples and self._recent_chunks:
                        removed = self._recent_chunks.popleft()
                        total -= removed.shape[0]
                if self._writer.sample_count >= max_samples:
                    raise RuntimeError("Timeline reached the configured maximum duration.")
        except Exception as exc:
            with self._lock:
                self._status.error = str(exc)
        finally:
            try:
                self._backend.stop()
            except Exception:
                pass
            try:
                self._backend.close()
            except Exception:
                pass
            summary = self._writer.finalize() if self._writer is not None else None
            with self._lock:
                self._summary = summary
                self._status.running = False

    def stop(self) -> TimelineStatus:
        with self._lock:
            running = self._status.running
            thread = self._thread
            self._stop_event.set()
        if running and thread is not None:
            thread.join(timeout=10)
        return self.status()

    def status(self) -> TimelineStatus:
        with self._lock:
            return TimelineStatus(
                running=self._status.running,
                exp_id=self._status.exp_id,
                backend_mode=self._status.backend_mode,
                file_path=self._status.file_path,
                sample_count=self._status.sample_count,
                sample_rate_hz=self._status.sample_rate_hz,
                channel_names=list(self._status.channel_names or []),
                started_at=self._status.started_at,
                error=self._status.error,
            )

    def summary(self) -> TimelineRecordingSummary | None:
        with self._lock:
            return self._summary

    def recent_data(self) -> np.ndarray:
        with self._lock:
            if not self._recent_chunks:
                return np.zeros((0, len(self.config.channels)), dtype=np.float64)
            return np.vstack(list(self._recent_chunks))

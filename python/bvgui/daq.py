from __future__ import annotations

import socket
from pathlib import Path
from typing import Callable

from .models import DaqEntry, MachineConfig
from .timeline import get_shared_timeline_recorder


LogFn = Callable[[str], None]


class DaqError(RuntimeError):
    pass


class DaqController:
    def __init__(self, config: MachineConfig, log: LogFn, timeline_backend_mode: str = "nidaqmx", timeline_output_dir: Path | None = None):
        self.config = config
        self.log = log
        self.timeline_backend_mode = timeline_backend_mode
        self.timeline_output_dir = timeline_output_dir
        self.entries = self._discover_entries()
        self.timeline_recorder = get_shared_timeline_recorder()

    def _discover_entries(self) -> list[DaqEntry]:
        entries = []
        for start_script in sorted(self.config.daq_start_dir.glob("*.m")):
            suffix = start_script.name.replace("_start.m", "_stop.m")
            stop_script = self.config.daq_stop_dir / suffix
            entries.append(DaqEntry(name=start_script.stem.replace("_start", ""), start_script=start_script, stop_script=stop_script if stop_script.exists() else None))
        return entries

    def start_enabled(self, exp_id: str, enabled_names: list[str]) -> list[DaqEntry]:
        started = []
        enabled = {name for name in enabled_names}
        for entry in self.entries:
            if entry.name not in enabled:
                continue
            self.log(f"Starting DAQ {entry.name}")
            self._run_entry(entry, "start", exp_id)
            started.append(entry)
        return started

    def stop_entries(self, entries: list[DaqEntry], exp_id: str) -> None:
        for entry in reversed(entries):
            self.log(f"Stopping DAQ {entry.name}")
            try:
                self._run_entry(entry, "stop", exp_id)
            except Exception as exc:
                self.log(f"Error stopping {entry.name}: {exc}")

    def _run_entry(self, entry: DaqEntry, action: str, exp_id: str) -> None:
        if entry.name == "daq01_EYEPY":
            self._send_udp("158.109.214.78", 1813, f"{'GOGO' if action == 'start' else 'STOP'}*{exp_id}")
            return
        if entry.name == "daq02_SI1":
            self._send_udp("158.109.215.110", 1813, f"{'GOGO' if action == 'start' else 'STOP'}*{exp_id}")
            return
        if entry.name == "daq03_SI2":
            self._send_udp("158.109.209.18", 1821, f"{'GOGO' if action == 'start' else 'STOP'}*{exp_id}")
            return
        if entry.name == "daq00_TL":
            self._run_timeline(action, exp_id)
            return
        script = entry.start_script if action == "start" else entry.stop_script
        if script is None:
            raise DaqError(f"No {action} script for {entry.name}")
        raise DaqError(f"Unsupported DAQ script {script.name}")

    def _run_timeline(self, action: str, exp_id: str) -> None:
        if action == "start":
            output_dir = self.timeline_output_dir
            if output_dir is None:
                animal_id = exp_id[14:] if len(exp_id) > 14 else exp_id
                remote_path = Path(self.config.remote_save_root) / animal_id / exp_id
                output_dir = remote_path
            status = self.timeline_recorder.start(
                exp_id=exp_id,
                output_dir=output_dir,
                backend_mode=self.timeline_backend_mode,
            )
            self.log(f"Timeline started with backend {status.backend_mode} -> {status.file_path}")
        else:
            status = self.timeline_recorder.stop()
            summary = self.timeline_recorder.summary()
            if summary is not None:
                self.log(f"Timeline saved {summary.sample_count} samples to {summary.file_path}")
            elif status.error:
                raise DaqError(f"Timeline stopped with error: {status.error}")

    @staticmethod
    def _send_udp(host: str, port: int, message: str) -> None:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(5)
            sock.sendto(message.encode("utf-8"), (host, port))

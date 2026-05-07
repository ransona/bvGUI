from __future__ import annotations

import configparser
import os
import re
from pathlib import Path

from .models import MachineConfig


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def machine_name() -> str:
    for key in ("BVG_MACHINE", "COMPUTERNAME", "HOSTNAME"):
        value = os.environ.get(key, "").strip()
        if value:
            return value.lower()
    available = sorted(path.name for path in (repo_root() / "configs").iterdir() if path.is_dir())
    if "ar-lab-tl2" in available:
        return "ar-lab-tl2"
    if "ar-lab-tl1" in available:
        return "ar-lab-tl1"
    if available:
        return available[0]
    return "default"


def _resolve_path(base_root: Path, raw: str, default: str = "") -> Path:
    value = (raw or default).strip()
    if not value:
        return Path()
    if value.startswith("\\\\"):
        return Path(value)
    drive_match = re.match(r"^([A-Za-z]):[\\/]*(.*)$", value)
    if drive_match:
        if os.name == "nt":
            return Path(value)
        drive = drive_match.group(1).lower()
        rest = drive_match.group(2).replace("\\", "/").strip("/")
        path = base_root / "simulated_windows_paths" / drive
        if rest:
            path = path / Path(rest)
        return path
    path = Path(value)
    if path.is_absolute():
        return path
    return base_root / path


def load_machine_config(selected_machine: str | None = None) -> MachineConfig:
    root = repo_root()
    machine = (selected_machine or machine_name()).strip().lower()
    machine_root = root / "configs" / machine
    ini_path = machine_root / "bvGUI.ini"
    if not ini_path.exists():
        raise FileNotFoundError(f"Missing machine config: {ini_path}")

    parser = configparser.ConfigParser()
    parser.read(ini_path, encoding="utf-8")

    paths = parser["paths"] if parser.has_section("paths") else {}
    settings = parser["settings"] if parser.has_section("settings") else {}
    network = parser["network"] if parser.has_section("network") else {}

    local_default = r"c:\local_repository"
    remote_default = r"\\AR-LAB-NAS1\DataServer\Remote_Repository"

    opto_port_raw = str(network.get("opto_2p_port", "")).strip()
    opto_port = int(opto_port_raw) if opto_port_raw else None

    return MachineConfig(
        repo_root=root,
        machine_name=machine,
        machine_root=machine_root,
        ini_path=ini_path,
        features_dir=machine_root / "features",
        stimsets_dir=machine_root / "stimsets",
        daq_start_dir=machine_root / "daqStart",
        daq_stop_dir=machine_root / "daqStop",
        bv_server=str(settings.get("bv_server", "127.0.0.1")).strip(),
        local_save_root_raw=str(paths.get("local_save_root", local_default)).strip() or local_default,
        local_save_root=_resolve_path(root, str(paths.get("local_save_root", "")), local_default),
        remote_save_root=str(paths.get("remote_save_root", remote_default)).strip(),
        python_exe=str(paths.get("python_exe", "")).strip(),
        hash_script=str(paths.get("hash_script", "")).strip(),
        opto2p_listener=str(network.get("opto_2p_listener", "")).strip(),
        opto2p_port=opto_port,
    )


def save_machine_settings(config: MachineConfig, *, bv_server: str) -> None:
    parser = configparser.ConfigParser()
    parser.read(config.ini_path, encoding="utf-8")
    if not parser.has_section("settings"):
        parser.add_section("settings")
    parser.set("settings", "bv_server", bv_server.strip())
    with config.ini_path.open("w", encoding="utf-8") as handle:
        parser.write(handle)

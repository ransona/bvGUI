from __future__ import annotations

import json
import tempfile
from pathlib import Path

from .config import load_machine_config
from .protocol_io import save_protocol_json


def write_temp_protocol(protocol) -> Path:
    temp_dir = Path(tempfile.mkdtemp(prefix="bvgui_protocol_"))
    path = temp_dir / "protocol.json"
    save_protocol_json(protocol, path)
    return path


def new_temp_abort_file() -> Path:
    temp_dir = Path(tempfile.mkdtemp(prefix="bvgui_abort_"))
    return temp_dir / "abort.flag"

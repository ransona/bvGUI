from __future__ import annotations

import json
from pathlib import Path

from .models import Protocol


def save_protocol_json(protocol: Protocol, path: str | Path) -> Path:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(protocol.to_dict(), indent=2, sort_keys=False), encoding="utf-8")
    return target


def load_protocol_json(path: str | Path) -> Protocol:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    protocol = Protocol.from_dict(payload)
    protocol.source_path = str(path)
    return protocol

from __future__ import annotations

import socket
import struct
from dataclasses import dataclass
from typing import Any


def _pad_osc_string(value: str) -> bytes:
    data = value.encode("utf-8") + b"\x00"
    while len(data) % 4:
        data += b"\x00"
    return data


def _encode_arg(arg: Any) -> tuple[str, bytes]:
    if isinstance(arg, bool):
        arg = int(arg)
    if isinstance(arg, int):
        return "i", struct.pack(">i", arg)
    if isinstance(arg, float):
        return "f", struct.pack(">f", arg)
    return "s", _pad_osc_string(str(arg))


def encode_osc_message(address: str, *args: Any) -> bytes:
    tags = ","
    body = b""
    for arg in args:
        tag, encoded = _encode_arg(arg)
        tags += tag
        body += encoded
    return _pad_osc_string(address) + _pad_osc_string(tags) + body


@dataclass
class OscClient:
    host: str
    port: int
    timeout_s: float = 10.0

    def __post_init__(self) -> None:
        self.sock = socket.create_connection((self.host, self.port), timeout=self.timeout_s)
        self.sock.settimeout(self.timeout_s)
        self._pending_size = 0

    def send(self, address: str, *args: Any) -> None:
        message = encode_osc_message(address, *args)
        self.sock.sendall(struct.pack(">I", len(message)) + message)

    def receive(self) -> bytes:
        if self._pending_size == 0:
            header = self._recv_exact(4)
            self._pending_size = struct.unpack(">I", header)[0]
        payload = self._recv_exact(self._pending_size)
        self._pending_size = 0
        return payload

    def _recv_exact(self, size: int) -> bytes:
        chunks = []
        remaining = size
        while remaining > 0:
            chunk = self.sock.recv(remaining)
            if not chunk:
                raise ConnectionError("OSC connection closed unexpectedly.")
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)

    def close(self) -> None:
        try:
            self.sock.close()
        except Exception:
            pass


class RigClient:
    def __init__(self, osc: OscClient):
        self.osc = osc

    def dataset(self, path: str) -> None:
        self.osc.send("/dataset", path)

    def experiment(self, exp_id: str) -> None:
        self.osc.send("/experiment", exp_id)

    def resource(self, path: str) -> None:
        self.osc.send("/resource", path)

    def preload(self) -> None:
        self.osc.send("/preload", 0)

    def clear(self) -> None:
        self.osc.send("/clear", 0)

    def start(self) -> None:
        self.osc.send("/start", 0)

    def success(self) -> None:
        self.osc.send("/success", 0)

    def pulse_valve(self) -> None:
        self.osc.send("/pulseValve", 0)

    def go(self, suppress: float, start: float, duration: float, threshold: int) -> None:
        self.osc.send("/go", float(suppress), float(start), float(duration), int(threshold))

    def nogo(self, suppress: float, start: float, duration: float, threshold: int) -> None:
        self.osc.send("/nogo", float(suppress), float(start), float(duration), int(threshold))

    def grating(self, params: dict[str, str]) -> None:
        values = [
            float(params.get("angle", 0)),
            float(params.get("width", 20)),
            float(params.get("height", 20)),
            float(params.get("x", 0)),
            float(params.get("y", 0)),
            float(params.get("contrast", 1)),
            float(params.get("opacity", 1)),
            float(params.get("phase", 0)),
            float(params.get("freq", 0.1)),
            float(params.get("speed", 0)),
            float(params.get("dcycle", 1)),
            float(params.get("onset", 0)),
            float(params.get("duration", 1)),
        ]
        self.osc.send("/gratings", *values)

    def video(self, params: dict[str, str]) -> None:
        raw_name = str(params.get("name", ""))
        media_name = raw_name.replace("\\", "/").split("/")[-1]
        values = [
            float(params.get("angle", 0)),
            float(params.get("width", 20)),
            float(params.get("height", 20)),
            float(params.get("x", 0)),
            float(params.get("y", 0)),
            float(params.get("loop", 1)),
            float(params.get("speed", 30)),
            media_name,
            float(params.get("onset", 0)),
            float(params.get("duration", 1)),
        ]
        self.osc.send("/video", *values)

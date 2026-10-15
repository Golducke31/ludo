#!/usr/bin/env python3
"""gen_placeholder_audio.py - short muted placeholder SFX as WAV.

Writes assets/audio/sfx/<id>.wav (22050 Hz, mono, 16-bit) for:
  roll, move, capture, bonus, finish, portal, ui_click
Deliberately short and soft (placeholder until real audio ships in M4+).
Pure stdlib (wave + math): deterministic, no dependencies.
"""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "sfx"
RATE = 22050

# id: (seconds, [(freq_hz, start_frac, end_frac, type)...])
# type: sine | tri | square_soft
SFX = {
    "roll":      (0.18, [(180.0, 0.0, 0.35, "tri"), (240.0, 0.35, 0.7, "tri"), (320.0, 0.7, 1.0, "tri")]),
    "move":      (0.10, [(520.0, 0.0, 1.0, "sine")]),
    "capture":   (0.22, [(420.0, 0.0, 0.4, "tri"), (300.0, 0.4, 0.75, "tri"), (180.0, 0.75, 1.0, "tri")]),
    "bonus":     (0.24, [(660.0, 0.0, 0.5, "sine"), (880.0, 0.5, 1.0, "sine")]),
    "finish":    (0.36, [(523.0, 0.0, 0.3, "sine"), (659.0, 0.3, 0.6, "sine"), (784.0, 0.6, 1.0, "sine")]),
    "portal":    (0.20, [(220.0, 0.0, 1.0, "tri")]),
    "ui_click":  (0.05, [(700.0, 0.0, 1.0, "sine")]),
    "exit":      (0.18, [(784.0, 0.0, 0.5, "sine"), (1046.0, 0.5, 1.0, "sine")]),
}


def tone(kind: str, phase: float) -> float:
    if kind == "sine":
        return math.sin(phase)
    if kind == "tri":
        return 2.0 * abs(2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0) - 1.0
    return 1.0 if math.sin(phase) >= 0 else -1.0  # square_soft (low gain below)


def render(spec) -> bytes:
    secs, parts = spec
    n = int(secs * RATE)
    frames = bytearray()
    for i in range(n):
        t = i / RATE
        frac = i / max(n - 1, 1)
        v = 0.0
        for freq, f0, f1, kind in parts:
            if f0 <= frac <= f1:
                span = max(f1 - f0, 1e-6)
                # envelope: attack/decay inside the part
                env = min((frac - f0) / 0.15, (f1 - frac) / 0.25, 1.0)
                v += 0.33 * tone(kind, 2.0 * math.pi * freq * t) * max(env, 0.0)
        v = max(-1.0, min(1.0, v * 0.5))  # master limiter
        frames += struct.pack("<h", int(v * 32767))
    return bytes(frames)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for sid, spec in SFX.items():
        path = OUT / f"{sid}.wav"
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(render(spec))
        print(f"  {sid}.wav ({spec[0]:.2f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

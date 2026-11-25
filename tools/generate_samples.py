"""Generates the bundled sample tracks.

All audio is synthesized from scratch by this script (chord progressions rendered
with simple additive synthesis), so it is original and royalty-free.

Usage: python tools/generate_samples.py   (requires numpy)
"""
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"
SR = 44100


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tone(freq, dur, harmonics, attack=0.02, release=0.25):
    t = np.arange(int(SR * dur)) / SR
    wave_ = sum(a * np.sin(2 * np.pi * freq * (i + 1) * t) for i, a in enumerate(harmonics))
    env = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / release)
    return wave_ * env


def render(progression, bpm, bars, harmonics, bass_harmonics, arp):
    beat = 60 / bpm
    out = np.zeros(int(SR * beat * 4 * bars) + SR)
    for bar in range(bars):
        chord = progression[bar % len(progression)]
        start = bar * beat * 4
        bass = tone(note(chord[0] - 12), beat * 3.8, bass_harmonics, release=0.4)
        _mix(out, bass * 0.5, start)
        for i, m in enumerate(chord):
            _mix(out, tone(note(m), beat * 3.9, harmonics, attack=0.08, release=0.5) * 0.18, start)
        if arp:
            for step in range(8):
                m = chord[step % len(chord)] + 12
                _mix(out, tone(note(m), beat * 0.5, [1, 0.3], release=0.15) * 0.2, start + step * beat * 0.5)
    out = out[: int(SR * beat * 4 * bars)]
    out /= max(1e-9, np.max(np.abs(out)))
    return (out * 0.8 * 32767).astype(np.int16)


def _mix(buf, sig, start_sec):
    i = int(start_sec * SR)
    buf[i : i + len(sig)] += sig[: len(buf) - i]


TRACKS = [
    # (file, bpm, bars, progression (MIDI), harmonics, bass harmonics, arp, art colours)
    ("midnight_drive", 96, 16, [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]],
     [1, 0.4, 0.2], [1, 0.5], True, ((255, 94, 58), (24, 24, 32))),
    ("glass_garden", 72, 12, [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]],
     [1, 0.1, 0.05], [1, 0.2], True, ((255, 140, 66), (30, 40, 60))),
    ("low_tide", 64, 12, [[52, 55, 59], [48, 52, 55], [50, 53, 57], [47, 50, 54]],
     [1, 0.6, 0.3, 0.15], [1, 0.7, 0.3], False, ((255, 112, 67), (20, 30, 28))),
    ("neon_rain", 120, 16, [[62, 65, 69], [58, 62, 65], [55, 58, 62], [57, 60, 64]],
     [1, 0.3, 0.6, 0.2], [1, 0.4], True, ((255, 80, 80), (40, 20, 50))),
]


def main():
    AUDIO.mkdir(parents=True, exist_ok=True)
    for name, bpm, bars, prog, h, bh, arp, colours in TRACKS:
        pcm = render(prog, bpm, bars, h, bh, arp)
        with wave.open(str(AUDIO / f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        print(f"{name}: {len(pcm) / SR:.1f}s")


if __name__ == "__main__":
    main()

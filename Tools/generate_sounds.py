#!/usr/bin/env python3
"""Generate Blaze's procedural sound set as small mono WAV files.

Pure stdlib (wave/math/random). Each sound matches a design-system moment:
  quest_complete — soft whoosh + crackle
  streak_up      — warm rising chime
  milestone      — bigger fanfare arpeggio
  freeze         — cool descending two-tone
  burnout        — low ember fade
  revival        — rising sweep into a bright chord

Usage: python3 Tools/generate_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "Blaze", "Sounds")
random.seed(7)


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.72 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
            for s in samples
        )
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples) / RATE:.2f}s)")


def env(i, n, attack=0.02, release=0.4):
    """Attack/decay envelope over n samples."""
    t = i / n
    a = min(1.0, (i / RATE) / max(attack, 1e-4))
    r = (1.0 - t) ** (1.0 / max(release, 1e-3))
    return a * r


def tone(freq, dur, harmonics=((1, 1.0), (2, 0.35), (3, 0.15)), attack=0.01, release=0.5):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(amp * math.sin(2 * math.pi * freq * h * t) for h, amp in harmonics)
        out.append(s * env(i, n, attack, release))
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


def delay(samples, seconds):
    return [0.0] * int(seconds * RATE) + samples


def noise_whoosh(dur, lowpass=0.12, sweep=True):
    """Filtered noise with a rising then fading amplitude — a soft whoosh."""
    n = int(dur * RATE)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / n
        white = random.uniform(-1, 1)
        prev = prev + lowpass * (white - prev)   # one-pole lowpass
        amp = math.sin(math.pi * min(1.0, t * 1.15)) if sweep else (1.0 - t)
        out.append(prev * amp)
    return out


def crackle(dur, density=0.004):
    n = int(dur * RATE)
    out = [0.0] * n
    for i in range(n):
        if random.random() < density:
            length = random.randint(8, 30)
            amp = random.uniform(0.2, 0.6) * (1.0 - i / n)
            for j in range(length):
                if i + j < n:
                    out[i + j] += amp * math.sin(2 * math.pi * j / length) * random.uniform(0.5, 1.0)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)

    # Quest complete: whoosh + gentle crackle + a soft confirming blip
    write_wav("quest_complete", mix(
        [s * 0.8 for s in noise_whoosh(0.45)],
        [s * 0.5 for s in crackle(0.45)],
        delay(tone(660, 0.18, attack=0.005, release=0.3), 0.16),
    ))

    # Streak up: warm two-note chime (C5 -> G5)
    write_wav("streak_up", mix(
        tone(523.25, 0.5, release=0.6),
        delay(tone(783.99, 0.55, release=0.6), 0.14),
    ))

    # Milestone: rising arpeggio into a chord
    write_wav("milestone", mix(
        tone(523.25, 0.35),
        delay(tone(659.25, 0.35), 0.12),
        delay(tone(783.99, 0.35), 0.24),
        delay(mix(tone(1046.50, 0.9, release=0.8),
                  tone(783.99, 0.9, release=0.8),
                  tone(659.25, 0.9, release=0.8)), 0.36),
        [s * 0.35 for s in crackle(1.3, density=0.002)],
    ))

    # Freeze: cool descending pair, no sparkle
    write_wav("freeze", mix(
        tone(740, 0.4, harmonics=((1, 1.0), (2, 0.1)), release=0.7),
        delay(tone(554, 0.6, harmonics=((1, 1.0), (2, 0.1)), release=0.8), 0.22),
    ))

    # Burnout: low fading rumble with dying crackle
    n = int(1.4 * RATE)
    rumble = []
    prev = 0.0
    for i in range(n):
        t = i / n
        white = random.uniform(-1, 1)
        prev = prev + 0.04 * (white - prev)
        base = math.sin(2 * math.pi * 82 * (i / RATE)) * 0.6 + prev * 0.7
        rumble.append(base * (1.0 - t) ** 1.6)
    write_wav("burnout", mix(rumble, [s * 0.3 * 1.0 for s in crackle(1.2, density=0.0015)]))

    # Revival: upward sweep blooming into a bright chord
    n = int(0.7 * RATE)
    sweep = []
    for i in range(n):
        t = i / n
        f = 180 + (880 - 180) * (t ** 1.4)
        sweep.append(math.sin(2 * math.pi * f * (i / RATE)) * math.sin(math.pi * t))
    write_wav("revival", mix(
        sweep,
        delay(mix(tone(659.25, 0.8, release=0.7),
                  tone(880.00, 0.8, release=0.7),
                  tone(1318.5, 0.8, release=0.7)), 0.55),
        delay([s * 0.5 for s in crackle(0.8, density=0.003)], 0.5),
    ))


if __name__ == "__main__":
    main()

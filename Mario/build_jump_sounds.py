"""Rebuild original retro jump effects: small is one octave above big."""
from array import array
from math import cos, exp, pi, sin
from pathlib import Path
import sys
import wave

RATE = 44100
DURATION = 0.22


def build_jump(filename, pitch):
    samples = []
    phase = 0.0
    for i in range(round(RATE * DURATION)):
        t = i / RATE
        # A stepped upward sweep with a short falling tail gives a springy chirp.
        step_time = int(t * 120) / 120
        if step_time < 0.14:
            frequency = 360 + 760 * (step_time / 0.14) ** 0.7
        else:
            frequency = 1120 - 420 * ((step_time - 0.14) / 0.08)
        frequency *= pitch
        phase += 2 * pi * frequency / RATE
        attack = min(1.0, t / 0.002)
        release = max(0.0, min(1.0, (DURATION - 1 / RATE - t) / 0.035))
        envelope = attack * release * exp(-t * 5)
        # Band-limited pulse and triangle keep the retro tone free of aliasing.
        pulse = sum(2 * sin(pi * h * 0.25) / (pi * h) * cos(h * phase)
                    for h in range(1, 13) if h * frequency < RATE * 0.45)
        triangle = sum((-1) ** ((h - 1) // 2) * sin(h * phase) / h ** 2
                       for h in (1, 3, 5, 7)) * 8 / pi ** 2
        samples.append(envelope * (0.65 * pulse + 0.35 * triangle))
    peak = max(abs(value) for value in samples)
    pcm = array('h', (round(value / peak * 0.65 * 32767) for value in samples))
    if sys.byteorder != 'little':
        pcm.byteswap()
    output = Path(__file__).with_name(filename)
    with wave.open(str(output), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(pcm.tobytes())
    print(f'{filename}: {len(pcm) / RATE:.2f}s, 16-bit mono, pitch {pitch:g}x')


if __name__ == '__main__':
    build_jump('jump_small.wav', 1.0)
    build_jump('jump_big.wav', 0.5)

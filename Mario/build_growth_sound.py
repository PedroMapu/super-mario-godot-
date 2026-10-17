"""Rebuild the original, ascending chip-style growth sound (PCM 16-bit mono)."""
from array import array
from math import cos, exp, pi, sin
from pathlib import Path
import sys
import wave

RATE = 44100
STEP = 0.1
NOTES = (60, 64, 67, 60, 67, 72, 76, 79)
samples = []
for note_index, midi in enumerate(NOTES):
    frequency = 440.0 * 2 ** ((midi - 69) / 12)
    for i in range(round(RATE * STEP)):
        t = i / RATE
        # Short attack/release on every note prevents clicks at the pitch changes.
        attack = min(1.0, t / 0.003)
        release = min(1.0, max(0.0, (STEP - 1 / RATE - t) / 0.018))
        envelope = attack * release * (0.75 + 0.25 * exp(-t * 22))
        phase = 2 * pi * frequency * t
        # Band-limited quarter-duty pulse plus a softer triangle an octave below.
        pulse = sum(2 * sin(pi * h * 0.25) / (pi * h) * cos(h * phase)
                    for h in range(1, 17) if h * frequency < RATE * 0.45)
        triangle = sum((-1) ** ((h - 1) // 2) * sin(h * phase * 0.5) / h ** 2
                       for h in (1, 3, 5, 7)) * 8 / pi ** 2
        samples.append(envelope * (0.84 * pulse + 0.16 * triangle))
peak = max(abs(value) for value in samples)
pcm = array('h', (round(value / peak * 0.68 * 32767) for value in samples))
if sys.byteorder != 'little':
    pcm.byteswap()
output = Path(__file__).with_name('small_to_big.wav')
with wave.open(str(output), 'wb') as audio:
    audio.setnchannels(1)
    audio.setsampwidth(2)
    audio.setframerate(RATE)
    audio.writeframes(pcm.tobytes())
print(f'{output.name}: {len(pcm) / RATE:.2f}s, {RATE}Hz, 16-bit mono, peak -3.35 dBFS')

"""Create original chiptune damage feedback and a looping victory theme."""
from array import array
from math import exp, pi, sin
from pathlib import Path
import random
import sys
import wave

RATE = 44100
ROOT = Path(__file__).parent


def write_wav(name, samples, peak=0.65):
    maximum = max(abs(value) for value in samples) or 1
    pcm = array('h', (round(value / maximum * peak * 32767) for value in samples))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(ROOT / name), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f'{name}: {len(samples) / RATE:.2f}s, 16-bit mono')


def build_damage():
    rng = random.Random(37)
    duration = 0.28
    samples = []
    phase = 0.0
    for index in range(round(RATE * duration)):
        t = index / RATE
        # A falling, rough pulse contrasts with the upward jump chirp.
        frequency = 720 * exp(-t * 7.5) + 75
        phase += 2 * pi * frequency / RATE
        pulse = sin(phase) + sin(3 * phase) / 3 + sin(5 * phase) / 5
        envelope = min(1, t / 0.002) * max(0, 1 - t / duration) ** 1.5
        flutter = 0.75 + 0.25 * sin(2 * pi * 42 * t)
        noise = rng.uniform(-1, 1) * exp(-t * 32)
        samples.append(envelope * (pulse * flutter * 0.8 + noise * 0.2))
    write_wav('dano_mario.wav', samples)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def note(samples, beat, duration, midi, volume, voice, beat_length):
    start = round(beat * beat_length * RATE)
    count = round(duration * beat_length * RATE)
    frequency = hz(midi)
    for index in range(min(count, len(samples) - start)):
        t = index / RATE
        phase = 2 * pi * frequency * t
        attack = min(1, t / 0.005)
        release = min(1, (count - 1 - index) / (RATE * 0.045))
        if voice == 'lead':
            value = sin(phase) + 0.25 * sin(3 * phase) + 0.12 * sin(5 * phase)
        else:
            value = sin(phase) - sin(3 * phase) / 9 + sin(5 * phase) / 25
        samples[start + index] += value * attack * max(0, release) * volume


def build_victory():
    # Eight original bars in C major, 144 BPM, with a resolution before looping.
    beat_length = 60 / 144
    samples = [0.0] * round(32 * beat_length * RATE)
    melody = [
        [(0, .5, 72), (.5, .5, 76), (1, .5, 79), (1.5, 1.5, 84), (3, .5, 79), (3.5, .5, 76)],
        [(0, 1, 81), (1, .5, 79), (1.5, .5, 77), (2, 1, 76), (3, 1, 74)],
        [(0, .5, 77), (.5, .5, 81), (1, 1, 84), (2, .5, 83), (2.5, .5, 81), (3, 1, 79)],
        [(0, 1, 79), (1, .5, 77), (1.5, .5, 74), (2, 1.75, 76)],
        [(0, .5, 72), (.5, .5, 76), (1, .5, 79), (1.5, .5, 84), (2, 1, 86), (3, 1, 84)],
        [(0, 1, 81), (1, .5, 84), (1.5, .5, 81), (2, 1, 79), (3, 1, 76)],
        [(0, .5, 77), (.5, .5, 79), (1, 1, 81), (2, .5, 79), (2.5, .5, 77), (3, 1, 74)],
        [(0, .5, 76), (.5, .5, 79), (1, 2.5, 84)],
    ]
    chords = [(48, 52, 55), (45, 48, 52), (41, 45, 48), (43, 47, 50),
              (48, 52, 55), (45, 48, 52), (43, 47, 50), (48, 52, 55)]
    for bar, notes in enumerate(melody):
        for offset, duration, pitch in notes:
            note(samples, bar * 4 + offset, duration * .88, pitch, .24, 'lead', beat_length)
        chord = chords[bar]
        for beat in range(4):
            note(samples, bar * 4 + beat, .75, chord[0] - 12 if beat % 2 == 0 else chord[2] - 12,
                 .15, 'bass', beat_length)
            for pitch in chord:
                note(samples, bar * 4 + beat + .5, .3, pitch + 12, .045, 'bass', beat_length)
    write_wav('vitoria_mario.wav', samples, .6)


if __name__ == '__main__':
    build_damage()
    build_victory()

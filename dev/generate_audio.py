"""Original synthesized score and ambience. No samples or third-party music."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
ROOT.mkdir(parents=True, exist_ok=True)
TAU = math.tau

def save(name, data):
    peak = max(abs(v) for v in data) or 1
    gain = min(1, .75 / peak)
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, v * gain)) * 32767)) for v in data))

def music(name, notes, pulse=False):
    data = [0.] * (RATE * 24)
    for beat in range(24):
        pitch = notes[beat % len(notes)]
        frequency = 440 * 2 ** ((pitch - 69) / 12)
        for i in range(RATE):
            t = i / RATE
            envelope = (1 - math.exp(-t * 70)) * math.exp(-t * 4.8)
            data[beat * RATE + i] += .15 * envelope * (math.sin(TAU * frequency * t) + .18 * math.sin(TAU * frequency * 2 * t))
            data[beat * RATE + i] += .07 * math.sin(TAU * frequency / 4 * t) * math.sin(math.pi * t) ** 2
            if pulse:
                data[beat * RATE + i] += .055 * math.sin(TAU * 65 * t) * math.exp(-t * 13)
    save(name, data)

music('small_town', [60, 67, 64, 69, 67, 62, 65, 64])
music('growing_company', [60, 64, 67, 72, 69, 67, 74, 71])
music('under_pressure', [57, 64, 60, 65, 57, 62, 59, 64], True)
rng = random.Random(912)
for kind in ['town', 'machines', 'crowd']:
    data, low = [], 0.
    for i in range(RATE * 12):
        t = i / RATE
        low = low * .96 + rng.uniform(-1, 1) * .04
        fade = min(1, t * 4, (12 - t) * 4)
        if kind == 'town':
            chirp = t % 3
            value = .1 * low + (.025 * math.sin(TAU * (1700 * chirp + 700 * chirp * chirp)) * math.sin(math.pi * chirp / .3) ** 2 if chirp < .3 else 0)
        elif kind == 'machines':
            value = .055 * math.sin(TAU * 72 * t) + .025 * math.sin(TAU * 144 * t) + .10 * low
        else:
            value = .15 * low + .035 * math.sin(TAU * 180 * t) * (.5 + .5 * math.sin(TAU * 2.5 * t)) + .025 * math.sin(TAU * 241 * t)
        data.append(value * fade)
    save(kind, data)
data=[]
for i in range(int(RATE * .48)):
    t=i/RATE
    envelope=math.sin(math.pi*t/.48)**2
    frequency=170 if t < .24 else 210
    data.append(envelope*(.10*math.sin(TAU*frequency*t)+.04*math.sin(TAU*frequency*3*t)+.015*math.sin(TAU*frequency*7*t)))
save('ai_voice',data)
print('Generated seven original audio assets.')

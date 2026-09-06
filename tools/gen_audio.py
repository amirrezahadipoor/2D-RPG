"""Procedural WAV loops: three music beds + three ambients (Phase E2).
Pure stdlib; deterministic so every build ships the same soundtrack."""
import math, os, struct, wave, random

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * 0.8)) * 32000)) for s in samples)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data)
    print("  wrote", name, "%.1fs" % (len(samples) / SR))


def env(t, dur, a=0.01, r=0.2):
    if t < a:
        return t / a
    if t > dur - r:
        return max(0.0, (dur - t) / r)
    return 1.0


def pluck(freq, dur, samples, start, vol=0.5, bright=1.0):
    i0 = int(start * SR)
    n = int(dur * SR)
    for i in range(n):
        if i0 + i >= len(samples):
            return
        t = i / SR
        e = env(t, dur, 0.005, dur * 0.6)
        v = (math.sin(2 * math.pi * freq * t) * 0.6
             + math.sin(2 * math.pi * freq * 2 * t) * 0.25 * bright
             + math.sin(2 * math.pi * freq * 3 * t) * 0.1 * bright)
        samples[i0 + i] += v * e * vol


def pad(freq, dur, samples, start, vol=0.12):
    i0 = int(start * SR)
    n = int(dur * SR)
    for i in range(n):
        if i0 + i >= len(samples):
            return
        t = i / SR
        e = env(t, dur, 0.4, 0.6)
        samples[i0 + i] += (math.sin(2 * math.pi * freq * t)
                            + math.sin(2 * math.pi * freq * 1.005 * t)) * e * vol


def noise_bed(dur, vol=0.2, lp=0.02):
    rnd = random.Random(7)
    n = int(dur * SR)
    out = [0.0] * n
    last = 0.0
    for i in range(n):
        w = rnd.uniform(-1, 1)
        last = last + lp * (w - last)
        out[i] = last * vol * 3.0
    return out


BPM = 96.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
LEN = 8 * BAR

# ---- day: bright pentatonic over a warm pad ----
day = [0.0] * int(SR * (LEN + 1))
PENTA = [392.0, 440.0, 523.25, 587.33, 659.25, 783.99]
for b in range(8):
    pad(196.0 if b % 4 < 2 else 146.83, BAR, day, b * BAR)
rnd = random.Random(11)
for b in range(8):
    for step in range(4):
        if rnd.random() < 0.75:
            f = PENTA[rnd.randrange(len(PENTA))]
            pluck(f, 0.5, day, b * BAR + step * BEAT, 0.4, 1.2)
    pluck(PENTA[b % 4] / 2.0, BAR * 0.9, day, b * BAR, 0.25, 0.6)
write("music_day.wav", day)

# ---- night: sparse minor bells + crickets ----
night = [0.0] * int(SR * (LEN + 1))
MINOR = [220.0, 261.63, 329.63, 349.23, 440.0]
for b in range(8):
    pad(110.0 if b % 4 < 2 else 87.31, BAR, night, b * BAR, 0.14)
rnd = random.Random(23)
for b in range(8):
    for step in range(2):
        if rnd.random() < 0.5:
            pluck(MINOR[rnd.randrange(len(MINOR))] * 2, 1.2, night, b * BAR + step * BEAT * 2, 0.22, 1.6)
    for c in range(3):
        t0 = b * BAR + rnd.random() * BAR
        pluck(4200.0, 0.03, night, t0, 0.05, 2.0)
write("music_night.wav", night)

# ---- dungeon: low drone, distant bell, stone ticks ----
dun = noise_bed(LEN + 1, 0.10, 0.004)
for b in range(8):
    pad(65.41 if b % 2 == 0 else 61.74, BAR, dun, b * BAR, 0.2)
rnd = random.Random(37)
for b in range(0, 8, 2):
    pluck(130.81, 2.0, dun, b * BAR + BEAT, 0.18, 0.4)
    pluck(98.0, 1.5, dun, b * BAR + BEAT * 3, 0.12, 0.3)
for i in range(14):
    pluck(rnd.uniform(800, 1600), 0.05, dun, rnd.random() * LEN, 0.05, 0.2)
write("music_dungeon.wav", dun)

# ---- ambients ----
rain = noise_bed(12.0, 0.35, 0.35)
rnd = random.Random(41)
for i in range(90):
    pluck(rnd.uniform(1200, 2600), 0.02, rain, rnd.random() * 11.5, 0.06, 2.0)
write("amb_rain.wav", rain)
wind = noise_bed(12.0, 0.22, 0.006)
for i in range(len(wind)):
    wind[i] *= 0.6 + 0.4 * math.sin(2 * math.pi * 0.13 * i / SR)
write("amb_wind.wav", wind)
crk = [0.0] * int(SR * 12)
rnd = random.Random(43)
for i in range(60):
    pluck(rnd.uniform(3800, 4600), 0.025, crk, rnd.random() * 11.6, 0.09, 2.0)
write("amb_crickets.wav", crk)
print("audio done")

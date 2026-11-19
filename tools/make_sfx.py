#!/usr/bin/env python3
"""Make the game's sound effects: python3 tools/make_sfx.py  (writes assets/sfx/*.wav and *.ogg)

Everything is synthesized here (numpy), so there are no third-party sound files to license:
  bat cracks (perfect / good / weak), foul tick, glove pop, catcher's mitt, whoosh, bounce, UI tap,
  crowd murmur loop, cheer, roar, groan, organ stings, and the umpire / PA calls.
The umpire calls start from espeak-ng (needs `espeak-ng` on PATH; its output is ours to use) and get pitched down,
band-limited like a PA horn and given a stadium echo.
Needs Python 3 with numpy, espeak-ng, and ffmpeg (for the .ogg loop).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
rng = np.random.default_rng(42)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def lowpass(x, cutoff):
    # one-pole low-pass, run twice for a softer slope
    a = np.exp(-2 * np.pi * cutoff / SR)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def bandpass(x, lo, hi):
    return lowpass(x, hi) - lowpass(x, lo)


def fft_band(x, lo, hi):
    # fast brick-wall-ish band filter for long signals
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    ramp = np.clip((f - lo * 0.8) / (lo * 0.2 + 1e-9), 0, 1) * np.clip((hi * 1.2 - f) / (hi * 0.2), 0, 1)
    return np.fft.irfft(X * ramp, len(x))


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.002, fout=0.02):
    n_in, n_out = int(fin * SR), int(fout * SR)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def reverb(x, delays=(0.09, 0.17, 0.26, 0.41), gain=0.35, tail=1.2):
    out = np.concatenate([x, np.zeros(int(tail * SR))])
    for k, d in enumerate(delays):
        i = int(d * SR)
        g = gain * (0.7 ** k)
        out[i:i + len(x)] += x * g
    return out


def save(name, x, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    x = norm(fade(x), peak)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name)


def noise(sec):
    return rng.standard_normal(int(sec * SR))


# ---------------- bat and ball ----------------

def bat(crisp):
    """crisp 1 = PERFECT (sharp crack with a ringing ping), 0 = a dull thud off the end of the bat"""
    n = int(0.35 * SR)
    click = np.zeros(n)
    nc = int(0.004 * SR)
    click[:nc] = rng.standard_normal(nc) * np.linspace(1, 0, nc)
    tt = np.arange(n) / SR
    ping = (np.sin(2 * np.pi * 2350 * tt) + 0.6 * np.sin(2 * np.pi * 3720 * tt)) * env_exp(n, 0.025 + 0.03 * crisp)
    body = np.sin(2 * np.pi * (170 + 40 * crisp) * tt) * env_exp(n, 0.04)
    snap = bandpass(noise(0.35), 900, 6000) * env_exp(n, 0.012 + 0.01 * crisp)
    thud = lowpass(noise(0.35), 500) * env_exp(n, 0.05)
    x = click * (0.6 + 1.2 * crisp) + ping * 0.9 * crisp ** 1.5 + body * (0.8 - 0.3 * crisp) + snap * (0.4 + 1.2 * crisp) \
        + thud * (1.4 - 1.2 * crisp)
    return x


def glove(big):
    n = int(0.18 * SR)
    tt = np.arange(n) / SR
    pop = lowpass(noise(0.18), 1800 + 1200 * big) * env_exp(n, 0.012)
    thump = np.sin(2 * np.pi * (320 - 120 * big) * tt) * env_exp(n, 0.03 + 0.02 * big)
    return pop * 1.4 + thump * (0.8 + 0.6 * big)


def whoosh(sec=0.35):
    n = int(sec * SR)
    x = fft_band(noise(sec), 400, 2600)
    shape = np.sin(np.linspace(0, np.pi, n)) ** 2
    return x * shape


def bounce():
    n = int(0.12 * SR)
    tt = np.arange(n) / SR
    return np.sin(2 * np.pi * 140 * tt) * env_exp(n, 0.025) + lowpass(noise(0.12), 700) * env_exp(n, 0.01)


def tap():
    n = int(0.05 * SR)
    tt = np.arange(n) / SR
    return np.sin(2 * np.pi * 1200 * tt) * env_exp(n, 0.008)


# ---------------- crowd ----------------

def crowd_bed(sec, seed):
    r = np.random.default_rng(seed)
    n = int(sec * SR)
    x = np.zeros(n)
    # many soft "voices": band-limited noise with slow random swells
    for _ in range(40):
        lo = r.uniform(250, 700)
        v = fft_band(r.standard_normal(n), lo, lo * r.uniform(2.0, 3.5))
        k = r.uniform(0.15, 0.6)
        lfo = 0.5 + 0.5 * np.sin(2 * np.pi * k * np.arange(n) / SR + r.uniform(0, 6.3))
        x += v * lfo
    return x


def crowd_loop(sec=8.0):
    # crossfade the end into the start so it loops without a click
    x = crowd_bed(sec + 1.0, 7)
    nf = int(1.0 * SR)
    body = x[:int(sec * SR)].copy()
    body[:nf] = body[:nf] * np.linspace(0, 1, nf) + x[-nf:] * np.linspace(1, 0, nf)
    return body


def cheer(sec, intensity):
    n = int(sec * SR)
    x = crowd_bed(sec, int(intensity * 100)) * 1.0
    x += fft_band(noise(sec), 700, 3500) * 0.8 * intensity
    # claps: short clicks scattered in time
    claps = np.zeros(n)
    for _ in range(int(60 * sec * intensity)):
        i = rng.integers(0, n - 400)
        claps[i:i + 300] += rng.standard_normal(300) * np.linspace(1, 0, 300)
    x += bandpass(claps, 800, 5000) * 0.6
    shape = np.minimum(1, np.arange(n) / (0.25 * SR)) * np.exp(-np.maximum(0, np.arange(n) - 0.5 * n) / (0.3 * sec * SR))
    return x * shape


def groan(sec=1.6):
    n = int(sec * SR)
    x = np.zeros(n)
    for k in range(18):
        f0 = rng.uniform(140, 260)
        ff = f0 * np.linspace(1.0, 0.72, n)
        ph = 2 * np.pi * np.cumsum(ff) / SR
        voice = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)
        x += voice * rng.uniform(0.5, 1.0)
    x = lowpass(x, 1400)
    x += crowd_bed(sec, 3) * 0.5
    shape = np.minimum(1, np.arange(n) / (0.15 * SR)) * np.linspace(1, 0.2, n)
    return x * shape


# ---------------- organ ----------------

def organ_note(freq, sec):
    tt = t(sec)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 6.0 * tt)
    ph = 2 * np.pi * freq * np.cumsum(vib) / SR
    x = sum(a * np.sin(ph * h) for h, a in ((1, 1.0), (2, 0.7), (3, 0.45), (4, 0.3), (6, 0.15), (8, 0.1)))
    n = len(tt)
    shape = np.minimum(1, np.arange(n) / (0.01 * SR)) * np.minimum(1, (n - np.arange(n)) / (0.04 * SR))
    return x * shape


def organ_tune(notes):
    # notes: (midi, beats); 0.16 s per beat
    parts = []
    for m, beats in notes:
        f = 440 * 2 ** ((m - 69) / 12)
        parts.append(organ_note(f, beats * 0.16))
    return reverb(np.concatenate(parts), gain=0.25, tail=0.8)


# ---------------- umpire / PA ----------------

def voice(text, pitch=35, speed=135, echo=True, gain_db=0.0):
    with tempfile.TemporaryDirectory() as d:
        raw = os.path.join(d, "v.wav")
        subprocess.run(["espeak-ng", "-v", "en-us+m3", "-p", str(pitch), "-s", str(speed), "-a", "180", "-w", raw, text],
                       check=True)
        with wave.open(raw) as w:
            sr = w.getframerate()
            x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768
    # resample to SR and pitch down a little (slower playback = deeper, chestier voice)
    deepen = 0.88
    idx = np.arange(0, len(x) - 1, sr / SR * deepen)
    x = np.interp(idx, np.arange(len(x)), x)
    x = np.tanh(x * 2.5)                    # a little grit, like a shouted call
    x = fft_band(x, 250, 3800)              # PA horn bandwidth
    if echo:
        x = reverb(x, delays=(0.14, 0.29, 0.47), gain=0.32, tail=0.9)
    return x * 10 ** (gain_db / 20)


def main():
    save("bat_perfect", bat(1.0), 0.95)
    save("bat_good", bat(0.55), 0.85)
    save("bat_weak", bat(0.0), 0.75)
    save("foul_tick", bat(0.2)[: int(0.12 * SR)], 0.6)
    save("glove", glove(0.0), 0.8)
    save("mitt", glove(1.0), 0.95)
    save("whoosh", whoosh(), 0.5)
    save("bounce", bounce(), 0.6)
    save("tap", tap(), 0.5)
    save("cheer", cheer(2.6, 0.7), 0.8)
    save("roar", cheer(4.5, 1.0), 0.95)
    save("groan", groan(), 0.7)
    # "Charge!"-style rally riff and a short between-innings sting
    save("organ_charge", organ_tune([(67, 1), (72, 1), (76, 1), (79, 2), (76, 1), (79, 4)]), 0.8)
    save("organ_sting", organ_tune([(72, 1), (76, 1), (79, 1), (84, 3)]), 0.75)
    save("organ_homer", organ_tune([(60, 1), (64, 1), (67, 1), (72, 1), (76, 1), (79, 1), (84, 5)]), 0.85)
    calls = {
        "ump_strike": ("Steee-rike!", 30, 120),
        "ump_strike3": ("Strike three!", 30, 125),
        "ump_ball": ("Ball.", 38, 140),
        "ump_ball4": ("Ball four. Take your base.", 38, 150),
        "ump_out": ("Yer out!", 28, 120),
        "ump_safe": ("Safe!", 34, 120),
        "ump_foul": ("Foul ball!", 34, 140),
        "ump_playball": ("Play ball!", 32, 125),
        "pa_homerun": ("Home run!", 40, 120),
    }
    for name, (text, pitch, speed) in calls.items():
        save(name, voice(text, pitch, speed), 0.9)
    # the crowd murmur loop as .ogg (small; the game turns looping on in code)
    os.makedirs(OUT, exist_ok=True)
    loop = norm(crowd_loop(), 0.6)
    tmp = os.path.join(OUT, "_crowd_tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((loop * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, "crowd_loop.ogg")], check=True)
    os.remove(tmp)
    print("wrote crowd_loop.ogg")


if __name__ == "__main__":
    main()

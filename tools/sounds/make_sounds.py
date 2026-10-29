#!/usr/bin/env python3
"""
يولّد أصوات الأبلكيشن كلها بالحساب (synthesis) — أصوات أصلية من غير حقوق لحد.

التشغيل:
  python3 tools/sounds/make_sounds.py
الناتج:
  apps/kids_app/assets/sounds/*.wav  (mono, 44.1kHz, 16-bit)

لو عايز تغيّر صوت: عدّل الدالة بتاعته هنا وشغّل السكريبت تاني.

ملحوظة: salam.wav («السلام عليكم ورحمة الله وبركاته» في شاشة البداية) مش من السكريبت ده.
النسخة الحالية مؤقتة للتجربة، متعملة بصوت macOS (Majed) — رخصة أصوات أبل ما تسمحش باستخدامها في أبلكيشن منشور،
فلازم تتبدل بتسجيل صوت حقيقي قبل النشر. أي ملف WAV أو M4A بنفس الاسم ينفع (يفضّل mono وأقل من 10 ثواني).
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parents[2] / 'apps/kids_app/assets/sounds'
rnd = random.Random(7)


def silence(dur):
    return [0.0] * int(SR * dur)


def env(n, a=.005, d=.08, s=.6, r=.1):
    """ADSR بالثواني على طول n عينة."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    out = []
    for i in range(n):
        if i < a:
            v = i / max(a, 1)
        elif i < a + d:
            v = 1 - (1 - s) * (i - a) / max(d, 1)
        elif i < n - r:
            v = s
        else:
            v = s * max(0, (n - i) / max(r, 1))
        out.append(v)
    return out


def osc(freq, dur, wave_='sine', glide_to=None, vib=0.0, vib_rate=6.0):
    """موجة بتردد ثابت أو بيتزحلق (glide) من freq لـ glide_to."""
    n = int(SR * dur)
    out, ph = [], 0.0
    for i in range(n):
        t = i / n
        f = freq if glide_to is None else freq * (glide_to / freq) ** t
        f *= 1 + vib * math.sin(2 * math.pi * vib_rate * i / SR)
        ph += 2 * math.pi * f / SR
        if wave_ == 'sine':
            v = math.sin(ph)
        elif wave_ == 'tri':
            v = 2 / math.pi * math.asin(math.sin(ph))
        else:  # مربعة ناعمة
            v = math.tanh(3 * math.sin(ph)) * .8
        out.append(v)
    return out


def bell(freq, dur, bright=1.0):
    """جرس: هارمونيات مش متساوية بتخفت بسرعات مختلفة."""
    n = int(SR * dur)
    parts = [(1, 1, 3.0), (2.0, .5 * bright, 5.0), (3.01, .25 * bright, 8.0), (4.2, .12 * bright, 12.0)]
    out = []
    for i in range(n):
        t = i / SR
        v = sum(a * math.exp(-k * t) * math.sin(2 * math.pi * freq * m * t) for m, a, k in parts)
        # دخول وخروج ناعمين عشان مفيش طقة لما الجرس يتقطع
        out.append(v * min(1, i / (SR * .006)) * min(1, (n - i) / (SR * .06)))
    return out


def noise(dur, lp_from=8000, lp_to=800, hp=0):
    """نويز بفلتر بيتحرك (للـ whoosh والتكسير)."""
    n = int(SR * dur)
    out, y, yh, prev = [], 0.0, 0.0, 0.0
    for i in range(n):
        t = i / n
        fc = lp_from * (lp_to / lp_from) ** t
        a = 1 - math.exp(-2 * math.pi * fc / SR)
        x = rnd.uniform(-1, 1)
        y += a * (x - y)
        v = y
        if hp:
            ah = math.exp(-2 * math.pi * hp / SR)
            yh = ah * (yh + v - prev)
            prev = v
            v = yh
        out.append(v)
    return out


def mul(sig, e):
    return [a * b for a, b in zip(sig, e)]


def mix(*tracks):
    """tracks = (offset_seconds, signal, gain)"""
    n = max(int(o * SR) + len(s) for o, s, _ in tracks)
    out = [0.0] * n
    for o, s, g in tracks:
        k = int(o * SR)
        for i, v in enumerate(s):
            out[k + i] += v * g
    return out


def note(name):
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    semis = names[name[0]] + (1 if '#' in name else 0)
    octave = int(name[-1])
    return 440 * 2 ** ((semis + 12 * (octave - 4)) / 12)


def save(name, sig, peak=.85):
    m = max(1e-9, max(abs(v) for v in sig))
    sig = [v / m * peak for v in sig]
    # تلاشي صغير في الآخر عشان مفيش طقة
    f = min(len(sig), int(.01 * SR))
    for i in range(f):
        sig[-1 - i] *= i / f
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in sig))
    print(f'{name:10s} {len(sig) / SR:.2f}s')


# ---------------- الأصوات ----------------

def tap():
    s = osc(1300, .05, glide_to=700)
    return mul(s, env(len(s), .001, .02, .3, .02))


def pop():
    s = mix((0, mul(osc(420, .08, glide_to=1500), env(int(.08 * SR), .001, .03, .3, .04)), 1),
            (0, mul(noise(.03, 6000, 2000), env(int(.03 * SR), .001, .01, .2, .015)), .25))
    return s


def correct():
    return mix((0, bell(note('G5'), .5), .8), (.09, bell(note('C6'), .7), 1))


def wrong():
    # "بووم" لطيف نازل (مش مخيف)
    a = mul(osc(330, .18, 'tri', glide_to=262, vib=.01), env(int(.18 * SR), .005, .05, .7, .05))
    b = mul(osc(247, .32, 'tri', glide_to=196, vib=.02), env(int(.32 * SR), .005, .08, .6, .2))
    return mix((0, a, .8), (.16, b, .8))


def win():
    arp = ['C5', 'E5', 'G5', 'C6']
    tracks = []
    for k, nm in enumerate(arp):
        f = note(nm)
        tracks.append((k * .11, mul(osc(f, .25, 'tri'), env(int(.25 * SR), .004, .06, .5, .1)), .5))
        tracks.append((k * .11, bell(f, .4), .35))
    for nm in ['C5', 'E5', 'G5', 'C6']:
        tracks.append((.46, mul(osc(note(nm), .9, 'tri', vib=.004), env(int(.9 * SR), .01, .2, .55, .5)), .3))
    for k in range(7):
        tracks.append((.5 + k * .09, bell(rnd.choice([2093, 2349, 2637, 3136]), .35, .6), .2))
    return mix(*tracks)


def star():
    return mix(*[(k * .06, bell(f, .45, .7), .6) for k, f in enumerate([2093, 2637, 3136])])


def coin():
    a = mul(osc(note('B5'), .07, 'square'), env(int(.07 * SR), .001, .02, .8, .01))
    b = mul(osc(note('E6'), .28, 'square'), env(int(.28 * SR), .001, .05, .6, .2))
    return mix((0, a, .5), (.065, b, .5))


def jump():
    s = osc(280, .2, glide_to=760)
    return mul(s, env(len(s), .005, .05, .6, .12))


def whoosh():
    s = noise(.45, 600, 5000)
    e = [math.sin(math.pi * i / len(s)) ** 2 for i in range(len(s))]
    return mul(s, e)


def swish():
    s = noise(.16, 2500, 7000, hp=600)
    e = [math.sin(math.pi * i / len(s)) ** 1.5 for i in range(len(s))]
    return mul(s, e)


def snap():
    click = mul(noise(.02, 9000, 4000, hp=1500), env(int(.02 * SR), .0005, .005, .3, .01))
    thump = mul(osc(190, .1, glide_to=120), env(int(.1 * SR), .001, .03, .3, .06))
    return mix((0, click, .7), (0, thump, .8), (.02, bell(note('E6'), .2, .4), .25))


def land():
    thud = mul(osc(150, .18, glide_to=80), env(int(.18 * SR), .001, .05, .4, .1))
    boing = mul(osc(320, .22, glide_to=420, vib=.06, vib_rate=18), env(int(.22 * SR), .005, .05, .5, .14))
    return mix((0, thud, 1), (.03, boing, .35))


def bump():
    a = mul(osc(220, .2, 'tri', glide_to=110, vib=.05, vib_rate=25), env(int(.2 * SR), .002, .05, .5, .12))
    return mix((0, a, 1), (0, mul(noise(.05, 3000, 600), env(int(.05 * SR), .001, .02, .3, .02)), .3))


def crumble():
    tracks = []
    for k in range(9):
        d = .05 + rnd.random() * .08
        s = mul(noise(d, 1800, 300), env(int(d * SR), .001, .02, .4, d * .5))
        tracks.append((k * .045 + rnd.random() * .02, s, .5 + rnd.random() * .5))
    return mix(*tracks)


def welcome():
    # جرس سحري طالع (سلم خماسي) وفي الآخر كورد
    seq = ['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'D6', 'E6']
    tracks = [(k * .085, bell(note(nm), .6, .8), .55) for k, nm in enumerate(seq)]
    for nm in ['C5', 'G5', 'C6', 'E6']:
        tracks.append((.72, mul(osc(note(nm), 1.1, 'sine', vib=.003), env(int(1.1 * SR), .02, .3, .5, .6)), .22))
    for k in range(10):
        tracks.append((.75 + k * .07, bell(rnd.choice([2637, 3136, 3520, 4186]), .3, .5), .12))
    tracks.append((0, mul(noise(.9, 3000, 9000, hp=2000), [math.sin(math.pi * i / int(.9 * SR)) * .5 for i in range(int(.9 * SR))]), .12))
    return mix(*tracks)


def level_up():
    seq = ['C5', 'E5', 'G5', 'C6', 'E6']
    tracks = [(k * .07, mul(osc(note(nm), .22, 'square'), env(int(.22 * SR), .002, .05, .5, .1)), .28) for k, nm in enumerate(seq)]
    tracks += [(k * .07, bell(note(nm), .35), .3) for k, nm in enumerate(seq)]
    tracks.append((.38, bell(note('C6'), 1.0), .5))
    tracks.append((.38, bell(note('G6'), .8, .6), .3))
    return mix(*tracks)


SOUNDS = {
    'tap': tap, 'pop': pop, 'correct': correct, 'wrong': wrong, 'win': win, 'star': star,
    'coin': coin, 'jump': jump, 'whoosh': whoosh, 'swish': swish, 'snap': snap, 'land': land,
    'bump': bump, 'crumble': crumble, 'welcome': welcome, 'level_up': level_up,
}

if __name__ == '__main__':
    for name, fn in SOUNDS.items():
        save(name, fn())

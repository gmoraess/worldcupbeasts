# -*- coding: utf-8 -*-
"""SFX + música chiptune procedurais (estilo Vampire Survivors / arcade).

Gera WAVs 44.1kHz 16-bit mono:
  kick, pass, tackle, goal, pop, click, shimmer, ko  +  music_loop (8 compassos).
"""
import wave, struct, math, random, sys, os

SR = 44100
random.seed(7)


def clamp(v):
    return max(-1.0, min(1.0, v))


def write_wav(path, samples, vol=1.0):
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = vol / peak
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', int(clamp(s * norm) * 32000)) for s in samples))
    print('OK', os.path.basename(path), '%.2fs' % (len(samples) / SR))


def silence(dur):
    return [0.0] * int(dur * SR)


def add(dst, src, at=0.0):
    i0 = int(at * SR)
    while len(dst) < i0 + len(src):
        dst.append(0.0)
    for i, s in enumerate(src):
        dst[i0 + i] += s
    return dst


def sine_sweep(f0, f1, dur, amp=1.0, decay=8.0):
    out = []
    ph = 0.0
    n = int(dur * SR)
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        ph += math.tau * f / SR
        out.append(math.sin(ph) * amp * math.exp(-decay * t))
    return out


def noise_burst(dur, amp=1.0, decay=14.0, lp=0.4):
    out = []
    n = int(dur * SR)
    y = 0.0
    for i in range(n):
        t = i / n
        y += lp * (random.uniform(-1, 1) - y)      # low-pass barato
        out.append(y * amp * math.exp(-decay * t))
    return out


def square(freq, dur, amp=1.0, duty=0.5, decay=5.0):
    out = []
    n = int(dur * SR)
    ph = 0.0
    for i in range(n):
        t = i / n
        ph = (ph + freq / SR) % 1.0
        v = 1.0 if ph < duty else -1.0
        out.append(v * amp * math.exp(-decay * t))
    return out


def bell(freq, dur, amp=1.0, decay=6.0):
    out = []
    n = int(dur * SR)
    for i in range(n):
        t = i / n
        env = math.exp(-decay * t)
        v = math.sin(math.tau * freq * i / SR) + 0.5 * math.sin(math.tau * freq * 2.01 * i / SR)
        out.append(v * amp * env)
    return out


# ------------------------------------------------------------------ SFX
def sfx_kick():       # chute: thump com queda de tom + clique
    s = sine_sweep(190, 55, 0.16, 1.0, 9.0)
    add(s, noise_burst(0.03, 0.6, 40.0, 0.9))
    return s


def sfx_pass():       # passe: toque mais seco e curto
    s = sine_sweep(150, 75, 0.09, 0.8, 14.0)
    add(s, noise_burst(0.02, 0.4, 50.0, 0.9))
    return s


def sfx_tackle():     # carrinho: whoosh crescendo + pancada
    s = []
    n = int(0.16 * SR)
    y = 0.0
    for i in range(n):
        t = i / n
        y += (0.15 + 0.5 * t) * (random.uniform(-1, 1) - y)
        s.append(y * 0.7 * math.sin(math.pi * t))          # swell
    add(s, sine_sweep(120, 45, 0.14, 1.0, 10.0), 0.12)
    add(s, noise_burst(0.05, 0.7, 26.0, 0.6), 0.12)
    return s


def sfx_goal():       # fanfarra: arpejo subindo + brilho
    s = silence(0.02)
    notes = [523.25, 659.25, 783.99, 1046.5]               # C5 E5 G5 C6
    for k, f in enumerate(notes):
        add(s, square(f, 0.16, 0.5, 0.25, 6.0), 0.02 + k * 0.07)
    add(s, bell(1567.98, 0.5, 0.35, 5.0), 0.3)             # G6 sparkle
    add(s, noise_burst(0.25, 0.12, 8.0, 0.25), 0.28)       # "chiado de torcida"
    return s


def sfx_pop():        # confete: POP + blip pra cima
    s = noise_burst(0.05, 1.0, 30.0, 0.8)
    add(s, sine_sweep(400, 900, 0.07, 0.5, 10.0), 0.01)
    return s


def sfx_click():      # UI: blip curtinho
    return square(950, 0.035, 0.6, 0.3, 18.0)


def sfx_shimmer():    # abrir pacote: sininhos subindo
    s = silence(0.02)
    for k, f in enumerate([659.25, 830.61, 1046.5, 1318.5]):   # E5 G#5 C6 E6
        add(s, bell(f, 0.35, 0.5 - k * 0.06, 7.0), k * 0.09)
    return s


def sfx_ko():         # nocaute: baque pesado
    s = sine_sweep(95, 32, 0.24, 1.0, 7.0)
    add(s, noise_burst(0.08, 0.8, 18.0, 0.4))
    return s


# ------------------------------------------------------------------ MÚSICA
# 140 BPM · 8 compassos · Am F C G (2 compassos cada) · loop perfeito
def music():
    step = 60.0 / 140.0 / 2.0          # colcheia
    steps = 64
    total = steps * step
    s = silence(total + 0.05)

    A2, C3, D3, E3, F2, G2 = 110.0, 130.81, 146.83, 164.81, 87.31, 98.0
    A4, C5, D5, E5, G5, A5 = 440.0, 523.25, 587.33, 659.25, 783.99, 880.0

    chords = [A2, A2, F2, F2, C3, C3, G2, G2]      # raiz por compasso
    fifth = {A2: E3, F2: C3, C3: G2 * 2, G2: D3}

    # melodia (64 colcheias; None = pausa) — motivo com pergunta/resposta
    M = [A4, None, C5, E5, None, E5, D5, C5,
         A4, None, C5, D5, E5, None, G5, E5,
         F2 * 8, None, A4, C5, None, C5, D5, C5,     # F: usa A4/C5
         A4, C5, D5, None, C5, A4, None, None,
         E5, None, G5, A5, None, A5, G5, E5,
         G5, E5, D5, C5, D5, None, E5, None,
         D5, None, D5, E5, None, D5, C5, A4,
         C5, A4, None, A4, None, None, None, None]

    for i in range(steps):
        t = i * step
        bar = i // 8
        root = chords[bar]
        # baixo: raiz nos tempos, quinta no contratempo
        bf = root if (i % 4) != 2 else fifth[root]
        add(s, square(bf, step * 0.9, 0.16, 0.5, 3.0), t)
        # bateria: bumbo 1/3, caixa 2/4, chimbal toda colcheia
        if i % 8 in (0, 4):
            add(s, sine_sweep(150, 50, 0.1, 0.5, 12.0), t)
        if i % 8 in (2, 6):
            add(s, noise_burst(0.09, 0.28, 22.0, 0.6), t)
        add(s, noise_burst(0.03, 0.10, 40.0, 0.95), t)
        # melodia
        note = M[i]
        if note:
            add(s, square(note, step * 1.7, 0.14, 0.25, 3.5), t)

    return s[:int(total * SR)]        # corta EXATO no fim do compasso → loop limpo


OUT = {
    'kick': (sfx_kick, 0.85), 'pass': (sfx_pass, 0.7), 'tackle': (sfx_tackle, 0.85),
    'goal': (sfx_goal, 0.8), 'pop': (sfx_pop, 0.7), 'click': (sfx_click, 0.5),
    'shimmer': (sfx_shimmer, 0.7), 'ko': (sfx_ko, 0.9), 'music_loop': (music, 0.7),
}

if __name__ == '__main__':
    outdir = sys.argv[1]
    for name, (fn, vol) in OUT.items():
        write_wav(os.path.join(outdir, name + '.wav'), fn(), vol)

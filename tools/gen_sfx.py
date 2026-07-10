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


# ------------------------------------------------------- TORCIDA (vocal)
def vowel(f0, f1, dur, amp=1.0, nvoices=6, breath=0.25):
    """Cluster de 'vozes' detunadas deslizando f0→f1 — torcida vocalizando.
    Envelope de sino (entra e sai suave). breath = camada de ruído junto."""
    n = int(dur * SR)
    out = [0.0] * n
    for _ in range(nvoices):
        det = 1.0 + random.uniform(-0.045, 0.045)
        ph1 = ph2 = ph3 = 0.0
        for i in range(n):
            t = i / n
            f = (f0 + (f1 - f0) * t) * det
            ph1 += math.tau * f / SR
            ph2 += math.tau * f * 2.02 / SR
            ph3 += math.tau * f * 3.03 / SR
            env = math.sin(math.pi * min(1.0, t * 1.12)) ** 1.4
            out[i] += (math.sin(ph1) + 0.45 * math.sin(ph2) + 0.2 * math.sin(ph3)) \
                * amp * env / nvoices
    if breath > 0.0:
        y = 0.0
        for i in range(n):
            t = i / n
            y += 0.22 * (random.uniform(-1, 1) - y)
            out[i] += y * breath * math.sin(math.pi * min(1.0, t * 1.12))
    return out


def sfx_crowd_goal():     # URRO de gol: rugido de estádio + palmas
    n = int(2.1 * SR)
    s = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / n
        atk = min(1.0, t * 9.0)                       # ataque rápido
        rel = math.exp(-2.2 * max(0.0, t - 0.25))     # decai devagar
        lp = 0.18 + 0.4 * atk                         # abre o filtro no pico
        y += lp * (random.uniform(-1, 1) - y)
        s[i] = y * atk * rel
    add(s, vowel(240, 300, 0.9, 0.5, 8), 0.05)        # "ÊÊÊ" por baixo
    for k in range(46):                                # salva de palmas
        at = 0.15 + random.random() * 1.4
        add(s, noise_burst(0.018, 0.35 * (1.0 - at / 2.2), 70.0, 0.85), at)
    return s


def sfx_crowd_ooh():      # "ôôô" — chute defendido/na trave
    return vowel(320, 195, 0.95, 0.9, 7, 0.3)


def sfx_crowd_sad():      # "aaah" murcho — gol sofrido
    return vowel(300, 140, 1.35, 0.8, 7, 0.35)


def sfx_crowd_uuh():      # "uuuh" crescente — pressão subindo
    return vowel(170, 330, 1.1, 0.85, 7, 0.3)


def sfx_crowd_applause():  # aplausos (defesa do nosso goleiro)
    s = silence(1.3)
    for k in range(70):
        at = random.random() ** 1.4 * 1.1
        add(s, noise_burst(0.016, 0.5 * (1.0 - at / 1.5), 80.0, 0.9), at)
    return s


def sfx_crowd_ola():      # swoosh da ola dando a volta
    n = int(1.6 * SR)
    s = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / n
        lp = 0.1 + 0.5 * math.sin(math.pi * t)        # filtro varre e volta
        y += lp * (random.uniform(-1, 1) - y)
        s[i] = y * math.sin(math.pi * t)
    add(s, vowel(200, 290, 1.2, 0.35, 6), 0.15)
    return s


def sfx_crowd_loop():     # murmúrio contínuo do estádio (loop ~8s)
    dur = 8.0
    n = int(dur * SR)
    s = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / dur                                    # em segundos/dur → ciclos exatos
        # 2 LFOs com nº INTEIRO de ciclos no loop → emenda sem pulo
        lfo = 0.72 + 0.18 * math.sin(math.tau * 2 * t) + 0.10 * math.sin(math.tau * 5 * t)
        y += 0.08 * (random.uniform(-1, 1) - y)        # ruído bem fechado (grave)
        s[i] = y * lfo
    return s


# ------------------------------------------------------- APITO DO JUIZ
def _whistle_blast(dur, amp=1.0):
    n = int(dur * SR)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        trill = 0.62 + 0.38 * math.sin(math.tau * 41.0 * i / SR)   # trinado da bolinha
        env = min(1.0, t * 22.0) * (1.0 if t < 0.82 else math.exp(-(t - 0.82) * 26.0))
        ph += math.tau * (2350.0 + 40.0 * math.sin(math.tau * 6.0 * t)) / SR
        out.append((math.sin(ph) + 0.3 * math.sin(ph * 1.5)) * trill * env * amp)
    return out


def sfx_whistle():        # apito curto (início de partida / gol)
    return _whistle_blast(0.42)


def sfx_whistle_end():    # apito final: pi! pi! piiiiii!
    s = silence(0.02)
    add(s, _whistle_blast(0.22), 0.0)
    add(s, _whistle_blast(0.22), 0.34)
    add(s, _whistle_blast(0.75), 0.68)
    return s


# ------------------------------------------------------- POWER-UPS / CARTAS
def sfx_explosion():      # 💣 bomba: BOOM com estilhaço
    s = sine_sweep(140, 28, 0.55, 1.0, 5.0)
    add(s, noise_burst(0.4, 0.9, 7.0, 0.3))
    add(s, noise_burst(0.12, 0.7, 22.0, 0.7), 0.02)   # crack inicial
    return s


def sfx_zap():            # ⚡ raio: zumbido elétrico serrilhado
    s = []
    n = int(0.38 * SR)
    ph = 0.0
    for i in range(n):
        t = i / n
        f = 1400.0 - 700.0 * t + random.uniform(-160, 160)   # jitter = faísca
        ph = (ph + f / SR) % 1.0
        v = 1.0 if ph < 0.5 else -1.0
        s.append(v * 0.8 * math.exp(-4.5 * t))
    add(s, noise_burst(0.1, 0.4, 30.0, 0.95))
    return s


def sfx_magnet():         # 🧲 ímã: hum subindo com wobble
    s = []
    n = int(0.45 * SR)
    ph = 0.0
    for i in range(n):
        t = i / n
        f = 190.0 + 420.0 * t + 34.0 * math.sin(math.tau * 13.0 * t)
        ph += math.tau * f / SR
        s.append((math.sin(ph) + 0.4 * math.sin(ph * 2.0)) * 0.7 * math.sin(math.pi * t))
    return s


def sfx_golden():         # 👟 chuteira de ouro: ding-ding nobre
    s = bell(1318.5, 0.3, 0.7, 7.0)                    # E6
    add(s, bell(1975.5, 0.5, 0.6, 6.0), 0.11)          # B6
    return s


def sfx_powerup():        # item aparece: sparkle convidativo
    s = sine_sweep(500, 1100, 0.12, 0.5, 6.0)
    add(s, bell(1567.98, 0.3, 0.4, 8.0), 0.06)
    return s


def sfx_slip():           # 🍌 escorregão: slide-whistle + tombo
    s = []
    n = int(0.32 * SR)
    ph = 0.0
    for i in range(n):
        t = i / n
        ph += math.tau * (950.0 - 620.0 * t) / SR
        s.append(math.sin(ph) * 0.7 * (1.0 - t * 0.4))
    add(s, sine_sweep(110, 40, 0.16, 0.9, 10.0), 0.3)
    add(s, noise_burst(0.05, 0.5, 30.0, 0.6), 0.3)
    return s


def sfx_web():            # 🕸 teia: splat grudento
    s = noise_burst(0.16, 0.9, 16.0, 0.35)
    add(s, sine_sweep(600, 180, 0.18, 0.5, 9.0), 0.01)
    return s


# --------------------------------------------------- FOGUINHO DE FÚRIA
def sfx_fire_full():      # 🔥 encheu: crepitar + sininho subindo (o AVISO)
    s = silence(0.02)
    for _ in range(10):
        add(s, noise_burst(0.02, 0.35, 45.0, 0.5), random.random() * 0.5)
    add(s, bell(880.0, 0.2, 0.5, 8.0), 0.1)
    add(s, bell(1318.5, 0.35, 0.55, 6.0), 0.28)
    return s


def sfx_fire_ignite():    # 🔥 clicou: FWOOSH + brasa crepitando
    s = []
    n = int(0.5 * SR)
    y = 0.0
    for i in range(n):
        t = i / n
        y += (0.12 + 0.6 * t) * (random.uniform(-1, 1) - y)
        s.append(y * math.sin(math.pi * min(1.0, t * 1.2)) * 0.9)
    add(s, sine_sweep(90, 40, 0.4, 0.7, 4.0), 0.05)
    for _ in range(8):
        add(s, noise_burst(0.02, 0.3, 50.0, 0.5), 0.25 + random.random() * 0.35)
    return s


# ----------------------------------------------- ALERTAS DE OFERTA (torcida)
def sfx_offer_cadeira():  # 🪑 "uh-oh" marotão + toc-toc de madeira
    s = silence(0.02)
    add(s, sine_sweep(330, 220, 0.13, 0.6, 5.0), 0.0)       # "uh"
    add(s, sine_sweep(270, 150, 0.2, 0.65, 4.5), 0.15)      # "oh"
    for at in (0.42, 0.54):                                  # toc, toc
        add(s, sine_sweep(185, 85, 0.05, 0.95, 30.0), at)
        add(s, noise_burst(0.018, 0.5, 60.0, 0.7), at)
    return s


def sfx_offer_corredor():  # 🏃 passinhos apressados + apito deslizando pra cima
    s = silence(0.02)
    for k in range(6):
        add(s, noise_burst(0.02, 0.55 - k * 0.05, 55.0, 0.85), k * 0.065)
    add(s, sine_sweep(480, 1040, 0.26, 0.55, 3.0), 0.16)
    return s


def sfx_offer_placa():    # 🪧 sininho de bicicleta (di-di-DING!)
    s = bell(1760.0, 0.16, 0.7, 11.0)                        # A6
    add(s, bell(1760.0, 0.2, 0.6, 9.0), 0.11)
    add(s, bell(2093.0, 0.34, 0.45, 6.0), 0.22)              # C7 fecha
    return s


def sfx_throw():          # arremesso: whoosh
    s = []
    n = int(0.34 * SR)
    y = 0.0
    for i in range(n):
        t = i / n
        y += (0.2 + 0.55 * t) * (random.uniform(-1, 1) - y)
        s.append(y * 0.8 * math.sin(math.pi * t) ** 0.7)
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
    'shimmer': (sfx_shimmer, 0.7), 'ko': (sfx_ko, 0.9),
    # torcida
    'crowd_goal': (sfx_crowd_goal, 0.85), 'crowd_ooh': (sfx_crowd_ooh, 0.7),
    'crowd_sad': (sfx_crowd_sad, 0.65), 'crowd_uuh': (sfx_crowd_uuh, 0.7),
    'crowd_applause': (sfx_crowd_applause, 0.7), 'crowd_ola': (sfx_crowd_ola, 0.55),
    'crowd_loop': (sfx_crowd_loop, 0.5),
    # juiz
    'whistle': (sfx_whistle, 0.6), 'whistle_end': (sfx_whistle_end, 0.6),
    # power-ups / cartas
    'explosion': (sfx_explosion, 0.95), 'zap': (sfx_zap, 0.75),
    'magnet': (sfx_magnet, 0.7), 'golden': (sfx_golden, 0.75),
    'powerup': (sfx_powerup, 0.7), 'slip': (sfx_slip, 0.75),
    'web': (sfx_web, 0.75), 'throw': (sfx_throw, 0.7),
    # alertas de oferta da torcida (1 por tipo de ofertante)
    'offer_cadeira': (sfx_offer_cadeira, 0.75),
    'offer_corredor': (sfx_offer_corredor, 0.7),
    'offer_placa': (sfx_offer_placa, 0.7),
    # foguinho de fúria
    'fire_full': (sfx_fire_full, 0.7),
    'fire_ignite': (sfx_fire_ignite, 0.85),
    # music_loop saiu daqui: as faixas agora vivem em tools/gen_music.py
}

if __name__ == '__main__':
    outdir = sys.argv[1]
    for name, (fn, vol) in OUT.items():
        write_wav(os.path.join(outdir, name + '.wav'), fn(), vol)

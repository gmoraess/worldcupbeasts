# -*- coding: utf-8 -*-
"""Trilha sonora chiptune do World Cup Beasts (substitui o music_loop único).

Faixas (WAV 44.1kHz 16-bit mono, corte exato no fim do compasso = loop limpo):
  music_menu     104 BPM · Am F C G  · calma (título/torre/loja)
  music_match_a  140 BPM · Am F C G  · a partida clássica (era o music_loop)
  music_match_b  152 BPM · Em C G D  · partida alternativa (alterna com a A)
  music_climax   168 BPM · Am Am F E · reta final / última mão (tensão)
  jingle_win     fanfarra curta (não-loop)
  jingle_lose    lamento curto (não-loop)

Uso: python tools/gen_music.py assets/sfx
O Sfx.gd troca as faixas com fade + pausa de respiro (music_play).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_sfx import (SR, silence, add, square, sine_sweep, noise_burst, bell,
                     write_wav, music)

# notas
A2, C3, D3, E3, F2, G2, E2, B2 = 110.0, 130.81, 146.83, 164.81, 87.31, 98.0, 82.41, 123.47
G3, A3 = 196.0, 220.0
E4, G4, A4, B4 = 329.63, 392.0, 440.0, 493.88
C5, D5, E5, F5, G5, A5, B5 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 987.77
C6, D6, E6, GS5 = 1046.5, 1174.66, 1318.5, 830.61


def sine_note(freq, dur, amp, decay=2.0):
    return sine_sweep(freq, freq, dur, amp, decay)


# ---------------------------------------------------------------- menu (calma)
def music_menu():
    step = 60.0 / 104.0 / 2.0
    M = [A4, 0, 0, 0, C5, 0, E5, 0, 0, 0, D5, 0, C5, 0, 0, 0,
         A4, 0, 0, 0, C5, 0, F5, 0, 0, 0, E5, 0, C5, 0, 0, 0,
         G4, 0, 0, 0, C5, 0, E5, 0, 0, 0, D5, 0, E5, 0, 0, 0,
         D5, 0, 0, 0, B4, 0, G4, 0, 0, 0, A4, 0, 0, 0, 0, 0]
    chords = [A2, A2, F2, F2, C3, C3, G2, G2]
    fifth = {A2: E3, F2: C3, C3: G3, G2: D3}
    total = len(M) * step
    s = silence(total + 0.05)
    for i in range(len(M)):
        t = i * step
        root = chords[i // 8]
        if i % 4 == 0:                                  # baixo macio nos tempos
            add(s, sine_note(root, step * 3.6, 0.22, 1.2), t)
        elif i % 4 == 2:
            add(s, sine_note(fifth[root], step * 1.8, 0.10, 2.0), t)
        if i % 4 == 2:                                  # chimbal de leve
            add(s, noise_burst(0.02, 0.05, 50.0, 0.95), t)
        if M[i]:
            add(s, bell(M[i], step * 3.0, 0.16, 3.0), t)
    return s[:int(total * SR)]


# ---------------------------------------------------------------- match B
def music_match_b():
    step = 60.0 / 152.0 / 2.0
    M = [E5, 0, G5, B5, 0, B5, A5, G5,
         E5, G5, A5, 0, B5, 0, D6, B5,
         C6, 0, B5, G5, 0, G5, A5, B5,
         A5, G5, E5, 0, G5, 0, E5, 0,
         D5, 0, G5, A5, 0, A5, B5, D6,
         B5, A5, G5, 0, A5, 0, B5, 0,
         D6, 0, B5, A5, 0, A5, G5, E5,
         G5, E5, 0, E5, 0, 0, 0, 0]
    chords = [E2, E2, C3, C3, G2, G2, D3, D3]
    fifth = {E2: B2, C3: G3, G2: D3, D3: A3}
    total = len(M) * step
    s = silence(total + 0.05)
    for i in range(len(M)):
        t = i * step
        root = chords[i // 8]
        bf = root if (i % 4) != 2 else fifth[root]
        add(s, square(bf, step * 0.9, 0.16, 0.5, 3.0), t)
        if i % 8 in (0, 4):
            add(s, sine_sweep(150, 50, 0.1, 0.5, 12.0), t)
        if i % 8 in (2, 6):
            add(s, noise_burst(0.09, 0.28, 22.0, 0.6), t)
        add(s, noise_burst(0.03, 0.10, 40.0, 0.95), t)
        if M[i]:
            add(s, square(M[i], step * 1.7, 0.13, 0.25, 3.5), t)
    return s[:int(total * SR)]


# ---------------------------------------------------------------- clímax
def music_climax():
    step = 60.0 / 168.0 / 2.0
    M = [A4, C5, E5, A5, E5, C5, E5, A4,
         A4, C5, E5, A5, E5, C5, D5, E5,
         A4, C5, F5, A5, F5, C5, A4, C5,
         E5, GS5, B5, E6, B5, GS5, E5, B4]
    chords = [A2, A2, F2, E2]
    total = len(M) * step
    s = silence(total + 0.05)
    for i in range(len(M)):
        t = i * step
        root = chords[i // 8]
        add(s, square(root, step * 0.85, 0.17, 0.5, 4.0), t)      # baixo TODA colcheia
        if i % 4 == 0:
            add(s, sine_sweep(160, 52, 0.09, 0.55, 13.0), t)
        if i % 8 in (2, 6):
            add(s, noise_burst(0.08, 0.3, 24.0, 0.6), t)
        add(s, noise_burst(0.02, 0.11, 45.0, 0.95), t)            # hats colcheia
        add(s, noise_burst(0.015, 0.06, 55.0, 0.95), t + step * 0.5)  # + contra
        if M[i]:
            add(s, square(M[i], step * 1.4, 0.13, 0.25, 4.5), t)
    return s[:int(total * SR)]


# ---------------------------------------------------------------- jingles
def jingle_win():
    s = silence(0.02)
    for k, f in enumerate([C5, E5, G5, C6]):
        add(s, square(f, 0.15, 0.5, 0.3, 5.0), k * 0.09)
    add(s, bell(C6, 0.9, 0.5, 3.5), 0.38)
    add(s, bell(E6, 0.9, 0.4, 3.5), 0.46)
    add(s, noise_burst(0.6, 0.14, 4.0, 0.2), 0.35)     # torcida ao fundo
    return s


def jingle_lose():
    s = silence(0.02)
    for k, f in enumerate([E5, C5, A4, E4]):
        add(s, square(f, 0.3, 0.4, 0.4, 3.5), k * 0.24)
    add(s, sine_sweep(110, 55, 0.9, 0.5, 3.0), 0.9)
    return s


OUT = {
    'music_menu': (music_menu, 0.65),
    'music_match_a': (music, 0.7),        # a original (140 BPM), renomeada
    'music_match_b': (music_match_b, 0.7),
    'music_climax': (music_climax, 0.72),
    'jingle_win': (jingle_win, 0.75),
    'jingle_lose': (jingle_lose, 0.7),
}

if __name__ == '__main__':
    outdir = sys.argv[1] if len(sys.argv) > 1 else 'assets/sfx'
    for name, (fn, vol) in OUT.items():
        write_wav(os.path.join(outdir, name + '.wav'), fn(), vol)

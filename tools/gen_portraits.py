# -*- coding: utf-8 -*-
"""Retratos das feras (assets/beasts/<id>.png) no MESMO estilo dos sprites.

Pega o frame idle 0 da spritesheet procedural de cada fera (gen_beasts /
gen_zab) e amplia x4 nearest (32x32 → 128x128, fundo transparente) — a loja,
os pacotes e as telas passam a combinar com a arte de campo.

Uso: python tools/gen_portraits.py assets/beasts
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_beasts
import gen_zab

SCALE = 4


def upscale(frame):
    big = []
    for row in frame:
        er = []
        for c in row:
            er.extend([c] * SCALE)
        for _ in range(SCALE):
            big.append(list(er))
    return big


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else 'assets/beasts'
    os.makedirs(outdir, exist_ok=True)
    for bid in gen_beasts.BEASTS:
        rows, _ = gen_beasts.build_sheet(bid)
        gen_beasts.write_png(os.path.join(outdir, '%s.png' % bid),
                             upscale(rows[0][0]), gen_beasts.BEASTS[bid]["pal"])
    # zab (gerador próprio, paleta própria)
    rows, _ = gen_zab.build_sheet()
    gen_zab.write_png(os.path.join(outdir, 'zab.png'), upscale(rows[0][0]))


if __name__ == '__main__':
    main()

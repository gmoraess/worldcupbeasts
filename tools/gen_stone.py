# -*- coding: utf-8 -*-
"""Fundo de pedra dos MENUS (assets/ui/stone_bg.png, 1280x720).

Muralha de tijolos de pedra escura (tema gótico/dourado da UI) com variação
determinística e vinheta baked (bordas mais escuras → o conteúdo salta).
Desenhado em meia resolução (640x360) e dobrado = pixel chunky do projeto.

Uso: python tools/gen_stone.py assets/ui
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_stadium import write_png, h2

BW, BH = 640, 360
BRICK_W, BRICK_H = 46, 16

BASE = (26, 19, 12)        # pedra base (entre STONE #17110b e PANEL #241a10)
LIGHT = (36, 27, 17)       # variação clara
EDGE = (14, 10, 6)         # junta/argamassa
HI = (48, 38, 24)          # canto iluminado do tijolo


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else 'assets/ui'
    os.makedirs(outdir, exist_ok=True)
    rows = []
    for y in range(BH):
        row = []
        for x in range(BW):
            by = y // BRICK_H
            off = (by % 2) * (BRICK_W // 2)          # fiadas alternadas
            bx = (x + off) // BRICK_W
            ly = y % BRICK_H
            lx = (x + off) % BRICK_W
            if ly == 0 or lx == 0:                    # junta
                c = EDGE
            elif ly == 1 and lx > 1:                  # brilho no topo do tijolo
                c = HI if h2(bx, by) > 96 else LIGHT
            else:
                v = h2(bx * 3 + lx // 12, by * 7 + ly // 5)
                c = LIGHT if v > 170 else (BASE if v > 40 else EDGE)
            # vinheta baked: escurece rumo às bordas
            dx = min(x, BW - 1 - x) / (BW * 0.5)
            dy = min(y, BH - 1 - y) / (BH * 0.5)
            vin = 0.55 + 0.45 * min(1.0, min(dx, dy) * 2.4)
            row.append((int(c[0] * vin), int(c[1] * vin), int(c[2] * vin), 255))
        rows.append(row)
    big = []
    for r in rows:
        er = []
        for c in r:
            er.append(c); er.append(c)
        big.append(er)
        big.append(list(er))
    write_png(os.path.join(outdir, 'stone_bg.png'), big)


if __name__ == '__main__':
    main()

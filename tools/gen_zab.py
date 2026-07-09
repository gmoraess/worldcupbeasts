# -*- coding: utf-8 -*-
"""Gera a spritesheet pixel-art da Zab (loba, tag 'sangue').

Sheet 6 colunas x 4 linhas de frames 32x32 (192x128):
  linha 0: idle  (4 frames)
  linha 1: run   (6 frames, galope)
  linha 2: kick  (4 frames)
  linha 3: slide (4 frames, carrinho)
Sprite olhando para a DIREITA (flip_h no jogo para a esquerda).
"""
import zlib, struct, math, sys

W = H = 32
COLS, ROWS = 6, 4
GROUND = 28.0

# paleta (indice -> RGBA)
PAL = {
    0: (0, 0, 0, 0),          # transparente
    1: (18, 14, 24, 255),     # contorno
    2: (52, 56, 74, 255),     # pelo escuro (costas / patas de tras)
    3: (88, 95, 128, 255),    # pelo medio (corpo)
    4: (154, 162, 194, 255),  # pelo claro (barriga, focinho, ponta da cauda)
    5: (216, 56, 62, 255),    # vermelho 'sangue' (olho, marcas)
    6: (142, 32, 48, 255),    # vermelho escuro
    7: (236, 233, 226, 255),  # branco (presa, brilho)
}
ASCII = {0: '.', 1: '#', 2: 'B', 3: 'b', 4: 'l', 5: 'R', 6: 'r', 7: 'W'}


def blank():
    return [[0] * W for _ in range(H)]


def px(g, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < W and 0 <= y < H:
        g[y][x] = c


def disk(g, cx, cy, r, c):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px(g, x, y, c)


def ellipse(g, cx, cy, rx, ry, c):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                px(g, x, y, c)


def line(g, x0, y0, x1, y1, c, w=1.0):
    """linha grossa: amostra e pinta discos pequenos."""
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
    for i in range(steps + 1):
        t = i / steps
        disk(g, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, w * 0.5 + 0.15, c)


def outline(g):
    """contorno externo: pixel vazio vizinho (4-viz) de pixel colorido vira 1."""
    out = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if g[y][x] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and g[ny][nx] not in (0, 1):
                    out[y][x] = 1
                    break
    return out


# ---------------------------------------------------------------- partes
def leg(g, hx, hy, fx, fy, col, paw=4):
    """pata: coxa + canela com leve 'joelho' recuado."""
    kx = (hx + fx) * 0.5 - 0.8
    ky = (hy + fy) * 0.5
    line(g, hx, hy, kx, ky, col, 2.0)
    line(g, kx, ky, fx, fy, col, 1.7)
    px(g, fx, fy, paw)


def tail(g, bx, by, ang, col_a=2, col_b=4):
    """cauda felpuda: discos decrescentes ao longo de uma curva."""
    a = math.radians(ang)
    for i in range(5):
        t = i / 4.0
        r = 2.2 - 1.1 * t
        x = bx - math.cos(a) * (2.0 + 5.5 * t)
        y = by - math.sin(a) * (2.0 + 5.5 * t) - t * t * 1.5
        disk(g, x, y, r, col_b if i >= 3 else col_a)


def head(g, hx, hy, ear_twitch=False, jaw_open=False):
    """cabeca p/ direita: cranio, focinho claro, orelhas, olho vermelho."""
    disk(g, hx, hy, 3.4, 3)                        # cranio
    ellipse(g, hx + 3.4, hy + 0.8, 2.6, 1.6, 4)    # focinho
    px(g, hx + 5.8, hy + 0.4, 1)                   # nariz
    if jaw_open:
        px(g, hx + 4.4, hy + 2.4, 7)               # presa
        px(g, hx + 3.4, hy + 2.4, 1)
    # orelhas (triangulos)
    for ex, tw in ((hx - 1.8, ear_twitch), (hx + 1.2, False)):
        top = hy - 5.4 - (0.8 if tw else 0.0)
        line(g, ex, hy - 2.4, ex + 0.4, top, 2, 1.6)
        px(g, ex + 0.4, top + 1.2, 6)              # interior vermelho-escuro
    px(g, hx + 1.6, hy - 0.9, 5)                   # olho vermelho
    px(g, hx + 0.6, hy - 0.9, 1)                   # canto do olho


def body(g, cx, cy, stretch=1.0, tilt=0.0):
    """tronco: elipse; costas escuras, barriga clara, marca 'sangue' no flanco."""
    rx, ry = 7.4 * stretch, 4.3
    ellipse(g, cx, cy, rx, ry, 3)
    # costas (faixa de cima) escuras
    for y in range(H):
        for x in range(W):
            if g[y][x] == 3:
                ny = (y - cy + (x - cx) * tilt)
                if ny < -1.6:
                    g[y][x] = 2
                elif ny > 2.4:
                    g[y][x] = 4
    # marca de guerra vermelha no flanco (identidade 'sangue')
    line(g, cx - 1.5, cy - 1.5, cx + 1.0, cy + 1.0, 5, 1.0)
    line(g, cx + 0.5, cy - 1.8, cx + 3.0, cy + 0.7, 6, 1.0)


# ---------------------------------------------------------------- frames
def frame_idle(i):
    g = blank()
    bob = 0.6 if i in (1, 2) else 0.0
    cy = 17.0 + bob
    tail(g, 8.5, cy - 1.5, 38 + (10 if i in (2, 3) else 0))
    # patas do lado de la (escuras) - estaticas
    leg(g, 12.0, cy + 2.5, 11.2, GROUND, 2)
    leg(g, 19.0, cy + 2.5, 19.6, GROUND, 2)
    body(g, 15.0, cy)
    line(g, 19.5, cy - 1.5, 23.0, 12.6 + bob, 3, 4.2)   # pescoco
    head(g, 24.0, 12.2 + bob, ear_twitch=(i == 3))
    # patas do lado de ca (claras)
    leg(g, 10.5, cy + 2.8, 9.6, GROUND, 3)
    leg(g, 20.5, cy + 2.8, 21.4, GROUND, 3)
    return outline(g)


def frame_run(i):
    g = blank()
    t = i / 6.0 * math.tau
    bob = 1.1 * math.sin(t + 0.8)              # sobe/desce do galope
    cy = 16.4 + bob
    stretch = 1.0 + 0.10 * math.sin(t)         # estica na suspensao
    tail(g, 8.0, cy - 1.0, 18 + 14 * math.sin(t + 1.2))
    # galope: par de tras empurra, par da frente alcanca (fases opostas)
    fb, ff = math.sin(t), math.sin(t + math.pi * 0.9)
    b_lift = max(0.0, -math.cos(t)) * 3.2
    f_lift = max(0.0, -math.cos(t + math.pi * 0.9)) * 3.2
    # lado de la (escuro), levemente defasado
    leg(g, 11.5, cy + 2.4, 11.5 + 3.6 * math.sin(t + 0.5), GROUND - max(0.0, -math.cos(t + 0.5)) * 3.0, 2)
    leg(g, 19.5, cy + 2.4, 19.5 + 3.8 * math.sin(t + math.pi * 0.9 + 0.5), GROUND - max(0.0, -math.cos(t + math.pi * 0.9 + 0.5)) * 3.0, 2)
    body(g, 15.0, cy, stretch, tilt=-0.06)
    line(g, 19.5 + 1.5, cy - 1.5, 23.4, 12.2 + bob * 0.7, 3, 4.2)
    head(g, 24.4, 11.8 + bob * 0.7, jaw_open=(i in (2, 3)))
    # lado de ca (claro)
    leg(g, 10.5, cy + 2.7, 10.5 + 4.4 * fb, GROUND - b_lift, 3)
    leg(g, 20.5, cy + 2.7, 20.5 + 4.6 * ff, GROUND - f_lift, 3)
    return outline(g)


def frame_kick(i):
    g = blank()
    # 0 arma (peso atras) - 1/2 chuta (pata estendida + risco de impacto) - 3 volta
    rear = (0.0, 1.6, 1.4, 0.4)[i]             # empina
    cy = 16.6 - rear * 0.4
    tail(g, 8.2, cy - 1.0, 30 + rear * 8)
    leg(g, 11.5, cy + 2.4, 10.4, GROUND, 2)
    leg(g, 19.5, cy + 2.4, 19.0 if i < 1 else 20.2, GROUND if i != 1 else GROUND - 1.0, 2)
    body(g, 14.6, cy, 1.0, tilt=-0.10 * rear)
    line(g, 19.6, cy - 1.8, 23.2, 12.0 - rear * 0.8, 3, 4.2)
    head(g, 24.2, 11.6 - rear * 0.8, jaw_open=(i in (1, 2)))
    leg(g, 10.5, cy + 2.7, 9.4, GROUND, 3)
    if i == 0:                                   # arma: pata da frente recuada
        leg(g, 20.5, cy + 2.7, 18.4, GROUND - 0.6, 3)
    elif i in (1, 2):                            # chute: pata esticada pra frente/alto
        ext = 6.4 if i == 1 else 7.2
        leg(g, 20.5, cy + 2.2, 20.5 + ext, cy + 2.8, 3)
        # risco de impacto
        for k in range(3):
            px(g, 27.5 + k, cy + 1.2 - k * 0.5, 7 if k == 0 else 4)
    else:                                        # volta
        leg(g, 20.5, cy + 2.7, 21.8, GROUND - 1.2, 3)
    return outline(g)


def frame_slide(i):
    g = blank()
    # deslizando: corpo baixo inclinado (bumbum no chao), patas frontais esticadas
    sink = (2.6, 3.4, 3.6, 3.2)[i]
    cy = 17.0 + sink
    tilt = 0.16                                 # traseira mais baixa
    tail(g, 8.0, cy - 2.5, 52)
    leg(g, 12.0, cy + 1.8, 9.4, GROUND + 0.4, 2)      # tras dobrada no chao
    body(g, 14.6, cy, 1.05, tilt=tilt)
    line(g, 19.8, cy - 2.6, 23.4, 13.6 + sink * 0.5, 3, 4.2)
    head(g, 24.4, 13.2 + sink * 0.5, jaw_open=True)
    # patas da frente esticadas rente ao chao (o carrinho)
    leg(g, 19.5, cy + 1.6, 26.0, GROUND + 0.4, 2)
    leg(g, 20.5, cy + 1.8, 27.4, GROUND + 0.2, 3)
    # poeira atras (cresce com i)
    for k in range(i + 2):
        ang = k * 1.7
        px(g, 6.0 - k * 1.4, GROUND - 0.5 - abs(math.sin(ang)) * (1.5 + i * 0.6), 4 if k % 2 else 2)
    return outline(g)


# ---------------------------------------------------------------- sheet + png
def build_sheet():
    rows = [
        [frame_idle(i) for i in range(4)],
        [frame_run(i) for i in range(6)],
        [frame_kick(i) for i in range(4)],
        [frame_slide(i) for i in range(4)],
    ]
    sheet = [[0] * (W * COLS) for _ in range(H * ROWS)]
    for r, frames in enumerate(rows):
        for c, f in enumerate(frames):
            for y in range(H):
                for x in range(W):
                    sheet[r * H + y][c * W + x] = f[y][x]
    return rows, sheet


def write_png(path, sheet):
    height = len(sheet)
    width = len(sheet[0])
    raw = b''
    for row in sheet:
        raw += b'\x00' + b''.join(bytes(PAL[c]) for c in row)

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


def show(f, label):
    print('--- %s ---' % label)
    for row in f:
        print(''.join(ASCII[c] for c in row))


if __name__ == '__main__':
    rows, sheet = build_sheet()
    out = sys.argv[1] if len(sys.argv) > 1 else 'zab.png'
    write_png(out, sheet)
    print('OK ->', out, '(%dx%d)' % (len(sheet[0]), len(sheet)))
    if '--show' in sys.argv:
        show(rows[0][0], 'idle 0')
        show(rows[1][1], 'run 1')
        show(rows[1][4], 'run 4')
        show(rows[2][1], 'kick 1 (impacto)')
        show(rows[3][2], 'slide 2')

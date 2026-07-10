# -*- coding: utf-8 -*-
"""Gera a arte do ESTÁDIO-COLISEU do World Cup Beasts.

Saídas (em assets/stadium/):
  stadium_bg.png  — fundo 1360x800 (mundo 1280x720 + 40px de overscan por lado,
                    pro shake da câmera não mostrar buraco). Desenhado em meia
                    resolução (680x400) e dobrado (nearest) = pixel chunky.
                    Conteúdo: gramado com listras de corte, faixa fora-de-campo,
                    muro do fosso, 3 anéis de arquibancada e muralha externa
                    com arcos de coliseu.
  fans_sheet.png  — torcedores-animais 12x12, 10 variantes x 3 frames
                    (0 sentado · 1 quicando · 2 comemorando de braços pra cima).
                    O Crowd.gd desenha centenas deles sobre os anéis.

GEOMETRIA COMPARTILHADA com scripts/fx/Crowd.gd (mudou aqui, muda lá):
  campo (mundo) = Rect2(90, 70, 1100, 580)
  anéis de arquibancada (distância da borda do campo, em px do mundo):
    fileira 0 (frente) = 16 · fileira 1 = 28 · fileira 2 = 40
  muro do fosso: 6..14 px da borda · muralha externa: começa a 46 px.
"""
import math
import os
import struct
import sys
import zlib

# ---------------------------------------------------------------- paleta
PAL = [
    (47, 125, 58),    # 0 grama base
    (53, 138, 66),    # 1 grama listra clara
    (40, 106, 50),    # 2 grama fora-de-campo (apron)
    (42, 33, 24),     # 3 pedra escura (sombra/degrau)
    (74, 58, 40),     # 4 pedra média (muro)
    (106, 86, 58),    # 5 pedra clara (topo de banco)
    (138, 115, 80),   # 6 pedra highlight (bordas)
    (23, 17, 11),     # 7 vão de arco (escuro)
    (216, 178, 90),   # 8 tocha/dourado
    (16, 12, 8),      # 9 void externo
]

SCALE = 2
BW, BH = 680, 400              # meia resolução; x2 = 1360x800
# campo em coordenadas de meia-res (mundo+40 overscan, /2)
FX0, FY0 = (90 + 40) // 2, (70 + 40) // 2      # 65, 55
FX1, FY1 = (1190 + 40) // 2, (650 + 40) // 2   # 615, 345

# bandas do anel, em px de meia-res a partir da borda do campo (d = 0 na linha)
APRON_END = 3        # grama fora-de-campo
WALL_END = 7         # muro do fosso (face)
ROWS = (8, 14, 20)   # início de cada banco (2px de topo claro + degrau escuro)
OUTER_START = 23     # muralha externa com arcos
OUTER_END = 33


def h2(x, y):
    """Hash determinístico 0..255 (sem random: regenerável byte a byte)."""
    n = (x * 73856093) ^ (y * 19349663)
    n = (n ^ (n >> 13)) * 1274126177
    return (n ^ (n >> 16)) & 0xFF


def ring_d(x, y):
    """Distância 'quadrada' até a borda do campo (0 dentro do campo)."""
    dx = max(FX0 - x, x - FX1, 0)
    dy = max(FY0 - y, y - FY1, 0)
    return max(dx, dy)


def perim_p(x, y):
    """Coordenada ao longo do perímetro (pra repetir arcos/pilares)."""
    dx = max(FX0 - x, x - FX1, 0)
    dy = max(FY0 - y, y - FY1, 0)
    return x if dy >= dx else y


def stadium_grid():
    g = [[0] * BW for _ in range(BH)]
    for y in range(BH):
        for x in range(BW):
            d = ring_d(x, y)
            if d == 0:
                # gramado: listras verticais de corte (34px de meia-res = 68 do mundo)
                g[y][x] = 1 if (x // 34) % 2 == 0 else 0
                continue
            if d <= APRON_END:
                g[y][x] = 2
                continue
            if d <= WALL_END:
                # muro do fosso: topo claro, face média com juntas de tijolo
                if d == APRON_END + 1:
                    g[y][x] = 6
                else:
                    g[y][x] = 3 if h2(x // 5, y // 3) < 34 else 4
                continue
            if d < OUTER_START:
                # arquibancada: bancos claros com degraus escuros
                col = 3
                for r0 in ROWS:
                    if r0 <= d <= r0 + 1:
                        col = 6 if d == r0 else 5   # topo do banco + face
                        break
                # poeirinha de variação na pedra escura
                if col == 3 and h2(x // 3, y // 3) < 22:
                    col = 4
                g[y][x] = col
                continue
            if d <= OUTER_END:
                # muralha externa: arcos de coliseu a cada 22px, vão de 12
                p = perim_p(x, y)
                cell = p % 22
                depth = d - OUTER_START          # 0..10 (fundo do arco = maior d)
                if 5 <= cell <= 16:
                    # dentro do vão: topo arredondado (vão encolhe no fundo)
                    half = 6 if depth >= 3 else (3 + depth)
                    if abs(cell - 10.5) <= half - 0.5:
                        g[y][x] = 7
                        # tocha dourada no fundo do vão
                        if depth >= 8 and abs(cell - 10.5) < 1.2 and h2(p // 22, 7) < 96:
                            g[y][x] = 8
                        continue
                if d == OUTER_START:
                    g[y][x] = 6                   # cornija clara
                else:
                    g[y][x] = 4 if h2(x // 4, y // 4) < 200 else 5
                continue
            g[y][x] = 9
    return g


# ---------------------------------------------------------------- fãs 12x12
# variantes: (nome, pelo_escuro, pelo_claro, camisa, feature)
FANS = [
    ("urso",    (94, 62, 34),   (128, 90, 52),  (63, 134, 173), "round"),
    ("gato",    (196, 150, 60), (224, 182, 92), (224, 122, 58), "point"),
    ("galo",    (210, 210, 200),(235, 235, 226),(224, 82, 99),  "comb"),
    ("coelho",  (150, 150, 156),(186, 186, 190),(95, 201, 107), "long"),
    ("croc",    (58, 122, 62),  (86, 156, 86),  (243, 210, 74), "snout"),
    ("porco",   (214, 140, 130),(232, 170, 158),(74, 144, 217), "round"),
    ("macaco",  (110, 78, 46),  (150, 110, 66), (176, 106, 224),"round"),
    ("lobo",    (104, 104, 116),(140, 140, 150),(224, 122, 58), "point"),
    ("rino",    (130, 130, 140),(162, 162, 170),(95, 201, 107), "horn"),
    ("arara",   (66, 108, 200), (96, 148, 230), (243, 210, 74), "beak"),
]
FW = FH = 12


def fan_frame(dark, light, shirt, feat, frame):
    """Grade RGBA 12x12 de um torcedor. frame: 0 sentado, 1 quica, 2 braços."""
    g = [[None] * FW for _ in range(FH)]

    def put(x, y, c):
        if 0 <= x < FW and 0 <= y < FH:
            g[int(y)][int(x)] = c

    dy = -1 if frame >= 1 else 0     # quica/comemora: corpo 1px pra cima
    # torso (camisa)
    for yy in range(8 + dy, 12):
        w = 3 if yy >= 10 else 2
        for xx in range(6 - w, 6 + w):
            put(xx, yy, shirt)
    # cabeça
    hy = 5 + dy - (1 if frame == 2 else 0)
    for yy in range(-3, 4):
        for xx in range(-3, 4):
            if xx * xx + yy * yy <= 9:
                put(6 + xx, hy + yy, light if yy < 1 else dark)
    # olhos
    eye = (20, 16, 22)
    put(5, hy, eye); put(8, hy, eye)
    if frame == 2:
        put(6, hy + 2, (240, 240, 235))          # boca aberta (gritando)
    # feature da espécie
    if feat == "point":                            # orelhas pontudas
        put(4, hy - 3, dark); put(4, hy - 4, dark)
        put(8, hy - 3, dark); put(8, hy - 4, dark)
    elif feat == "round":                          # orelhas redondas
        put(3, hy - 2, dark); put(3, hy - 3, dark); put(4, hy - 3, light)
        put(9, hy - 2, dark); put(9, hy - 3, dark); put(8, hy - 3, light)
    elif feat == "long":                           # orelhas compridas (coelho)
        for k in range(4):
            put(4, hy - 3 - k, light); put(8, hy - 3 - k, light)
    elif feat == "comb":                           # crista de galo
        red = (224, 60, 70)
        put(5, hy - 4, red); put(6, hy - 4, red); put(7, hy - 4, red); put(6, hy - 5, red)
    elif feat == "snout":                          # focinho de jacaré
        put(9, hy + 1, light); put(10, hy + 1, light)
    elif feat == "horn":                           # chifre de rino
        put(9, hy - 1, (230, 226, 214)); put(10, hy - 2, (230, 226, 214))
    elif feat == "beak":                           # bico de arara
        put(9, hy, (243, 210, 74)); put(10, hy + 1, (243, 210, 74))
    # braços
    if frame == 2:                                 # pro alto!
        put(2, hy, shirt); put(1, hy - 1, dark)
        put(10, hy, shirt); put(11, hy - 1, dark)
    else:                                          # no colo
        put(3, 9 + dy, dark); put(9, 9 + dy, dark)
    return g


def fans_sheet():
    sheet = [[None] * (FW * 3) for _ in range(FH * len(FANS))]
    for v, (_, dark, light, shirt, feat) in enumerate(FANS):
        for f in range(3):
            fr = fan_frame(dark, light, shirt, feat, f)
            for yy in range(FH):
                for xx in range(FW):
                    sheet[v * FH + yy][f * FW + xx] = fr[yy][xx]
    return sheet


# ---------------------------------------------------------------- png
def write_png(path, rows_rgba):
    def as_rgba(c):
        if c is None:
            return b'\x00\x00\x00\x00'
        if len(c) == 3:
            return bytes((c[0], c[1], c[2], 255))
        return bytes(c)

    raw = b''
    for row in rows_rgba:
        raw += b'\x00' + b''.join(as_rgba(c) for c in row)

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB',
                 len(rows_rgba[0]), len(rows_rgba), 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
    print('OK', path, '(%dx%d)' % (len(rows_rgba[0]), len(rows_rgba)))


# ---------------------------------------------------------------- mascote
# Bonecão de torcida 24x24, 4 frames de dancinha (onda de braços + quique).
# Visual PRÓPRIO (fantasia fofa de corpo redondo + camisa do time), de
# propósito DIFERENTE das feras de campo — o usuário confundia o mascote
# (que reusava spritesheet de jogador) com um "jogador bugado na torcida".
MW = MH = 24


def mascot_frame(f):
    g = [[None] * MW for _ in range(MH)]
    fur = (226, 178, 96)      # pelúcia clara
    fur2 = (190, 140, 64)     # sombra da pelúcia
    shirt = (63, 134, 173)    # camisa AZUL do time da casa (UI.HOME)
    shirt2 = (44, 100, 134)
    eye = (24, 18, 26)
    white = (240, 238, 230)

    def put(x, y, c):
        if 0 <= x < MW and 0 <= y < MH:
            g[int(y)][int(x)] = c

    def blob(cx, cy, r, c):
        for yy in range(int(cy - r), int(cy + r) + 1):
            for xx in range(int(cx - r), int(cx + r) + 1):
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r:
                    put(xx, yy, c)

    dy = -1 if f % 2 == 1 else 0                     # quique da dança
    # corpo redondo com camisa
    blob(12, 17 + dy, 5, shirt)
    for xx in range(8, 17):
        put(xx, 21 + dy, shirt2)                     # barra da camisa
    # pés
    put(9, 23, fur2); put(10, 23, fur2)
    put(14, 23, fur2); put(15, 23, fur2)
    # cabeçona de pelúcia
    blob(12, 9 + dy, 6, fur)
    for xx in range(7, 18):
        put(xx, 13 + dy, fur2)                       # queixo/sombra
    # orelhas redondas
    blob(7, 4 + dy, 2, fur2)
    blob(17, 4 + dy, 2, fur2)
    # carão: olhos grandes + sorriso
    blob(10, 8 + dy, 1.4, white); blob(15, 8 + dy, 1.4, white)
    put(10, 8 + dy, eye); put(15, 8 + dy, eye)
    for xx in range(10, 15):
        put(xx, 11 + dy, eye)
    put(9, 10 + dy, eye); put(15, 10 + dy, eye)      # cantos do sorrisão
    # focinho
    put(12, 9 + dy, fur2); put(13, 9 + dy, fur2)
    # BRAÇOS por frame (a onda: baixo → esq. cima → os dois → dir. cima)
    la_up = f in (1, 2)
    ra_up = f in (2, 3)
    if la_up:
        put(5, 12 + dy, fur); put(4, 10 + dy, fur); put(3, 8 + dy, fur2)
    else:
        put(6, 17 + dy, fur); put(5, 19 + dy, fur); put(4, 20 + dy, fur2)
    if ra_up:
        put(19, 12 + dy, fur); put(20, 10 + dy, fur); put(21, 8 + dy, fur2)
    else:
        put(18, 17 + dy, fur); put(19, 19 + dy, fur); put(20, 20 + dy, fur2)
    return g


def mascot_sheet():
    sheet = [[None] * (MW * 4) for _ in range(MH)]
    for f in range(4):
        fr = mascot_frame(f)
        for yy in range(MH):
            for xx in range(MW):
                sheet[yy][f * MW + xx] = fr[yy][xx]
    return sheet


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else 'assets/stadium'
    os.makedirs(outdir, exist_ok=True)

    # fundo: índice → RGBA opaco, dobrado x2
    g = stadium_grid()
    rgba = []
    for y in range(BH):
        row = []
        for x in range(BW):
            r, gg, b = PAL[g[y][x]]
            row.append((r, gg, b, 255))
            row.append((r, gg, b, 255))
        rgba.append(row)
        rgba.append(list(row))
    write_png(os.path.join(outdir, 'stadium_bg.png'), rgba)

    write_png(os.path.join(outdir, 'fans_sheet.png'), fans_sheet())
    write_png(os.path.join(outdir, 'mascot_sheet.png'), mascot_sheet())


if __name__ == '__main__':
    main()

# -*- coding: utf-8 -*-
"""Gera spritesheets pixel-art das 14 feras restantes do World Cup Beasts.

Arquétipos: quad (felinos/lobos/tanques), bird (galo/arara), brute (gorila),
scorp (escorpião), mantis, serpent (quetzal). Sheet 6x4 frames de 32x32:
linha 0 idle(4) · linha 1 run(6) · linha 2 kick(4) · linha 3 slide(4).
Sprite olhando para a DIREITA. Índices de cor: 1 contorno, 2 escuro, 3 médio,
4 claro, 5 acento (olho/feature), 6 acento 2, 7 branco.
"""
import zlib, struct, math, sys, os

W = H = 32
GROUND = 28.0
ASCII = {0: '.', 1: '#', 2: 'B', 3: 'b', 4: 'l', 5: 'R', 6: 'r', 7: 'W'}


# ------------------------------------------------------------------ base
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
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
    for i in range(steps + 1):
        t = i / steps
        disk(g, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, w * 0.5 + 0.15, c)


def outline(g):
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


def leg(g, hx, hy, fx, fy, col, w=2.0):
    kx = (hx + fx) * 0.5 - 0.8
    ky = (hy + fy) * 0.5
    line(g, hx, hy, kx, ky, col, w)
    line(g, kx, ky, fx, fy, col, w * 0.85)
    px(g, fx, fy, 4)


def dust(g, i, base_x=6.0):
    for k in range(i + 2):
        ang = k * 1.7
        px(g, base_x - k * 1.4, GROUND - 0.5 - abs(math.sin(ang)) * (1.5 + i * 0.6),
           4 if k % 2 else 2)


# ------------------------------------------------------------------ QUAD
def q_tail(g, bx, by, ang, kind):
    a = math.radians(ang)
    if kind == "none":
        return
    if kind == "short":
        disk(g, bx - 1.5, by - 1.0, 1.4, 2)
        return
    n = 5 if kind == "bushy" else 4
    for i in range(n):
        t = i / (n - 1.0)
        if kind == "bushy":
            r = 2.2 - 1.1 * t
        elif kind == "tuft":
            r = 0.9 if i < n - 1 else 1.6      # fino com tufo na ponta
        else:                                   # thin
            r = 1.0 - 0.3 * t
        x = bx - math.cos(a) * (2.0 + 5.5 * t)
        y = by - math.sin(a) * (2.0 + 5.5 * t) - t * t * 1.5
        col = 4 if (kind in ("bushy", "tuft") and i >= n - 2) else 2
        q = 6 if (kind == "tuft" and i == n - 1) else col
        disk(g, x, y, r, q)


def q_head(g, cfg, hx, hy, ear_twitch=False, jaw_open=False):
    r = 3.4 * cfg.get("hsize", 1.0)
    if cfg.get("mane"):
        disk(g, hx - 1.2, hy + 0.6, r + 2.4, 6)     # juba atrás da cabeça
    disk(g, hx, hy, r, 3)
    mz = cfg.get("muzzle", 1.0)
    ellipse(g, hx + r, hy + 0.8, 2.6 * mz, 1.6, 4)   # focinho
    px(g, hx + r + 2.4 * mz, hy + 0.4, 1)            # nariz
    if cfg.get("trunk"):                              # tromba caindo do focinho
        line(g, hx + r + 1.5, hy + 1.2, hx + r + 2.6, hy + 6.5, 3, 1.8)
        line(g, hx + r + 2.6, hy + 6.5, hx + r + 1.6, hy + 8.5, 3, 1.5)
    if cfg.get("tusks"):
        px(g, hx + r + 0.5, hy + 3.0, 7)
        px(g, hx + r + 1.5, hy + 2.6, 7)
    if cfg.get("horn"):                               # chifre no focinho
        line(g, hx + r + 1.2, hy - 0.4, hx + r + 2.8, hy - 3.6, 7, 1.6)
    if jaw_open:
        px(g, hx + r + 1.0, hy + 2.4, 7)
        px(g, hx + r, hy + 2.4, 1)
    ears = cfg.get("ears", "point")
    if ears == "point":
        for ex, tw in ((hx - 1.8, ear_twitch), (hx + 1.2, False)):
            top = hy - r - 2.0 - (0.8 if tw else 0.0)
            line(g, ex, hy - r + 1.0, ex + 0.4, top, 2, 1.6)
            px(g, ex + 0.4, top + 1.2, 6)
    elif ears == "round":
        disk(g, hx - 2.2, hy - r - 0.6, 1.7, 2)
        disk(g, hx + 1.6, hy - r - 0.6, 1.7, 2)
        px(g, hx - 2.2, hy - r - 0.6, 6)
    elif ears == "big":                               # orelhas de elefante
        ellipse(g, hx - 3.2, hy + 0.2, 2.8, 3.6, 2)
        ellipse(g, hx - 3.4, hy + 0.4, 1.6, 2.4, 3)
    # (tiny: sem orelhas visíveis)
    px(g, hx + 1.6, hy - 0.9, 5)                      # olho
    px(g, hx + 0.6, hy - 0.9, 1)


def q_mark(g, cfg, cx, cy, rx):
    m = cfg.get("marking", "none")
    if m == "spots":
        for k in range(6):
            a = k * 2.4
            px(g, cx - rx * 0.7 + (k * 2.3) % (rx * 1.5), cy - 2.5 + math.sin(a) * 2.2, 6)
    elif m == "stripes":
        for k in range(4):
            x = cx - rx * 0.62 + k * (rx * 0.42)
            line(g, x, cy - 3.6, x - 0.8, cy - 0.4, 6, 1.0)
    elif m == "plates":                                # placas de armadura no dorso
        for k in range(3):
            x = cx - rx * 0.55 + k * (rx * 0.42)
            line(g, x, cy - 3.8, x + 1.6, cy - 4.2, 4, 1.4)
            line(g, x, cy - 3.8, x, cy - 1.8, 6, 1.0)


def q_body(g, cfg, cx, cy, stretch=1.0, tilt=0.0):
    rx = 7.4 * cfg.get("blen", 1.0) * stretch
    ry = 4.3 * cfg.get("bulk", 1.0)
    ellipse(g, cx, cy, rx, ry, 3)
    for y in range(H):
        for x in range(W):
            if g[y][x] == 3:
                ny = (y - cy + (x - cx) * tilt)
                if ny < -ry * 0.38:
                    g[y][x] = 2
                elif ny > ry * 0.56:
                    g[y][x] = 4
    q_mark(g, cfg, cx, cy, rx)
    return rx, ry


def quad_frame(cfg, anim, i):
    g = blank()
    bulk = cfg.get("bulk", 1.0)
    lw = 2.0 * math.sqrt(bulk)
    leg_top = 2.5 * bulk
    if anim == "idle":
        bob = 0.6 if i in (1, 2) else 0.0
        cy = 17.0 + bob
        q_tail(g, 8.5, cy - 1.5, 38 + (10 if i in (2, 3) else 0), cfg.get("tail", "bushy"))
        leg(g, 12.0, cy + leg_top, 11.2, GROUND, 2, lw)
        leg(g, 19.0, cy + leg_top, 19.6, GROUND, 2, lw)
        q_body(g, cfg, 15.0, cy)
        line(g, 19.5, cy - 1.5, 23.0, 12.6 + bob, 3, 4.2 * bulk)
        q_head(g, cfg, 24.0, 12.2 + bob, ear_twitch=(i == 3))
        leg(g, 10.5, cy + leg_top, 9.6, GROUND, 3, lw)
        leg(g, 20.5, cy + leg_top, 21.4, GROUND, 3, lw)
    elif anim == "run":
        t = i / 6.0 * math.tau
        bob = 1.1 * math.sin(t + 0.8)
        cy = 16.4 + bob
        stretch = 1.0 + 0.10 * math.sin(t)
        q_tail(g, 8.0, cy - 1.0, 18 + 14 * math.sin(t + 1.2), cfg.get("tail", "bushy"))
        fb, ff = math.sin(t), math.sin(t + math.pi * 0.9)
        leg(g, 11.5, cy + leg_top - 0.3, 11.5 + 3.6 * math.sin(t + 0.5),
            GROUND - max(0.0, -math.cos(t + 0.5)) * 3.0, 2, lw)
        leg(g, 19.5, cy + leg_top - 0.3, 19.5 + 3.8 * math.sin(t + math.pi * 0.9 + 0.5),
            GROUND - max(0.0, -math.cos(t + math.pi * 0.9 + 0.5)) * 3.0, 2, lw)
        q_body(g, cfg, 15.0, cy, stretch, tilt=-0.06)
        line(g, 21.0, cy - 1.5, 23.4, 12.2 + bob * 0.7, 3, 4.2 * bulk)
        q_head(g, cfg, 24.4, 11.8 + bob * 0.7, jaw_open=(i in (2, 3)))
        leg(g, 10.5, cy + leg_top, 10.5 + 4.4 * fb, GROUND - max(0.0, -math.cos(t)) * 3.2, 3, lw)
        leg(g, 20.5, cy + leg_top, 20.5 + 4.6 * ff,
            GROUND - max(0.0, -math.cos(t + math.pi * 0.9)) * 3.2, 3, lw)
    elif anim == "kick":
        rear = (0.0, 1.6, 1.4, 0.4)[i]
        cy = 16.6 - rear * 0.4
        q_tail(g, 8.2, cy - 1.0, 30 + rear * 8, cfg.get("tail", "bushy"))
        leg(g, 11.5, cy + leg_top, 10.4, GROUND, 2, lw)
        leg(g, 19.5, cy + leg_top, 19.0 if i < 1 else 20.2,
            GROUND if i != 1 else GROUND - 1.0, 2, lw)
        q_body(g, cfg, 14.6, cy, 1.0, tilt=-0.10 * rear)
        line(g, 19.6, cy - 1.8, 23.2, 12.0 - rear * 0.8, 3, 4.2 * bulk)
        q_head(g, cfg, 24.2, 11.6 - rear * 0.8, jaw_open=(i in (1, 2)))
        leg(g, 10.5, cy + leg_top, 9.4, GROUND, 3, lw)
        if i == 0:
            leg(g, 20.5, cy + leg_top, 18.4, GROUND - 0.6, 3, lw)
        elif i in (1, 2):
            ext = 6.4 if i == 1 else 7.2
            leg(g, 20.5, cy + leg_top - 0.5, 20.5 + ext, cy + 2.8, 3, lw)
            for k in range(3):
                px(g, 27.5 + k, cy + 1.2 - k * 0.5, 7 if k == 0 else 4)
        else:
            leg(g, 20.5, cy + leg_top, 21.8, GROUND - 1.2, 3, lw)
    else:  # slide
        sink = (2.6, 3.4, 3.6, 3.2)[i]
        cy = 17.0 + sink
        q_tail(g, 8.0, cy - 2.5, 52, cfg.get("tail", "bushy"))
        leg(g, 12.0, cy + 1.8, 9.4, GROUND + 0.4, 2, lw)
        q_body(g, cfg, 14.6, cy, 1.05, tilt=0.16)
        line(g, 19.8, cy - 2.6, 23.4, 13.6 + sink * 0.5, 3, 4.2 * bulk)
        q_head(g, cfg, 24.4, 13.2 + sink * 0.5, jaw_open=True)
        leg(g, 19.5, cy + 1.6, 26.0, GROUND + 0.4, 2, lw)
        leg(g, 20.5, cy + 1.8, 27.4, GROUND + 0.2, 3, lw)
        dust(g, i)
    return outline(g)


# ------------------------------------------------------------------ BIRD
def b_tailfeathers(g, bx, by, sway, two_tone):
    for k in range(3):
        a = math.radians(38 + k * 16 + sway)
        col = 6 if (two_tone and k == 1) else 2
        line(g, bx, by, bx - math.cos(a) * (7.5 - k), by - math.sin(a) * (7.5 - k), col, 1.6)


def b_head(g, cfg, hx, hy, jaw_open=False):
    disk(g, hx, hy, 2.9, 3)
    if cfg.get("face_white"):
        ellipse(g, hx + 1.2, hy + 0.3, 1.6, 1.4, 7)
    # bico
    if cfg.get("beak") == "curved":                   # arara
        line(g, hx + 2.6, hy - 0.4, hx + 4.6, hy + 0.6, 1, 1.8)
        px(g, hx + 4.2, hy + 1.6, 1)
    else:                                             # galo
        line(g, hx + 2.6, hy + 0.2, hx + 4.8, hy + 0.6, 5, 1.6)
        if jaw_open:
            px(g, hx + 3.6, hy + 1.6, 5)
    # crista
    if cfg.get("comb"):
        for k in range(3):
            px(g, hx - 1.2 + k * 1.3, hy - 3.6 - (k % 2), 6)
            px(g, hx - 1.2 + k * 1.3, hy - 2.8, 6)
        px(g, hx + 2.0, hy + 2.6, 6)                  # barbela
    if cfg.get("crest"):
        for k in range(3):
            line(g, hx - 0.5, hy - 2.6, hx - 2.5 - k * 1.2, hy - 4.0 - k * 0.8, 5 if k == 1 else 2, 1.2)
    px(g, hx + 1.2, hy - 0.7, 5 if not cfg.get("eye7") else 7)
    px(g, hx + 0.3, hy - 0.7, 1)


def bird_frame(cfg, anim, i):
    g = blank()
    if anim == "idle":
        bob = 0.5 if i in (1, 2) else 0.0
        cy = 18.5 + bob
        b_tailfeathers(g, 10.5, cy - 1.5, 4 * math.sin(i * 1.5), cfg.get("tail2", False))
        ellipse(g, 15.0, cy, 5.6, 4.6, 3)             # corpo
        ellipse(g, 17.0, cy + 1.6, 3.2, 2.4, 4)       # peito
        if cfg.get("chest6"):
            ellipse(g, 17.2, cy + 1.4, 2.0, 1.6, 5)
        ellipse(g, 13.5, cy - 0.5, 3.4, 2.6, 6 if cfg.get("wing6") else 2)   # asa
        line(g, 17.5, cy - 3.0, 19.5, 11.6 + bob, 3, 3.0)   # pescoço
        b_head(g, cfg, 20.5, 10.8 + bob)
        leg(g, 13.5, cy + 3.6, 12.8, GROUND, 5, 1.2)
        leg(g, 16.5, cy + 3.6, 17.0, GROUND, 5, 1.2)
    elif anim == "run":
        t = i / 6.0 * math.tau
        bob = 1.0 * math.sin(t * 2.0)
        cy = 17.8 + bob
        b_tailfeathers(g, 10.5, cy - 1.5, 8 * math.sin(t), cfg.get("tail2", False))
        ellipse(g, 15.0, cy, 5.8, 4.4, 3)
        ellipse(g, 17.0, cy + 1.6, 3.2, 2.2, 4)
        if cfg.get("chest6"):
            ellipse(g, 17.2, cy + 1.4, 2.0, 1.5, 5)
        # asa abre um pouco no meio do passo
        wl = 3.4 + 1.2 * max(0.0, math.sin(t))
        ellipse(g, 13.0, cy - 0.8, wl, 2.6, 6 if cfg.get("wing6") else 2)
        line(g, 17.5, cy - 3.0, 19.8, 11.0 + bob * 0.6, 3, 3.0)
        b_head(g, cfg, 20.8, 10.2 + bob * 0.6, jaw_open=(i in (2, 3)))
        # pernas alternadas (passada de ave)
        fa, fb_ = math.sin(t), math.sin(t + math.pi)
        leg(g, 13.5, cy + 3.4, 13.5 + 4.2 * fa, GROUND - max(0.0, -math.cos(t)) * 3.4, 5, 1.2)
        leg(g, 16.5, cy + 3.4, 16.5 + 4.2 * fb_, GROUND - max(0.0, math.cos(t)) * 3.4, 5, 1.2)
    elif anim == "kick":
        rear = (0.0, 1.4, 1.2, 0.3)[i]
        cy = 18.0 - rear * 0.5
        b_tailfeathers(g, 10.5, cy - 1.5, -6 * rear, cfg.get("tail2", False))
        ellipse(g, 14.6, cy, 5.6, 4.5, 3)
        ellipse(g, 16.6, cy + 1.6, 3.0, 2.2, 4)
        wl = 3.4 + rear * 1.4
        ellipse(g, 12.8, cy - 1.0, wl, 2.8, 6 if cfg.get("wing6") else 2)
        line(g, 17.0, cy - 3.0, 19.4, 11.2 - rear, 3, 3.0)
        b_head(g, cfg, 20.4, 10.4 - rear, jaw_open=(i in (1, 2)))
        leg(g, 13.5, cy + 3.4, 12.6, GROUND, 5, 1.2)
        if i == 0:
            leg(g, 16.5, cy + 3.4, 14.8, GROUND - 0.6, 5, 1.3)
        elif i in (1, 2):
            ext = 6.8 if i == 1 else 7.6
            leg(g, 16.5, cy + 2.8, 16.5 + ext, cy + 3.6, 5, 1.4)
            for k in range(3):
                px(g, 24.5 + k, cy + 2.4 - k * 0.5, 7 if k == 0 else 4)
        else:
            leg(g, 16.5, cy + 3.4, 17.6, GROUND - 1.0, 5, 1.2)
    else:  # slide — mergulho de asa
        sink = (2.2, 3.0, 3.2, 2.8)[i]
        cy = 19.0 + sink
        b_tailfeathers(g, 10.0, cy - 2.5, -14, cfg.get("tail2", False))
        ellipse(g, 14.6, cy, 6.2, 3.8, 3)
        ellipse(g, 16.8, cy + 1.2, 3.2, 2.0, 4)
        ellipse(g, 12.4, cy - 1.6, 4.6, 2.4, 6 if cfg.get("wing6") else 2)   # asa aberta
        line(g, 18.0, cy - 2.4, 21.0, cy - 4.2, 3, 2.8)
        b_head(g, cfg, 22.0, cy - 4.6, jaw_open=True)
        leg(g, 15.0, cy + 2.6, 21.5, GROUND + 0.2, 5, 1.2)
        leg(g, 13.0, cy + 2.6, 19.0, GROUND + 0.4, 5, 1.1)
        dust(g, i)
    return outline(g)


# ------------------------------------------------------------------ BRUTE (gorila)
def brute_frame(cfg, anim, i):
    g = blank()

    def torso(cx, cy, tilt=0.0):
        ellipse(g, cx, cy, 6.2, 6.6, 3)
        # dorso prateado
        for y in range(H):
            for x in range(W):
                if g[y][x] == 3 and (y - cy + (x - cx) * tilt) < -2.2:
                    g[y][x] = 4
        ellipse(g, cx + 2.0, cy + 3.4, 3.4, 2.6, 2)   # barriga escura

    def bhead(hx, hy, jaw=False):
        disk(g, hx, hy, 2.8, 3)
        line(g, hx - 2.0, hy - 1.8, hx + 2.0, hy - 1.8, 2, 1.6)   # testa/brow
        ellipse(g, hx + 1.6, hy + 1.0, 1.8, 1.4, 4)               # focinho
        px(g, hx + 0.8, hy - 0.8, 5)
        px(g, hx - 0.2, hy - 0.8, 1)
        if jaw:
            px(g, hx + 2.2, hy + 2.2, 7)

    if anim == "idle":
        bob = 0.5 if i in (1, 2) else 0.0
        cy = 16.5 + bob
        torso(14.0, cy)
        bhead(17.5, cy - 7.2)
        # braços longos apoiados (nós dos dedos)
        line(g, 17.5, cy - 2.0, 21.5 + (0.5 if i == 3 else 0.0), GROUND - 1.0, 2, 2.6)
        disk(g, 21.8, GROUND - 0.8, 1.6, 2)
        line(g, 16.5, cy - 2.4, 20.0, GROUND - 1.0, 3, 2.6)
        disk(g, 20.2, GROUND - 0.8, 1.6, 3)
        # pernas curtas atrás
        leg(g, 11.0, cy + 4.5, 9.8, GROUND, 2, 2.4)
        leg(g, 12.5, cy + 4.8, 12.0, GROUND, 3, 2.4)
    elif anim == "run":
        t = i / 6.0 * math.tau
        bob = 1.2 * math.sin(t + 0.6)
        cy = 15.8 + bob
        rock = 0.10 * math.sin(t)
        torso(14.0, cy, rock)
        bhead(17.8, cy - 7.0 + bob * 0.3, jaw=(i in (2, 3)))
        # galope de nós de dedos: braços alcançam, pernas empurram
        fa = math.sin(t)
        ax = 19.5 + 4.5 * fa
        ay = GROUND - 1.0 - max(0.0, -math.cos(t)) * 3.0
        line(g, 17.5, cy - 2.0, ax, ay, 3, 2.6)
        disk(g, ax + 0.3, ay + 0.2, 1.6, 3)
        line(g, 16.5, cy - 2.4, ax - 2.0, ay + 0.4, 2, 2.4)
        disk(g, ax - 1.7, ay + 0.6, 1.4, 2)
        fbk = math.sin(t + math.pi)
        leg(g, 11.0, cy + 4.4, 11.0 + 3.6 * fbk, GROUND - max(0.0, math.cos(t)) * 2.6, 2, 2.4)
        leg(g, 12.5, cy + 4.7, 12.5 + 3.8 * fbk, GROUND - max(0.0, math.cos(t)) * 2.6, 3, 2.4)
    elif anim == "kick":                              # soco!
        rear = (0.0, 1.6, 1.4, 0.4)[i]
        cy = 16.2 - rear * 0.3
        torso(13.6, cy, -0.06 * rear)
        bhead(17.2, cy - 7.0 - rear * 0.4, jaw=(i in (1, 2)))
        leg(g, 11.0, cy + 4.5, 9.6, GROUND, 2, 2.4)
        leg(g, 12.5, cy + 4.8, 11.8, GROUND, 3, 2.4)
        line(g, 16.5, cy - 2.4, 19.6, GROUND - 1.2, 2, 2.5)   # braço de apoio
        disk(g, 19.8, GROUND - 1.0, 1.5, 2)
        if i == 0:
            line(g, 17.5, cy - 3.0, 14.5, cy - 5.0, 3, 2.8)   # arma o soco
            disk(g, 14.2, cy - 5.2, 1.9, 3)
        elif i in (1, 2):
            ext = 7.6 if i == 1 else 8.4
            line(g, 17.5, cy - 3.0, 17.5 + ext, cy - 3.4, 3, 2.8)
            disk(g, 17.8 + ext, cy - 3.4, 2.0, 3)
            for k in range(3):
                px(g, 20.5 + ext + k, cy - 3.6 - k * 0.4, 7 if k == 0 else 4)
        else:
            line(g, 17.5, cy - 2.6, 20.5, cy + 1.0, 3, 2.6)
    else:  # slide — investida de ombro
        sink = (2.4, 3.2, 3.4, 3.0)[i]
        cy = 17.5 + sink
        torso(14.0, cy, 0.14)
        bhead(19.0, cy - 5.2, jaw=True)
        line(g, 17.0, cy - 1.0, 24.5, GROUND + 0.2, 3, 2.6)
        disk(g, 24.8, GROUND + 0.2, 1.7, 3)
        line(g, 16.0, cy - 1.4, 22.5, GROUND + 0.4, 2, 2.4)
        leg(g, 11.0, cy + 3.0, 8.6, GROUND + 0.4, 2, 2.4)
        dust(g, i)
    return outline(g)


# ------------------------------------------------------------------ SCORP
def scorp_frame(cfg, anim, i):
    g = blank()

    def base(cy, tail_lift, claw_ext=0.0, legs_t=0.0, moving=False):
        # cauda: segmentos subindo por cima do corpo
        for k in range(5):
            t = k / 4.0
            x = 10.0 - t * 4.0
            y = cy - 1.0 - t * (5.5 + tail_lift)
            disk(g, x, y, 2.0 - 0.5 * t, 2)
        sx = 6.0 + (2.0 if tail_lift > 2 else 0.0)
        sy = cy - 7.0 - tail_lift * 1.4
        disk(g, sx, sy, 1.3, 6)
        px(g, sx + 1.4, sy - 0.8, 5)                  # ferrão
        # corpo baixo (abdômen + tórax)
        ellipse(g, 12.5, cy, 5.0, 3.0, 3)
        ellipse(g, 18.5, cy - 0.4, 4.2, 2.8, 3)
        ellipse(g, 13.0, cy + 1.2, 4.0, 1.4, 4)
        for k in range(3):                            # segmentos
            line(g, 10.5 + k * 3.0, cy - 2.6, 10.5 + k * 3.0, cy - 0.6, 2, 1.0)
        # olhos
        px(g, 21.5, cy - 2.2, 5)
        px(g, 20.5, cy - 2.2, 1)
        # pinças à frente
        for side, dy in ((0, -1.2), (1, 1.0)):
            ax = 22.5 + claw_ext
            line(g, 20.5, cy + dy, ax + 1.5, cy + dy + (0.5 if side else -0.5), 2 if side == 0 else 3, 1.8)
            disk(g, ax + 2.6, cy + dy + (0.6 if side else -0.6), 1.8, 2 if side == 0 else 3)
            px(g, ax + 3.8, cy + dy + (0.6 if side else -0.6), 1)   # boca da pinça
        # patas (3 de cada lado)
        for k in range(3):
            ph = legs_t + k * 2.1
            sw = math.sin(ph) * (2.2 if moving else 0.6)
            lift = max(0.0, -math.cos(ph)) * (2.0 if moving else 0.0)
            line(g, 12.0 + k * 3.0, cy + 1.5, 11.0 + k * 3.0 + sw, GROUND - lift, 2, 1.1)
            line(g, 13.0 + k * 3.0, cy + 1.8, 12.2 + k * 3.0 - sw, GROUND, 3, 1.1)

    if anim == "idle":
        cy = 23.5
        base(cy, (0.0, 0.5, 0.8, 0.4)[i], claw_ext=(0.0, 0.0, 0.4, 0.0)[i])
    elif anim == "run":
        t = i / 6.0 * math.tau
        cy = 23.2 + 0.5 * math.sin(t * 2)
        base(cy, 0.6 + 0.4 * math.sin(t), legs_t=t * 1.5, moving=True)
    elif anim == "kick":                              # bote do ferrão por cima
        cy = 23.5
        lift = (1.0, 3.4, 3.0, 1.2)[i]
        base(cy, lift, claw_ext=(0.0, 1.8, 2.4, 0.5)[i])
        if i in (1, 2):                               # ferrão chicoteia à frente
            sx, sy = 16.0 + i * 3.0, cy - 9.5
            line(g, 8.0, cy - 8.0, sx, sy, 2, 1.6)
            disk(g, sx + 0.8, sy, 1.3, 6)
            px(g, sx + 2.2, sy + 0.6, 5)
            for k in range(2):
                px(g, sx + 3.2 + k, sy + 1.2 + k, 7 if k == 0 else 4)
    else:  # slide — disparada rasteira
        cy = 24.5 + (0.4, 0.8, 1.0, 0.8)[i]
        base(cy, 0.2, claw_ext=1.6, legs_t=i * 2.0, moving=True)
        dust(g, i, base_x=5.0)
    return outline(g)


# ------------------------------------------------------------------ MANTIS
def mantis_frame(cfg, anim, i):
    g = blank()

    def base(cy, lean, arm_ext=0.0, legs_t=0.0, moving=False, wings_open=0.0):
        # abdômen inclinado + tórax ereto (postura de louva-a-deus)
        ellipse(g, 11.0, cy, 4.8, 2.6, 3)
        for k in range(3):
            line(g, 8.5 + k * 2.2, cy - 1.8, 8.5 + k * 2.2, cy + 1.2, 2, 0.9)
        # asas dobradas nas costas (abrem no slide)
        line(g, 8.0, cy - 2.0 - wings_open * 2.0, 15.0, cy - 3.5 - wings_open * 3.0, 4, 1.4)
        line(g, 7.0, cy - 1.2 - wings_open * 3.0, 14.0, cy - 4.5 - wings_open * 4.0, 2, 1.2)
        # tórax sobe pra frente
        tx, ty = 16.5 + lean, cy - 5.5
        line(g, 14.0, cy - 1.0, tx, ty, 3, 2.6)
        # cabeça triangular + antenas
        hx, hy = tx + 2.5, ty - 3.0
        disk(g, hx, hy, 2.0, 3)
        px(g, hx + 1.8, hy + 0.4, 4)
        px(g, hx + 1.0, hy - 0.6, 5)                  # olho grande
        px(g, hx + 2.0, hy - 0.9, 5)
        line(g, hx, hy - 1.8, hx - 3.0, hy - 5.0, 2, 0.8)
        line(g, hx + 1.0, hy - 1.8, hx - 1.0, hy - 5.6, 2, 0.8)
        # braços raptoriais (dobrados em zigue; estendem no golpe)
        for side, col, dy in ((0, 2, 0.8), (1, 3, 0.0)):
            sx, sy = tx + 1.0, ty + 1.0 + dy
            if arm_ext <= 0.0:
                mx, my = sx + 2.5, sy + 2.5
                line(g, sx, sy, mx, my, col, 1.6)
                line(g, mx, my, mx + 1.5, my - 3.5, col, 1.4)
                px(g, mx + 1.8, my - 4.2, 1)
            else:
                ex = sx + 4.0 + arm_ext * 3.0
                line(g, sx, sy, ex, sy - 1.0, col, 1.6)
                line(g, ex, sy - 1.0, ex + 2.5, sy - 0.2, col, 1.3)
                px(g, ex + 3.0, sy, 1)
        # pernas traseiras longas (4)
        for k in range(2):
            ph = legs_t + k * math.pi
            sw = math.sin(ph) * (2.6 if moving else 0.4)
            lift = max(0.0, -math.cos(ph)) * (2.4 if moving else 0.0)
            leg(g, 10.0 + k * 3.5, cy + 1.0, 8.5 + k * 3.5 + sw, GROUND - lift, 2, 1.2)
            leg(g, 11.5 + k * 3.5, cy + 1.4, 10.5 + k * 3.5 - sw * 0.8, GROUND, 3, 1.2)

    if anim == "idle":
        cy = 21.5 + (0.0, 0.4, 0.4, 0.0)[i]
        base(cy, (0.0, 0.0, 0.3, 0.0)[i])
    elif anim == "run":
        t = i / 6.0 * math.tau
        cy = 21.0 + 0.7 * math.sin(t * 2)
        base(cy, 1.0, legs_t=t, moving=True)
    elif anim == "kick":                              # golpe raptorial
        cy = 21.5
        base(cy, (0.0, 2.0, 2.2, 0.6)[i], arm_ext=(0.0, 1.6, 2.2, 0.0)[i])
        if i in (1, 2):
            for k in range(3):
                px(g, 27.0 + k * 0.8, 14.0 - k, 7 if k == 0 else 4)
    else:  # slide — investida com asas abertas
        cy = 23.0 + (0.6, 1.2, 1.4, 1.0)[i]
        base(cy, 2.4, arm_ext=1.0, legs_t=i * 1.8, moving=True, wings_open=1.0)
        dust(g, i, base_x=4.5)
    return outline(g)


# ------------------------------------------------------------------ SERPENT (quetzal)
def serpent_frame(cfg, anim, i):
    g = blank()

    def body(phase, amp, head_ext=0.0, lift=0.0, jaw=False):
        n = 16
        pts = []
        for k in range(n):
            t = k / (n - 1.0)
            x = 5.0 + t * (19.0 + head_ext)
            y = 19.0 - lift * t - math.sin(t * math.tau * 1.2 + phase) * amp * (0.4 + 0.6 * (1 - t))
            pts.append((x, y))
        for k, (x, y) in enumerate(pts):
            r = 1.6 + 1.1 * math.sin((k / (n - 1.0)) * math.pi)
            disk(g, x, y, r, 3)
        for k, (x, y) in enumerate(pts):
            if k % 3 == 0:
                px(g, x, y + 1.5, 4)                  # barriga clara
            if k % 4 == 1:
                px(g, x, y - 2.0, 6)                  # penas douradas no dorso
        # asinhas emplumadas no meio do corpo
        mx, my = pts[7]
        line(g, mx, my - 2.0, mx - 3.5, my - 5.5, 5, 1.4)
        line(g, mx + 1.5, my - 2.0, mx - 1.5, my - 6.0, 6, 1.2)
        # cabeça + crista de penas vermelhas
        hx, hy = pts[-1][0] + 1.5, pts[-1][1] - 0.5
        disk(g, hx, hy, 2.6, 3)
        ellipse(g, hx + 2.2, hy + 0.6, 1.8, 1.2, 4)   # focinho
        px(g, hx + 3.8, hy + 0.4, 1)
        for k in range(3):                            # crista
            line(g, hx - 0.5, hy - 2.0, hx - 3.0 - k * 1.4, hy - 3.5 - k * 1.0, 5, 1.3)
        px(g, hx + 1.2, hy - 0.8, 6)                  # olho dourado
        px(g, hx + 0.3, hy - 0.8, 1)
        if jaw:
            px(g, hx + 2.8, hy + 1.8, 7)
            line(g, hx + 2.0, hy + 1.6, hx + 3.4, hy + 2.6, 1, 0.8)
        return hx, hy

    if anim == "idle":
        ph = i / 4.0 * math.tau
        hx, hy = body(ph, 1.6)
        if i == 3:
            line(g, hx + 4.0, hy + 0.6, hx + 6.0, hy + 0.4, 5, 0.8)   # língua
    elif anim == "run":
        ph = i / 6.0 * math.tau
        body(ph * 1.0, 2.6, lift=1.0, jaw=(i in (2, 3)))
    elif anim == "kick":                              # bote da cabeça
        ext = (0.0, 4.0, 5.0, 1.0)[i]
        hx, hy = body(1.0, 1.4, head_ext=ext, jaw=(i in (1, 2)))
        if i in (1, 2):
            for k in range(3):
                px(g, hx + 4.5 + k, hy - 0.5 - k * 0.4, 7 if k == 0 else 4)
    else:  # slide — dá um mergulho rasante
        ph = i / 4.0 * math.tau
        body(ph, 1.2, lift=-2.0, jaw=True)
        dust(g, i, base_x=5.0)
    return outline(g)


# ------------------------------------------------------------------ CONFIGS
BEASTS = {
    # --- quadrúpedes ---
    "zak": {"arch": "quad", "bulk": 0.9, "blen": 1.0, "ears": "point", "tail": "thin",
            "marking": "spots", "muzzle": 0.9,
            "pal": {2: (139, 94, 38), 3: (217, 163, 66), 4: (245, 222, 158),
                    5: (255, 178, 44), 6: (71, 47, 24)}},
    "lobo": {"arch": "quad", "bulk": 1.0, "blen": 1.0, "ears": "point", "tail": "bushy",
             "marking": "none",
             "pal": {2: (84, 101, 122), 3: (127, 150, 173), 4: (196, 212, 229),
                     5: (140, 220, 255), 6: (60, 72, 90)}},
    "boss_leao": {"arch": "quad", "bulk": 1.15, "blen": 1.05, "ears": "round", "tail": "tuft",
                  "marking": "none", "mane": True, "hsize": 1.05,
                  "pal": {2: (150, 95, 26), 3: (201, 143, 46), 4: (240, 205, 130),
                          5: (255, 90, 40), 6: (122, 62, 20)}},
    "elite_tigre": {"arch": "quad", "bulk": 1.05, "blen": 1.05, "ears": "round", "tail": "thin",
                    "marking": "stripes",
                    "pal": {2: (150, 72, 24), 3: (217, 122, 43), 4: (240, 225, 200),
                            5: (255, 200, 60), 6: (40, 30, 26)}},
    "urso": {"arch": "quad", "bulk": 1.3, "blen": 1.05, "ears": "round", "tail": "short",
             "marking": "none", "muzzle": 1.1,
             "pal": {2: (74, 48, 30), 3: (110, 74, 47), 4: (170, 130, 95),
                     5: (255, 170, 60), 6: (52, 32, 20)}},
    "rinoceronte": {"arch": "quad", "bulk": 1.35, "blen": 1.1, "ears": "tiny", "tail": "thin",
                    "marking": "none", "horn": True, "muzzle": 1.15,
                    "pal": {2: (94, 97, 106), 3: (138, 141, 149), 4: (190, 193, 201),
                            5: (240, 120, 60), 6: (70, 72, 80)}},
    "elite_elefante": {"arch": "quad", "bulk": 1.4, "blen": 1.1, "ears": "big", "tail": "thin",
                       "marking": "none", "trunk": True, "tusks": True, "muzzle": 0.6,
                       "pal": {2: (84, 90, 104), 3: (125, 131, 143), 4: (178, 184, 196),
                               5: (255, 220, 120), 6: (66, 70, 82)}},
    "cuirass": {"arch": "quad", "bulk": 1.2, "blen": 1.05, "ears": "tiny", "tail": "short",
                "marking": "plates", "muzzle": 0.9,
                "pal": {2: (86, 90, 99), 3: (122, 127, 136), 4: (183, 189, 201),
                        5: (255, 120, 60), 6: (58, 60, 70)}},
    # --- aves ---
    "foot": {"arch": "bird", "comb": True, "beak": "straight", "wing6": False,
             "pal": {2: (34, 60, 66), 3: (201, 75, 50), 4: (245, 205, 140),
                     5: (240, 190, 60), 6: (228, 44, 58)}},
    "arara": {"arch": "bird", "crest": True, "beak": "curved", "wing6": True,
              "tail2": True, "chest6": True, "face_white": True,
              "pal": {2: (140, 32, 48), 3: (216, 56, 74), 4: (235, 130, 130),
                      5: (240, 190, 70), 6: (63, 111, 217)}},
    # --- bruto ---
    "elite_gorila": {"arch": "brute",
                     "pal": {2: (40, 43, 52), 3: (58, 61, 74), 4: (154, 162, 174),
                             5: (255, 120, 90), 6: (28, 30, 36)}},
    # --- insetos ---
    "escorpiao": {"arch": "scorp",
                  "pal": {2: (94, 34, 24), 3: (142, 58, 40), 4: (200, 110, 70),
                          5: (255, 90, 60), 6: (64, 22, 16)}},
    "boss_mantis": {"arch": "mantis",
                    "pal": {2: (52, 110, 48), 3: (95, 174, 74), 4: (170, 220, 130),
                            5: (255, 220, 100), 6: (36, 72, 36)}},
    # --- serpente ---
    "boss_quetzal": {"arch": "serpent",
                     "pal": {2: (32, 110, 90), 3: (63, 174, 143), 4: (150, 230, 190),
                             5: (228, 60, 70), 6: (220, 180, 60)}},
}

FRAME_FN = {"quad": quad_frame, "bird": bird_frame, "brute": brute_frame,
            "scorp": scorp_frame, "mantis": mantis_frame, "serpent": serpent_frame}
ANIMS = [("idle", 4), ("run", 6), ("kick", 4), ("slide", 4)]


def build_sheet(bid):
    cfg = BEASTS[bid]
    fn = FRAME_FN[cfg["arch"]]
    rows = [[fn(cfg, a, i) for i in range(n)] for a, n in ANIMS]
    sheet = [[0] * (W * 6) for _ in range(H * 4)]
    for r, frames in enumerate(rows):
        for c, f in enumerate(frames):
            for y in range(H):
                for x in range(W):
                    sheet[r * H + y][c * W + x] = f[y][x]
    return rows, sheet


def write_png(path, sheet, pal):
    full = {0: (0, 0, 0, 0), 1: (18, 14, 24, 255), 7: (236, 233, 226, 255)}
    for k, rgb in pal.items():
        full[k] = (rgb[0], rgb[1], rgb[2], 255)
    raw = b''
    for row in sheet:
        raw += b'\x00' + b''.join(bytes(full[c]) for c in row)

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', len(sheet[0]), len(sheet), 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


def show(f, label):
    print('--- %s ---' % label)
    for row in f:
        print(''.join(ASCII[c] for c in row))


if __name__ == '__main__':
    outdir = sys.argv[1]
    only = [a for a in sys.argv[2:] if not a.startswith('--')]
    for bid in (only if only else BEASTS):
        rows, sheet = build_sheet(bid)
        write_png(os.path.join(outdir, '%s_sheet.png' % bid), sheet, BEASTS[bid]["pal"])
        print('OK', bid)
        if '--show' in sys.argv:
            show(rows[1][1], bid + ' run1')

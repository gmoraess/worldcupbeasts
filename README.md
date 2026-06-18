# ⚽🔥 World Cup Beasts

> **Futebol arcade 2D com física de bola real + roguelike**, num mundo gótico onde nações de feras decidem tudo no futebol. Você comanda uma fera-campeã e sua seleção sobrenatural numa gauntlet de 3 atos rumo ao título — montando **build + tática** e **assistindo** a partida emergir de uma física de verdade.

Feito em **Godot 4** (GDScript). Este repositório é a **reconstrução com física real** (ver [HISTORY.md](HISTORY.md) para a jornada de design). O repo antigo [`football-autobattler`](https://github.com/gmoraess/football-autobattler) fica apenas como **histórico**.

---

## 🎯 A visão (o que o jogo É)

Um futebol arcade onde **a bola é a estrela**: passes que correm pelo gramado, cruzamentos que sobem, chutes que curvam e pegam fogo, e o gol em câmera lenta com zoom. Você **não micra 10 jogadores** — você monta o time e a tática (camada roguelike) e a partida **roda sozinha** (autobattler); o espetáculo é assistir o time tramar a jogada. A profundidade vem da corrida: feras, sinergias, relíquias, eventos, mata-mata.

### Os 4 pilares
1. **A bola é a estrela** — física custom: previsível quando importa, caótica onde diverte.
2. **O lance é o espetáculo** — o passe que corre, a tabela, o chute em slow-motion com fogo na rede.
3. **Você gerencia e finaliza, não micra** — agência na build + tática (a partida é auto-simulada).
4. **Profundidade vem do roguelike**, não do realismo.

---

## ▶️ Como rodar

1. Abra o **Godot 4** (4.2+; testado no 4.6.3).
2. **Import** → aponte para `project.godot` → confirme.
3. **F5** (cena principal: `scenes/Match.tscn`).

- **`scenes/Match.tscn`** — a **partida** (auto-simulada; você assiste).
- **`scenes/Main.tscn`** — o **sandbox da bola** (Etapa 0): chuta à vontade pra sentir a física. Controles: segura/solta o botão esquerdo (potência), A/D curva, W elevar, 1-5 presets, R reseta, Tab+↑↓ ajusta o feel ao vivo.

---

## 🧱 Arquitetura (camadas fracamente acopladas)

```
META (roguelike)      -> corrida, feras, relíquias, eventos, mapa de 3 atos      [a portar]
   | entrega "time A vs time B + modificadores"
SIM (a partida)       -> física da bola + jogadores (CharacterBody2D) + IA + regras
   | emite eventos (passe, chute, gol, defesa, roubo)
APRESENTAÇÃO          -> câmera (zoom/slow-mo), partículas (fogo/rastro), shake, rede, "GOOOL!"
HUD                   -> broadcast minimalista (placar + relógio)
```

**Scripts:**
- `scripts/Ball.gd` — bola com **física custom** (`CharacterBody2D`): atrito do gramado, curva (Magnus/spin), quicada (restituição), **altura falsa (eixo z 2D)** p/ lobs/voleios, e **slow-motion local** (não global, pra HUD/câmera ficarem fluidas).
- `scripts/Player.gd` — jogador com steering (arrive), freio rápido (sem "deslize no gelo"), e características individuais (velocidade/seguir-bloco próprios).
- `scripts/Match.gd` — a partida **100% auto-simulada**: posse, cérebro do lance (dribla/passa/finaliza), **defesa zonal** (bloco que desliza, imperfeito), goleiro (fecha ângulo, espalma, distribui), gols, placar, relógio, e o juice (slow-mo/zoom/shake/fogo/GOOOL).

---

## 🗺️ Roadmap (etapas)

- **Etapa 0 — Vertical slice da bola** ✅ — sandbox que prova que a bola é incrível (portão vai/não-vai). **Aprovado.**
- **Etapa 1 — A partida** ✅ — futebol N×N que emerge da física + IA: movimento meio-termo (linha junta mas imperfeita), passes que conectam, defesa zonal, goleiro, placar realista.
- **Etapa 2 — A corrida (roguelike)** 🔄 — **jogável**: `GameState` com feras como **perfis de stats que enviesam a física**, relíquias mexendo em **parâmetros físicos**, mapa de 3 atos, loja, eventos; roteador (seleção→mapa→partida→relíquia/evento/loja→resultado). Falta: passe de **balanceamento/paridade** entre feras e valor da loja.
- **Etapa 3 — HUD broadcast + juice + arte** ⏳ — transmissão minimalista, feras como sprites, áudio.
- **Etapa 4 — Conteúdo e meta** ⏳ — mais feras, desbloqueáveis, balanceamento.

---

## ⚙️ Como o futebol funciona (sem cartas nem determinismo)

O resultado **emerge** da física; a confiabilidade da build vem de **stats que enviesam o motor** (não números fixos): Finalização -> potência/precisão do chute; Controle -> menos perda no contato; Desarme -> força do bote; Defesa -> alcance do goleiro; Fôlego -> fadiga. Um time melhor vence **na maioria** das vezes, com zebras — como futebol de verdade.

---

*Tecnologia: Godot 4 · GDScript · física e IA custom (sem RigidBody cru na bola).*

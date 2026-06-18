# 📜 Histórico do World Cup Beasts

Registro da jornada de design e dos avanços. Cada avanço também fica nos commits.

## A jornada de direção (por que chegamos aqui)
O projeto passou por **três direções** até achar a certa (protótipo é a fase de pivotar):

1. **Autobattler de física** (`index.html`, "Mundial dos Mitos") — futebol com física em tempo real, jogadores como discos. Arquivado.
2. **Duelo de cartas / 4 barras** (`beasts.html` → port Godot em [`football-autobattler`](https://github.com/gmoraess/football-autobattler)) — duelo por turnos determinístico com deck-building e roguelike de 3 atos. Funcionava e foi validado headless, mas **não estava divertido** de jogar.
3. **Futebol arcade 2D com física de bola REAL** (este repo, guiado pelo `GDD_FISICA_GODOT`) — joga fora cartas/determinismo; a bola vira a estrela com física custom; o resultado emerge da física + stats; a profundidade vem do roguelike por cima. **Direção atual.**

O repo `football-autobattler` fica como **histórico**; este é a reconstrução.

---

## Avanços (este repositório)

### Etapa 0 — Vertical slice da bola ✅ (portão vai/não-vai)
- Bola com física custom: atrito do gramado, curva (Magnus), quicada, altura falsa (z), slow-motion local.
- Sandbox de chute (potência/curva/elevação + presets) com câmera lenta, zoom, fogo, rede, screen shake.
- **Critério:** "chuta 20 vezes e sorri" — **aprovado pelo usuário.**

### Etapa 1 — A partida (auto-simulada) 🔄
Futebol N×N que **emerge da física + IA** (autobattler: você assiste, sem comandos). Iterações:

1. **Primeira versão jogável** — 2 times 5v5, posse por proximidade, cérebro do lance (dribla/passa/finaliza), defesa, goleiro, placar, kickoff. Gols emergindo.
2. **Anti-gelo + forma de time + ritmo arcade** — jogadores freiam rápido (fim do "deslize no gelo"); carregador/atacantes/meio/defesa com papéis; goleiro fecha ângulo.
3. **Anti-pinball + mais passes + independência** — bola colada no pé (drible suave), roubo deliberado (cooldown), tiki-taka, marcação individual + jitter.
4. **Defesa zonal + correções do goleiro** — bloco que desliza por zonas (corrige o amontoado), goleiro sai pouco/agarra/distribui, fim do deadlock no goleiro.
5. **Meio-termo de movimento + passes que conectam** ✅ — a linha anda junta **mas imperfeita** (força de seguir + deriva + velocidade individuais); o destinatário do passe corre pra receber (passes **completam**, fim do loop de ping-pong), com margem de erro pra bote/interceptação. **Aprovado pelo usuário.**

### Próximo — Etapa 2 (roguelike)
Enxertar a corrida: feras como perfis de stats que enviesam a física; relíquias mexendo em parâmetros físicos; mapa de 3 atos; loja; eventos.

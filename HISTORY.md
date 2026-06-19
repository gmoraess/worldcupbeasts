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

### Etapa 2 — A corrida (roguelike) ✅ jogável + balanceada
- **2A:** `GameState` (autoload) com as 4 feras como **perfis de stats** que enviesam a física, inimigos (normal/elite/chefe, escalam por ato), relíquias que mexem em **parâmetros físicos**, mapa de 3 atos e navegação. A partida lê o `GameState` (perfil da fera/inimigo aplicado aos jogadores).
- **2B:** telas de meta + roteador (`Main.gd`): seleção de fera → mapa → partida → relíquia/evento/loja → resultado (repescagem, ato, vitória/derrota). Dá pra **jogar uma corrida inteira** (3 atos → Copa).
- **2C — passe de balanceamento (headless em volume)** ✅ — runner `tests/test_balance.gd` (round-robin IA×IA, 240 partidas + calibração forte-vs-fraco; roda rápido com `--fixed-fps`). Resultados após ajuste dos perfis: **paridade de 5,8 pts** de amplitude (todas as 4 feras em 47–53% de vitória), **gols ~1,2/lado** (alvo do GDD), **mando neutro**, e **"stats importam" confirmado** (time forte vence ~85-90%, com zebras). Insight: o motor valoriza **defesa e controle** acima de finalização/desarme — perfis reequilibrados em torno disso.
- **2C — valor da loja** ✅ — pool de relíquias **6 → 12** (com duplo-efeito e contrapartida, pra escolha real); preço da loja **escala por ato** (25/35/45); **boss agora dá relíquia** (antes só elite).
- **2C — anti cabo-de-guerra** ✅ — a bola travava em disputa parada por mais de 1 minuto (jogadores se bloqueando fisicamente). Trava de segurança: se a bola fica num raio pequeno **e disputada** por >3s, alguém "ganha o bate-pé" e a bola escapa do amontoado (passe pra companheiro/alívio, com cooldown de roubo). Nenhum congelamento passa de 3s. *Nota: o motor ainda aglomera bastante (a trava dispara muitas vezes/partida); reduzir a frequência das disputas — não só o teto — é polimento de IA/steering pra fazer com playtest visual.*

### Etapa 3 — HUD broadcast + arte 🔄 em andamento
- **HUD de transmissão** ✅ — placar broadcast no topo (brasões/retratos casa×fora + placar na placa ornamentada `score_plate`), **relógio estilo futebol** (minutos `0'`→`90'`, "PRORROGAÇÃO" na morte súbita) e **indicador de posse** em tempo real. Centralização corrigida (full-width + shrink-center).
- **Controle de velocidade** ✅ — botões **Lento (0,5x) · Normal (1x) · Rápido (2x)** no canto. Usa `Engine.time_scale` (passo de física fixo em 1/60 → 2x não tunela), resetado ao sair da partida.
- **Arte (PNGs temporários do projeto antigo `football-autobattler`)** ✅ — retratos das feras na **seleção** e no cabeçalho do **mapa**; **ícones de nó** desenhados no mapa; retratos casa×fora no placar. Helper `UI.icon()` (textura com fallback p/ emoji) + mapeamento de retratos no `GameState`. *Esses PNGs são paliativos — a arte definitiva virá depois.*
- **Fúria & Supers & Cut-ins** ✅ (SPEC §5/§6) — barras de **fúria** por time (carregam por eventos: gol/defesa/roubo/chute defendido/sofrer gol). Cheia → arma o **super** da capitã/líder: **Super-Chute** (bomba no canto, slow-mo, fura a defesa) p/ atacantes, **Super-Defesa** (defesa garantida) p/ a muralha. Dispara um **cut-in**: retrato + nome + frase **deslizando do canto inferior** (esquerda=seu time, direita=inimigo), segura e some. Cap de 1 a cada ~12s.
- **Falta na Etapa 3:** áudio (precisa de assets) e arte definitiva.

### SPEC §1 — Squad de 5 feras (fundação) ✅
Troca de "1 fera = time" por **time de 5** de um **pool compartilhado de 15** (os 15 retratos viram o pool). `GameState` reescrito: pool com papel/tags/super/frase/stats, **tiers** (comuns / elites / chefes por ato), **squad** (5 titulares + capitã + reservas), squads padrão **determinísticos e parelhos** por capitã. A partida agora dá **1 perfil por jogador** (cada um no campo é uma fera). Inimigos sacam do mesmo pool por tier (normal=comuns, elite=+elites, chefe=chefe+elite+comuns). Seleção escolhe a **capitã** (mostra o time); HUD/mapa usam retratos do pool. Validado headless (`test_balance` reescrito p/ squads): paridade ~10 pts entre capitãs, calibração 92% (squad forte vence), ~1 gol/lado.

### Doc 3 — Camada Balatro (pontuação) 🔄
**Muda a condição de vitória:** de saldo de gols → **pontuação-alvo** (blind). Cada **posse é uma "mão"** que acumula `chips × mult`; ao fechar (perder a bola/marcar), soma `round(chips×mult)` no total. **Vencer = bater o alvo** do nó dentro dos 90s (morte súbita aposentada).
- **§3 Pontuação** ✅ — `ScoreEngine.gd` (chips por ação: passe +1, lançamento +3, desarme +5, finalização +5, gol +30, super-gol +60); placar Balatro no HUD (total na placa com "número pulando", barra até o alvo, `chips×mult` da posse).
- **§4 Jokers** ✅ — `Modifiers.gd` (data-driven gatilho×condição×efeito): Matador (+1 mult/gol), Fúria Ímpar (×3 em gol ímpar), Tiki-Taka (+50 se 4+ passes), Carrinho Elétrico, Violência Recompensada, Artilharia. Jogador começa com 1 joker.
- **Alvos** por tier/ato (normal 170+, elite 240+, boss 320+), calibrados pro patamar real (~250–390 pts/90s). Headless: paridade ~87 pts entre capitãs, forte pontua ~50% mais que fraco.
- **§6 Combate + HP** ✅ — cada jogador tem **HP individual** (barra verde→vermelho; resistência ≈ def+fôlego → 80–200). O marcador colado pode dar **porrada** (dano ∝ desarme, com **cooldown** anti-abuso §6.4); HP zera → **nocaute**: o jogador cai e sai ~6s (time com **um a menos**), volta com HP parcial. Porrada **+4** e nocaute **+10** chips pro time (vias de pontuar além do gol). Calibração com combate: forte pontua ~2,1× o fraco. Alvos recalibrados (normal 210+, elite 270+, boss 360+ por ato).
- **§5 Cartas de partida** ✅ — mão de 3 poções no rodapé; clicar **pausa** o jogo (auto-pause §5.4); `jogador_alvo` abre seletor de jogador, demais aplicam na hora. Físicas (cura/velocidade/potência do próx. chute/recarrega fúria) e de pontuação (+mult, ×mult, +chips na posse). `MatchCards.gd`.
- **FX de combate** ✅ — clarão branco no atingido + **estrela de impacto ("POW")** no ponto da pancada; **super-chute vira aríete** (adversário no caminho da bola perde HP/cai).
- **Desvantagens por inimigo (blinds) + punição por sofrer gol** ✅ — cada inimigo impõe uma **regra** que dificulta pontuar (Neblina −15% chips, Teto de Vidro mult máx ×4, Muralha passes não pontuam, Anti-Artilheiro gols valem metade; bosses: Tempestade/Tirania mais pesadas), crescente normal→elite→boss. **Sofrer gol aumenta o alvo** (+25/+40/+60 por tier) com pulso vermelho — punição maior que o tempo de reposição. Aviso no HUD.
- **Falta no Doc 3:** §6.3 relíquias por jogador, §7 fonte m6x11plus, jokers como recompensa na corrida. *Watch: capitã defensiva (cuirass) pontua menos — "modo difícil"; punição de boss (+60/gol) pode estar dura.*

### Notas / pendências
- **Polimento de Etapa 1 (feel):** movimento off-ball / steering pra criar linhas de passe e diminuir o aglomerado (a trava anti cabo-de-guerra resolve o teto, não a frequência). Melhor com playtest visual.

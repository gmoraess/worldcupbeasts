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
- **Tela de Preparação (Doc 2 §4) + §6.3 relíquias por jogador + §2 sinergias** ✅ — `PrepScreen`: trocar titulares por reservas (capitã fixa), **equipar gear por jogador** (Caneleira/Garras/Chuteira/Tornozeleira/Manopla → mods só daquela fera), e **sinergias** ativas (tags pedra/sangue/sombra/fogo entre os 5 → bônus de time). *Acessada pelo botão "Organizar Time" no mapa — NÃO é mais obrigatória antes da partida.*
- **§7 Fonte m6x11** ✅ — fonte pixel (Balatro) aplicada globalmente via Theme (`assets/ui_theme.tres` em `project.godot [gui]`), import pixel-perfeito (sem antialiasing/hinting/subpixel) + fallback do sistema p/ acentos PT.
- **Jokers/gear/relíquias como recompensa** ✅ — RelicScreen e loja agora oferecem 🛡 relíquia (time) · 🃏 joker (pontuação) · 🦿 equipamento (jogador), misturados. A build Balatro cresce na corrida.
- **Início "tipo Balatro"** ✅ — **raridades** (comum-cinza/incomum-verde/raro-azul/épico-laranja/lendário-dourado); **pacote de figurinhas** no começo (3 pacotes → abre 1 → 3 feras por raridade → escolhe 1 pro elenco); **passivas de capitã** que mexem nos chips (Muralha Viva, Fome de Caça, Relâmpago, Instinto Matador) + **nº de cartas** por capitã (padrão 2; cuirass +1, foot −1 com passiva forte); **sem relíquias/gear iniciais** (ganha na corrida); **botão "Organizar Time"** no mapa; **+variedade** (+6 cartas, +6 equipamentos, +5 relíquias).
- **Balanço das capitãs (simulação quantitativa)** ✅ — passe headless (K=10, 120 partidas) medindo pts/partida por capitã com as passivas. Após ajuste das passivas, **amplitude caiu de 649 → ~40 pts** (todas ~427–466), calibração forte ~2,4× fraco. Passivas finais: cuirass +4 chips/jogada (mói), zab +1 mult/finalização, zak +18 chips em jogada 4+ passes, foot +2 mult/gol (−1 carta).
- **Doc 3: completo.** *Watch p/ playtest: punição de boss (+60/gol) pode estar dura; afinar valores no jogo real.*

### Ajustes de UX/ritmo (pós-Doc 3)
- **Sem preparação obrigatória** ✅ — escolher um nó vai direto pra partida; a `PrepScreen` fica só no botão **⚙ Organizar Time** do mapa.
- **Mapa mais amplo (estilo Slay the Spire)** ✅ — **7 colunas/ato** (entrada → 2 caminhos → 🎁 **TESOURO** → caminho → pré-chefe → chefe), com movimento por raias vizinhas. A **coluna do tesouro é toda de baús** → todo caminho passa por 1 baú garantido.
- **Cartas de pontuação → "próxima jogada"** ✅ — em vez de mexer na posse atual (dependia do timing), agendam o bônus pra **próxima posse** (`ScoreEngine.queue_next` aplicado em `start_possession`). Valores reforçados (Festival ×3, Jackpot +100, etc.).

### Doc 4 — O Verbo da Partida ✅ (press-your-luck + agência real)
**O jogador agora JOGA a partida** (não só assiste): chutar **banca** a mão (chips×mult) na hora; perder a bola sem chutar = **bust a zero**; gol soma bônus por cima com o mult capturado no chute. Partida limitada a **12 mãos**.
- **Chute de perícia** ✅ — pausa + mira na boca do gol com **tell do goleiro** (mire longe de onde ele vai mergulhar), força pelo arraste, zona de perdão ∝ finalização. Atributo `fin` = precisão E potência (piso 900, sem "chute mole" perseguível — `_shot_live`: só o goleiro resolve bola chutada).
- **Passe manual 360º** ✅ — botão próprio (A / botão direito), **pausa com overlay** destacando aliados; o mais próximo do ALVO corre pra receber; passe pra trás/lado é **protegido** (só seu time recebe) e mais suave. **Passe não pontua** (anti toca-toca infinito) — salvo relíquia Maestro.
- **Carrinho** ✅ — botão próprio (S), cooldown 3,2s, dano ∝ desarme, e a bola é **cuspida na direção do carrinho** (vira sobra, raramente fica). No modo Auto o carrinho também sai sozinho.
- **Modelo de dano fechado** ✅ — dano SÓ de super-chute e carrinho (combate ambiente desligado); **goleiro imune a tudo**; **capitã nunca é nocauteada** (game over por KO da capitã era frustrante — removido).
- **IA anti-bust** ✅ — telemetria mostrou 13,6 busts/partida (toca-toca da IA); IA agora **dribla por padrão** e só passa a mate claramente aberto → chutes 1,4→3,8/partida, mãos zeradas 47%→9%.
- **Balanço por simulação** ✅ — passivas de capitã refeitas pro modelo Doc 4 (amplitude 649→~31 pts); alvos por degrau recalibrados.

### Torre estilo Mortal Kombat + tela inicial/save ✅ (substitui o mapa)
**O mapa StS saiu; entrou a TORRE** (ladder de oponentes visível, você sobe degrau a degrau).
- **3 dificuldades** com winrate verificado por simulação (1º oponente, IA casual): **Fácil** 5 degraus ~67% · **Normal** 7 ~57% · **Hardcore** 9 ~37% (separação por força do inimigo × multiplicador de alvo 0,72/1,0/1,28).
- **Fluxo:** título → capitã → dificuldade (mostrando a torre inteira de cada uma) → **recompensa inicial** (1 pacote OU 1 relíquia OU 3 cartas) → torre (animação de subida + oponente em highlight) → partida → loja com "Organizar Time" → sobe → ... → boss no topo = Copa. "Repescagem" virou **Vida Extra**.
- **Tela inicial** ✅ — banner de retratos, Jogar / **Continuar** (save JSON em `user://wcb_save.json`, auto-save na torre) / Configurações (fullscreen, vsync, volumes em `user://settings.cfg`) / Sair.
- **Partida começa no modo Auto** (Pro é opt-in pelo botão).
- **Crash fix (lição reusável):** o jogo fechava ao avançar de partida — `await create_timer` disparando em nó já liberado (segfault sem SCRIPT ERROR). **Nunca usar `await create_timer` pra auto-mutação em nó que pode ser liberado**; virou contadores no `_physics_process`. Regressão coberta por `tests/test_loop.gd`.

### Arte pixel + juice + áudio ✅ (tudo procedural, gerado por código)
- **15 feras animadas em campo** — spritesheets pixel-art 32×32 (idle 4 / corrida 6 / chute 4 / carrinho 4) **gerados por script Python** (PNG escrito byte a byte, sem dependências), 5 arquétipos paramétricos: quadrúpede (lobos/felinos/tanques com juba/chifre/tromba/placas/listras/pintas), ave (galo Foot, arara), brutamontes (gorila anda nos nós dos dedos e SOCA), inseto (escorpião com bote de ferrão, mantis raptorial) e serpente (quetzal ondula). `Player.gd` troca o disco por `AnimatedSprite2D` (nearest, flip pela direção, velocidade da animação ∝ movimento, sombra no lugar do anel); **time inimigo também animado** (`squad_ids` no inimigo); elite 1,7× e boss 1,85× de presença.
- **Juice de partida** — bola com **squash + rastro** em chute forte; **explosão de GOL** (confete + flash branco + soco de zoom — só em gol SEU; sofrido dá baque grave); **confete** ao abrir pacotes (loja e recompensa inicial). `scripts/fx/Confetti.gd` (sem timers órfãos).
- **Juice de UI (Balatro)** — cartas/recompensas assentam com **pop elástico em cascata**; botões com mini-pop no hover; **ticker** de pontos (partida) e ouro (loja) rolando número a número; **fade ~0,15s** entre telas.
- **Áudio 100% procedural** — 8 SFX chiptune gerados por script (chute, passe, carrinho, gol-fanfarra, pop, click automático em TODO botão, shimmer de pacote, nocaute) com variação de pitch, + **loop musical chiptune** (140 BPM, Am–F–C–G, 13,7s de loop limpo). Autoload `Sfx` cria os buses Music/Sfx que os sliders das Configurações já controlavam.

### Estádio-coliseu + torcida viva + trilha multi-faixa + power-ups/arremessos ✅ (2026-07-09)
**O campo virou um COLISEU com torcida de animais, a música virou trilha de verdade e a partida ganhou caos divertido** (tudo aprovado pelo usuário via checklist antes de aplicar; ficaram DE FORA por escolha dele: bola em chamas e eventos de caos).
- **Coliseu** — `tools/gen_stadium.py` gera `assets/stadium/stadium_bg.png` (1360×800: mundo 1280×720 + 40px de overscan pro shake da câmera; meia-res ×2 = pixel chunky): gramado com listras de corte, muro do fosso, 3 anéis de arquibancada e muralha externa com arcos + tochas. ⚠️ A GEOMETRIA (campo `Rect2(90,70,1100,580)`, fileiras a 16/28/40px da borda) é ESPELHADA em `scripts/fx/Crowd.gd` — mudou num, muda no outro.
- **Torcida viva** — `scripts/fx/Crowd.gd`: ~650 torcedores-animais (10 espécies × 3 frames, `fans_sheet.png` 12×12) desenhados num único `_draw` (uma textura = um batch). Vida ociosa (bob dessincronizado + fã aleatório se empolgando), **pula com braços pra cima + chuva de confete** no seu gol, **murcha acinzentada** no gol sofrido, **"ôôô"** em defesa/bust, **ola mexicana** periódica (com swoosh), e **mascote**: uma fera COM spritesheet que não está nos dois elencos dança na arquibancada de baixo e comemora gols com "kick".
- **Trilha multi-faixa** (o loop infinito de 14s morreu) — `tools/gen_music.py`: **menu** (104 BPM, sinos calmos) · **match A** (140, a original) · **match B** (152, Em–C–G–D) · **clímax** (168, baixo dirigido, entra quando `clock ≤ 14s` OU última mão) · jingles de **vitória/derrota** (tocam no pool de SFX pra sobreviver à troca de faixa). `Sfx.music_play`: fade-out → **pausa de respiro** → fade-in; partidas **alternam A/B**; telas de menu voltam pro tema no `Main._switch` (só `Control`; a partida escolhe a própria faixa). **Ambience**: murmúrio de estádio (`crowd_loop`, 8s seamless) só durante a partida (`Match._exit_tree` desliga).
- **SFX novos (31 WAVs no total)** — torcida VOCAL sintetizada (cluster de senoides detunadas deslizando = "urro/ôôô/aaah/uuuh" + palmas), apito de juiz (início e **final pi-pi-piiii**), e sons dos power-ups/cartas (explosão, zap, ímã, ding dourado, escorregão, teia, whoosh). Torcida reage: urro no gol, "uuuh" quando a pressão passa de 0,78, aplauso em defesa do SEU goleiro.
- **Power-ups no gramado** (estilo Mario Strikers) — `scripts/fx/PowerUp.gd` + `Match._powerup_step`: item pulsante surge a cada 13–20s (1 por vez, some em 10s piscando), QUALQUER jogador que encostar ativa pro time dele: 💣 **bomba** (explosão raio 135: dano 55 + empurrão + a bola voa), ⚡ **raio** (time ×1,5 velocidade 5s), 🧲 **ímã** (raio de controle ×1,85 e roubo ×1,7 por 6s — `_ctrl_r()`), 👟 **chuteira de ouro** (próximo chute ×1,6 — funciona pros DOIS times via `_shot_boost`).
- **Power-ups CLICÁVEIS → INVENTÁRIO com arrasto** (2 iterações com o usuário: efeito instantâneo no clique era "sem graça") — clique no item ("clique!" pulsando) → ele **VOA pra barra lateral** de 4 slots ("ITENS") → **arrasta o slot pro campo em CÂMERA LENTA** (0,25×, fantasma do emoji no mouse via `_process`, que ignora time_scale) → soltou, o **MASCOTE arremessa em arco** (com animação de chute — `Crowd.mascot_pos()/mascot_throw()`). Soltar fora do campo/botão direito devolve ao slot. TODOS os efeitos viraram arremesso de área (`Throwable` ganhou modos): 💣 explosão · ⚡ relâmpago desenhado (dano+paralisia) · 🧲 plantado ~5s PUXANDO a bola · 👟 entrega pra fera SUA mais perto do ponto (brilho + velocidade + chute ×1,8 via `gold_cb`). Toque por contato agora é SÓ do inimigo — e detona o efeito ali mesmo contra você (`Throwable.spawn()` direto). Commits `82c3199` (v1 mira) e o seguinte (v2 inventário).
- **🐛 Lição de INPUT (o item "inclicável")** — o `Main` (Control tela-cheia do roteador) tinha `mouse_filter` padrão **STOP** e ENGOLIA todo clique fora de botões: `_unhandled_input` da partida nunca via o mouse. Correção dupla: `Main.mouse_filter = IGNORE` + mouse dos power-ups movido pro **`Match._input`** (roda ANTES de toda a GUI — imune a qualquer Control futuro; consome só quando o clique é do item/arrasto). Regressão coberta por `tests/test_click.gd` — que também documenta: `Input.parse_input_event` NÃO dispatcha em headless; usar `viewport.push_input(ev, true)` (in_local_coords=true, senão a transform janela→viewport degenerada do headless corrompe a posição).
- **Cartas arremessáveis** — 3 novas em `MatchCards.POOL` com `alvo:"arremesso"` (entram sozinhas na loja/recompensas): 💣 Bomba, 🍌 Casca de Banana (1º inimigo que pisar escorrega — `Player.slip()`: giro cômico + quase-parado 1s), 🕸 Teia (prende inimigos na área 4,5s). Fluxo: clica a carta → pausa → **clica um ponto do campo** (botão direito cancela SEM gastar) → arremesso em arco do banco (`scripts/fx/Throwable.gd`, nó multi-modo fly/boom/banana/teia, sem timers).
- **Fundos de pedra nos menus** — `tools/gen_stone.py` → `assets/ui/stone_bg.png` (tijolos escuros + vinheta baked); `UI.stone_bg()` com fallback pro `bg_rect()` chapado. **Retratos novos** — `tools/gen_portraits.py` regenera os 15 `assets/beasts/<id>.png` (128×128 = frame idle da spritesheet ×4 nearest) → loja/pacotes/título combinam com a arte de campo.
- **Skills de sprite instaladas** (a pedido do usuário, inspecionadas antes): plugin MCPmarket (`~/.claude/plugins/mcpmarket-me`, skill `animated-sprite-gen`) e **`.claude/skills/generate2dsprite/` (committada NESTE repo)** — servem como referência de técnica (frame âncora, tiras completas, QC); a arte do jogo segue 100% procedural (este ambiente não tem tool de geração de imagem).
- **Gotchas novos:** o writer PNG precisa de RGBA — tupla RGB de 3 corrompia o arquivo (writer agora normaliza); um `.png.import` criado a partir de PNG corrompido continua quebrado após corrigir o PNG — **apagar o `.import` e o cache `.godot/imported/...` e reimportar**.

### Notas / pendências
- **Polimento de Etapa 1 (feel):** movimento off-ball / steering pra criar linhas de passe e diminuir o aglomerado (a trava anti cabo-de-guerra resolve o teto, não a frequência). Melhor com playtest visual.

### 📍 ESTADO ATUAL (onde paramos) — guia pra retomar DO ZERO
**Tudo implementado até aqui:** 4 documentos de design (GDD física, SPEC squad/supers/HUD, Doc 3 Balatro, Doc 4 Verbo) + torre MK + arte/juice/áudio procedurais + **coliseu com torcida viva, trilha multi-faixa, power-ups no gramado e cartas de arremesso**. Fluxo do jogo: título (save/continuar) → capitã → dificuldade → recompensa inicial → torre → partidas Doc 4 (bancar a mão, chute de perícia, passe 360º, carrinho, power-ups, cartas) num coliseu lotado → loja/organizar time → boss no topo = Copa.

**Como rodar/testar** (Windows; Godot NÃO está no PATH):
- Binário: `C:\Users\Chess\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe` (exit code 255 é NORMAL deste console build — erro de verdade = `SCRIPT ERROR` no output).
- Jogar: `<godot> --path .` · Smoke: `<godot> --headless --path . --script tests/test_flow.gd --fixed-fps 60` · Regressão de crash: `tests/test_loop.gd` · Balanço: `tests/test_balance.gd` (aceita `K= LEN= ALVO= EF=`).
- Depois de gerar/alterar QUALQUER asset: `<godot> --headless --path . --import` (se um asset "Failed loading", apague o `.import` + `.godot/imported/<nome>-*` e reimporte).

**Geradores procedurais (tudo em `tools/`, saídas commitadas):**
- `gen_beasts.py assets/beasts/anim [ids] [--show]` — spritesheets das 14 feras (arquétipos paramétricos) · `gen_zab.py` — a 15ª (zab).
- `gen_sfx.py assets/sfx` — 25 SFX chiptune · `gen_music.py assets/sfx` — 4 faixas + 2 jingles.
- `gen_stadium.py assets/stadium` — coliseu + torcedores (geometria espelhada em `scripts/fx/Crowd.gd`!) · `gen_stone.py assets/ui` — fundo dos menus · `gen_portraits.py assets/beasts` — retratos 128×128.

**Mapa da arquitetura:** autoloads `GameState` (corrida/save/pool/loja) e `Sfx` (SFX + trilha + ambience). `Main.gd` roteia telas por sinais. `Match.gd` é o coração (~1900 linhas: física+IA+Doc4+pontuação+HUD+power-ups). `scripts/fx/` = Confetti, Crowd, PowerUp, Throwable. `UI.gd` = helpers estáticos (stone_bg, pop_in, hoverify, count_to, icon). `scripts/match/` = ScoreEngine, MatchCards, SkillShot, PassAim.

**Regras de trabalho combinadas com o usuário (IMPORTANTES):**
- **NUNCA `await create_timer`** em nó que pode ser liberado (crash histórico) — usar contadores no `_physics_process`/`_process`.
- **Perguntar ANTES de aplicar juice/animação sugerida por mim** (pedidos explícitos dele são exceção). Já **vetados**: hit-stop forte e números de dano flutuantes; **não escolhidos** no checklist: bola em chamas, eventos de caos. Não aplicar sem perguntar de novo.
- Commits em PT-BR; push pra `etapa2-balanceamento` E `main` (fast-forward) é autorizado.

**Pendências/"watches":** afinar dificuldade/capitãs no modo Pro com playtest; steering (aglomeração); balanço dos power-ups/cartas novas (valores chutados: bomba 55 dano/135 raio, ímã ×1,85, ouro ×1,6 — validar jogando); teia/banana não afetam o goleiro por design do modelo de dano, mas PRENDEM ele (ok?).
**Próximos candidatos:** mais conteúdo (feras/jokers/eventos) · polimento do modo Pro · placar/replay de lances · achievements.

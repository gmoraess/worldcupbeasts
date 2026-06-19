extends Node
## Autoload — estado da corrida roguelike. As feras são PERFIS DE STATS que
## enviesam a física (GDD §8); relíquias mexem em parâmetros físicos. Agora o time
## é um SQUAD de 5 feras de um POOL compartilhado (SPEC §1): 1 capitã fixa + 4.
## Os inimigos sacam do MESMO pool. Cada jogador no campo = uma fera (papel).

# ==========================================================================
#  POOL DE FERAS (15) — compartilhado entre jogador e inimigos (SPEC §1.2)
#  stats ~0.8–1.35 (multiplicadores) · papel GK/DEF/MID/FWD · tags p/ sinergia
#  super_id/frase usados pela Fúria & cut-ins (SPEC §5/§6). img == id do arquivo.
# ==========================================================================
const POOL := {
	# — HERÓIS (capitães selecionáveis) —
	"cuirass": {"nome": "Cuirass", "crest": "🛡", "papel": "DEF", "tags": ["pedra"],
		"stats": {"fin": 0.90, "ctrl": 1.05, "des": 1.22, "def": 1.20, "spd": 0.95, "sta": 1.18},
		"super": "super_defesa_muralha", "frase": "Nada passa.",
		"lore": "O tatu couraçado. Muralha viva — difícil de furar."},
	"zab": {"nome": "Zab", "crest": "🐺", "papel": "DEF", "tags": ["sangue"],
		"stats": {"fin": 1.05, "ctrl": 1.00, "des": 1.30, "def": 1.08, "spd": 1.08, "sta": 1.15},
		"super": "super_bote_fera", "frase": "A caçada acabou.",
		"lore": "O lobo implacável. Caça por desgaste e bote."},
	"zak": {"nome": "Zak", "crest": "🐆", "papel": "MID", "tags": ["sombra"],
		"stats": {"fin": 1.05, "ctrl": 1.18, "des": 0.95, "def": 0.95, "spd": 1.20, "sta": 1.02},
		"super": "super_arranque", "frase": "Rápido demais.",
		"lore": "O guepardo relâmpago. Controle e contra-ataque."},
	"foot": {"nome": "Foot", "crest": "🐓", "papel": "FWD", "tags": ["fogo"],
		"stats": {"fin": 1.35, "ctrl": 1.08, "des": 0.95, "def": 0.98, "spd": 1.10, "sta": 0.98},
		"super": "super_chute_bicuda", "frase": "O gol é meu.",
		"lore": "O galo de briga. Gol no instinto."},
	# — GOLEIROS —
	"urso": {"nome": "Urso do Norte", "crest": "🐻", "papel": "GK", "tags": ["pedra"],
		"stats": {"fin": 0.80, "ctrl": 0.95, "des": 1.05, "def": 1.30, "spd": 0.85, "sta": 1.20},
		"super": "super_defesa_muralha", "frase": "A muralha resiste.",
		"lore": "Guardião do gelo. Pega tudo."},
	"rinoceronte": {"nome": "Rinoceronte", "crest": "🦏", "papel": "GK", "tags": ["pedra"],
		"stats": {"fin": 0.85, "ctrl": 0.92, "des": 1.10, "def": 1.22, "spd": 0.95, "sta": 1.10},
		"super": "super_defesa_muralha", "frase": "Investida!",
		"lore": "Couro grosso, presença imponente na meta."},
	"elite_elefante": {"nome": "Elefante de Guerra", "crest": "🐘", "papel": "GK", "tags": ["pedra"],
		"stats": {"fin": 0.90, "ctrl": 0.98, "des": 1.18, "def": 1.28, "spd": 0.88, "sta": 1.22},
		"super": "super_defesa_muralha", "frase": "Inabalável.",
		"lore": "Montanha sob as traves."},
	# — DEFENSORES —
	"elite_gorila": {"nome": "Gorila das Sombras", "crest": "🦍", "papel": "DEF", "tags": ["pedra"],
		"stats": {"fin": 0.95, "ctrl": 1.05, "des": 1.24, "def": 1.12, "spd": 1.00, "sta": 1.18},
		"super": "super_bote_fera", "frase": "Esmagar.",
		"lore": "Bote que derruba qualquer um."},
	"boss_mantis": {"nome": "Mantis da Tempestade", "crest": "🦗", "papel": "DEF", "tags": ["sombra"],
		"stats": {"fin": 1.10, "ctrl": 1.15, "des": 1.20, "def": 1.12, "spd": 1.15, "sta": 1.12},
		"super": "super_bote_fera", "frase": "Mil lâminas.",
		"lore": "Cortes precisos vindos das sombras."},
	# — MEIAS —
	"lobo": {"nome": "Lobo da Névoa", "crest": "🐺", "papel": "MID", "tags": ["sangue"],
		"stats": {"fin": 1.00, "ctrl": 1.08, "des": 1.12, "def": 1.05, "spd": 1.08, "sta": 1.10},
		"super": "super_arranque", "frase": "Em matilha.",
		"lore": "Tece a jogada e recupera a bola."},
	"boss_leao": {"nome": "Leão Dourado", "crest": "🦁", "papel": "MID", "tags": ["fogo"],
		"stats": {"fin": 1.20, "ctrl": 1.15, "des": 1.12, "def": 1.08, "spd": 1.12, "sta": 1.18},
		"super": "super_chute_bicuda", "frase": "Rugido real.",
		"lore": "O maestro dourado do meio-campo."},
	# — ATACANTES —
	"arara": {"nome": "Arara Carmesim", "crest": "🦜", "papel": "FWD", "tags": ["sombra"],
		"stats": {"fin": 1.08, "ctrl": 1.06, "des": 0.98, "def": 1.02, "spd": 1.15, "sta": 0.98},
		"super": "super_arranque", "frase": "Voo carmesim.",
		"lore": "Velocidade pura pela ponta."},
	"escorpiao": {"nome": "Escorpião", "crest": "🦂", "papel": "FWD", "tags": ["fogo"],
		"stats": {"fin": 1.08, "ctrl": 1.00, "des": 1.08, "def": 1.10, "spd": 1.02, "sta": 1.02},
		"super": "super_chute_bicuda", "frase": "Ferrão.",
		"lore": "Finaliza com veneno na bola."},
	"elite_tigre": {"nome": "Tigre Relâmpago", "crest": "🐯", "papel": "FWD", "tags": ["fogo"],
		"stats": {"fin": 1.18, "ctrl": 1.12, "des": 1.02, "def": 0.98, "spd": 1.22, "sta": 1.02},
		"super": "super_chute_bicuda", "frase": "Bote relâmpago.",
		"lore": "Arranque e finalização fulminantes."},
	"boss_quetzal": {"nome": "Quetzal", "crest": "🐉", "papel": "FWD", "tags": ["sombra"],
		"stats": {"fin": 1.30, "ctrl": 1.25, "des": 1.10, "def": 1.12, "spd": 1.18, "sta": 1.22},
		"super": "super_chute_bicuda", "frase": "Serpente imortal.",
		"lore": "A serpente alada que decide tudo."},
}

# capitães que o jogador pode escolher pra liderar a corrida
const HERO_IDS := ["cuirass", "zab", "zak", "foot"]
# formação: papéis dos 5 titulares, em ordem (casa com os slots do Match).
# Obs.: o SLOT define a posição no campo; a fera só empresta os stats (pode jogar
# em qualquer slot), então os squads abaixo misturam papéis livremente.
const FORMATION := ["GK", "DEF", "DEF", "MID", "FWD"]

# TIERS do pool — curva de dificuldade e recrutamento (heróis = só capitães):
const COMMON_IDS := ["urso", "rinoceronte", "lobo", "arara", "escorpiao"]
const ELITE_IDS := ["elite_elefante", "elite_gorila", "elite_tigre"]
const ACT_BOSS := ["boss_mantis", "boss_leao", "boss_quetzal"]   # chefe por ato

# Squad inicial por capitã (determinístico e parelho): capitã + comuns. Slots
# [GK, DEF, DEF, MID, FWD]. Elites/bosses entram via inimigos e recrutamento.
const DEFAULT_SQUADS := {
	"cuirass": ["urso", "cuirass", "rinoceronte", "lobo", "arara"],
	"zab":     ["urso", "zab", "rinoceronte", "lobo", "escorpiao"],
	"zak":     ["urso", "rinoceronte", "escorpiao", "zak", "arara"],
	"foot":    ["urso", "rinoceronte", "escorpiao", "lobo", "foot"],
}

const NEUTRAL := {"fin": 1.0, "ctrl": 1.0, "des": 1.0, "def": 1.0, "spd": 1.0, "sta": 1.0}

# relíquias — mexem em PARÂMETROS FÍSICOS (mods aplicados a TODO o time do jogador).
const RELICS := {
	"chuteira_rapida": {"name": "Chuteira Veloz", "ic": "⚡", "desc": "+velocidade do time", "mods": {"spd_mult": 0.12}},
	"bota_craque":     {"name": "Bota de Craque", "ic": "👟", "desc": "+potência/precisão de chute", "mods": {"fin_mult": 0.18}},
	"luvas_goleiro":   {"name": "Luvas do Goleiro", "ic": "🧤", "desc": "+alcance/defesa do goleiro", "mods": {"def_mult": 0.20}},
	"garra_afiada":    {"name": "Garra Afiada", "ic": "🐾", "desc": "+força do bote/desarme", "mods": {"des_mult": 0.20}},
	"coracao_ferro":   {"name": "Coração de Ferro", "ic": "🔥", "desc": "+fôlego (menos fadiga)", "mods": {"sta_mult": 0.20}},
	"imã_da_bola":     {"name": "Imã da Bola", "ic": "🧲", "desc": "+controle (segura a bola)", "mods": {"ctrl_mult": 0.20}},
	"manto_sombrio":   {"name": "Manto Sombrio", "ic": "🌑", "desc": "+velocidade e +desarme", "mods": {"spd_mult": 0.08, "des_mult": 0.10}},
	"elmo_guardiao":   {"name": "Elmo do Guardião", "ic": "⛑", "desc": "+defesa e +fôlego", "mods": {"def_mult": 0.12, "sta_mult": 0.10}},
	"garras_gemeas":   {"name": "Garras Gêmeas", "ic": "✌", "desc": "+desarme e +finalização", "mods": {"des_mult": 0.12, "fin_mult": 0.10}},
	"talisma_furia":   {"name": "Talismã da Fúria", "ic": "😤", "desc": "++chute e velocidade, −defesa", "mods": {"fin_mult": 0.22, "spd_mult": 0.08, "def_mult": -0.10}},
	"couraca_antiga":  {"name": "Couraça Antiga", "ic": "🛡", "desc": "++defesa e controle, −velocidade", "mods": {"def_mult": 0.18, "ctrl_mult": 0.10, "spd_mult": -0.08}},
	"essencia_veloz":  {"name": "Essência Veloz", "ic": "💨", "desc": "++velocidade e controle, −fôlego", "mods": {"spd_mult": 0.18, "ctrl_mult": 0.08, "sta_mult": -0.08}},
}

## Preço da loja escala por ato (tensão econômica: ouro vale mais cedo).
func shop_price() -> int:
	return 25 + act * 10            # ato 1=25 · ato 2=35 · ato 3=45

# ==========================================================================
#  ESTADO DA CORRIDA
# ==========================================================================
var capita: String = ""            # id da fera-capitã (identidade da run)
var titulares: Array = []          # 5 ids na ordem da FORMATION
var reservas: Array = []           # ids no banco
var beast_id: String = ""          # == capita (compat. com telas antigas)
var beast: Dictionary = {}         # == POOL[capita] (compat.)
var relics: Array = []
var gold: int = 20
var extra_life: bool = true
var act: int = 0
var col: int = -1
var lane: int = 1
var map_data: Array = []
var current_node: Dictionary = {}

func start_run(p_captain_id: String) -> void:
	capita = p_captain_id
	beast_id = p_captain_id
	beast = POOL.get(p_captain_id, POOL["cuirass"])
	titulares = build_default_squad(p_captain_id)
	reservas = _pick_reserves(titulares, 2)
	relics = []
	gold = 20
	extra_life = true
	act = 0; col = -1; lane = 1
	generate_map()

## Squad inicial da capitã (determinístico). Fallback: capitã + comuns.
func build_default_squad(captain_id: String) -> Array:
	if DEFAULT_SQUADS.has(captain_id):
		return (DEFAULT_SQUADS[captain_id] as Array).duplicate()
	var result := [captain_id]
	for id in COMMON_IDS:
		if result.size() >= 5 and not result.has(captain_id): break
		if id != captain_id and result.size() < 5: result.append(id)
	while result.size() < 5: result.append(COMMON_IDS[result.size() % COMMON_IDS.size()])
	return result

func _pick_reserves(exclude: Array, n: int) -> Array:
	var cands: Array = []
	for id in (COMMON_IDS + ELITE_IDS):
		if not exclude.has(id): cands.append(id)
	cands.shuffle()
	return cands.slice(0, mini(n, cands.size()))

# ==========================================================================
#  STATS → FÍSICA (por jogador). home = squad do jogador (+relíquias).
# ==========================================================================
## Aplica relíquias a um perfil base (multiplicadores aditivos).
func _with_relics(base: Dictionary) -> Dictionary:
	var s: Dictionary = base.duplicate()
	for r in relics:
		var mods: Dictionary = RELICS.get(r, {}).get("mods", {})
		for k in mods:
			var stat := (k as String).replace("_mult", "")
			s[stat] = s.get(stat, 1.0) + mods[k]
	return s

var home_squad_override: Array = []   # seam de teste (vazio em produção)

## Perfis dos 5 titulares do jogador (com relíquias), na ordem da FORMATION.
func home_squad() -> Array:
	if home_squad_override.size() == 5:
		return home_squad_override
	var out: Array = []
	for id in titulares:
		var base: Dictionary = POOL.get(id, {}).get("stats", NEUTRAL)
		out.append(_with_relics(base))
	if out.size() < 5:
		while out.size() < 5: out.append(NEUTRAL.duplicate())
	return out

## Perfis (stats puros, sem relíquias) de uma lista de ids — usado por testes/IA.
func squad_profiles(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append((POOL.get(id, {}).get("stats", NEUTRAL) as Dictionary).duplicate())
	return out

## Perfis dos 5 do inimigo do nó atual (já escalados na geração do mapa).
func away_squad() -> Array:
	var sq: Array = current_node.get("enemy", {}).get("squad", [])
	if sq.size() == 5: return sq
	var out: Array = []
	for i in 5: out.append(NEUTRAL.duplicate())
	return out

## Perfil representativo (capitã + relíquias) — compat. com telas/diagnóstico.
func home_stats() -> Dictionary:
	return _with_relics(POOL.get(capita, {}).get("stats", NEUTRAL))

func away_stats() -> Dictionary:
	var enemy: Dictionary = current_node.get("enemy", {})
	return (enemy.get("stats", NEUTRAL) as Dictionary).duplicate()

func enemy_name() -> String:
	return current_node.get("enemy", {}).get("name", "Oponente")

# ==========================================================================
#  GERAÇÃO DE SQUAD INIMIGO (saca do mesmo pool, escala por ato/tier)
# ==========================================================================
## Monta o squad inimigo de um nó (saca por tier do mesmo pool) + líder p/ exibir.
## normal=5 comuns · elite=2 elites+3 comuns · boss=chefe+1 elite+3 comuns.
func _make_enemy(tier: String, a: int, boss_id: String = "") -> Dictionary:
	var tier_mult: float = {"normal": 1.0, "elite": 1.08, "boss": 1.16}.get(tier, 1.0)
	var f: float = (1.0 + a * 0.10) * tier_mult
	var commons: Array = COMMON_IDS.duplicate(); commons.shuffle()
	var elites: Array = ELITE_IDS.duplicate(); elites.shuffle()
	var ids: Array = []
	match tier:
		"boss":  ids = [boss_id, elites[0]] + commons.slice(0, 3)
		"elite": ids = elites.slice(0, 2) + commons.slice(0, 3)
		_:       ids = commons                       # normal: os 5 comuns
	# perfis escalados
	var squad: Array = []
	for id in ids:
		squad.append(_scaled(POOL[id]["stats"], f))
	# líder p/ exibição: o chefe, senão o de maior finalização
	var leader: String = boss_id
	if leader == "":
		var best := -1.0
		for id in ids:
			var fin: float = POOL[id]["stats"]["fin"]
			if fin > best: best = fin; leader = id
	return {"name": POOL[leader]["nome"], "crest": POOL[leader]["crest"],
		"leader": leader, "stats": _scaled(POOL[leader]["stats"], f), "squad": squad}

func _scaled(stats: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in stats: out[k] = stats[k] * f
	return out

# retratos: id da fera == nome do arquivo PNG.
func home_img() -> String:
	return _img(capita)

func away_img() -> String:
	return _img(current_node.get("enemy", {}).get("leader", ""))

func enemy_img_path(enemy: Dictionary) -> String:
	return _img(enemy.get("leader", ""))

func _img(id: String) -> String:
	return "res://assets/beasts/%s.png" % id if id != "" else ""

# ==========================================================================
#  MAPA (3 atos × colunas × raias)
# ==========================================================================
func generate_map() -> void:
	map_data = []
	for a in 3:
		var act_cols: Array = []
		var c0: Array = []
		for _l in 3:
			c0.append(_mk_node("partida", a, false))
		act_cols.append(c0)
		var variants := [["partida", "evento", "loja"], ["evento", "partida", "partida"], ["loja", "partida", "evento"]]
		var picked: Array = variants[randi() % variants.size()]
		var c1: Array = []
		for l in 3:
			c1.append(_mk_node(picked[l], a, false))
		act_cols.append(c1)
		act_cols.append([_mk_node("elite", a, true), _mk_node("bau", a, false), _mk_node("elite", a, true)])
		act_cols.append([_mk_boss(a)])
		map_data.append(act_cols)

func _mk_node(tp: String, a: int, elite: bool) -> Dictionary:
	var enemy: Dictionary = {}
	if tp == "partida":
		enemy = _make_enemy("normal", a)
	elif tp == "elite":
		enemy = _make_enemy("elite", a)
	return {"type": tp, "enemy": enemy, "visited": false}

func _mk_boss(a: int) -> Dictionary:
	var enemy := _make_enemy("boss", a, ACT_BOSS[a % ACT_BOSS.size()])
	return {"type": "boss", "enemy": enemy, "visited": false}

func reachable_next() -> Array:
	var next_col: int = col + 1
	if act >= map_data.size() or next_col >= map_data[act].size():
		return []
	if map_data[act][next_col].size() == 1:
		return [[next_col, 0]]
	var result: Array = []
	for l in 3:
		if col == -1 or abs(l - lane) <= 1:
			result.append([next_col, l])
	return result

func enter_node(target_col: int, target_lane: int) -> Dictionary:
	col = target_col
	lane = target_lane
	var node: Dictionary
	if map_data[act][col].size() == 1:
		node = map_data[act][col][0]
	else:
		node = map_data[act][col][lane]
	node["visited"] = true
	current_node = node
	return node

## Resultado do nó: "continue" | "defeat" | "repechage" | "act_clear" | "victory"
func complete_node(won: bool) -> String:
	var tp: String = current_node.get("type", "partida")
	if not won:
		if tp == "partida" and extra_life:
			extra_life = false
			return "repechage"
		return "defeat"
	match tp:
		"partida": gold += 10
		"elite":   gold += 20
		"boss":    gold += 30
	if tp == "boss":
		act += 1; col = -1; lane = 1
		return "victory" if act >= 3 else "act_clear"
	return "continue"

func add_relic(id: String) -> void:
	if not relics.has(id):
		relics.append(id)

func random_relic_choices(n: int = 3) -> Array:
	var avail: Array = RELICS.keys().filter(func(r): return not relics.has(r))
	avail.shuffle()
	return avail.slice(0, mini(n, avail.size()))

# ==========================================================================
#  RECRUTAMENTO (loja/repescagem) — trocar reserva por fera nova do pool
# ==========================================================================
## Feras do pool que o jogador ainda não tem (nem titular nem reserva).
func recruitable(n: int = 3) -> Array:
	var have := titulares + reservas
	var avail: Array = []
	for id in (COMMON_IDS + ELITE_IDS):
		if not have.has(id): avail.append(id)
	avail.shuffle()
	return avail.slice(0, mini(n, avail.size()))

func add_reserve(id: String) -> void:
	if not titulares.has(id) and not reservas.has(id):
		reservas.append(id)

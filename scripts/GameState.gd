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

# DESVANTAGENS (blinds, Doc 3) — cada inimigo impõe uma regra que dificulta pontuar.
# cfg lido pelo ScoreEngine: chips_mult · gol_mult · passe_chips · mult_max.
const DEBUFFS := {
	"neblina":         {"nome": "Neblina", "desc": "Chips −15%", "cfg": {"chips_mult": 0.85}},
	"teto":            {"nome": "Teto de Vidro", "desc": "Mult máximo ×4", "cfg": {"mult_max": 4.0}},
	"muralha":         {"nome": "Muralha", "desc": "Passes não pontuam", "cfg": {"passe_chips": 0}},
	"anti_artilheiro": {"nome": "Anti-Artilheiro", "desc": "Gols valem metade", "cfg": {"gol_mult": 0.5}},
	"tempestade":      {"nome": "Tempestade", "desc": "Chips −30% · mult máx ×4", "cfg": {"chips_mult": 0.70, "mult_max": 4.0}},
	"tirania":         {"nome": "Tirania", "desc": "Gols valem 40% · chips −15%", "cfg": {"gol_mult": 0.4, "chips_mult": 0.85}},
}
const DEBUFF_POOL := {"normal": ["neblina", "teto"], "elite": ["muralha", "anti_artilheiro"], "boss": ["tempestade", "tirania"]}

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
	"estandarte":      {"name": "Estandarte Real", "ic": "🚩", "desc": "+controle e +finalização do time", "mods": {"ctrl_mult": 0.10, "fin_mult": 0.10}},
	"tambor_guerra":   {"name": "Tambor de Guerra", "ic": "🥁", "desc": "+velocidade e +desarme do time", "mods": {"spd_mult": 0.10, "des_mult": 0.12}},
	"armadura_real":   {"name": "Armadura Real", "ic": "🏰", "desc": "++defesa e fôlego, −velocidade", "mods": {"def_mult": 0.16, "sta_mult": 0.12, "spd_mult": -0.10}},
	"relicario_fogo":  {"name": "Relicário de Fogo", "ic": "🌋", "desc": "++chute e velocidade, −controle", "mods": {"fin_mult": 0.18, "spd_mult": 0.10, "ctrl_mult": -0.08}},
	"calice_vida":     {"name": "Cálice da Vida", "ic": "🏆", "desc": "+fôlego e +defesa (resistência)", "mods": {"sta_mult": 0.14, "def_mult": 0.10}},
}

# GEAR — relíquias EQUIPADAS num jogador (Doc 3 §6.3): mods só pra aquela fera.
const GEAR := {
	"caneleira":    {"nome": "Caneleira de Ferro", "ic": "🦿", "desc": "+resistência (def/fôlego)", "mods": {"def": 0.12, "sta": 0.12}},
	"garras":       {"nome": "Garras Afiadas", "ic": "🐾", "desc": "+desarme/combate", "mods": {"des": 0.20}},
	"chuteira":     {"nome": "Chuteira Leve", "ic": "👟", "desc": "+velocidade", "mods": {"spd": 0.16}},
	"tornozeleira": {"nome": "Tornozeleira", "ic": "🎯", "desc": "+finalização", "mods": {"fin": 0.20}},
	"manopla":      {"nome": "Manopla", "ic": "🥊", "desc": "+controle", "mods": {"ctrl": 0.16}},
	"peitoral":     {"nome": "Peitoral", "ic": "🛡", "desc": "++resistência, −velocidade", "mods": {"def": 0.18, "sta": 0.14, "spd": -0.08}},
	"esporas":      {"nome": "Esporas", "ic": "⚙", "desc": "+velocidade e +finalização", "mods": {"spd": 0.12, "fin": 0.10}},
	"luva_grude":   {"nome": "Luva Aderente", "ic": "🧤", "desc": "+controle e +defesa", "mods": {"ctrl": 0.12, "def": 0.12}},
	"presa":        {"nome": "Presa de Aço", "ic": "🦷", "desc": "++desarme/combate, −controle", "mods": {"des": 0.24, "ctrl": -0.08}},
	"talisma_gol":  {"nome": "Talismã do Gol", "ic": "🔱", "desc": "++finalização, −defesa", "mods": {"fin": 0.26, "def": -0.10}},
	"botina_veloz": {"nome": "Botina Veloz", "ic": "🥾", "desc": "++velocidade, −fôlego", "mods": {"spd": 0.22, "sta": -0.08}},
}

# SINERGIAS (§2) — contam as tags entre os 5 titulares; limiar ativa mods de TIME.
const SINERGIAS := {
	"pedra":  {"nome": "Muralha", "2": {"def": 0.08}, "4": {"def": 0.16}},
	"sangue": {"nome": "Matilha", "2": {"des": 0.12}},
	"sombra": {"nome": "Sombra", "2": {"spd": 0.08}, "3": {"spd": 0.15}},
	"fogo":   {"nome": "Brasa", "2": {"fin": 0.10}, "3": {"fin": 0.18}},
}

# RARIDADE (figurinhas) — cinza/verde/azul/laranja/dourado.
const RARITY := {
	"comum":    {"nome": "Comum", "cor": Color("9aa0a6")},
	"incomum":  {"nome": "Incomum", "cor": Color("5fc96b")},
	"raro":     {"nome": "Raro", "cor": Color("4a90d9")},
	"epico":    {"nome": "Épico", "cor": Color("e08a3a")},
	"lendario": {"nome": "Lendário", "cor": Color("f3d24a")},
}
const RARIDADE := {
	"urso": "comum", "rinoceronte": "comum", "arara": "comum",
	"lobo": "incomum", "escorpiao": "incomum",
	"elite_elefante": "raro", "elite_gorila": "raro", "elite_tigre": "raro",
	"boss_mantis": "epico", "boss_leao": "epico", "boss_quetzal": "lendario",
	"cuirass": "epico", "zab": "raro", "zak": "raro", "foot": "epico",
}
const RARITY_WEIGHT := {"comum": 45, "incomum": 28, "raro": 17, "epico": 8, "lendario": 2}

func rarity(id: String) -> String:
	return RARIDADE.get(id, "comum")
func rarity_color(id: String) -> Color:
	return RARITY[rarity(id)]["cor"]

# PASSIVAS DE CAPITÃ — toda capitã mexe nos chips (joker embutido) + delta de cartas.
const CAPTAIN_PASSIVE := {
	"cuirass": {"nome": "Muralha Viva", "desc": "Cada jogada fecha com +4 chips · +1 carta", "cartas": 1,
		"joker": {"gatilho": "ao_finalizar_jogada", "condicao": "", "efeito": {"chips": 4}}},
	"zab": {"nome": "Fome de Caça", "desc": "Cada finalização: +1 mult", "cartas": 0,
		"joker": {"gatilho": "ao_finalizar", "condicao": "", "efeito": {"add_mult": 1.0}}},
	"zak": {"nome": "Relâmpago", "desc": "Jogada com 4+ passes: +18 chips", "cartas": 0,
		"joker": {"gatilho": "ao_finalizar_jogada", "condicao": "passes_na_jogada_>=4", "efeito": {"chips": 18}}},
	"foot": {"nome": "Instinto Matador", "desc": "Gol: +2 mult (−1 carta)", "cartas": -1,
		"joker": {"gatilho": "ao_marcar_gol", "condicao": "", "efeito": {"add_mult": 2.0}}},
}
func captain_passive() -> Dictionary:
	return CAPTAIN_PASSIVE.get(capita, {})
## Nº de cartas (poções) na partida: 2 padrão ± delta da capitã (mín. 1).
func hand_size() -> int:
	return maxi(1, 2 + int(captain_passive().get("cartas", 0)))

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
var jokers: Array = []             # Doc 3 §4 — ids de jokers (relíquias de pontuação)
var gear_inv: Array = []           # gear no inventário (não equipado)
var equipped: Array = []           # gear equipado por slot de titular (5; "" = vazio)
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
	jokers = []                     # sem joker inicial — a passiva da capitã já mexe nos chips
	gear_inv = []                   # sem gear inicial — ganha em packs/recompensas/loja
	equipped = ["", "", "", "", ""]
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

## Perfis dos 5 titulares do jogador: stats base + relíquias globais + SINERGIAS
## (time) + GEAR (por jogador). Ordem da FORMATION.
func home_squad() -> Array:
	if home_squad_override.size() == 5:
		return home_squad_override
	var syn: Dictionary = _synergy_mods()
	var out: Array = []
	for i in titulares.size():
		var base: Dictionary = POOL.get(titulares[i], {}).get("stats", NEUTRAL)
		var s: Dictionary = _with_relics(base)            # relíquias globais
		for k in syn: s[k] = s.get(k, 1.0) + syn[k]       # sinergias (time)
		if i < equipped.size() and equipped[i] != "":     # gear (por jogador)
			var gm: Dictionary = GEAR[equipped[i]]["mods"]
			for k in gm: s[k] = s.get(k, 1.0) + gm[k]
		out.append(s)
	while out.size() < 5: out.append(NEUTRAL.duplicate())
	return out

## Mods de sinergia agregados (conta tags entre os titulares, aplica limiares).
func _synergy_mods() -> Dictionary:
	var counts: Dictionary = _tag_counts()
	var mods: Dictionary = {}
	for tag in SINERGIAS:
		var n: int = counts.get(tag, 0)
		var best: Dictionary = {}
		for thr in ["2", "3", "4", "5"]:
			if SINERGIAS[tag].has(thr) and n >= int(thr):
				best = SINERGIAS[tag][thr]
		for k in best: mods[k] = mods.get(k, 0.0) + best[k]
	return mods

func _tag_counts() -> Dictionary:
	var counts: Dictionary = {}
	for id in titulares:
		for t in POOL.get(id, {}).get("tags", []):
			counts[t] = counts.get(t, 0) + 1
	return counts

## Sinergias ATIVAS (p/ a PrepScreen): [{tag, nome, n}] que bateram o limiar.
func active_synergies() -> Array:
	var counts: Dictionary = _tag_counts()
	var out: Array = []
	for tag in SINERGIAS:
		var n: int = counts.get(tag, 0)
		var hit := false
		for thr in ["2", "3", "4", "5"]:
			if SINERGIAS[tag].has(thr) and n >= int(thr): hit = true
		if hit: out.append({"tag": tag, "nome": SINERGIAS[tag]["nome"], "n": n})
	return out

# — equipar/desequipar gear num slot de titular (PrepScreen §6.3) —
func equip_gear(slot: int, gid: String) -> void:
	if slot < 0 or slot >= 5 or not gear_inv.has(gid): return
	if equipped[slot] != "": gear_inv.append(equipped[slot])   # devolve o atual
	gear_inv.erase(gid)
	equipped[slot] = gid

func unequip_gear(slot: int) -> void:
	if slot < 0 or slot >= 5 or equipped[slot] == "": return
	gear_inv.append(equipped[slot])
	equipped[slot] = ""

## Troca o titular de um slot por uma reserva (capitã é fixa). Gear fica no slot.
func swap_titular(slot: int, reserve_id: String) -> void:
	if slot < 0 or slot >= 5 or titulares[slot] == capita or not reservas.has(reserve_id): return
	var old: String = titulares[slot]
	titulares[slot] = reserve_id
	reservas.erase(reserve_id)
	reservas.append(old)

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

## Pontuação-alvo do nó atual (Doc 3). Fallback p/ cena solta.
func target() -> int:
	return current_node.get("enemy", {}).get("target", 80)

const ModifiersLib = preload("res://scripts/data/Modifiers.gd")

## Jokers do jogador resolvidos em dicts (p/ o ScoreEngine) + a passiva da capitã.
func player_jokers() -> Array:
	var out: Array = ModifiersLib.resolve(jokers)
	var p: Dictionary = captain_passive()
	if p.has("joker"):
		var j: Dictionary = (p["joker"] as Dictionary).duplicate(true)
		j["id"] = "cap_" + capita
		out.append(j)
	return out

# — PACOTE DE FIGURINHAS (Balatro) — sorteia feras por raridade pro elenco —
## Abre um pacote: retorna n feras (não-heróis, ainda não no elenco) por peso de raridade.
func open_pack(n: int = 3) -> Array:
	var have: Array = titulares + reservas
	var avail: Array = []
	for id in POOL:
		if not HERO_IDS.has(id) and not have.has(id): avail.append(id)
	var picks: Array = []
	for _i in n:
		if avail.is_empty(): break
		var id: String = _weighted_pick(avail)
		picks.append(id); avail.erase(id)
	return picks

func _weighted_pick(ids: Array) -> String:
	var total := 0
	for id in ids: total += int(RARITY_WEIGHT.get(rarity(id), 10))
	var r := randi() % maxi(1, total)
	for id in ids:
		r -= int(RARITY_WEIGHT.get(rarity(id), 10))
		if r < 0: return id
	return ids[0]

## Recruta uma fera pro banco (vinda de pacote/loja).
func recruit(id: String) -> void:
	if not (titulares + reservas).has(id): reservas.append(id)

## Desvantagem (blind) do nó atual — cfg p/ o ScoreEngine + nome/desc p/ o HUD.
func debuff() -> Dictionary:
	var id: String = current_node.get("enemy", {}).get("debuff", "")
	return DEBUFFS.get(id, {})

func debuff_cfg() -> Dictionary:
	return debuff().get("cfg", {})

## Quanto o alvo SOBE a cada gol sofrido (punição > tempo de reposição).
func concede_bump() -> int:
	return current_node.get("enemy", {}).get("concede_bump", 0)

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
	var target := _target_for(tier, a)
	var pool: Array = DEBUFF_POOL.get(tier, DEBUFF_POOL["normal"])
	var debuff: String = pool[randi() % pool.size()]
	var bump: int = {"normal": 25, "elite": 40, "boss": 60}.get(tier, 25)
	return {"name": POOL[leader]["nome"], "crest": POOL[leader]["crest"], "leader": leader,
		"stats": _scaled(POOL[leader]["stats"], f), "squad": squad, "target": target,
		"debuff": debuff, "concede_bump": bump}

## Pontuação-alvo da blind (Doc 3 §3.3) — escala por tier e ato. Calibrada pro
## patamar real (~250–390 pts/90s no ato 1); cresce com o ato (build do jogador).
func _target_for(tier: String, a: int) -> int:
	match tier:
		"boss":  return 360 + a * 170           # A1 360 · A2 530 · A3 700
		"elite": return 270 + a * 90            # A1 270 · A2 360 · A3 450
		_:       return 210 + a * 65            # normal: A1 210 · A2 275 · A3 340

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

func add_joker(id: String) -> void:
	if not jokers.has(id): jokers.append(id)

## Recompensas/oferta MISTAS: relíquias globais + jokers ainda não possuídos.
## Cada item: {"kind": "relic"|"joker", "id": ...}.
func reward_choices(n: int = 3) -> Array:
	var pool: Array = []
	for r in RELICS:
		if not relics.has(r): pool.append({"kind": "relic", "id": r})
	for j in ModifiersLib.JOKERS:
		if not jokers.has(j): pool.append({"kind": "joker", "id": j})
	for g in GEAR:
		if not gear_inv.has(g) and not equipped.has(g): pool.append({"kind": "gear", "id": g})
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))

## Dados de exibição de um item de recompensa (nome/ic/desc/kind).
func reward_info(item: Dictionary) -> Dictionary:
	var k: String = item.get("kind", "")
	if k == "joker":
		var j: Dictionary = ModifiersLib.JOKERS[item["id"]]
		return {"nome": j["nome"], "ic": j["ic"], "desc": j["desc"], "kind": "joker"}
	if k == "gear":
		var g: Dictionary = GEAR[item["id"]]
		return {"nome": g["nome"], "ic": g["ic"], "desc": g["desc"], "kind": "gear"}
	var r: Dictionary = RELICS[item["id"]]
	return {"nome": r["name"], "ic": r["ic"], "desc": r["desc"], "kind": "relic"}

func take_reward(item: Dictionary) -> void:
	var k: String = item.get("kind", "")
	if k == "joker": add_joker(item["id"])
	elif k == "gear": gear_inv.append(item["id"])
	else: add_relic(item["id"])

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

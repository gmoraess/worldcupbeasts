extends Node
## Autoload — estado da corrida roguelike (Etapa 2). As feras são PERFIS DE STATS
## que enviesam a física; as relíquias mexem em PARÂMETROS FÍSICOS. GDD §8.

# ==========================================================================
#  PERFIS (stats ~0.8–1.4 — multiplicadores que enviesam o motor físico)
#  fin=finalização · ctrl=controle · des=desarme · def=goleiro/defesa
#  spd=velocidade · sta=fôlego
# ==========================================================================
const BEASTS := {
	"cuirass": {"name": "Cuirass", "crest": "🛡", "type": "Tanque",
		"stats": {"fin": 0.85, "ctrl": 1.05, "des": 1.25, "def": 1.32, "spd": 0.95, "sta": 1.20},
		"lore": "O tatu couraçado. Muralha viva — difícil de furar."},
	"zab": {"name": "Zab", "crest": "🐺", "type": "Caçador",
		"stats": {"fin": 1.05, "ctrl": 1.00, "des": 1.32, "def": 1.09, "spd": 1.08, "sta": 1.15},
		"lore": "O lobo implacável. Caça por desgaste e bote."},
	"zak": {"name": "Zak", "crest": "🐆", "type": "Veloz",
		"stats": {"fin": 1.02, "ctrl": 1.12, "des": 0.92, "def": 0.92, "spd": 1.16, "sta": 1.00},
		"lore": "O guepardo relâmpago. Controle e contra-ataque."},
	"foot": {"name": "Foot", "crest": "🐓", "type": "Artilheiro",
		"stats": {"fin": 1.38, "ctrl": 1.08, "des": 0.98, "def": 1.00, "spd": 1.08, "sta": 0.95},
		"lore": "O galo de briga. Gol no instinto."},
}

# inimigos como perfis (mais fracos na base; escalam por ato)
const NORMAL_ENEMIES := [
	{"name": "Rinoceronte Sombrio", "crest": "🦏", "stats": {"fin": 0.95, "ctrl": 0.9, "des": 1.05, "def": 0.95, "spd": 0.9, "sta": 1.05}},
	{"name": "Lobo da Névoa", "crest": "🐺", "stats": {"fin": 1.0, "ctrl": 0.95, "des": 1.1, "def": 0.9, "spd": 1.05, "sta": 1.0}},
	{"name": "Urso do Norte", "crest": "🐻", "stats": {"fin": 0.95, "ctrl": 0.95, "des": 1.05, "def": 1.05, "spd": 0.85, "sta": 1.1}},
	{"name": "Escorpião Ferreiro", "crest": "🦂", "stats": {"fin": 1.05, "ctrl": 0.95, "des": 1.05, "def": 0.9, "spd": 1.0, "sta": 0.95}},
	{"name": "Arara Carmesim", "crest": "🦜", "stats": {"fin": 1.05, "ctrl": 1.05, "des": 0.9, "def": 0.9, "spd": 1.1, "sta": 0.95}},
]
const ELITE_ENEMIES := [
	{"name": "Elefante de Guerra", "crest": "🐘", "stats": {"fin": 1.05, "ctrl": 1.0, "des": 1.2, "def": 1.2, "spd": 0.9, "sta": 1.2}},
	{"name": "Gorila das Sombras", "crest": "🦍", "stats": {"fin": 1.1, "ctrl": 1.05, "des": 1.2, "def": 1.05, "spd": 1.0, "sta": 1.15}},
	{"name": "Tigre Relâmpago", "crest": "🐯", "stats": {"fin": 1.15, "ctrl": 1.15, "des": 1.05, "def": 1.0, "spd": 1.25, "sta": 1.0}},
]
const BOSSES := [
	{"name": "Mantis da Tempestade", "crest": "🦗", "stats": {"fin": 1.2, "ctrl": 1.15, "des": 1.2, "def": 1.15, "spd": 1.2, "sta": 1.2}},
	{"name": "Leão Dourado", "crest": "🦁", "stats": {"fin": 1.3, "ctrl": 1.15, "des": 1.15, "def": 1.2, "spd": 1.15, "sta": 1.25}},
	{"name": "Quetzal, a Serpente Imortal", "crest": "🐉", "stats": {"fin": 1.35, "ctrl": 1.3, "des": 1.2, "def": 1.3, "spd": 1.25, "sta": 1.3}},
]

# relíquias — mexem em PARÂMETROS FÍSICOS (mods aplicados ao time do jogador).
# valores + ou − no stat (suporta contrapartida). Pool variado pra loja seguir
# relevante na corrida inteira (escolha real, não "junta tudo").
const RELICS := {
	# simples (1 stat) — bloco básico
	"chuteira_rapida": {"name": "Chuteira Veloz", "ic": "⚡", "desc": "+velocidade do time", "mods": {"spd_mult": 0.12}},
	"bota_craque":     {"name": "Bota de Craque", "ic": "👟", "desc": "+potência/precisão de chute", "mods": {"fin_mult": 0.18}},
	"luvas_goleiro":   {"name": "Luvas do Goleiro", "ic": "🧤", "desc": "+alcance/defesa do goleiro", "mods": {"def_mult": 0.20}},
	"garra_afiada":    {"name": "Garra Afiada", "ic": "🐾", "desc": "+força do bote/desarme", "mods": {"des_mult": 0.20}},
	"coracao_ferro":   {"name": "Coração de Ferro", "ic": "🔥", "desc": "+fôlego (menos fadiga)", "mods": {"sta_mult": 0.20}},
	"imã_da_bola":     {"name": "Imã da Bola", "ic": "🧲", "desc": "+controle (segura a bola)", "mods": {"ctrl_mult": 0.20}},
	# duplo efeito (2 stats menores) — recompensa quem combina
	"manto_sombrio":   {"name": "Manto Sombrio", "ic": "🌑", "desc": "+velocidade e +desarme", "mods": {"spd_mult": 0.08, "des_mult": 0.10}},
	"elmo_guardiao":   {"name": "Elmo do Guardião", "ic": "⛑", "desc": "+defesa e +fôlego", "mods": {"def_mult": 0.12, "sta_mult": 0.10}},
	"garras_gemeas":   {"name": "Garras Gêmeas", "ic": "✌", "desc": "+desarme e +finalização", "mods": {"des_mult": 0.12, "fin_mult": 0.10}},
	# contrapartida (sobe forte, abre mão de algo) — build de risco
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
var beast_id: String = ""
var beast: Dictionary = {}
var relics: Array = []
var gold: int = 20
var extra_life: bool = true
var act: int = 0
var col: int = -1
var lane: int = 1
var map_data: Array = []
var current_node: Dictionary = {}

func start_run(p_beast_id: String) -> void:
	beast_id = p_beast_id
	beast = BEASTS.get(p_beast_id, BEASTS["cuirass"]).duplicate(true)
	relics = []
	gold = 20
	extra_life = true
	act = 0; col = -1; lane = 1
	generate_map()

## Stats do jogador (perfil da fera + relíquias). Fallback: perfil neutro.
func home_stats() -> Dictionary:
	var s: Dictionary = (beast.get("stats", {}) as Dictionary).duplicate()
	if s.is_empty():
		s = {"fin": 1.0, "ctrl": 1.0, "des": 1.0, "def": 1.0, "spd": 1.0, "sta": 1.0}
	for r in relics:
		var mods: Dictionary = RELICS.get(r, {}).get("mods", {})
		for k in mods:
			var stat := (k as String).replace("_mult", "")
			s[stat] = s.get(stat, 1.0) + mods[k]
	return s

## Stats do inimigo do nó atual (escalado pelo ato). Fallback: perfil neutro.
func away_stats() -> Dictionary:
	var enemy: Dictionary = current_node.get("enemy", {})
	var s: Dictionary = (enemy.get("stats", {}) as Dictionary).duplicate()
	if s.is_empty():
		s = {"fin": 1.0, "ctrl": 1.0, "des": 1.0, "def": 1.0, "spd": 1.0, "sta": 1.0}
	return s

func enemy_name() -> String:
	return current_node.get("enemy", {}).get("name", "Oponente")

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

func _scale(stats: Dictionary, a: int) -> Dictionary:
	var f := 1.0 + a * 0.10            # inimigos ficam mais fortes por ato
	var out := {}
	for k in stats:
		out[k] = stats[k] * f
	return out

func _mk_node(tp: String, a: int, elite: bool) -> Dictionary:
	var enemy: Dictionary = {}
	if tp in ["partida", "elite"]:
		var pool: Array = ELITE_ENEMIES if elite else NORMAL_ENEMIES
		var base: Dictionary = pool[randi() % pool.size()].duplicate(true)
		base["stats"] = _scale(base["stats"], a)
		enemy = base
	return {"type": tp, "enemy": enemy, "visited": false}

func _mk_boss(a: int) -> Dictionary:
	var e: Dictionary = BOSSES[a % BOSSES.size()].duplicate(true)
	e["stats"] = _scale(e["stats"], a)
	return {"type": "boss", "enemy": e, "visited": false}

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

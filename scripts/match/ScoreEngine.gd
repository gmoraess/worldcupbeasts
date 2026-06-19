extends RefCounted
## Doc 3 §3/§4 — pontuação estilo Balatro: cada POSSE é uma "mão" que acumula
## chips e mult; ao fechar a jogada, pontua `round(chips × mult)` no total. Jokers
## (relíquias globais, data-driven) disparam por gatilho×condição×efeito.

# chips-base por ação (Doc 3 §3.1) — varrer no playtest
const CHIPS := {
	"passe": 1, "lancamento": 3, "desarme": 5, "porrada": 4,
	"nocaute": 10, "finalizacao": 5, "gol": 30, "super_gol": 60,
}

var total := 0
var chips := 0
var mult := 1.0
var passes_na_jogada := 0
var gols_marcados := 0           # p/ condição gol_impar
var jokers: Array = []           # dicts §4 (gatilho/condicao/efeito)
var _counters := {}              # p/ condições "cada_N"

# desvantagem do inimigo (blind, Doc 3) — modificadores de pontuação
var chips_mult := 1.0            # multiplica os chips pontuados na jogada
var gol_mult := 1.0              # multiplica os chips de gol/super-gol
var passe_chips := -1            # < 0 = usa o padrão; senão sobrescreve chips de passe
var mult_max := 0.0              # 0 = sem teto; senão limita o mult

## Aplica a desvantagem do nó (cfg do GameState.debuff_cfg()).
func apply_debuff(cfg: Dictionary) -> void:
	if cfg.has("chips_mult"): chips_mult = float(cfg["chips_mult"])
	if cfg.has("gol_mult"): gol_mult = float(cfg["gol_mult"])
	if cfg.has("passe_chips"): passe_chips = int(cfg["passe_chips"])
	if cfg.has("mult_max"): mult_max = float(cfg["mult_max"])

## Início de uma posse do jogador (reseta chips/mult da "mão").
func start_possession() -> void:
	chips = 0
	mult = 1.0
	passes_na_jogada = 0

## Registra uma ação de futebol/combate; soma chips e dispara jokers do gatilho.
func action(kind: String) -> void:
	var base: int = int(CHIPS.get(kind, 0))
	if kind == "passe" and passe_chips >= 0:
		base = passe_chips                       # debuff Muralha: passes não pontuam
	if kind == "gol" or kind == "super_gol":
		base = int(round(base * gol_mult))       # debuff Anti-Artilheiro: gol vale menos
	chips += base
	if kind == "passe" or kind == "lancamento":
		passes_na_jogada += 1
	if kind == "gol" or kind == "super_gol":
		gols_marcados += 1
	_fire(_trigger_for(kind), kind)

## Fecha a jogada: dispara jokers de fim, pontua chips×mult e zera a "mão".
## Retorna quanto pontuou (p/ a animação do HUD).
func finalizar_jogada() -> int:
	_fire("ao_finalizar_jogada", "")
	var m := mult
	if mult_max > 0.0: m = minf(m, mult_max)        # debuff Teto de Vidro
	var gained := int(round(float(chips) * m * chips_mult))   # chips_mult: debuff Neblina/Tempestade
	total += gained
	start_possession()
	return gained

func _trigger_for(kind: String) -> String:
	match kind:
		"gol", "super_gol": return "ao_marcar_gol"
		"desarme": return "ao_desarmar"
		"nocaute": return "ao_nocautear"
		"finalizacao": return "ao_finalizar"
		_: return ""

func _fire(trigger: String, kind: String) -> void:
	if trigger == "":
		return
	for j in jokers:
		if j.get("gatilho", "") != trigger:
			continue
		if not _cond_ok(j, kind):
			continue
		_apply(j.get("efeito", {}))

func _cond_ok(j: Dictionary, _kind: String) -> bool:
	var c: String = j.get("condicao", "")
	match c:
		"": return true
		"gol_impar": return (gols_marcados % 2) == 1
		"passes_na_jogada_>=4": return passes_na_jogada >= 4
		_:
			if c.begins_with("cada_"):
				var n := int(c.substr(5))
				if n <= 0: return false
				var id: String = j.get("id", "?")
				_counters[id] = int(_counters.get(id, 0)) + 1
				return int(_counters[id]) % n == 0
			return true

func _apply(e: Dictionary) -> void:
	if e.has("chips"): chips += int(e["chips"])
	if e.has("add_mult"): mult += float(e["add_mult"])
	if e.has("x_mult"): mult *= float(e["x_mult"])

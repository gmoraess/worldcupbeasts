extends RefCounted
## Doc 3 §3/§4 — pontuação estilo Balatro: cada POSSE é uma "mão" que acumula
## chips e mult; ao fechar a jogada, pontua `round(chips × mult)` no total. Jokers
## (relíquias globais, data-driven) disparam por gatilho×condição×efeito.

# chips-base por ação (Doc 3 §3.1) — varrer no playtest
const CHIPS := {
	"passe": 1, "lancamento": 3, "desarme": 5, "porrada": 4,
	"nocaute": 10, "finalizacao": 10, "gol": 40, "super_gol": 80,
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
var passe_scores := false        # passe/lançamento só pontuam chips se TRUE (relíquia Maestro).
                                 # Por padrão NÃO pontuam (senão tocar infinito ganharia sempre).

# buffs de "próxima jogada" (cartas de pontuação) — aplicados no início da próxima posse
var next_chips := 0
var next_add_mult := 0.0
var next_x_mult := 1.0

## Agenda um bônus pra PRÓXIMA jogada (carta de pontuação §5, escopo proxima_jogada).
func queue_next(e: Dictionary) -> void:
	if e.has("chips"): next_chips += int(e["chips"])
	if e.has("add_mult"): next_add_mult += float(e["add_mult"])
	if e.has("x_mult"): next_x_mult *= float(e["x_mult"])

## Aplica a desvantagem do nó (cfg do GameState.debuff_cfg()).
func apply_debuff(cfg: Dictionary) -> void:
	if cfg.has("chips_mult"): chips_mult = float(cfg["chips_mult"])
	if cfg.has("gol_mult"): gol_mult = float(cfg["gol_mult"])
	if cfg.has("passe_chips"): passe_chips = int(cfg["passe_chips"])
	if cfg.has("mult_max"): mult_max = float(cfg["mult_max"])

## Início de uma posse do jogador (reseta chips/mult; aplica bônus agendado).
func start_possession() -> void:
	chips = next_chips
	mult = (1.0 + next_add_mult) * next_x_mult
	passes_na_jogada = 0
	next_chips = 0; next_add_mult = 0.0; next_x_mult = 1.0

## Registra uma ação de futebol/combate; soma chips e dispara jokers do gatilho.
func action(kind: String) -> void:
	var base: int = int(CHIPS.get(kind, 0))
	if kind == "passe" or kind == "lancamento":
		if not passe_scores:
			base = 0                             # passe não pontua por padrão (anti-toca-toca)
		elif kind == "passe" and passe_chips >= 0:
			base = passe_chips                   # debuff Muralha: passes não pontuam
	if kind == "gol" or kind == "super_gol":
		base = int(round(base * gol_mult))       # debuff Anti-Artilheiro: gol vale menos
	chips += base
	if kind == "passe" or kind == "lancamento":
		passes_na_jogada += 1
	if kind == "gol" or kind == "super_gol":
		gols_marcados += 1
	_fire(_trigger_for(kind), kind)

## Mult efetivo da mão (com teto do debuff aplicado) — p/ Doc 4: o bônus de gol
## usa o MESMO mult da mão chutada.
func effective_mult() -> float:
	var m := mult
	if mult_max > 0.0: m = minf(m, mult_max)
	return m

## Fecha a jogada: dispara jokers de fim, pontua chips×mult e zera a "mão".
## Retorna quanto pontuou (p/ a animação do HUD).
func finalizar_jogada() -> int:
	_fire("ao_finalizar_jogada", "")
	var gained := int(round(float(chips) * effective_mult() * chips_mult))   # chips_mult: debuff Neblina/Tempestade
	total += gained
	start_possession()
	return gained

## Doc 4 §2.3 — GOL adiciona um bônus POR CIMA da mão já bancada no chute,
## usando o mult capturado no momento do chute. Retorna quanto somou.
func add_goal_bonus(super_gol: bool, shot_mult: float) -> int:
	gols_marcados += 1
	var base: int = int(CHIPS.get("super_gol" if super_gol else "gol", 30))
	var gmult := shot_mult
	# jokers/passivas de GOL (ex.: foot +mult; zak +chips; relíquias) afetam o bônus.
	# (no Doc 4 o gol não passa mais por action(), então disparamos o gatilho aqui)
	for j in jokers:
		if j.get("gatilho", "") != "ao_marcar_gol":
			continue
		if not _cond_ok(j, "gol"):
			continue
		var e: Dictionary = j.get("efeito", {})
		base += int(e.get("chips", 0))
		gmult += float(e.get("add_mult", 0.0))
		gmult *= float(e.get("x_mult", 1.0))
	var bonus := int(round(float(base) * gol_mult * gmult * chips_mult))
	total += bonus
	return bonus

## Doc 4 §2.3 — BUST (perder a bola): zera a mão atual SEM pontuar. Não toca nos
## bônus agendados (next_*), que valem pra próxima posse.
func reset_hand() -> void:
	chips = 0
	mult = 1.0
	passes_na_jogada = 0

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
		_:
			if c.begins_with("passes_na_jogada_>="):
				return passes_na_jogada >= int(c.substr(19))
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

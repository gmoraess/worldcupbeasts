extends Node2D
## ETAPA 1 — partida 100% AUTO-SIMULADA (autobattler, GDD §6 opção B sem comandos).
## Os dois times jogam pela IA; o jogador só ASSISTE. Resultado emerge da física
## + stats. Slow-mo/zoom/fogo são só apresentação. Agência fica no build+tática
## (fora da partida). O cérebro do lance mora aqui; o Player só faz steering.
const Ball = preload("res://scripts/Ball.gd")
const Player = preload("res://scripts/Player.gd")
const ScoreEngineLib = preload("res://scripts/match/ScoreEngine.gd")

signal match_over(home_won: bool)   # avisa o roteador quando a partida termina

const FIELD := Rect2(90, 70, 1100, 580)
const GOAL_TOP := 290.0
const GOAL_BOT := 430.0
const MID := Vector2(640, 360)
const CONTROL_R := 26.0          # raio pra "controlar" a bola
const SHOOT_RANGE := 360.0
const PRESSURE := 95.0
const MATCH_SECONDS := 90.0

var ball: Ball
var cam: Camera2D
var home: Array[Player] = []
var away: Array[Player] = []
var all: Array[Player] = []
var carrier: Player = null
var poss := ""                   # "home"/"away"/"" (bola solta/no ar)
var score := {"home": 0, "away": 0}
var clock := MATCH_SECONDS
var over := false
var sudden_death := false

var _decide := 0.0
var _goal_cd := 0.0
var _shake := 0.0
var _climax := false
var _in_flight := false       # bola viajando (passe/chute) — ninguém controla
var _steal_cd := 0.0          # tempo mínimo entre trocas de posse (anti-pinball)
var _save_rolled := false     # 1 tentativa de defesa por chute
var _shot_cd := 0.0           # cooldown global de chute (controla o placar)
var _pass_to: Player = null   # destinatário do passe (corre pra receber)
var _pass_t := 0.0            # janela do passe
var _stuck_t := 0.0           # tempo com a bola "presa" num ponto (anti cabo-de-guerra)
var _stuck_ref := MID         # posição de referência pra medir o deslocamento da bola
var _scrambles := 0           # quantas vezes a trava anti-cabo-de-guerra atuou (telemetria)

var _score_lbl: Label
var _clock_lbl: Label
var _goal_lbl: Label
var _poss_lbl: Label
var _speed_btns: Array[Button] = []
var _home_name := "CASA"
var _away_name := "FORA"
var _home_crest := "🛡"
var _away_crest := "🦁"

# — FÚRIA & SUPERS (SPEC §5) —
const FURY_GAIN := {"GOAL": 26.0, "DEFEND": 16.0, "STEAL": 18.0, "MISS": 8.0, "CONCEDE": 6.0}
var _fury := {"home": 0.0, "away": 0.0}
var _super_ready := {"home": false, "away": false}
var _home_super := ""
var _away_super := ""
var _home_frase := ""
var _away_frase := ""
var _super_shot_live := ""      # lado cujo super-chute está viajando ("" se nenhum)
var _fury_bar := {"home": null, "away": null}
var _cutin_cd := 0.0            # cap de 1 cut-in a cada ~12s (SPEC §6.2)
var _cutin_layer: CanvasLayer = null

# — PONTUAÇÃO BALATRO (Doc 3 §3) —
var _score = null              # ScoreEngineLib instance
var _target := 100             # pontuação-alvo da blind (vitória = bater o alvo)
var _home_has_poss := false    # se a posse de pontuação atual é do jogador
var _target_lbl: Label
var _chips_lbl: Label
var _prog: ProgressBar

func goal_x(team: String) -> float:
	# o gol que o time ATACA
	return FIELD.end.x if team == "home" else FIELD.position.x

func own_goal_x(team: String) -> float:
	return FIELD.position.x if team == "home" else FIELD.end.x

func _ready() -> void:
	var grass := ColorRect.new(); grass.color = Color("2f7d3a")
	grass.size = Vector2(1280, 720); add_child(grass)
	_pitch_lines()
	_walls()
	_goal("home")   # gol que o HOME ataca (direita)
	_goal("away")   # gol que o AWAY ataca (esquerda)

	cam = Camera2D.new(); cam.position = MID; add_child(cam); cam.make_current()

	ball = Ball.new(); add_child(ball)
	ball.bounced.connect(func(s, w): _shake = clampf(s * 0.01, 0.0, 12.0))

	_build_team("home")
	_build_team("away")
	all.append_array(home)
	all.append_array(away)

	_score = ScoreEngineLib.new()
	_score.jokers = GameState.player_jokers()
	_target = GameState.target()

	_build_hud()
	_kickoff("home")

# ==========================================================================
#  TIMES / FORMAÇÃO
# ==========================================================================
func _build_team(team: String) -> void:
	var arr: Array = home if team == "home" else away
	var defend_x := own_goal_x(team)
	var dir := 1.0 if team == "home" else -1.0   # sentido do ataque
	# SQUAD de 5 feras (1 perfil por jogador) — cada um enviesa a física do seu papel
	var squad: Array = GameState.home_squad() if team == "home" else GameState.away_squad()
	var slots := [
		["gk",  defend_x + 40.0 * dir, MID.y],
		["def", defend_x + 230.0 * dir, MID.y - 110.0],
		["def", defend_x + 230.0 * dir, MID.y + 110.0],
		["mid", MID.x - 110.0 * dir, MID.y],
		["fwd", MID.x + 150.0 * dir, MID.y],
	]
	for i in slots.size():
		var s: Array = slots[i]
		var profile: Dictionary = squad[i] if i < squad.size() else GameState.NEUTRAL
		var p := Player.new()
		p.team = team; p.role = s[0]
		p.home_pos = Vector2(s[1], s[2])
		p.global_position = p.home_pos
		add_child(p)
		p.stats = profile.duplicate()
		p.max_speed *= profile.get("spd", 1.0)
		arr.append(p)

func _kickoff(team: String) -> void:
	ball.reset_to(MID)
	for p in all:
		p.global_position = p.home_pos
		p.velocity = Vector2.ZERO
	carrier = null
	poss = team
	_climax = false
	_in_flight = false
	_super_shot_live = ""
	_steal_cd = 0.0
	_stuck_t = 0.0
	_stuck_ref = ball.global_position
	ball.ball_time_scale = 1.0

# ==========================================================================
#  LOOP
# ==========================================================================
func _physics_process(delta: float) -> void:
	if over: return
	_goal_cd = maxf(0.0, _goal_cd - delta)
	_shot_cd = maxf(0.0, _shot_cd - delta)
	_pass_t = maxf(0.0, _pass_t - delta)
	_cutin_cd = maxf(0.0, _cutin_cd - delta)
	if _pass_t <= 0.0: _pass_to = null
	if _goal_cd <= 0.0:
		clock = maxf(0.0, clock - delta)
		if clock <= 0.0 and not over:
			# fim do tempo → venceu se bateu a pontuação-alvo (Doc 3)
			_finish_by_target(_score != null and _score.total >= _target)

	_update_possession(delta)
	_combat_step(delta)           # porradaria: dano/nocaute (Doc 3 §6)
	_anti_deadlock(delta)         # rede de segurança: bola presa em disputa > 3s
	_gk_save()                    # goleiro defende (por lógica — a bola atravessa fisicamente)
	_carry_ball()                 # cola a bola no pé do carregador (drible suave)
	_decide -= delta
	if _decide <= 0.0:
		_decide = randf_range(0.16, 0.30)
		if carrier != null:
			_carrier_decide()
	_move_players()
	_check_goal()
	_camera_juice(delta)
	if ball.speed() > 240.0:
		_spawn_trail(ball.speed())
	_hud_update()

func _update_possession(delta: float) -> void:
	_steal_cd = maxf(0.0, _steal_cd - delta)
	var spd := ball.speed()
	if _in_flight and spd < 45.0:
		_in_flight = false           # bola parou → vira bola solta (disputável)
		_super_shot_live = ""
	if _in_flight:
		# recepção: alguém alcança a bola já desacelerada
		if spd < 470.0:
			var p := _closest_any()
			if p != null and p.global_position.distance_to(ball.global_position) < CONTROL_R + 5.0:
				_set_carrier(p)
	elif carrier == null:
		var p := _closest_any()
		if p != null and p.global_position.distance_to(ball.global_position) < CONTROL_R and spd < 230.0:
			_set_carrier(p)
	elif _steal_cd <= 0.0:
		# goleiro adversário AGARRA bola colada (resolve bola travada GK×atacante)
		var dgk := _team_gk("away" if carrier.team == "home" else "home")
		if dgk != null and dgk.global_position.distance_to(carrier.global_position) < 26.0:
			if randf() < 0.40:
				_set_carrier(dgk)
				_add_fury(dgk.team, "STEAL")
				if dgk.team == "home" and _score: _score.action("desarme")
				_steal_cd = 0.6
				return
		# ROUBO deliberado: um adversário coladinho rola uma chance (não instantâneo)
		var opp := _closest_opp_to(carrier)
		if opp != null and opp.global_position.distance_to(carrier.global_position) < 28.0:
			var des: float = opp.stats.get("des", 1.0)
			var ctrl: float = carrier.stats.get("ctrl", 1.0)
			if randf() < 0.10 * clampf(des / maxf(0.4, ctrl), 0.4, 2.4):
				_shake = maxf(_shake, 4.0)
				_set_carrier(opp)
				_add_fury(opp.team, "STEAL")
				if opp.team == "home" and _score: _score.action("desarme")
				_steal_cd = 0.7

func _set_carrier(p: Player) -> void:
	carrier = p
	poss = p.team
	_in_flight = false
	_pass_to = null
	_steal_cd = maxf(_steal_cd, 0.3)
	_score_owner(p.team)

# ==========================================================================
#  PONTUAÇÃO BALATRO (Doc 3 §3) — posse do jogador = "mão"
# ==========================================================================
## Troca de dono da posse: começa a "mão" do jogador ou fecha (banca) ao perdê-la.
func _score_owner(side: String) -> void:
	if _score == null: return
	if side == "home" and not _home_has_poss:
		_home_has_poss = true
		_score.start_possession()
	elif side != "home" and _home_has_poss:
		_home_has_poss = false
		_bank()

## Fecha a jogada do jogador: pontua chips×mult, anima e checa o alvo.
func _bank() -> void:
	var g: int = _score.finalizar_jogada()
	if g > 0:
		_score_pop(g)
	_check_target()

func _check_target() -> void:
	if over: return
	if _score.total >= _target:
		_finish_by_target(true)

## Anti cabo-de-guerra: se a bola fica num raio pequeno por mais de 3s (disputa
## parada, ninguém progride), alguém "ganha o bate-pé" e ela escapa do amontoado.
## Mede pelo DESLOCAMENTO da bola — passe/chute/condução normais a tiram da zona.
func _anti_deadlock(delta: float) -> void:
	# só conta como "preso" quando a bola não progride E está DISPUTADA (jogadores
	# dos dois times coladinhos) — é o cabo-de-guerra; posse limpa não dispara.
	if over or _goal_cd > 0.0 or ball.global_position.distance_to(_stuck_ref) > 60.0 or not _ball_contested():
		_stuck_ref = ball.global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t >= 3.0:
		_break_scramble()
		_stuck_t = 0.0
		_stuck_ref = ball.global_position

## Porradaria (Doc 3 §6): o marcador mais próximo do carregador pode dar uma porrada
## (cooldown anti-abuso). Dano ∝ desarme; HP zera → nocaute (vítima sai ~6s). Porrada
## e nocaute pontuam pro jogador (chips). Carregador nocauteado → solta a bola.
func _combat_step(_delta: float) -> void:
	if carrier == null or _in_flight or carrier.ko: return
	var opp := _closest_opp_to(carrier)
	if opp == null or opp.ko: return
	if opp.global_position.distance_to(carrier.global_position) >= 30.0 or opp.hit_cd > 0.0:
		return
	var aggro: float = opp.stats.get("des", 1.0)
	if randf() < 0.025 * clampf(aggro, 0.5, 1.6):
		opp.hit_cd = 1.8                       # anti-abuso: porrada espaçada (§6.4)
		_shake = maxf(_shake, 5.0)
		if opp.team == "home" and _score: _score.action("porrada")
		var victim := carrier
		var knocked: bool = victim.take_damage(22.0 * clampf(aggro, 0.6, 1.5))
		if knocked:
			if opp.team == "home" and _score: _score.action("nocaute")
			if carrier == victim:
				carrier = null          # carregador nocauteado solta a bola (fica solta)

## Bola disputada: há jogadores dos DOIS times bem perto dela (scrum/cabo-de-guerra).
func _ball_contested() -> bool:
	var has_home := false
	var has_away := false
	for p in all:
		if p.ko: continue
		if p.global_position.distance_to(ball.global_position) < 46.0:
			if p.team == "home": has_home = true
			else: has_away = true
	return has_home and has_away

## Resolve a disputa parada: o jogador mais perto escapa a bola pra frente, longe
## do aglomerado, e trava o roubo por um tempinho (não re-prende na hora).
func _break_scramble() -> void:
	var p := _closest_any()
	if p == null: return
	_scrambles += 1
	# "joga pra fora da pressão": manda a bola DECISIVAMENTE pra um companheiro em
	# espaço (não é chute a gol → não infla placar) e, sem opção, pra longe do
	# aglomerado adversário. Limpa o scrum de vez (não fica cutucando).
	var mate := _best_pass(p)
	var target: Vector2
	if mate != null:
		target = mate.global_position
		_pass_to = mate; _pass_t = 1.5
	else:
		target = ball.global_position + _escape_dir(p) * 280.0
		_pass_to = null
	var to := target - ball.global_position
	ball.kick(to, clampf(to.length() * 2.2, 460.0, 760.0), 0.0, 0.0)
	_in_flight = true
	carrier = null
	_save_rolled = false
	_steal_cd = 1.2
	_shake = maxf(_shake, 5.0)

## Direção de fuga do scrum: média apontando PARA LONGE dos adversários próximos.
func _escape_dir(p: Player) -> Vector2:
	var acc := Vector2.ZERO
	for o in all:
		if o.team == p.team: continue
		var d := ball.global_position - o.global_position
		if d.length() < 130.0:
			acc += d.normalized()
	if acc.length() < 0.1:
		var atk := 1.0 if p.team == "home" else -1.0
		acc = Vector2(atk, randf_range(-0.5, 0.5))
	return acc.normalized()

## Defesa do goleiro: 1 tentativa por chute. Se a bola passa coladinha no GK,
## ele espalma (chance alta, enviesada por 'def'). Como ele fecha o ângulo,
## chutes centrais são defendidos; chutes precisos/abertos passam.
func _gk_save() -> void:
	if not _in_flight or _save_rolled: return
	for p in all:
		if p.role != "gk": continue
		if p.global_position.distance_to(ball.global_position) < 34.0:
			_save_rolled = true
			var def_side := p.team
			var shooter := "away" if def_side == "home" else "home"
			var dfn: float = p.stats.get("def", 1.0)
			var chance := 0.64 * clampf(dfn, 0.5, 1.4)
			if _super_shot_live == shooter: chance *= 0.15        # super-chute fura a defesa
			var super_save: bool = _super_ready[def_side] and _super_kind(def_side) == "save"
			if super_save: chance = 1.0                            # muralha: pega tudo
			if randf() < chance:
				ball.velocity *= 0.04
				_set_carrier(p)
				_shake = maxf(_shake, 6.0)
				_add_fury(def_side, "DEFEND")
				_add_fury(shooter, "MISS")
				if super_save:
					_super_ready[def_side] = false; _fury[def_side] = 0.0
					_play_cutin(def_side)
			_super_shot_live = ""
			return

func _closest_any() -> Player:
	var best: Player = null
	var bd := 1e9
	for p in all:
		if p.ko: continue
		var d := p.global_position.distance_to(ball.global_position)
		if d < bd: bd = d; best = p
	return best

func _team_gk(team: String) -> Player:
	for p in (home if team == "home" else away):
		if p.role == "gk" and not p.ko: return p
	return null

func _closest_opp_to(me: Player) -> Player:
	var best: Player = null
	var bd := 1e9
	for o in all:
		if o.team == me.team or o.ko: continue
		var d := o.global_position.distance_to(me.global_position)
		if d < bd: bd = d; best = o
	return best

## Cola a bola um pouco à frente do carregador (drible suave, sem pinball).
func _carry_ball() -> void:
	if carrier == null or _in_flight: return
	var atk := 1.0 if carrier.team == "home" else -1.0
	var dir := Vector2(atk, 0.0)
	if carrier.velocity.length() > 35.0:
		dir = (dir + carrier.velocity.normalized() * 0.7).normalized()
	var ctrl_pt := carrier.global_position + dir * 17.0
	ball.global_position = ball.global_position.lerp(ctrl_pt, 0.4)
	ball.velocity = Vector2.ZERO
	ball.spin = 0.0; ball.height = 0.0; ball.vz = 0.0

func _carrier_decide() -> void:
	if carrier == null or _in_flight: return
	# GOLEIRO com a bola → afasta rápido (tiro de meta/lançamento), não dribla na área
	if carrier.role == "gk":
		var gmate := _best_pass(carrier)
		if gmate != null:
			var gto := gmate.global_position - carrier.global_position
			ball.kick(gto, clampf(gto.length() * 2.0, 380.0, 820.0), 0.0, 0.0)
			_pass_to = gmate; _pass_t = 1.6        # distribui curto (mantém posse)
		else:
			ball.kick(Vector2(goal_x(carrier.team) - carrier.global_position.x, randf_range(-120, 120)), 700.0, 0.0, 110.0)
		_in_flight = true; carrier = null; _save_rolled = false
		return
	var team := carrier.team
	var goal_c := Vector2(goal_x(team), MID.y)
	var dist := carrier.global_position.distance_to(goal_c)
	var pressure := _nearest_opp_dist(carrier)

	# CHUTE — arcade: finaliza sempre que chega perto (mesmo sob pressão)
	if dist < 270.0:
		# SUPER-CHUTE: fúria cheia + super do tipo "shot" → bomba + cut-in (SPEC §5/§6)
		if _super_ready[carrier.team] and _super_kind(carrier.team) == "shot":
			_fire_super_shot(carrier, carrier.team)
			return
		var fin: float = carrier.stats.get("fin", 1.0)
		var noise := (1.6 - clampf(fin, 0.5, 1.5)) * 60.0
		var aim := goal_c + Vector2(0, randf_range(-noise, noise))
		ball.kick(aim - carrier.global_position, 780.0 + fin * 220.0, randf_range(-1.2, 1.2) * (1.4 - fin), 0.0)
		if carrier.team == "home" and _score:
			_score.action("finalizacao")
		_in_flight = true; carrier = null; _save_rolled = false
		_enter_climax()
		return
	# PASSE — mais frequente (tiki-taka): sob pressão sempre; senão, chance se há bom mate
	var mate := _best_pass(carrier)
	var pass_it := false
	if pressure < PRESSURE:
		pass_it = true
	elif mate != null and randf() < 0.45:
		pass_it = true
	if pass_it and mate != null:
		var lead := mate.velocity * 0.10
		var aim := mate.global_position + lead + Vector2(randf_range(-22, 22), randf_range(-22, 22))  # margem de erro
		var to := aim - carrier.global_position
		ball.kick(to, clampf(to.length() * 2.0, 380.0, 820.0), 0.0, 0.0)
		if carrier.team == "home" and _score:
			_score.action("lancamento" if to.length() > 280.0 else "passe")
		_pass_to = mate; _pass_t = 1.4         # o companheiro corre pra receber → conecta
		_in_flight = true; carrier = null; _save_rolled = false
		return
	# senão, segue driblando (o _carry_ball + o alvo rumo ao gol cuidam do resto);
	# se travar cercado, a rede de segurança _anti_deadlock resolve em até 3s


func _best_pass(from: Player) -> Player:
	var gx := goal_x(from.team)
	var best: Player = null
	var bs := -1e9
	for p in all:
		if p.team != from.team or p == from or p.role == "gk" or p.ko: continue
		# prefere quem está mais à frente (perto do gol adversário) e aberto
		var ahead := -p.global_position.distance_to(Vector2(gx, p.global_position.y))
		var open := _nearest_opp_dist(p)
		var dist := from.global_position.distance_to(p.global_position)
		if dist > 520.0: continue
		var s := ahead * 0.6 + open * 1.2
		if s > bs: bs = s; best = p
	return best

func _nearest_opp_dist(p: Player) -> float:
	var d := 1e9
	for o in all:
		if o.team == p.team: continue
		d = minf(d, p.global_position.distance_to(o.global_position))
	return d

# ==========================================================================
#  MOVIMENTO (steering targets)
# ==========================================================================
func _move_players() -> void:
	var def_team := "away" if poss == "home" else "home"
	var presser := _closest_to_ball(def_team)
	for p in all:
		p.target = _target_for(p, presser)

func _target_for(p: Player, presser: Player) -> Vector2:
	var atk := 1.0 if p.team == "home" else -1.0
	var minx := FIELD.position.x + 36.0
	var maxx := FIELD.end.x - 36.0

	# GOLEIRO — fecha o ângulo, mas SAI POUCO da linha (não vira scrum)
	if p.role == "gk":
		var gc := Vector2(own_goal_x(p.team), MID.y)
		var d := ball.global_position - gc
		var pos := gc + d.normalized() * clampf(d.length() * 0.14, 16.0, 52.0)
		pos.y = clampf(pos.y, GOAL_TOP + 8.0, GOAL_BOT - 8.0)
		if p.team == "home":
			pos.x = clampf(pos.x, FIELD.position.x + 10, FIELD.position.x + 70)
		else:
			pos.x = clampf(pos.x, FIELD.end.x - 70, FIELD.end.x - 10)
		return pos

	# CARREGADOR — avança rumo ao gol desviando do marcador
	if p == carrier:
		var gc := Vector2(goal_x(p.team), MID.y)
		var dir := (gc - p.global_position).normalized()
		var opp := _closest_opp_to(p)
		if opp != null and p.global_position.distance_to(opp.global_position) < 80.0:
			dir = (dir + (p.global_position - opp.global_position).normalized() * 0.55).normalized()
		return p.global_position + dir * 110.0

	# RECEPTOR do passe corre pra bola (faz o passe CONECTAR — menos ping-pong)
	if p == _pass_to:
		return ball.global_position

	# PRESSER — o ÚNICO do time sem posse que vai à bola (o resto segura a forma)
	if p.team != poss and p == presser:
		return ball.global_position

	# ZONAL — bloco que desliza (x da bola + fase) mas IMPERFEITO: cada jogador
	# segue com força própria (p.follow) + deriva temporal (wander) na sua fase
	# → meio-termo entre linha sincronizada e movimento independente.
	var t := float(Time.get_ticks_msec()) * 0.001
	var wander := Vector2(sin(t * 0.7 + p.phase), cos(t * 1.05 + p.phase * 1.6)) * 20.0
	var hx := (ball.global_position.x - MID.x) * 0.5 * p.follow
	var phase := (56.0 if p.team == poss else -34.0) * atk
	var tx := clampf(p.home_pos.x + hx + phase, minx, maxx)
	var ty := clampf(lerpf(p.home_pos.y, ball.global_position.y, 0.18 * p.follow), FIELD.position.y + 30, FIELD.end.y - 30)
	return Vector2(tx, ty) + p.jitter * 0.5 + wander

func _closest_to_ball(team: String) -> Player:
	var best: Player = null; var bd := 1e9
	for p in (home if team == "home" else away):
		if p.role == "gk" or p.ko: continue
		var d := p.global_position.distance_to(ball.global_position)
		if d < bd: bd = d; best = p
	return best

# ==========================================================================
#  GOL / CÂMERA / JUICE
# ==========================================================================
func _check_goal() -> void:
	if _goal_cd > 0.0: return
	var bx := ball.global_position.x
	var by := ball.global_position.y
	if by < GOAL_TOP or by > GOAL_BOT: return
	if bx > FIELD.end.x + 4.0:
		_score_goal("home")
	elif bx < FIELD.position.x - 4.0:
		_score_goal("away")

func _score_goal(team: String) -> void:
	score[team] += 1
	# PONTUAÇÃO (Doc 3): gol do jogador pontua (super gol vale mais) e fecha a "mão"
	var was_super := _super_shot_live == team
	if team == "home" and _score != null:
		_score.action("super_gol" if was_super else "gol")
		_home_has_poss = false
		_bank()
	print("GOL %s! pts=%d/%d (t=%.0f)" % [team, _score.total if _score else 0, _target, clock])
	_add_fury(team, "GOAL")
	_add_fury("away" if team == "home" else "home", "CONCEDE")
	_super_shot_live = ""
	_goal_cd = 2.2
	_shake = 16.0
	ball.ball_time_scale = 1.0
	_popup_goal()
	if over:
		return
	await get_tree().create_timer(2.0).timeout
	if not over:
		_kickoff("home" if team == "away" else "away")

func _camera_juice(delta: float) -> void:
	var spd := ball.speed()
	if _climax and (spd < 120.0 or _goal_cd > 0.0):
		_exit_climax()
	var target := MID.lerp(ball.global_position, 0.35)
	if _climax:
		target = ball.global_position
	cam.position = cam.position.lerp(target, 0.1)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 36.0)
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		cam.offset = cam.offset.lerp(Vector2.ZERO, 0.3)

func _enter_climax() -> void:
	if _climax: return
	_climax = true
	ball.ball_time_scale = 0.4
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(1.5, 1.5), 0.25).set_trans(Tween.TRANS_SINE)

func _exit_climax() -> void:
	_climax = false
	ball.ball_time_scale = 1.0
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(1, 1), 0.4).set_trans(Tween.TRANS_SINE)

func _spawn_trail(spd: float) -> void:
	var dot := Polygon2D.new()
	var r := clampf(spd * 0.011, 4.0, 10.0)
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	dot.polygon = pts
	dot.color = Color(1.0, 0.5, 0.12, 0.7) if (_climax or spd > 700.0) else Color(1.0, 0.85, 0.4, 0.4)
	dot.global_position = ball.global_position + Vector2(0, -ball.height)
	add_child(dot)
	var tw := create_tween(); tw.set_parallel(true)
	tw.tween_property(dot, "modulate:a", 0.0, 0.33)
	tw.tween_property(dot, "scale", Vector2(0.2, 0.2), 0.33)
	tw.chain().tween_callback(dot.queue_free)

## Fim por pontuação-alvo (Doc 3): venceu = bateu o alvo (ou bateu antes do tempo).
func _finish_by_target(won: bool) -> void:
	if over: return
	over = true
	var pts: int = _score.total if _score else 0
	_goal_lbl.text = ("ALVO BATIDO!  %d / %d" % [pts, _target]) if won else ("FALHOU  %d / %d" % [pts, _target])
	_goal_lbl.modulate = Color(1, 1, 1, 1)
	await get_tree().create_timer(1.8).timeout
	match_over.emit(won)

# ==========================================================================
#  CAMPO / HUD
# ==========================================================================
func _pitch_lines() -> void:
	var col := Color(1, 1, 1, 0.5)
	_line([FIELD.position, Vector2(FIELD.end.x, FIELD.position.y), FIELD.end, Vector2(FIELD.position.x, FIELD.end.y), FIELD.position], col, 3.0)
	_line([Vector2(640, FIELD.position.y), Vector2(640, FIELD.end.y)], col, 2.0)
	var circ := Line2D.new(); circ.width = 2.0; circ.default_color = col; circ.closed = true
	for i in 32:
		var a := TAU * float(i) / 32.0
		circ.add_point(MID + Vector2(cos(a), sin(a)) * 70.0)
	add_child(circ)

func _line(points: Array, col: Color, w: float) -> void:
	var l := Line2D.new(); l.width = w; l.default_color = col
	for p in points: l.add_point(p)
	add_child(l)

func _walls() -> void:
	_wall(Rect2(FIELD.position.x - 20, FIELD.position.y - 20, FIELD.size.x + 40, 20))
	_wall(Rect2(FIELD.position.x - 20, FIELD.end.y, FIELD.size.x + 40, 20))
	# laterais com gap pros gols
	for side_x in [FIELD.position.x - 20, FIELD.end.x]:
		_wall(Rect2(side_x, FIELD.position.y, 20, GOAL_TOP - FIELD.position.y))
		_wall(Rect2(side_x, GOAL_BOT, 20, FIELD.end.y - GOAL_BOT))

func _wall(r: Rect2) -> void:
	var sb := StaticBody2D.new()
	sb.position = r.position + r.size / 2.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new(); shape.size = r.size
	cs.shape = shape; sb.add_child(cs); add_child(sb)

func _goal(team: String) -> void:
	# gol que o `team` ATACA
	var gx := goal_x(team)
	for y in [GOAL_TOP, GOAL_BOT]:
		var post := StaticBody2D.new(); post.position = Vector2(gx, y)
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new(); sh.radius = 7.0; cs.shape = sh
		post.add_child(cs); add_child(post)
		var dot := Polygon2D.new(); var pts := PackedVector2Array()
		for i in 12:
			var a := TAU * float(i) / 12.0
			pts.append(Vector2(cos(a), sin(a)) * 7.0)
		dot.polygon = pts; dot.color = Color(1, 1, 1, 0.95); post.add_child(dot)

func _build_hud() -> void:
	# nomes/brasões dos dois lados (fallback se a cena rodar fora de uma corrida)
	_home_crest = GameState.beast.get("crest", "🛡")
	_home_name = GameState.beast.get("nome", "CASA")
	_home_super = GameState.beast.get("super", "")
	_home_frase = GameState.beast.get("frase", "")
	var enemy: Dictionary = GameState.current_node.get("enemy", {})
	_away_crest = enemy.get("crest", "🦁")
	_away_name = enemy.get("name", "FORA")
	var leader: Dictionary = GameState.POOL.get(enemy.get("leader", ""), {})
	_away_super = leader.get("super", "")
	_away_frase = leader.get("frase", "")

	var layer := CanvasLayer.new(); add_child(layer)

	# barra de transmissão: VBox full-width no topo; filhos CENTRALIZADOS (shrink-center)
	# — centralização confiável (o anchor CENTER_TOP estava jogando a barra pra esquerda).
	var top := VBoxContainer.new()
	layer.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 12
	top.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)
	row.add_child(_team_badge(GameState.home_img(), _home_name, _home_crest, UI.HOME))
	row.add_child(_score_plate())   # agora mostra a PONTUAÇÃO total (Balatro)
	row.add_child(_team_badge(GameState.away_img(), _away_name, _away_crest, UI.AWAY))

	# barra de progresso até a pontuação-alvo (Doc 3 §3)
	_prog = ProgressBar.new()
	_prog.custom_minimum_size = Vector2(300, 12)
	_prog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prog.min_value = 0; _prog.max_value = _target; _prog.value = 0
	_prog.show_percentage = false
	_prog.add_theme_stylebox_override("background", UI.sbf(UI.PANEL2, UI.BRONZE, 1, 6, 0, 0))
	_prog.add_theme_stylebox_override("fill", UI.sbf(UI.GOLD, UI.GOLD, 0, 6, 0, 0))
	top.add_child(_prog)
	_target_lbl = _chip("ALVO  0 / %d" % _target, 11, UI.GOLD2)
	_target_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(_target_lbl)

	# linha de baixo: chips×mult da posse · relógio · posse
	var sub := HBoxContainer.new()
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub.add_theme_constant_override("separation", 16)
	top.add_child(sub)
	_chips_lbl = _chip("🎰 0 × 1", 14, UI.RUNE)
	_clock_lbl = _chip("0'", 14, UI.RUNE)
	_poss_lbl = _chip("• bola livre •", 13, UI.RUNE2)
	sub.add_child(_chips_lbl)
	sub.add_child(_clock_lbl)
	sub.add_child(_poss_lbl)

	# controle de velocidade (canto superior direito): Lento · Normal · Rápido
	var speed := HBoxContainer.new()
	layer.add_child(speed)
	speed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	speed.offset_left = -260; speed.offset_top = 12; speed.offset_right = -12
	speed.alignment = BoxContainer.ALIGNMENT_END
	speed.add_theme_constant_override("separation", 6)
	for item: Array in [["Lento", 0.5], ["Normal", 1.0], ["Rápido", 2.0]]:
		var b := UI.gold_btn(item[0], 13)
		b.pressed.connect(_set_speed.bind(item[1] as float, b))
		speed.add_child(b)
		_speed_btns.append(b)
	_set_speed(1.0, _speed_btns[1])    # começa em Normal

	# barras de FÚRIA nos cantos inferiores (SPEC §7.1)
	_fury_bar["home"] = _make_fury_bar(layer, true, UI.HOME, _home_name)
	_fury_bar["away"] = _make_fury_bar(layer, false, UI.AWAY, _away_name)

	_goal_lbl = _lbl(Vector2(430, 150), 60, Color(1, 0.85, 0.3))
	_goal_lbl.text = "G O O O L !"; _goal_lbl.modulate = Color(1, 1, 1, 0)
	layer.add_child(_goal_lbl)

## Rótulo do time (brasão+nome) com leve contorno, pra ler sobre o gramado.
func _tag(txt: String, sz: int, col: Color) -> Label:
	var l := UI.lbl(txt, sz, col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

## Chip pequeno num painel discreto (relógio/posse).
func _chip(txt: String, sz: int, col: Color) -> Label:
	var l := UI.lbl(txt, sz, col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Crachá do time: retrato (PNG) + nome embaixo. Fallback p/ emoji se faltar a arte.
func _team_badge(img_path: String, team_name: String, emoji: String, col: Color) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var tex: Texture2D = load(img_path) if img_path != "" and ResourceLoader.exists(img_path) else null
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(58, 64)
		v.add_child(tr)
	else:
		v.add_child(_tag(emoji, 30, col))
	var nm := _tag(team_name.to_upper(), 12, col)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	return v

## Placar central na placa ornamentada (score_plate). Fallback p/ painel chapado.
func _score_plate() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(196, 76)
	var plate: Texture2D = load("res://assets/frames/score_plate.png") if ResourceLoader.exists("res://assets/frames/score_plate.png") else null
	if plate != null:
		var bg := TextureRect.new()
		bg.texture = plate
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(bg)
	else:
		var pnl := UI.framed(UI.PANEL2, UI.GOLD)
		pnl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(pnl)
	_score_lbl = _tag("0", 34, UI.GOLD2)      # PONTUAÇÃO total da partida (Balatro)
	_score_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(_score_lbl)
	return holder

## Velocidade do jogo. time_scale só muda QUANTOS passos de física rodam por segundo
## (o passo segue 1/60 fixo) → 2x não tunela pela parede/gol. Reseta no _exit_tree.
func _set_speed(scale: float, active: Button) -> void:
	Engine.time_scale = scale
	for b in _speed_btns:
		b.modulate = Color(1, 1, 1, 1.0) if b == active else Color(1, 1, 1, 0.45)

func _exit_tree() -> void:
	Engine.time_scale = 1.0    # não deixa a velocidade vazar pros menus

# ==========================================================================
#  FÚRIA & SUPERS (SPEC §5/§6)
# ==========================================================================
func _make_fury_bar(layer: CanvasLayer, is_home: bool, col: Color, nm: String) -> ProgressBar:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	layer.add_child(box)
	if is_home:
		box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		box.offset_left = 16; box.offset_top = -52; box.offset_bottom = -12
	else:
		box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		box.offset_left = -236; box.offset_right = -16; box.offset_top = -52; box.offset_bottom = -12
	box.add_child(_chip("FÚRIA · " + nm, 10, col))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 14)
	bar.min_value = 0; bar.max_value = 100; bar.value = 0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UI.sbf(UI.PANEL2, UI.BRONZE, 1, 6, 0, 0))
	bar.add_theme_stylebox_override("fill", UI.sbf(col, col, 0, 6, 0, 0))
	box.add_child(bar)
	return bar

## Soma fúria de um lado por evento (SPEC §5.1). Cheia → arma o super (não acumula).
func _add_fury(side: String, kind: String) -> void:
	if _super_ready[side]: return
	_fury[side] = clampf(_fury[side] + FURY_GAIN.get(kind, 0.0), 0.0, 100.0)
	if _fury[side] >= 100.0:
		_super_ready[side] = true

## Tipo do super do lado: "save" (muralha do goleiro) ou "shot" (os demais).
func _super_kind(side: String) -> String:
	var sid: String = _home_super if side == "home" else _away_super
	return "save" if sid == "super_defesa_muralha" else "shot"

## Dispara o super-chute: bomba mirada no canto + slow-mo forte + cut-in (SPEC §5.3).
func _fire_super_shot(shooter: Player, side: String) -> void:
	_super_ready[side] = false
	_fury[side] = 0.0
	_super_shot_live = side
	var corner_y := GOAL_TOP + 20.0 if randf() < 0.5 else GOAL_BOT - 20.0
	var aim := Vector2(goal_x(side), corner_y)
	ball.kick(aim - shooter.global_position, 1320.0, randf_range(-0.7, 0.7), 0.0)
	if side == "home" and _score:
		_score.action("finalizacao")
	_in_flight = true; carrier = null; _save_rolled = false
	_enter_super_climax()
	_play_cutin(side)

func _enter_super_climax() -> void:
	_climax = true
	ball.ball_time_scale = 0.22
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(1.7, 1.7), 0.2).set_trans(Tween.TRANS_SINE)

## Cut-in: retrato + nome + frase DESLIZA de um canto inferior (esquerda p/ super
## do seu time, direita p/ inimigo), segura um instante e some. Cap de 1/12s.
func _play_cutin(side: String) -> void:
	if _cutin_cd > 0.0: return
	_cutin_cd = 12.0
	var nm: String = _home_name if side == "home" else _away_name
	var frase: String = _home_frase if side == "home" else _away_frase
	var img: String = GameState.home_img() if side == "home" else GameState.away_img()
	var col: Color = UI.HOME if side == "home" else UI.AWAY
	if _cutin_layer != null and is_instance_valid(_cutin_layer):
		_cutin_layer.queue_free()
	_cutin_layer = CanvasLayer.new(); _cutin_layer.layer = 50; add_child(_cutin_layer)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL2, col, 3, 10, 12, 10))
	var card_w := 330.0
	var card_h := 118.0
	card.custom_minimum_size = Vector2(card_w, card_h)
	card.size = Vector2(card_w, card_h)
	_cutin_layer.add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	h.add_child(UI.icon(img, Vector2(82, card_h - 18), "🔥", col))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.lbl("⚡ SUPER!", 13, UI.GOLD2))
	v.add_child(UI.lbl(nm.to_upper(), 22, col))
	v.add_child(UI.lbl("« " + frase + " »", 12, UI.RUNE))
	h.add_child(v)

	# desliza do canto inferior (entra · segura · sai)
	var vp := get_viewport_rect().size
	var y := vp.y - card_h - 70.0                       # logo acima da barra de fúria
	var target_x := 16.0 if side == "home" else vp.x - card_w - 16.0
	var start_x := -card_w - 12.0 if side == "home" else vp.x + 12.0
	card.position = Vector2(start_x, y)
	var tw := create_tween()
	tw.tween_property(card, "position:x", target_x, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.65)
	tw.tween_property(card, "position:x", start_x, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_cutin_layer.queue_free)

func _lbl(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new(); l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l

## "Número que pula" do Balatro: dá um tranco de escala no total ao pontuar.
func _score_pop(_gained: int) -> void:
	if _score_lbl == null: return
	_score_lbl.pivot_offset = _score_lbl.size / 2.0
	_score_lbl.scale = Vector2(1.45, 1.45)
	var tw := create_tween()
	tw.tween_property(_score_lbl, "scale", Vector2(1, 1), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _popup_goal() -> void:
	_goal_lbl.text = "G O O O L !"
	_goal_lbl.modulate = Color(1, 1, 1, 0)
	_goal_lbl.scale = Vector2(0.3, 0.3)
	_goal_lbl.pivot_offset = _goal_lbl.size / 2.0
	var tw := create_tween(); tw.set_parallel(true)
	tw.tween_property(_goal_lbl, "modulate:a", 1.0, 0.12)
	tw.tween_property(_goal_lbl, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.0)
	tw.chain().tween_property(_goal_lbl, "modulate:a", 0.0, 0.4)

func _hud_update() -> void:
	# PONTUAÇÃO Balatro (Doc 3): total na placa, progresso até o alvo, chips×mult
	if _score != null:
		_score_lbl.text = str(_score.total)
		_prog.value = mini(_score.total, _target)
		_target_lbl.text = "ALVO  %d / %d" % [_score.total, _target]
		_chips_lbl.text = "🎰 %d × %.1f" % [_score.chips, _score.mult]
		if _home_has_poss:
			_chips_lbl.add_theme_color_override("font_color", UI.GOLD2)
		else:
			_chips_lbl.add_theme_color_override("font_color", UI.RUNE2)
	_clock_lbl.text = "%d'" % clampi(int(MATCH_SECONDS - clock), 0, 99)
	# indicador de posse: ponto colorido + nome do time com a bola
	if poss == "home":
		_poss_lbl.text = "● " + _home_name
		_poss_lbl.add_theme_color_override("font_color", UI.HOME)
	elif poss == "away":
		_poss_lbl.text = _away_name + " ●"
		_poss_lbl.add_theme_color_override("font_color", UI.AWAY)
	else:
		_poss_lbl.text = "• bola livre •"
		_poss_lbl.add_theme_color_override("font_color", UI.RUNE2)
	# barras de fúria (pulsam quando o super está armado)
	for side in ["home", "away"]:
		var bar: ProgressBar = _fury_bar[side]
		if bar == null: continue
		bar.value = _fury[side]
		if _super_ready[side]:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
			bar.modulate = Color(1, 1, 1, pulse)
		else:
			bar.modulate = Color(1, 1, 1, 1)

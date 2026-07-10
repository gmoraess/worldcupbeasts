extends Node2D
## ETAPA 1 — partida 100% AUTO-SIMULADA (autobattler, GDD §6 opção B sem comandos).
## Os dois times jogam pela IA; o jogador só ASSISTE. Resultado emerge da física
## + stats. Slow-mo/zoom/fogo são só apresentação. Agência fica no build+tática
## (fora da partida). O cérebro do lance mora aqui; o Player só faz steering.
const Ball = preload("res://scripts/Ball.gd")
const Player = preload("res://scripts/Player.gd")
const ScoreEngineLib = preload("res://scripts/match/ScoreEngine.gd")
const MatchCardsLib = preload("res://scripts/match/MatchCards.gd")
const SkillShotLib = preload("res://scripts/match/SkillShot.gd")
const PassAimLib = preload("res://scripts/match/PassAim.gd")
const ConfettiFX = preload("res://scripts/fx/Confetti.gd")
const CrowdFX = preload("res://scripts/fx/Crowd.gd")
const PowerUpFX = preload("res://scripts/fx/PowerUp.gd")
const ThrowFX = preload("res://scripts/fx/Throwable.gd")

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
var _crowd: Node2D = null        # torcida do coliseu (reage a gol/defesa)
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
var _debuff_lbl: Label
var _concede_bump := 0          # quanto o alvo sobe a cada gol sofrido (Doc 3)

# — CARTAS DE PARTIDA (Doc 3 §5) —
var _hand: Array = []          # ids das poções na mão
var _next_shot_pot := 1.0      # multiplicador da PRÓXIMA finalização (poção Mira)
var _hand_layer: CanvasLayer = null
var _targeting := ""           # id da carta esperando escolha de jogador ("" = nenhuma)

# --- DOC 4: o verbo (press-your-luck + chute de perícia) ---
const HANDS_TOTAL := 12        # posses de ataque por partida (Doc 4 §6) — mais mãos = menos variância
const BASE_PRESSAO := 0.05     # pressão sobe por segundo (base) — mais tempo p/ decidir
const K_PRESSAO := 0.16        # ganho extra por desarme do adversário
const LIMIAR_BOTE := 0.45      # acima disso, botes do adversário escalam
const TACKLE_CD := 3.2         # cooldown do carrinho manual (Doc 4 §2.4)
const TACKLE_REACH := 90.0     # de quão longe o carrinho alcança o portador
var _tackle_cd := 0.0
var pro_mode := true           # true = jogador decide quando chutar e mira (Doc 4 §3.2)
var _pressao := 0.0            # 0..1, NÃO exibido como número (vinheta/pulso)
var _hand_banked := false      # a mão atual já foi bancada (chute saiu)? evita bust duplo
var _shot_mult := 1.0          # mult capturado no chute (p/ o bônus de gol por cima)
var _shot_pending_super := false
var _human_shot := false       # o chute em voo é de perícia do jogador (GK resolve por geometria)
var _shot_live := false        # há um CHUTE a caminho do gol — só o goleiro resolve (sem interceptação solta)
var _pass_safe := false        # passe pra trás/lado: protegido (só o seu time recebe — Doc do usuário)
var _hands_left := HANDS_TOTAL
var _shots_taken := 0          # telemetria de balanceamento
var _busts := 0
var _goals_home := 0

# Contadores no PROCESSO (não usar await create_timer: ele dispararia na partida já
# destruída ao trocar de tela → crash). Aqui param sozinhos quando o nó é liberado.
var _kickoff_t := -1.0
var _kickoff_team := ""
var _climax_music := false     # a trilha já virou clímax? (1x por partida)

# — POWER-UPS no gramado (💣⚡🧲👟) — quem encostar ativa pro seu time —
var _powerup: Node2D = null
var _powerup_t := 0.0          # tempo até o próximo spawn
var _magnet := {"home": 0.0, "away": 0.0}       # 🧲 controle ampliado (timer)
var _shot_boost := {"home": 1.0, "away": 1.0}   # 👟 mult do PRÓXIMO chute
var _finish_after_t := -1.0
var _endmatch_t := -1.0
var _endmatch_won := false
var _aiming := false           # mira ativa (árvore pausada)
var _bust_anim := false        # animação de "PERDEU!" rodando (não sobrescrever o medidor)
var _skill: Node2D = null      # overlay do chute de perícia
var _passer: Node2D = null     # overlay da mira de passe (360º)
var _hand_meter: Label = null  # readout chips×mult perto da bola
var _vignette: Control = null
var _pass_btn: Button = null
var _chutar_btn: Button = null
var _tackle_btn: Button = null
var _auto_btn: Button = null
var _hands_lbl: Label = null

func goal_x(team: String) -> float:
	# o gol que o time ATACA
	return FIELD.end.x if team == "home" else FIELD.position.x

func own_goal_x(team: String) -> float:
	return FIELD.position.x if team == "home" else FIELD.end.x

func _ready() -> void:
	# estádio-coliseu (arte procedural). Overscan de 40px cobre o shake da câmera.
	var bgt: Texture2D = UI.tex("res://assets/stadium/stadium_bg.png")
	if bgt != null:
		var bg := Sprite2D.new()
		bg.texture = bgt
		bg.centered = false
		bg.position = Vector2(-40, -40)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(bg)
	else:
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

	# torcida de animais + mascote (uma fera de fora dos dois elencos)
	_crowd = CrowdFX.new()
	_crowd.mascot_id = _pick_mascot()
	add_child(_crowd)

	_score = ScoreEngineLib.new()
	_score.jokers = GameState.player_jokers()
	_score.apply_debuff(GameState.debuff_cfg())     # desvantagem do inimigo (blind)
	_score.passe_scores = GameState.passes_score()  # passe só pontua com a relíquia Maestro
	_target = GameState.target()
	_concede_bump = GameState.concede_bump()
	_hands_left = HANDS_TOTAL
	# começa no AUTO (piloto automático) — o jogador liga o Pro pelo botão se quiser.
	pro_mode = false
	# mão = consumíveis comprados na loja (até o nº de slots da capitã)
	_hand = GameState.consumables.slice(0, GameState.hand_size())

	_build_hud()
	_build_hand()
	_kickoff("home")

	# clima de estádio: faixa de partida (alterna A/B), murmúrio e apito inicial
	Sfx.music_match()
	Sfx.ambience_start()
	Sfx.play("whistle")
	_powerup_t = randf_range(9.0, 15.0)

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
		# capitã do jogador: nunca é nocauteada (não "cai" em campo)
		if team == "home" and i < GameState.titulares.size():
			p.is_captain = GameState.titulares[i] == GameState.capita
			p.beast_id = GameState.titulares[i]     # liga o sprite animado (se a fera tiver)
		elif team == "away":
			var eids: Array = GameState.current_node.get("enemy", {}).get("squad_ids", [])
			if i < eids.size(): p.beast_id = str(eids[i])
		p.home_pos = Vector2(s[1], s[2])
		p.global_position = p.home_pos
		add_child(p)
		p.stats = profile.duplicate()
		p.max_speed *= profile.get("spd", 1.0)
		arr.append(p)

## Mascote da torcida: uma fera com spritesheet que NÃO esteja em campo.
func _pick_mascot() -> String:
	var used: Array = GameState.titulares.duplicate()
	used.append_array(GameState.current_node.get("enemy", {}).get("squad_ids", []))
	var cands: Array = []
	for id in GameState.POOL:
		if used.has(id): continue
		if ResourceLoader.exists("res://assets/beasts/anim/%s_sheet.png" % id):
			cands.append(id)
	return String(cands.pick_random()) if not cands.is_empty() else ""

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
	_shot_live = false
	_pass_safe = false
	_steal_cd = 0.0
	_stuck_t = 0.0
	_stuck_ref = ball.global_position
	ball.ball_time_scale = 1.0

# ==========================================================================
#  LOOP
# ==========================================================================
func _physics_process(delta: float) -> void:
	# fim da partida agendado (avisa o roteador) — roda mesmo com over=true
	if _endmatch_t >= 0.0:
		_endmatch_t -= delta
		if _endmatch_t <= 0.0:
			_endmatch_t = -1.0
			match_over.emit(_endmatch_won)
		return
	if over: return
	# reinício pós-gol e fecho por fim-de-mãos (no processo, não em timers órfãos)
	if _kickoff_t >= 0.0:
		_kickoff_t -= delta
		if _kickoff_t <= 0.0:
			_kickoff_t = -1.0
			_kickoff(_kickoff_team)
	if _finish_after_t >= 0.0:
		_finish_after_t -= delta
		if _finish_after_t <= 0.0:
			_finish_after_t = -1.0
			_finish_by_target(_score != null and _score.total >= _target)
			return
	_goal_cd = maxf(0.0, _goal_cd - delta)
	_shot_cd = maxf(0.0, _shot_cd - delta)
	_pass_t = maxf(0.0, _pass_t - delta)
	_cutin_cd = maxf(0.0, _cutin_cd - delta)
	# reta final (pouco tempo OU última mão): a música vira o tema de clímax
	if not _climax_music and not over and (clock <= 14.0 or _hands_left <= 1):
		_climax_music = true
		Sfx.music_climax()
	_tackle_cd = maxf(0.0, _tackle_cd - delta)
	if _pass_t <= 0.0: _pass_to = null
	if _goal_cd <= 0.0:
		clock = maxf(0.0, clock - delta)
		if clock <= 0.0 and not over:
			# fim do tempo → venceu se bateu a pontuação-alvo (Doc 3)
			_finish_by_target(_score != null and _score.total >= _target)

	_update_possession(delta)
	_pressure_step(delta)         # Doc 4 §2.1: a marcação aperta enquanto você segura a bola
	_auto_tackle_step()           # modo Auto: carrinho automático na defesa
	_powerup_step(delta)          # power-ups no gramado (💣⚡🧲👟)
	_combat_step(delta)           # (desativado) dano ambiente
	_super_shot_hits()            # super-chute atropela adversários no caminho
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
		_shot_live = false
		_pass_safe = false
	if _shot_live and _in_flight:
		pass    # Doc 4: CHUTE a caminho do gol — ninguém "recebe" no meio; só o goleiro resolve
	elif _in_flight and _pass_safe:
		# passe pra trás/lado PROTEGIDO e PRECISO: o recebedor mirado pega (raio generoso,
		# sem trava de velocidade — ele corre pra bola e domina). Só o seu time recebe.
		var rcv: Player = _pass_to if (_pass_to != null and is_instance_valid(_pass_to) and not _pass_to.ko) else _closest_home_to_ball()
		if rcv != null and rcv.global_position.distance_to(ball.global_position) < CONTROL_R + 26.0:
			_set_carrier(rcv)
	elif _in_flight:
		# recepção: alguém alcança a bola já desacelerada (passe/sobra)
		if spd < 470.0:
			var p := _closest_any()
			if p != null and p.global_position.distance_to(ball.global_position) < _ctrl_r(p.team) + 5.0:
				_set_carrier(p)
	elif carrier == null:
		var p := _closest_any()
		if p != null and p.global_position.distance_to(ball.global_position) < _ctrl_r(p.team) and spd < 230.0:
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
		# ROUBO deliberado: um adversário coladinho rola uma chance (não instantâneo).
		# Doc 4: na posse do jogador, a PRESSÃO escala o roubo (cedo seguro, tarde perigoso).
		var opp := _closest_opp_to(carrier)
		if opp != null and opp.global_position.distance_to(carrier.global_position) < 28.0:
			var des: float = opp.stats.get("des", 1.0)
			var ctrl: float = carrier.stats.get("ctrl", 1.0)
			var press_mult := (0.35 + _pressao * 1.4) if carrier.team == "home" else 1.0
			var mag_mult := 1.7 if _magnet.get(opp.team, 0.0) > 0.0 else 1.0   # 🧲 rouba mais
			if randf() < 0.07 * clampf(des / maxf(0.4, ctrl), 0.4, 2.4) * press_mult * mag_mult:
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
	_pass_safe = false
	_shot_live = false
	_steal_cd = maxf(_steal_cd, 0.7)   # graça ao receber: controla a bola antes de poder ser roubado
	_score_owner(p.team)

# ==========================================================================
#  PONTUAÇÃO BALATRO (Doc 3 §3) — posse do jogador = "mão"
# ==========================================================================
## Doc 4 §2.3 — troca de dono da posse:
##  • home ganha a bola → começa a "mão" (reseta pressão; chips/mult zerados).
##  • home perde a bola SEM ter chutado → BUST: zera a mão (banca nada). Doi.
##  • se já chutou (mão bancada no chute), a perda é só a resolução do lance.
func _score_owner(side: String) -> void:
	if _score == null: return
	if side == "home" and not _home_has_poss:
		_home_has_poss = true
		_pressao = 0.0
		_hand_banked = false
		_score.start_possession()
	elif side != "home" and _home_has_poss:
		_home_has_poss = false
		if not _hand_banked:
			_bust()

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

# ==========================================================================
#  DOC 4 — O VERBO: chutar (banca) · bust (zera) · contagem de mãos
# ==========================================================================
## BUST: perdeu a bola sem chutar → a mão vira pó. Consome uma posse. Tem que doer.
func _bust() -> void:
	_busts += 1
	_score.reset_hand()
	_bust_fx()
	_spend_hand()
	if _crowd != null: _crowd.ooh()          # a torcida lamenta o bust
	Sfx.play("crowd_ooh", 0.7)

## Chute do JOGADOR (Pro) ou do piloto (Casual): BANCA a mão inteira na hora.
## A bola sai pra `aim` com `power01` (0..1). Gol depois soma bônus por cima.
func _home_shoot(aim: Vector2, power01: float, is_super: bool, by_human: bool) -> void:
	if carrier == null or carrier.team != "home": return
	_shots_taken += 1
	var shooter := carrier
	shooter.play_action("kick")
	Sfx.play("kick")
	if _score: _score.action("finalizacao")         # o chute em si conta chips + jokers (matador)
	_shot_mult = _score.effective_mult()
	var gained: int = _score.finalizar_jogada()    # banca chips×mult AGORA (deu gol ou não)
	if gained > 0: _score_pop(gained)
	_hand_banked = true
	_shot_pending_super = is_super
	_human_shot = by_human and not is_super     # super usa o caminho perfurante/cinemático
	_spend_hand()
	if is_super:
		_fire_super_shot(shooter, "home")          # bomba + cut-in (usa o caminho do super)
		return
	var fin: float = shooter.stats.get("fin", 1.0)
	# FORÇA (atributo de chute = fin): o piso já é um chute de verdade (rápido demais
	# pra perseguir); a força do arraste e o fin somam por cima. Fica no patamar do
	# automático ou acima — sem aquela sensação de "chute mole".
	var pot := lerpf(900.0, 1500.0, clampf(power01, 0.0, 1.0)) + fin * 200.0
	pot *= _next_shot_pot; _next_shot_pot = 1.0     # poção Mira Certeira
	pot *= float(_shot_boost["home"]); _shot_boost["home"] = 1.0   # 👟 chuteira de ouro
	# PRECISÃO (fin): finalização alta = menos ruído na direção (mira mais fiel)
	var noise := (1.5 - clampf(fin, 0.5, 1.5)) * (8.0 if by_human else 48.0)
	var tgt := aim + Vector2(0, randf_range(-noise, noise))
	ball.kick(tgt - shooter.global_position, pot, randf_range(-0.5, 0.5) * (1.3 - fin), 0.0)
	_in_flight = true; carrier = null; _save_rolled = false; _shot_live = true
	_enter_climax()

## Gasta uma posse de ataque; acabando as mãos, encerra pela pontuação-alvo.
func _spend_hand() -> void:
	_hands_left = maxi(0, _hands_left - 1)
	if _hands_left <= 0 and not over:
		# deixa o lance em voo resolver (gol/defesa) antes de fechar
		_finish_after_flight()

func _finish_after_flight() -> void:
	_finish_after_t = 2.4        # contado no _physics_process (sem timer órfão)

## Pede o chute de perícia: pausa, monta o overlay de mira com o tell do goleiro.
func _begin_skillshot() -> void:
	if _aiming or carrier == null or carrier.team != "home" or _in_flight: return
	_aiming = true
	var shooter := carrier
	var is_super: bool = _super_ready["home"] and _super_kind("home") == "shot"
	var gk := _team_gk("away")
	var gx := goal_x("home")
	# o goleiro "se compromete" com um lado (o tell que o jogador lê e evita)
	var tell_y: float = (GOAL_TOP + GOAL_BOT) * 0.5
	if gk != null:
		var bias: float = signf(shooter.global_position.y - MID.y)   # tende ao lado do atacante
		if bias == 0.0: bias = (1.0 if randf() < 0.5 else -1.0)
		tell_y = clampf(MID.y + bias * randf_range(28.0, 62.0), GOAL_TOP + 14.0, GOAL_BOT - 14.0)
		gk.set_meta("dive_y", tell_y)
	var fin: float = shooter.stats.get("fin", 1.0)
	var forgive := lerpf(6.0, 22.0, clampf((fin - 0.6) / 0.9, 0.0, 1.0))   # Doc 4 §3
	_skill = SkillShotLib.new()
	add_child(_skill)
	_skill.setup(ball.global_position, gx, GOAL_TOP, GOAL_BOT,
		Vector2(gx, tell_y), UI.AWAY, forgive, is_super)
	_skill.aimed.connect(_on_skill_aimed)
	get_tree().paused = true

func _on_skill_aimed(aim_world: Vector2, power01: float) -> void:
	get_tree().paused = false
	if _skill != null:
		_skill.queue_free(); _skill = null
	_aiming = false
	_home_shoot(aim_world, power01, _super_ready["home"] and _super_kind("home") == "shot", true)

## Pede a mira de PASSE (360º): pausa, destaca os companheiros, espera o clique.
func _begin_passaim() -> void:
	if _aiming or carrier == null or carrier.team != "home" or _in_flight: return
	_aiming = true
	var passer := carrier
	var mate_pos: Array = []
	for p in home:
		if p == passer or p.ko: continue        # qualquer companheiro (inclui goleiro)
		mate_pos.append(p.global_position)
	_passer = PassAimLib.new()
	add_child(_passer)
	_passer.setup(ball.global_position, mate_pos, FIELD)
	_passer.passed.connect(_on_passed)
	_passer.cancelled.connect(_on_pass_cancelled)
	get_tree().paused = true

func _on_passed(aim_world: Vector2) -> void:
	get_tree().paused = false
	if _passer != null:
		_passer.queue_free(); _passer = null
	_aiming = false
	_manual_pass(aim_world)

func _on_pass_cancelled() -> void:
	get_tree().paused = false
	if _passer != null:
		_passer.queue_free(); _passer = null
	_aiming = false

## Feedback de BUST (Doc 4 §5): a mão estilhaça/acinzenta — a lição "devia ter chutado".
func _bust_fx() -> void:
	_shake = maxf(_shake, 7.0)
	if _hand_meter != null:
		_bust_anim = true
		_hand_meter.visible = true
		_hand_meter.text = "PERDEU!"
		_hand_meter.add_theme_color_override("font_color", Color("ff5a4a"))
		_hand_meter.pivot_offset = _hand_meter.size / 2.0
		var tw := create_tween()
		tw.tween_property(_hand_meter, "scale", Vector2(1.5, 1.5), 0.12)
		tw.tween_property(_hand_meter, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func(): _bust_anim = false; _hand_meter.visible = false)

## Doc 4 §2.1 — a pressão sobe enquanto o jogador segura a bola (∝ desarme do
## marcador mais próximo). NÃO é exibida como número; vira vinheta/pulso (§4.3).
func _pressure_step(delta: float) -> void:
	if not (_home_has_poss and carrier != null and carrier.team == "home" and not _in_flight):
		return
	var opp := _closest_opp_to(carrier)
	var des: float = opp.stats.get("des", 1.0) if opp != null else 0.6
	var antes := _pressao
	_pressao = minf(1.0, _pressao + delta * (BASE_PRESSAO + des * K_PRESSAO))
	if antes < 0.78 and _pressao >= 0.78:
		Sfx.play("crowd_uuh", 0.75)          # "uuuh" crescente: o perigo chegou

# ==========================================================================
#  POWER-UPS NO GRAMADO (juice aprovado: 💣 bomba · ⚡ raio · 🧲 ímã · 👟 ouro)
# ==========================================================================
func _powerup_step(delta: float) -> void:
	_magnet["home"] = maxf(0.0, _magnet["home"] - delta)
	_magnet["away"] = maxf(0.0, _magnet["away"] - delta)
	if _powerup == null or not is_instance_valid(_powerup):
		_powerup = null
		_powerup_t -= delta
		if _powerup_t <= 0.0:
			_spawn_powerup()
		return
	for p in all:
		if p.ko: continue
		if p.global_position.distance_to(_powerup.global_position) < 30.0:
			_grab_powerup(p)
			return

func _spawn_powerup() -> void:
	_powerup_t = randf_range(13.0, 20.0)
	var pos := MID
	for i in 10:                                   # longe da bola e dos gols
		pos = Vector2(randf_range(300.0, 980.0), randf_range(140.0, 560.0))
		if pos.distance_to(ball.global_position) > 170.0: break
	var pu := PowerUpFX.new()
	pu.kind = String(["bomba", "raio", "ima", "ouro"].pick_random())
	pu.position = pos
	add_child(pu)
	_powerup = pu
	Sfx.play("powerup")

func _grab_powerup(p: Player) -> void:
	var kind: String = _powerup.kind
	_powerup.queue_free()
	_powerup = null
	var team := p.team
	var foes: Array = away if team == "home" else home
	var mates: Array = home if team == "home" else away
	match kind:
		"bomba":
			ThrowFX.boom(self, p.global_position, foes, ball,
				func(v: float): _shake = maxf(_shake, v))
		"raio":
			Sfx.play("zap")
			for q in mates:
				if not q.ko: q.apply_speed(1.5, 5.0)
		"ima":
			Sfx.play("magnet")
			_magnet[team] = 6.0
		"ouro":
			Sfx.play("golden")
			_shot_boost[team] = 1.6
	_announce_power(kind, team, p.global_position)

## Aviso flutuante no ponto da coleta (sobe e some).
func _announce_power(kind: String, team: String, pos: Vector2) -> void:
	var names := {"bomba": "💣 KABUM!", "raio": "⚡ VELOCIDADE!",
		"ima": "🧲 ÍMÃ! (6s)", "ouro": "👟 CHUTEIRA DE OURO!"}
	var l := _lbl(pos + Vector2(-60, -40), 20, UI.HOME if team == "home" else UI.AWAY)
	l.text = names.get(kind, kind)
	l.z_index = 200
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 44.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)

## Raio de controle do time (o 🧲 amplia por alguns segundos).
func _ctrl_r(team: String) -> float:
	return CONTROL_R * (1.85 if _magnet.get(team, 0.0) > 0.0 else 1.0)

## Vinheta radial (transparente no centro → vermelha nas bordas). Alpha = pressão.
func _make_vignette() -> Control:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.55, 0.0, 0.0, 0.9))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 1280; gt.height = 720
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	return tr

## Pode chutar agora? (jogador com a bola, modo Pro, sem estar mirando/em voo)
func _can_shoot() -> bool:
	return pro_mode and not _aiming and not _in_flight and not over \
		and carrier != null and carrier.team == "home"

## Pode passar? (mesmo do chute — você precisa estar com a bola)
func _can_pass() -> bool:
	return _can_shoot()

## Pode dar carrinho? (Pro, adversário com a bola, cooldown zerado) — Doc 4 §2.4
func _can_tackle() -> bool:
	return pro_mode and not _aiming and not over and _tackle_cd <= 0.0 \
		and carrier != null and carrier.team == "away"

func _press_pass() -> void:
	if _can_pass(): _begin_passaim()

func _press_shoot() -> void:
	if _can_shoot(): _begin_skillshot()

func _press_tackle() -> void:
	if _can_tackle(): _do_tackle()

func _toggle_auto() -> void:
	pro_mode = not pro_mode
	if _auto_btn != null:
		_auto_btn.text = "Auto: " + ("OFF" if pro_mode else "ON")
	if not pro_mode and _aiming:
		# virou Casual no meio da mira → resolve/cancela o overlay aberto
		if _skill != null:
			_skill.quick_shot()
		elif _passer != null:
			_on_pass_cancelled()

func _unhandled_input(e: InputEvent) -> void:
	if _aiming or not pro_mode: return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE:
				if _can_shoot(): _begin_skillshot()         # CHUTAR
			KEY_A:
				if _can_pass(): _begin_passaim()            # PASSAR (abre mira 360º)
			KEY_S:
				if _can_tackle(): _do_tackle()              # CARRINHO
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		if _can_pass(): _begin_passaim()                    # passe alternativo (botão dir.)

## PASSE manual (Doc 4): mira LIVRE em 360º — a bola vai pra ONDE você apontar.
## O companheiro mais próximo do ponto (menos o que passou) corre pra pegá-la; se
## chegar antes do adversário, "recebe" sozinho (passe bem executado). Lane fechada
## = pode ser interceptada (perde a posse). Passe NÃO pontua (salvo relíquia Maestro).
func _manual_pass(aim: Vector2) -> void:
	if not _can_pass(): return
	# clampa o alvo dentro do campo (mas em qualquer direção a partir do portador)
	var tgt := Vector2(clampf(aim.x, FIELD.position.x, FIELD.end.x), clampf(aim.y, FIELD.position.y, FIELD.end.y))
	var to := tgt - carrier.global_position
	if to.length() < 8.0: return
	var long_ball := to.length() > 280.0
	# passe pra TRÁS/LADO (não claramente pra frente) é PROTEGIDO: só o seu time
	# recebe (o adversário não rouba). Pra frente continua contestável (mais difícil).
	_pass_safe = to.x < 70.0
	# força ∝ distância. Pra trás (protegido) sai mais SUAVE, pra parar perto do alvo
	# e o recebedor dominar com precisão; pra frente sai com mais pace.
	var pw := clampf(to.length() * (1.9 if _pass_safe else 2.4), 240.0, 980.0)
	carrier.play_action("kick")
	Sfx.play("pass")
	ball.kick(to, pw, 0.0, 0.0)
	if _score: _score.action("lancamento" if long_ball else "passe")   # conta p/ jokers; chips só com Maestro
	var mate := _best_mate_to(tgt)        # mais próximo do ALVO (não do portador)
	if mate != null:
		_pass_to = mate; _pass_t = 1.8     # ele corre pro ponto (recepção é "1º a chegar")
		mate.apply_speed(1.45, 1.4)        # arranca pra buscar a bola (passe bem dado conecta)
	_in_flight = true; carrier = null; _save_rolled = false

## CARRINHO manual (Doc 4 §2.4): o seu jogador mais perto do portador desliza.
func _do_tackle() -> void:
	if not _can_tackle(): return
	_execute_tackle(true)

## Carrinho automático (modo Auto/Casual): quando o adversário tem a bola e há um
## defensor no alcance com o cooldown zerado, desliza sozinho. Pedido do usuário.
func _auto_tackle_step() -> void:
	if pro_mode or over or _aiming or _tackle_cd > 0.0: return
	if carrier == null or carrier.team != "away": return
	var t := _closest_home_outfield_to(carrier)
	if t == null or t.global_position.distance_to(carrier.global_position) > TACKLE_REACH: return
	_execute_tackle(false)

## Execução do carrinho: dá dano (salvo goleiro) e SOLTA a bola na direção do
## carrinho (ela "escapa" pra frente — raramente fica no pé de quem deu).
func _execute_tackle(manual: bool) -> void:
	var target := carrier
	if target == null: return
	var tackler := _closest_home_outfield_to(target)
	_tackle_cd = TACKLE_CD
	if tackler == null or tackler.global_position.distance_to(target.global_position) > TACKLE_REACH:
		if manual: _shake = maxf(_shake, 3.0)   # carrinho manual no vazio: gastou o cooldown
		return
	var dir := (target.global_position - tackler.global_position).normalized()
	if dir.length() < 0.1: dir = Vector2(1, 0)
	# avança o atacante pro contato (desliza) e bate
	tackler.play_action("slide")
	Sfx.play("tackle")
	tackler.global_position = tackler.global_position.lerp(target.global_position, 0.6)
	_shake = maxf(_shake, 6.0)
	var des: float = tackler.stats.get("des", 1.0)
	# o goleiro não toma dano (mas ainda perde a bola pro carrinho)
	if target.role != "gk":
		var knocked: bool = target.take_damage(20.0 * clampf(des, 0.6, 1.6))
		if knocked: Sfx.play("ko")
		_hit_burst(target.global_position, knocked)
		if _score:
			_score.action("nocaute" if knocked else "porrada")
	# a bola é "cuspida" na direção do carrinho (pra frente do contato), virando sobra
	ball.global_position = target.global_position
	ball.kick(dir, randf_range(300.0, 460.0), 0.0, 0.0)
	carrier = null
	_in_flight = true
	_save_rolled = false
	_shot_live = false
	_steal_cd = 0.35

## Companheiro mais próximo de um ponto (exceto o passador/KO) — o provável recebedor
## (mesmo conjunto destacado no overlay de passe; inclui o goleiro).
func _best_mate_to(pos: Vector2) -> Player:
	var best: Player = null
	var bd := 1e9
	for p in home:
		if p == carrier or p.ko: continue
		var d := p.global_position.distance_to(pos)
		if d < bd: bd = d; best = p
	return best

## Jogador home de linha (não-goleiro) mais perto de um alvo — o que dá o carrinho.
func _closest_home_outfield_to(target: Player) -> Player:
	var best: Player = null
	var bd := 1e9
	for p in home:
		if p.ko or p.role == "gk": continue
		var d := p.global_position.distance_to(target.global_position)
		if d < bd: bd = d; best = p
	return best

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
	# DESATIVADO (pedido do usuário): nada de dano ambiente por disputar a bola.
	# O dano agora vem SÓ de ações intencionais — super chute (_super_shot_hits) e
	# carrinho manual (_do_tackle). O goleiro é imune a tudo (Player.take_damage).
	return

## Estrela de impacto ("POW") no ponto da pancada — feedback visual do dano/nocaute.
func _hit_burst(pos: Vector2, big: bool) -> void:
	var star := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		var r := (20.0 if i % 2 == 0 else 9.0) * (1.7 if big else 1.0)
		pts.append(Vector2(cos(a), sin(a)) * r)
	star.polygon = pts
	star.color = Color(1, 0.85, 0.3) if big else Color(1, 0.5, 0.2)
	star.global_position = pos
	star.z_index = 50
	star.scale = Vector2(0.3, 0.3)
	add_child(star)
	var tw := create_tween(); tw.set_parallel(true)
	tw.tween_property(star, "scale", Vector2(1.5, 1.5) if big else Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(star, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(star.queue_free)

## Super-chute é um aríete: adversários no caminho da bola perdem HP (Doc 3 / pedido).
func _super_shot_hits() -> void:
	if _super_shot_live == "": return
	for p in all:
		if p.team == _super_shot_live or p.ko or p.hit_cd > 0.0 or p.role == "gk": continue
		if p.global_position.distance_to(ball.global_position) < 17.0:
			p.hit_cd = 0.5
			var knocked: bool = p.take_damage(26.0)
			_hit_burst(p.global_position, knocked)
			_shake = maxf(_shake, 6.0)

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
	# DOC 4 §3 — chute de perícia do jogador: o goleiro resolve por GEOMETRIA (sem %).
	# Acertou longe do mergulho dele = passa; perto = defende. 'def' alarga o alcance.
	if _human_shot:
		var gk := _team_gk("away")
		if gk == null:
			_human_shot = false
		elif ball.global_position.x > goal_x("home") - 70.0:
			_save_rolled = true
			_human_shot = false
			_shot_live = false                   # resolvido na linha: vira lance normal (gol/sobra)
			var dive_y: float = float(gk.get_meta("dive_y", MID.y))
			var dfn: float = gk.stats.get("def", 1.0)
			var reach := lerpf(40.0, 92.0, clampf((dfn - 0.6) / 0.9, 0.0, 1.0))
			var super_save: bool = _super_ready["away"] and _super_kind("away") == "save"
			var saved: bool = super_save or absf(ball.global_position.y - dive_y) < reach
			if saved:
				ball.velocity *= 0.04
				ball.global_position = Vector2(goal_x("home") - 30.0, ball.global_position.y)
				_set_carrier(gk)
				_shot_live = false
				_shake = maxf(_shake, 6.0)
				_add_fury("away", "DEFEND"); _add_fury("home", "MISS")
				if _crowd != null: _crowd.ooh()      # "ôôô" — chute nosso defendido
				Sfx.play("crowd_ooh", 0.8)
				if super_save:
					_super_ready["away"] = false; _fury["away"] = 0.0; _play_cutin("away")
			_super_shot_live = ""
		return                                   # viajando ou já resolvido: pula o save aleatório
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
				_shot_live = false
				_shake = maxf(_shake, 6.0)
				_add_fury(def_side, "DEFEND")
				_add_fury(shooter, "MISS")
				if def_side == "home":
					Sfx.play("crowd_applause", 0.9)  # nosso goleiro pegou!
				else:
					if _crowd != null: _crowd.ooh()
					Sfx.play("crowd_ooh", 0.8)
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

## Jogador HOME mais próximo da bola (p/ recepção protegida de passe pra trás).
func _closest_home_to_ball() -> Player:
	var best: Player = null
	var bd := 1e9
	for p in home:
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

	# CASUAL (piloto faz o press-your-luck): pressão apertou na metade de ataque →
	# BANCA agora (finalização + chance de gol) em vez de arriscar o bust a ZERO.
	# (sem pontos de passe a mão fica ~0, então NÃO exige chips mínimos pra chutar)
	if carrier.team == "home" and not pro_mode \
			and ((_pressao > 0.3 and carrier.global_position.x > MID.x - 60.0) or _pressao > 0.45):
		var is_super_c: bool = _super_ready["home"] and _super_kind("home") == "shot"
		_home_shoot(Vector2(goal_x("home"), MID.y + randf_range(-70.0, 70.0)), randf_range(0.5, 0.9), is_super_c, false)
		return

	# CHUTE (Doc 4 §2.2) — chegou perto do gol:
	if dist < 270.0:
		if carrier.team == "home":
			if pro_mode:
				return                # Pro: o JOGADOR decide quando chutar; segura/dribla
			# Casual/headless: o piloto banca a mão (mira assistida no gol)
			var is_super_h: bool = _super_ready["home"] and _super_kind("home") == "shot"
			var aim_y := goal_c.y + randf_range(-70.0, 70.0)
			_home_shoot(Vector2(goal_x("home"), aim_y), randf_range(0.55, 0.95), is_super_h, false)
			return
		# AWAY: piloto automático (não pontua chips do jogador)
		if _super_ready["away"] and _super_kind("away") == "shot":
			_fire_super_shot(carrier, "away")
			return
		var fin: float = carrier.stats.get("fin", 1.0)
		var noise := (1.6 - clampf(fin, 0.5, 1.5)) * 60.0
		var aim := goal_c + Vector2(0, randf_range(-noise, noise))
		carrier.play_action("kick")
		Sfx.play("kick", 0.7)
		var pot_a: float = (780.0 + fin * 220.0) * float(_shot_boost["away"])
		_shot_boost["away"] = 1.0                    # 👟 (se o away pegou o power-up)
		ball.kick(aim - carrier.global_position, pot_a, randf_range(-1.2, 1.2) * (1.4 - fin), 0.0)
		_in_flight = true; carrier = null; _save_rolled = false; _shot_live = true
		_enter_climax()
		return
	# PASSE conservador: só pra um companheiro CLARAMENTE ABERTO (e de vez em quando).
	# Tocar na marcação era o que mais bustava (interceptação) — agora DRIBLA rumo ao
	# gol por padrão, o que mantém a posse viva e leva à finalização. (vale Casual e Pro)
	var mate := _best_pass(carrier)
	var mate_open: bool = mate != null and _nearest_opp_dist(mate) > 130.0
	if mate_open and randf() < 0.25:
		var lead := mate.velocity * 0.10
		var aim := mate.global_position + lead + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		var to := aim - carrier.global_position
		carrier.play_action("kick")
		Sfx.play("pass", 0.7)
		ball.kick(to, clampf(to.length() * 2.0, 380.0, 820.0), 0.0, 0.0)
		if carrier.team == "home" and _score:
			_score.action("lancamento" if to.length() > 280.0 else "passe")
		_pass_to = mate; _pass_t = 1.4         # o companheiro corre pra receber → conecta
		_in_flight = true; carrier = null; _save_rolled = false
		return
	# senão, segue driblando rumo ao gol (o _carry_ball + o alvo cuidam do resto);
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
		# Doc 4: no chute de perícia, o GK adversário MERGULHA pro canto comprometido
		if _human_shot and _in_flight and p.team == "away" and p.has_meta("dive_y"):
			return Vector2(own_goal_x("away") - 18.0, float(p.get_meta("dive_y")))
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
		_goals_home += 1
		# Doc 4 §2.3: a mão já foi bancada no chute; o GOL soma um BÔNUS por cima.
		var bonus: int = _score.add_goal_bonus(was_super, _shot_mult)
		_score_pop(bonus)
		_home_has_poss = false
		_check_target()
	elif team == "away" and _concede_bump > 0:
		# PUNIÇÃO por sofrer gol: o alvo SOBE (maior que o tempo de reposição). Doc 3.
		_target += _concede_bump
		if _prog != null: _prog.max_value = _target
		_target_bump_fx()
	print("GOL %s! pts=%d/%d (t=%.0f)" % [team, _score.total if _score else 0, _target, clock])
	_add_fury(team, "GOAL")
	_add_fury("away" if team == "home" else "home", "CONCEDE")
	_super_shot_live = ""
	_shot_live = false
	_goal_cd = 2.2
	_shake = 16.0
	ball.ball_time_scale = 1.0
	if team == "home":
		_goal_blast()            # festa: confete + flash + soco de zoom
		Sfx.play("goal")
		Sfx.play("crowd_goal")   # urro da torcida (silencioso se o wav não existir)
		if _crowd != null: _crowd.goal_home()
	else:
		Sfx.play("ko", 0.8)      # gol sofrido: baque, não fanfarra
		Sfx.play("crowd_sad", 0.8)
		if _crowd != null: _crowd.goal_away()
	_popup_goal()
	if over:
		return
	_kickoff_team = "home" if team == "away" else "away"
	_kickoff_t = 2.0             # reinício agendado no _physics_process

## Explosão de GOL (juice aprovado): confete na boca do gol + na bola, flash
## branco curto e um "soco" de zoom. Tweens presos ao Match — morrem com ele.
func _goal_blast() -> void:
	ConfettiFX.burst(self, Vector2(goal_x("home"), MID.y), 90, 520.0)
	ConfettiFX.burst(self, ball.global_position, 40, 380.0)
	var lay := CanvasLayer.new()
	lay.layer = 90
	add_child(lay)
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.45)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(f)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.28)
	tw.tween_callback(lay.queue_free)
	var tz := create_tween()
	tz.tween_property(cam, "zoom", Vector2(1.14, 1.14), 0.10).set_trans(Tween.TRANS_SINE)
	tz.tween_property(cam, "zoom", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)

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
	_endmatch_won = won
	_endmatch_t = 1.8            # avisa o roteador pelo _physics_process (sem timer órfão)
	# apito final + jingle (jingle toca no pool de SFX: sobrevive à troca de faixa)
	Sfx.play("whistle_end")
	Sfx.play("jingle_win" if won else "jingle_lose")
	if _crowd != null:
		if won: _crowd.goal_home()
		else: _crowd.goal_away()

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
	# desvantagem do inimigo (blind) — pra o jogador saber o que dificulta
	var dbf: Dictionary = GameState.debuff()
	if not dbf.is_empty():
		_debuff_lbl = _chip("⚠ %s — %s  ·  sofrer gol: +%d alvo" % [dbf.get("nome", ""), dbf.get("desc", ""), _concede_bump], 11, Color("ff8a6b"))
		_debuff_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		top.add_child(_debuff_lbl)

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

	# DOC 4 §4.3 — VINHETA de pressão (qualitativa, sem número): avermelha as bordas.
	_vignette = _make_vignette()
	layer.add_child(_vignette)

	# DOC 4 §4.1 — POSSES RESTANTES (mãos do blind) ao lado do relógio
	_hands_lbl = _chip("⚽×%d" % _hands_left, 14, UI.GOLD2)
	sub.add_child(_hands_lbl)

	# DOC 4 §4.4 — botões distintos: PASSAR · CHUTAR (com a bola) · CARRINHO (defesa)
	var bottom := HBoxContainer.new()
	layer.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_top = -70; bottom.offset_bottom = -16
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pass_btn = UI.gold_btn("🎯 PASSAR  (A)", 16)
	_pass_btn.pressed.connect(_press_pass)
	bottom.add_child(_pass_btn)
	_chutar_btn = UI.gold_btn("⚽ CHUTAR  (Espaço)", 18)
	_chutar_btn.pressed.connect(_press_shoot)
	bottom.add_child(_chutar_btn)
	_tackle_btn = UI.gold_btn("🦵 CARRINHO  (S)", 16)
	_tackle_btn.pressed.connect(_press_tackle)
	bottom.add_child(_tackle_btn)
	_auto_btn = UI.gold_btn("Auto: " + ("OFF" if pro_mode else "ON"), 12)
	_auto_btn.pressed.connect(_toggle_auto)
	bottom.add_child(_auto_btn)

	# DOC 4 §4.2 — MEDIDOR DA MÃO (chips×mult) flutuando perto da bola (espaço de mundo)
	_hand_meter = _tag("", 18, UI.GOLD2)
	_hand_meter.z_index = 120
	add_child(_hand_meter)

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
	Sfx.ambience_stop()        # o murmúrio do estádio morre com a partida

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
	var pot := 1320.0
	if side == "home":
		pot *= _next_shot_pot; _next_shot_pot = 1.0
	shooter.play_action("kick")
	Sfx.play("kick")
	ball.kick(aim - shooter.global_position, pot, randf_range(-0.7, 0.7), 0.0)
	# (a finalização/banca do home já foi feita em _home_shoot antes de chamar aqui)
	_in_flight = true; carrier = null; _save_rolled = false; _shot_live = true
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

# ==========================================================================
#  CARTAS DE PARTIDA (Doc 3 §5) — poções com auto-pause
# ==========================================================================
func _build_hand() -> void:
	_hand_layer = CanvasLayer.new(); _hand_layer.layer = 40
	_hand_layer.process_mode = Node.PROCESS_MODE_ALWAYS    # clicável mesmo pausado
	add_child(_hand_layer)
	_refresh_hand()

func _refresh_hand() -> void:
	for c in _hand_layer.get_children(): c.queue_free()
	if _hand.is_empty(): return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_layer.add_child(row)
	# faixa de largura total logo ACIMA da borda inferior (cartas centralizadas)
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 0; row.offset_right = 0
	row.offset_top = -96; row.offset_bottom = -14
	for i in _hand.size():
		row.add_child(_card_btn(_hand[i], i))

func _card_btn(id: String, idx: int) -> Button:
	var card: Dictionary = MatchCardsLib.POOL[id]
	var col: Color = UI.GOLD2 if card["tipo"] == "pontuacao" else UI.HOME
	var b := Button.new()
	b.custom_minimum_size = Vector2(184, 78)
	b.add_theme_stylebox_override("normal", UI.sbf(UI.PANEL, col, 2, 9, 8, 6))
	b.add_theme_stylebox_override("hover", UI.sbf(UI.PANEL2, UI.GOLD2, 2, 9, 8, 6))
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", UI.RUNE)
	b.add_theme_color_override("font_hover_color", UI.GOLD2)
	b.text = "%s %s\n%s" % [card["ic"], card["nome"], card["desc"]]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.pressed.connect(_use_card.bind(idx))
	return b

## Clicar numa carta → PAUSA o jogo; se precisa de alvo, escolhe o jogador.
func _use_card(idx: int) -> void:
	if over or idx >= _hand.size() or _targeting != "" or _aiming: return
	var id: String = _hand[idx]
	var card: Dictionary = MatchCardsLib.POOL[id]
	get_tree().paused = true
	if card["alvo"] == "jogador_alvo":
		_targeting = id
		_show_target_picker(idx)
	elif card["alvo"] == "arremesso":
		_targeting = id
		_show_throw_picker(idx)
	else:
		_apply_card(card, null)
		_consume_card(idx)
		get_tree().paused = false

func _show_target_picker(idx: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "picker"
	panel.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL2, UI.GOLD, 2, 10, 14, 12))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -200; panel.offset_right = 200; panel.offset_top = -90; panel.offset_bottom = 90
	_hand_layer.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); panel.add_child(v)
	v.add_child(UI.clbl("Escolha um jogador", 15, UI.GOLD2))
	for p in home:
		var b := UI.gold_btn("%s · HP %d/%d" % [p.role.to_upper(), int(p.hp), int(p.hp_max)], 12)
		b.pressed.connect(_pick_target.bind(p, idx))
		v.add_child(b)

func _pick_target(p: Player, idx: int) -> void:
	if _targeting == "": return
	_apply_card(MatchCardsLib.POOL[_targeting], p)
	_targeting = ""
	_consume_card(idx)
	get_tree().paused = false

## Carta de ARREMESSO: jogo pausado, o jogador clica um PONTO do campo.
## Botão direito cancela (a carta volta pra mão sem gastar).
func _show_throw_picker(idx: int) -> void:
	var catcher := Control.new()
	catcher.name = "picker"
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_hand_layer.add_child(catcher)
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card: Dictionary = MatchCardsLib.POOL[_targeting]
	var hint := UI.clbl("%s  Clique no campo para arremessar  ·  botão direito cancela" % card["ic"], 16, UI.GOLD2)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(640 - 280, 90)
	hint.custom_minimum_size = Vector2(560, 0)
	catcher.add_child(hint)
	catcher.gui_input.connect(_throw_input.bind(catcher, idx))

func _throw_input(ev: InputEvent, catcher: Control, idx: int) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed: return
	var mb := ev as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:      # cancela sem gastar a carta
		_targeting = ""
		catcher.queue_free()
		get_tree().paused = false
		return
	if mb.button_index != MOUSE_BUTTON_LEFT: return
	if _targeting == "": return
	# tela → mundo (a câmera pode estar deslocada/com zoom)
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * mb.position
	world.x = clampf(world.x, FIELD.position.x + 10.0, FIELD.end.x - 10.0)
	world.y = clampf(world.y, FIELD.position.y + 10.0, FIELD.end.y - 10.0)
	var kind: String = MatchCardsLib.POOL[_targeting]["efeito"]["arremesso"]
	_targeting = ""
	catcher.queue_free()
	_consume_card(idx)
	get_tree().paused = false
	ThrowFX.throw(self, kind, Vector2(640.0, 736.0), world, away, ball,
		func(v: float): _shake = maxf(_shake, v))

func _consume_card(idx: int) -> void:
	if idx < _hand.size():
		# consumo permanente: gasta a cópia comprada no inventário da corrida
		GameState.consumables.erase(_hand[idx])
		_hand.remove_at(idx)
	_refresh_hand()

## Aplica o efeito da carta (físico no jogador/time, ou de pontuação Balatro).
func _apply_card(card: Dictionary, who: Player) -> void:
	var e: Dictionary = card["efeito"]
	match card["alvo"]:
		"jogador_alvo":
			if who != null: _apply_physical(e, [who])
		"todos":
			_apply_physical(e, home)
		"time":
			if e.has("next_shot_pot"): _next_shot_pot = float(e["next_shot_pot"])
			if e.has("recarrega_furia"): _fury["home"] = 100.0; _super_ready["home"] = true
		"pontuacao":
			if _score != null:
				_score.queue_next(e)   # buff na PRÓXIMA jogada (sem depender do timing)

func _apply_physical(e: Dictionary, players: Array) -> void:
	for p in players:
		if e.has("cura_hp"): p.heal(float(e["cura_hp"]))
		if e.has("vel_burst"): p.apply_speed(float(e["vel_burst"]), float(e.get("dur_s", 5.0)))

func _lbl(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new(); l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l

## Feedback de punição: o rótulo do alvo pulsa em vermelho quando sobe (sofreu gol).
func _target_bump_fx() -> void:
	if _target_lbl == null: return
	_target_lbl.pivot_offset = _target_lbl.size / 2.0
	_target_lbl.scale = Vector2(1.4, 1.4)
	_target_lbl.add_theme_color_override("font_color", Color("ff5a4a"))
	var tw := create_tween(); tw.set_parallel(true)
	tw.tween_property(_target_lbl, "scale", Vector2(1, 1), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_target_lbl, "theme_override_colors/font_color", UI.GOLD2, 0.6)

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
		UI.count_to(_score_lbl, _score.total, "", "", 0.3)   # ticker (Balatro)
		_prog.value = mini(_score.total, _target)
		_target_lbl.text = "ALVO  %d / %d" % [_score.total, _target]
		_chips_lbl.text = "🎰 %d × %.1f" % [_score.chips, _score.mult]
		if _home_has_poss:
			_chips_lbl.add_theme_color_override("font_color", UI.GOLD2)
		else:
			_chips_lbl.add_theme_color_override("font_color", UI.RUNE2)
	_clock_lbl.text = "%d'" % clampi(int(MATCH_SECONDS - clock), 0, 99)
	if _hands_lbl != null:
		_hands_lbl.text = "⚽×%d" % _hands_left

	# DOC 4 §4.2 — medidor da mão flutua perto da bola enquanto VOCÊ tem a posse
	if _hand_meter != null and not _bust_anim:
		if _home_has_poss and not _in_flight and _score != null:
			_hand_meter.visible = true
			_hand_meter.modulate.a = 1.0
			_hand_meter.text = "%d × %.1f" % [_score.chips, _score.effective_mult()]
			_hand_meter.global_position = ball.global_position + Vector2(-26, -54)
			# pulso quando o cerco aperta (consciência de risco, sem número)
			if _pressao > LIMIAR_BOTE:
				var pz := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02)
				_hand_meter.scale = Vector2(pz, pz)
				_hand_meter.add_theme_color_override("font_color", Color("ff7a4a"))
			else:
				_hand_meter.scale = Vector2.ONE
				_hand_meter.add_theme_color_override("font_color", UI.GOLD2)
		elif _hand_meter.modulate.a > 0.0 and not _home_has_poss:
			_hand_meter.visible = false   # (bust mostra "PERDEU!" via tween próprio)

	# DOC 4 §4.3 — vinheta avermelha conforme a pressão; §4.4 botão liga/desliga
	if _vignette != null:
		var want: float = _pressao if _home_has_poss and not _in_flight else 0.0
		_vignette.modulate.a = lerpf(_vignette.modulate.a, want, 0.15)
	# botões distintos PASSAR · CHUTAR · CARRINHO (habilitam por contexto)
	if _pass_btn != null:
		_pass_btn.disabled = not _can_pass()
		_pass_btn.modulate.a = 1.0 if _can_pass() else 0.4
	if _chutar_btn != null:
		_chutar_btn.disabled = not _can_shoot()
		_chutar_btn.modulate.a = 1.0 if _can_shoot() else 0.4
	if _tackle_btn != null:
		var defending: bool = carrier != null and carrier.team == "away"
		_tackle_btn.text = "🦵 CARRINHO  (S)" if _tackle_cd <= 0.0 else "🦵 CARRINHO  %.0fs" % ceil(_tackle_cd)
		_tackle_btn.disabled = not _can_tackle()
		_tackle_btn.modulate.a = 1.0 if (_can_tackle() or defending) else 0.4
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

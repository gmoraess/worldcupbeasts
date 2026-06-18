extends Node2D
## ETAPA 1 — partida 100% AUTO-SIMULADA (autobattler, GDD §6 opção B sem comandos).
## Os dois times jogam pela IA; o jogador só ASSISTE. Resultado emerge da física
## + stats. Slow-mo/zoom/fogo são só apresentação. Agência fica no build+tática
## (fora da partida). O cérebro do lance mora aqui; o Player só faz steering.
const Ball = preload("res://scripts/Ball.gd")
const Player = preload("res://scripts/Player.gd")

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

var _score_lbl: Label
var _clock_lbl: Label
var _goal_lbl: Label

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

	_build_hud()
	_kickoff("home")

# ==========================================================================
#  TIMES / FORMAÇÃO
# ==========================================================================
func _build_team(team: String) -> void:
	var arr: Array = home if team == "home" else away
	var defend_x := own_goal_x(team)
	var dir := 1.0 if team == "home" else -1.0   # sentido do ataque
	# perfil de stats (fera do jogador / inimigo) — enviesa a física
	var profile: Dictionary = GameState.home_stats() if team == "home" else GameState.away_stats()
	var slots := [
		["gk",  defend_x + 40.0 * dir, MID.y],
		["def", defend_x + 230.0 * dir, MID.y - 110.0],
		["def", defend_x + 230.0 * dir, MID.y + 110.0],
		["mid", MID.x - 110.0 * dir, MID.y],
		["fwd", MID.x + 150.0 * dir, MID.y],
	]
	for s in slots:
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
	_steal_cd = 0.0
	ball.ball_time_scale = 1.0

# ==========================================================================
#  LOOP
# ==========================================================================
func _physics_process(delta: float) -> void:
	if over: return
	_goal_cd = maxf(0.0, _goal_cd - delta)
	_shot_cd = maxf(0.0, _shot_cd - delta)
	_pass_t = maxf(0.0, _pass_t - delta)
	if _pass_t <= 0.0: _pass_to = null
	if _goal_cd <= 0.0:
		if not sudden_death:
			clock = maxf(0.0, clock - delta)
		if clock <= 0.0 and not over:
			if score["home"] != score["away"]:
				_finish_match()
			else:
				sudden_death = true   # empate no tempo → morte súbita (gol de ouro)

	_update_possession(delta)
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
				_steal_cd = 0.7

func _set_carrier(p: Player) -> void:
	carrier = p
	poss = p.team
	_in_flight = false
	_pass_to = null
	_steal_cd = maxf(_steal_cd, 0.3)

## Defesa do goleiro: 1 tentativa por chute. Se a bola passa coladinha no GK,
## ele espalma (chance alta, enviesada por 'def'). Como ele fecha o ângulo,
## chutes centrais são defendidos; chutes precisos/abertos passam.
func _gk_save() -> void:
	if not _in_flight or _save_rolled: return
	for p in all:
		if p.role != "gk": continue
		if p.global_position.distance_to(ball.global_position) < 34.0:
			_save_rolled = true
			var dfn: float = p.stats.get("def", 1.0)
			if randf() < 0.64 * clampf(dfn, 0.5, 1.4):
				ball.velocity *= 0.04
				_set_carrier(p)
				_shake = maxf(_shake, 6.0)
			return

func _closest_any() -> Player:
	var best: Player = null
	var bd := 1e9
	for p in all:
		var d := p.global_position.distance_to(ball.global_position)
		if d < bd: bd = d; best = p
	return best

func _team_gk(team: String) -> Player:
	for p in (home if team == "home" else away):
		if p.role == "gk": return p
	return null

func _closest_opp_to(me: Player) -> Player:
	var best: Player = null
	var bd := 1e9
	for o in all:
		if o.team == me.team: continue
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
		var fin: float = carrier.stats.get("fin", 1.0)
		var noise := (1.6 - clampf(fin, 0.5, 1.5)) * 60.0
		var aim := goal_c + Vector2(0, randf_range(-noise, noise))
		ball.kick(aim - carrier.global_position, 780.0 + fin * 220.0, randf_range(-1.2, 1.2) * (1.4 - fin), 0.0)
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
		_pass_to = mate; _pass_t = 1.4         # o companheiro corre pra receber → conecta
		_in_flight = true; carrier = null; _save_rolled = false
		return
	# senão, segue driblando (o _carry_ball + o alvo rumo ao gol cuidam do resto)

func _best_pass(from: Player) -> Player:
	var gx := goal_x(from.team)
	var best: Player = null
	var bs := -1e9
	for p in all:
		if p.team != from.team or p == from or p.role == "gk": continue
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
		if p.role == "gk": continue
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
	print("GOL %s! %d-%d (t=%.0f)" % [team, score["home"], score["away"], clock])
	_goal_cd = 2.2
	_shake = 16.0
	ball.ball_time_scale = 1.0
	_popup_goal()
	# fim imediato: goleada (5 de diferença) ou gol de ouro na morte súbita
	if absi(score["home"] - score["away"]) >= 5 or sudden_death:
		_finish_match()
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

func _finish_match() -> void:
	if over: return
	over = true
	var home_won: bool = score["home"] >= score["away"]   # ST resolvida não empata
	_goal_lbl.text = "FIM  %d x %d" % [score["home"], score["away"]]
	_goal_lbl.modulate = Color(1, 1, 1, 1)
	await get_tree().create_timer(1.6).timeout
	match_over.emit(home_won)

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
	var layer := CanvasLayer.new(); add_child(layer)
	_score_lbl = _lbl(Vector2(560, 14), 30, Color(1, 1, 1)); layer.add_child(_score_lbl)
	_clock_lbl = _lbl(Vector2(600, 52), 16, Color(1, 0.95, 0.7)); layer.add_child(_clock_lbl)
	_goal_lbl = _lbl(Vector2(430, 150), 60, Color(1, 0.85, 0.3))
	_goal_lbl.text = "G O O O L !"; _goal_lbl.modulate = Color(1, 1, 1, 0)
	layer.add_child(_goal_lbl)

func _lbl(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new(); l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l

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
	_score_lbl.text = "%d   %d" % [score["home"], score["away"]]
	_clock_lbl.text = "%02d:%02d" % [int(clock) / 60, int(clock) % 60]

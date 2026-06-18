extends Node2D
## ETAPA 1 — partida 100% AUTO-SIMULADA (autobattler, GDD §6 opção B sem comandos).
## Os dois times jogam pela IA; o jogador só ASSISTE. Resultado emerge da física
## + stats. Slow-mo/zoom/fogo são só apresentação. Agência fica no build+tática
## (fora da partida). O cérebro do lance mora aqui; o Player só faz steering.
const Ball = preload("res://scripts/Ball.gd")
const Player = preload("res://scripts/Player.gd")

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

var _decide := 0.0
var _dribble := 0.0
var _goal_cd := 0.0
var _shake := 0.0
var _climax := false

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
		arr.append(p)

func _kickoff(team: String) -> void:
	ball.reset_to(MID)
	for p in all:
		p.global_position = p.home_pos
		p.velocity = Vector2.ZERO
	carrier = null
	poss = team
	_climax = false
	ball.ball_time_scale = 1.0

# ==========================================================================
#  LOOP
# ==========================================================================
func _physics_process(delta: float) -> void:
	if over: return
	_goal_cd = maxf(0.0, _goal_cd - delta)
	if _goal_cd <= 0.0:
		clock = maxf(0.0, clock - delta)
		if clock <= 0.0:
			_end_match()

	_update_possession()
	_decide -= delta
	if _decide <= 0.0:
		_decide = randf_range(0.16, 0.30)
		if carrier != null:
			_carrier_decide()
	_dribble -= delta
	_move_players()
	_check_goal()
	_camera_juice(delta)
	if ball.speed() > 240.0:
		_spawn_trail(ball.speed())
	_hud_update()

func _update_possession() -> void:
	var spd := ball.speed()
	# acha o mais perto da bola
	var best: Player = null
	var bd := 1e9
	for p in all:
		var d := p.global_position.distance_to(ball.global_position)
		if d < bd: bd = d; best = p
	if best != null and bd < CONTROL_R and (spd < 280.0 or _goal_cd > 0.0):
		if carrier != best:
			# troca de posse / recepção / bote
			if carrier != null and carrier.team != best.team:
				_shake = maxf(_shake, 3.0)   # carrinho
			carrier = best
			poss = best.team
	elif spd > 320.0:
		carrier = null               # bola no ar/voando: ninguém controla

func _carrier_decide() -> void:
	if carrier == null: return
	var team := carrier.team
	var gx := goal_x(team)
	var goal_c := Vector2(gx, MID.y)
	var dist := carrier.global_position.distance_to(goal_c)
	var pressure := _nearest_opp_dist(carrier)

	# CHUTE: perto do gol e com ângulo → finaliza (IA, sem input)
	if dist < SHOOT_RANGE and pressure < PRESSURE * 2.2:
		var fin: float = carrier.stats.get("fin", 1.0)
		var noise := (1.6 - clampf(fin, 0.5, 1.5)) * 60.0    # menos precisão = mais erro
		var aim := goal_c + Vector2(0, randf_range(-noise, noise))
		var power := 760.0 + fin * 220.0
		var spin := randf_range(-1.2, 1.2) * (1.4 - fin)
		ball.kick(aim - carrier.global_position, power, spin, 0.0)
		carrier = null
		_enter_climax()
		return
	# PASSE: sob pressão → tabela com companheiro à frente e aberto
	if pressure < PRESSURE:
		var mate := _best_pass(carrier)
		if mate != null:
			var to := mate.global_position - carrier.global_position
			ball.kick(to, clampf(to.length() * 2.2, 360.0, 820.0), 0.0, 0.0)
			carrier = null
			return
	# DRIBLE: empurra a bola na direção do gol (toques mais frequentes = mais rápido)
	if _dribble <= 0.0:
		_dribble = 0.18
		var d := (goal_c - carrier.global_position).normalized()
		ball.kick(d, 300.0 + carrier.stats.get("ctrl", 1.0) * 50.0, 0.0, 0.0)

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
	# quem persegue a bola no time SEM posse: o mais perto
	var def_team := "away" if poss == "home" else "home"
	var chaser := _closest_to_ball(def_team)
	for p in all:
		p.target = _target_for(p, chaser)

func _target_for(p: Player, presser: Player) -> Vector2:
	var bx := ball.global_position.x
	var by := ball.global_position.y
	var atk := 1.0 if p.team == "home" else -1.0   # sentido de ataque do time de p
	var minx := FIELD.position.x + 36.0
	var maxx := FIELD.end.x - 36.0

	# GOLEIRO — fecha o ângulo: fica na reta bola↔centro do gol, perto da linha
	if p.role == "gk":
		var gc := Vector2(own_goal_x(p.team), MID.y)
		var d := ball.global_position - gc
		var pos := gc + d.normalized() * clampf(d.length() * 0.18, 22.0, 82.0)
		pos.y = clampf(pos.y, GOAL_TOP + 8.0, GOAL_BOT - 8.0)
		if p.team == "home":
			pos.x = clampf(pos.x, FIELD.position.x + 12, FIELD.position.x + 120)
		else:
			pos.x = clampf(pos.x, FIELD.end.x - 120, FIELD.end.x - 12)
		return pos

	# CARREGADOR — leva a bola rumo ao gol (um passo à frente dela)
	if p == carrier:
		return ball.global_position + Vector2(18.0 * atk, 0.0)

	# raia do jogador, puxando um pouco pra altura da bola (compacta o time)
	var lane := clampf(lerpf(p.home_pos.y, by, 0.28), FIELD.position.y + 30, FIELD.end.y - 30)

	if p.team == poss:
		# ATAQUE sem a bola: fwd corre à frente, mid apoia, def cobre atrás
		var push := 210.0 if p.role == "fwd" else (70.0 if p.role == "mid" else -50.0)
		return Vector2(clampf(bx + push * atk, minx, maxx), lane)
	else:
		# DEFESA sem a bola: presser vai na bola; resto segura linha goal-side
		if p == presser:
			return ball.global_position
		var own_gx := own_goal_x(p.team)
		var line_x := lerpf(bx, own_gx, 0.32)
		return Vector2(clampf(line_x, minx, maxx), lane)

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

func _end_match() -> void:
	over = true
	_goal_lbl.text = "FIM  %d × %d" % [score["home"], score["away"]]
	_goal_lbl.modulate = Color(1, 1, 1, 1)

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

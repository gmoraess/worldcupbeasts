extends Node2D
## Doc 4 — Mira de PASSE (360º). Igual ao chute, PAUSA a partida e mostra a mira;
## a bola pode ir pra QUALQUER direção. Destaca os companheiros (anel), com o mais
## próximo do cursor (o provável recebedor) em dourado. Clique = passa pro ponto.
##
## Uso: Match instancia, chama setup(...), conecta:
##   passed(aim_world: Vector2)   → confirmou o passe
##   cancelled                    → desistiu (botão dir./Esc)
## Roda em PROCESS_MODE_ALWAYS (a árvore fica pausada enquanto mira).

signal passed(aim_world: Vector2)
signal cancelled

var ball_pos := Vector2.ZERO
var mates: Array = []        # Vector2: posições dos companheiros elegíveis
var field := Rect2()

func setup(p_ball: Vector2, p_mates: Array, p_field: Rect2) -> void:
	ball_pos = p_ball
	mates = p_mates
	field = p_field
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_d: float) -> void:
	queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("passed", _aim())
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("cancelled")
	elif e is InputEventScreenTouch and e.pressed:
		emit_signal("passed", _aim())
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_A or e.keycode == KEY_SPACE or e.keycode == KEY_ENTER:
			emit_signal("passed", _aim())
		elif e.keycode == KEY_ESCAPE:
			emit_signal("cancelled")

## Alvo do passe: cursor, preso ao campo (mas livre em 360º a partir da bola).
func _aim() -> Vector2:
	var m := get_global_mouse_position()
	return Vector2(clampf(m.x, field.position.x, field.end.x), clampf(m.y, field.position.y, field.end.y))

func _nearest_mate(to: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 1e9
	for mp: Vector2 in mates:
		var d: float = mp.distance_to(to)
		if d < bd: bd = d; best = mp
	return best

func _draw() -> void:
	var aim := _aim()
	var near := _nearest_mate(aim)
	# linha de passe da bola até o alvo (qualquer direção)
	draw_line(ball_pos, aim, Color(0.5, 0.9, 1.0, 0.55), 2.0)
	# destaque dos companheiros — o mais perto do cursor em dourado (vai receber)
	for mp: Vector2 in mates:
		var is_near: bool = mp == near
		var col := Color(1.0, 0.85, 0.3, 0.95) if is_near else Color(0.5, 0.9, 1.0, 0.7)
		draw_arc(mp, 20.0, 0, TAU, 28, col, 3.0)
		if is_near:
			draw_arc(mp, 26.0, 0, TAU, 28, Color(1.0, 0.85, 0.3, 0.5), 2.0)
	# reticle no ponto de destino
	var rc := Color(0.6, 0.95, 1.0, 0.95)
	draw_arc(aim, 13.0, 0, TAU, 28, rc, 3.0)
	draw_line(aim - Vector2(18, 0), aim + Vector2(18, 0), rc, 1.5)
	draw_line(aim - Vector2(0, 18), aim + Vector2(0, 18), rc, 1.5)

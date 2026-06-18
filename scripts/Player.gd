extends CharacterBody2D
class_name Player
## Jogador com steering (arrive). O cérebro (decisão de passe/chute/bote) mora no
## Match; aqui só se move pra um alvo e dá toques na bola. GDD Etapa 1.

var team := "home"            # "home" ataca pra direita · "away" pra esquerda
var role := "mid"             # gk / def / mid / fwd
var home_pos := Vector2.ZERO  # vaga na formação (campo)
var max_speed := 330.0    # arcade: mais rápido
var accel := 3000.0       # acelera rápido (snappy)
var decel := 4200.0       # FREIA rápido — mata o "deslize no gelo"
var stats := {"fin": 1.0, "ctrl": 1.0, "des": 1.0, "def": 1.0, "sta": 1.0}

var target := Vector2.ZERO    # pra onde mover (o Match seta por frame)
var radius := 13.0

var _sprite: Polygon2D

func _ready() -> void:
	# camadas: jogador = layer 2, colide com paredes (1) e outros jogadores (2);
	# NÃO colide com a bola (layer 4).
	collision_layer = 2
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new(); c.radius = radius
	cs.shape = c
	add_child(cs)
	# disco colorido por time + anel por papel
	var base: Color = Color("3f86ad") if team == "home" else Color("e07a3a")
	if role == "gk": base = base.lightened(0.35)
	_sprite = _disc(radius, base)
	add_child(_sprite)
	var ring := _ring(radius + 3.0, Color(0, 0, 0, 0.5))
	add_child(ring)

func _disc(r: float, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	p.polygon = pts; p.color = col
	return p

func _ring(r: float, col: Color) -> Line2D:
	var l := Line2D.new(); l.width = 2.0; l.default_color = col; l.closed = true
	for i in 18:
		var a := TAU * float(i) / 18.0
		l.add_point(Vector2(cos(a), sin(a)) * r)
	return l

func _physics_process(delta: float) -> void:
	var to := target - global_position
	var dist := to.length()
	var desired := Vector2.ZERO
	if dist > 4.0:
		var sp := max_speed
		if dist < 24.0:
			sp = max_speed * (dist / 24.0)   # arrive: desacelera perto do alvo
		desired = to.normalized() * sp
	# acelera rápido quando ganha velocidade; FREIA mais rápido ainda (anti-gelo)
	var rate := accel if desired.length() >= velocity.length() - 1.0 else decel
	velocity = velocity.move_toward(desired, rate * delta)
	move_and_slide()

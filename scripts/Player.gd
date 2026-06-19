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
var jitter := Vector2.ZERO    # deslocamento próprio (independência de movimento)
var phase := 0.0              # fase pra corridas/oscilações individuais
var follow := 1.0             # o quanto segue o bloco (imperfeito por jogador)

# — COMBATE / HP (Doc 3 §6) — individual por jogador —
var hp_max := 120.0
var hp := 120.0
var ko := false               # nocauteado (fora do campo por alguns segundos)
var ko_t := 0.0
var hit_cd := 0.0             # cooldown entre porradas (anti-abuso)
var _hp_bg: ColorRect
var _hp_fill: ColorRect

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
	jitter = Vector2(randf_range(-22, 22), randf_range(-22, 22))
	phase = randf() * TAU
	follow = randf_range(0.78, 1.16)        # cada um segue o bloco diferente
	max_speed *= randf_range(0.93, 1.08)    # velocidades individuais
	accel *= randf_range(0.9, 1.12)
	_sprite = _disc(radius, base)
	add_child(_sprite)
	var ring := _ring(radius + 3.0, Color(0, 0, 0, 0.5))
	add_child(ring)
	# HP derivado dos stats: resistência ≈ (def+sta)/2 → 80..200 (Doc 3 §6.2)
	var tough: float = (stats.get("def", 1.0) + stats.get("sta", 1.0)) * 0.5
	hp_max = lerpf(80.0, 200.0, clampf((tough - 0.8) / 0.6, 0.0, 1.0))
	hp = hp_max
	_build_hp_bar()

func _build_hp_bar() -> void:
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0, 0, 0, 0.6)
	_hp_bg.size = Vector2(26, 4)
	_hp_bg.position = Vector2(-13, -radius - 11)
	add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.4, 0.9, 0.4)
	_hp_fill.size = Vector2(26, 4)
	_hp_fill.position = _hp_bg.position
	add_child(_hp_fill)

func _refresh_hp_bar() -> void:
	if _hp_fill == null: return
	var frac := clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)
	_hp_fill.size.x = 26.0 * frac
	_hp_fill.color = Color(0.9, 0.3, 0.3) if frac < 0.35 else (Color(0.95, 0.8, 0.3) if frac < 0.7 else Color(0.4, 0.9, 0.4))
	var vis := not ko
	_hp_bg.visible = vis; _hp_fill.visible = vis

## Dano de combate; HP zera → nocaute (fora do campo alguns segundos).
func take_damage(d: float) -> bool:
	if ko: return false
	hp = maxf(0.0, hp - d)
	_refresh_hp_bar()
	if hp <= 0.0:
		_knockout()
		return true
	return false

func _knockout() -> void:
	ko = true
	ko_t = 6.0
	velocity = Vector2.ZERO
	collision_layer = 0; collision_mask = 0     # caído não atrapalha o jogo
	_sprite.modulate = Color(1, 1, 1, 0.25)
	_refresh_hp_bar()

func _revive() -> void:
	ko = false
	hp = hp_max * 0.55
	global_position = home_pos
	collision_layer = 2; collision_mask = 1 | 2
	_sprite.modulate = Color(1, 1, 1, 1)
	_refresh_hp_bar()

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
	hit_cd = maxf(0.0, hit_cd - delta)
	if ko:
		ko_t -= delta
		velocity = Vector2.ZERO
		if ko_t <= 0.0:
			_revive()
		return                      # nocauteado: não se move (desfalque numérico)
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

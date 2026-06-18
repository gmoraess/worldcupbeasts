extends CharacterBody2D
class_name Ball
## Bola com FÍSICA CUSTOM (GDD §5): atrito do gramado, curva (Magnus), quicada,
## altura falsa (eixo z 2D p/ lobs/voleios) e slow-motion próprio (não global).

@export var ground_drag := 1.6     # atrito do gramado (s^-1)
@export var restitution := 0.62    # quão "viva" é a quicada
@export var magnus_k    := 0.9     # força da curva/efeito
@export var spin_decay  := 1.2     # spin perde força com o tempo
@export var gravity     := 1100.0  # gravidade da altura falsa
@export var radius      := 11.0

var spin := 0.0          # + horário / - anti-horário
var height := 0.0        # eixo z falso
var vz := 0.0
var ball_time_scale := 1.0   # 1.0 normal · <1.0 câmera lenta DO chute (local)

var _sprite: Sprite2D
var _shadow: Node2D

signal bounced(strength: float, where: Vector2)

func _ready() -> void:
	# colisão (círculo)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new(); c.radius = radius
	cs.shape = c
	add_child(cs)
	# sombra (elipse escura no chão)
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * radius * 1.15, sin(a) * radius * 0.55))
	sh.polygon = pts
	sh.color = Color(0, 0, 0, 0.40)
	_shadow = sh
	add_child(_shadow)
	# sprite da bola
	_sprite = Sprite2D.new()
	var tex := _load_ball_tex()
	if tex != null:
		_sprite.texture = tex
		_sprite.scale = Vector2.ONE * (radius * 2.0 / float(maxi(1, tex.get_width())))
	add_child(_sprite)

func _load_ball_tex() -> Texture2D:
	var p := "res://assets/ball.png"
	if ResourceLoader.exists(p):
		var r: Resource = load(p)
		if r is Texture2D: return r
	return null

## Chuta: define velocidade na direção, com potência, efeito e elevação.
func kick(dir: Vector2, power: float, new_spin: float = 0.0, lift: float = 0.0) -> void:
	velocity = dir.normalized() * power
	spin = new_spin
	if lift > 0.0:
		vz = lift
		height = max(height, 0.01)

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	spin = 0.0; height = 0.0; vz = 0.0
	ball_time_scale = 1.0

func speed() -> float:
	return velocity.length()

func _physics_process(delta: float) -> void:
	var dt := delta * ball_time_scale
	if dt <= 0.0: return
	var spd := velocity.length()

	# 1) Magnus — acelera lateral à direção; "previsível quando importa":
	#    reduz a curva quando a bola está lenta (finalização justa).
	if spd > 4.0:
		var mk := magnus_k * clampf(spd / 350.0, 0.25, 1.0)
		velocity += velocity.orthogonal().normalized() * spin * spd * mk * dt
		spin = move_toward(spin, 0.0, spin_decay * dt)

	# 2) atrito do gramado (só no chão)
	if height <= 0.01:
		velocity = velocity.move_toward(Vector2.ZERO, ground_drag * spd * dt)

	# 3) altura falsa (z) p/ lobs e voleios
	if height > 0.0 or vz != 0.0:
		vz -= gravity * dt
		height = max(0.0, height + vz * dt)
		if height <= 0.0 and vz < 0.0:
			vz = -vz * restitution * 0.6
			if absf(vz) < 40.0:
				vz = 0.0; height = 0.0

	# 4) move e resolve colisão (bordas, traves, jogadores)
	var col := move_and_collide(velocity * dt)
	if col:
		var before := velocity.length()
		velocity = velocity.bounce(col.get_normal()) * restitution
		# a quicada dá um pouco de efeito
		spin += randf_range(-0.4, 0.4)
		bounced.emit(before, global_position)

	# 5) apresentação: sombra no chão, sprite sobe com a altura, gira
	if _shadow:
		_shadow.position = Vector2(0, 0)
		_shadow.scale = Vector2(1.0 - height * 0.0006, 1.0 - height * 0.0010)
		_shadow.modulate.a = clampf(0.42 - height * 0.0004, 0.08, 0.42)
	if _sprite:
		_sprite.position = Vector2(0, -height)
		_sprite.rotation += spd * 0.00018 * (delta * 60.0)

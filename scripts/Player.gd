extends CharacterBody2D
class_name Player
## Jogador com steering (arrive). O cérebro (decisão de passe/chute/bote) mora no
## Match; aqui só se move pra um alvo e dá toques na bola. GDD Etapa 1.

var team := "home"            # "home" ataca pra direita · "away" pra esquerda
var role := "mid"             # gk / def / mid / fwd
var is_captain := false       # capitã: nunca é nocauteada (não "cai" em campo)
var beast_id := ""            # id da fera (POOL) — liga o sprite animado se houver
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
var vel_mult := 1.0           # buff de velocidade (poções §5)
var vel_mult_t := 0.0
var _hp_bg: ColorRect
var _hp_fill: ColorRect

## Buff de velocidade temporário (poção Adrenalina/Fôlego Coletivo).
func apply_speed(mult: float, dur: float) -> void:
	vel_mult = mult
	vel_mult_t = dur

func heal(amount: float) -> void:
	hp = minf(hp_max, hp + amount)
	_refresh_hp_bar()

var _sprite: Polygon2D

# — SPRITE ANIMADO (pixel art) — feras com spritesheet trocam o disco por animação —
const ANIM_FRAME := 32
# nome: [linha na sheet, nº de frames, fps, loop]
const ANIM_DEFS := {
	"idle":  [0, 4, 6.0, true],
	"run":   [1, 6, 12.0, true],
	"kick":  [2, 4, 14.0, false],
	"slide": [3, 4, 12.0, false],
}
var _anim: AnimatedSprite2D
var _face := 1.0              # última direção horizontal (evita flip nervoso)
var _action_t := 0.0          # tempo restante de uma ação one-shot (kick/slide)

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
	if not _has_sheet():                        # fera animada dispensa o anel
		var ring := _ring(radius + 3.0, Color(0, 0, 0, 0.5))
		add_child(ring)
	# HP derivado dos stats: resistência ≈ (def+sta)/2 → 80..200 (Doc 3 §6.2)
	var tough: float = (stats.get("def", 1.0) + stats.get("sta", 1.0)) * 0.5
	hp_max = lerpf(80.0, 200.0, clampf((tough - 0.8) / 0.6, 0.0, 1.0))
	hp = hp_max
	_build_hp_bar()
	_setup_anim()

func _sheet_path() -> String:
	return "res://assets/beasts/anim/%s_sheet.png" % beast_id

func _has_sheet() -> bool:
	return beast_id != "" and ResourceLoader.exists(_sheet_path())

## Monta o AnimatedSprite2D a partir da spritesheet da fera (se existir).
## O disco some (vira sombra); a barra de HP continua (o anel é dispensado).
func _setup_anim() -> void:
	if not _has_sheet(): return
	var tex: Texture2D = load(_sheet_path())
	if tex == null: return
	var frames := SpriteFrames.new()
	for anim_name in ANIM_DEFS:
		var d: Array = ANIM_DEFS[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, d[2])
		frames.set_animation_loop(anim_name, d[3])
		for i in int(d[1]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * ANIM_FRAME, int(d[0]) * ANIM_FRAME, ANIM_FRAME, ANIM_FRAME)
			frames.add_frame(anim_name, at)
	if frames.has_animation("default"): frames.remove_animation("default")
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = frames
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nítida
	var s := 1.5                                # presença em campo por tier
	if beast_id.begins_with("boss_"): s = 1.85
	elif beast_id.begins_with("elite_"): s = 1.7
	_anim.scale = Vector2(s, s)
	# pés do sprite (y≈28.5 no frame de 32) alinhados à base do disco (radius)
	_anim.offset = Vector2(0, radius / s - 12.5)
	_anim.z_index = 5
	_anim.play("idle")
	add_child(_anim)
	# o disco vira uma "sombra" achatada sob a fera
	_sprite.polygon = _squash(_sprite.polygon, 0.38)
	_sprite.position.y = radius - 3.0
	_sprite.color = Color(0, 0, 0, 0.30)

func _squash(pts: PackedVector2Array, fy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts: out.append(Vector2(v.x, v.y * fy))
	return out

## Nó que recebe os efeitos visuais (clarão de dano, fade de KO).
func _visual() -> CanvasItem:
	return _anim if _anim != null else _sprite

## Ação one-shot ("kick" no chute/passe, "slide" no carrinho) — volta pra idle/run.
func play_action(anim_name: String) -> void:
	if _anim == null or not ANIM_DEFS.has(anim_name): return
	var d: Array = ANIM_DEFS[anim_name]
	_action_t = float(d[1]) / float(d[2])
	_anim.play(anim_name)

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
	# o GOLEIRO nunca toma dano de nenhuma mecânica (super chute / carrinho / combate)
	if role == "gk":
		return false
	# a capitã aguenta o tranco: nunca é nocauteada (mantém um fio de HP)
	if is_captain:
		hp = maxf(hp_max * 0.12, hp - d)
		_refresh_hp_bar()
		_visual().modulate = Color(2.2, 2.2, 2.2, 1.0)
		var twc := create_tween()
		twc.tween_property(_visual(), "modulate", Color(1, 1, 1, 1), 0.18)
		return false
	hp = maxf(0.0, hp - d)
	_refresh_hp_bar()
	if hp <= 0.0:
		_knockout()
		return true
	# clarão branco rápido — feedback de que levou a pancada
	_visual().modulate = Color(2.2, 2.2, 2.2, 1.0)
	var tw := create_tween()
	tw.tween_property(_visual(), "modulate", Color(1, 1, 1, 1), 0.18)
	return false

func _knockout() -> void:
	ko = true
	ko_t = 6.0
	velocity = Vector2.ZERO
	collision_layer = 0; collision_mask = 0     # caído não atrapalha o jogo
	_visual().modulate = Color(1, 1, 1, 0.25)
	if _anim != null: _anim.pause()
	_refresh_hp_bar()

func _revive() -> void:
	ko = false
	hp = hp_max * 0.55
	global_position = home_pos
	collision_layer = 2; collision_mask = 1 | 2
	_visual().modulate = Color(1, 1, 1, 1)
	if _anim != null: _anim.play("idle")
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
	if vel_mult_t > 0.0:
		vel_mult_t -= delta
		if vel_mult_t <= 0.0: vel_mult = 1.0
	var to := target - global_position
	var dist := to.length()
	var desired := Vector2.ZERO
	if dist > 4.0:
		var sp := max_speed * vel_mult
		if dist < 24.0:
			sp = max_speed * vel_mult * (dist / 24.0)   # arrive: desacelera perto do alvo
		desired = to.normalized() * sp
	# acelera rápido quando ganha velocidade; FREIA mais rápido ainda (anti-gelo)
	var rate := accel if desired.length() >= velocity.length() - 1.0 else decel
	velocity = velocity.move_toward(desired, rate * delta)
	move_and_slide()
	_update_anim(delta)

## Estado da animação: ação one-shot tem prioridade; senão run/idle pela velocidade.
func _update_anim(delta: float) -> void:
	if _anim == null: return
	if absf(velocity.x) > 24.0:
		_face = signf(velocity.x)
	_anim.flip_h = _face < 0.0
	if _action_t > 0.0:
		_action_t -= delta
		return                      # deixa kick/slide terminar
	var sp := velocity.length()
	if sp > 40.0:
		if _anim.animation != "run": _anim.play("run")
		_anim.speed_scale = clampf(sp / 300.0, 0.65, 1.6)
	else:
		if _anim.animation != "idle": _anim.play("idle")
		_anim.speed_scale = 1.0

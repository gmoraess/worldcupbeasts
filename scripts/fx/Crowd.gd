extends Node2D
## Torcida do coliseu: centenas de fãs-animais desenhados em _draw (1 nó só),
## sentados nos anéis da arquibancada do stadium_bg. Sem timers — tudo contado
## no _process (seguro ao trocar de tela, mesma lição do Confetti/Match).
##
## GEOMETRIA ESPELHADA de tools/gen_stadium.py (mudou lá, muda aqui):
##   campo Rect2(90, 70, 1100, 580) · fileiras a 16/28/40 px da borda.
##
## API (o Match chama):
##   goal_home()  → pulos + braços pra cima + chuva de confete + mascote comemora
##   goal_away()  → torcida murcha (cinza, cabisbaixa)
##   ooh()        → reação curta (chute pra fora / defesa)

const ConfettiFX = preload("res://scripts/fx/Confetti.gd")

const TEX_PATH := "res://assets/stadium/fans_sheet.png"
const FW := 12.0
const FH := 12.0
const N_VAR := 10
const FIELD := Rect2(90, 70, 1100, 580)
const ROW_OFF: Array[float] = [16.0, 28.0, 40.0]
const SEAT_STEP := 16.0
const SC := 1.25                 # escala dos fãs (12px → ~15px no mundo)
const OLA_DUR := 5.0             # segundos pra onda dar a volta
const OLA_W := 0.055             # largura da janela da ola (fração do perímetro)

var _tex: Texture2D
var _seats: Array = []           # {p: Vector2, v: int, ph: float, t: float}
var _t := 0.0
var _mood := ""                  # "" | "cheer" | "sad" | "ooh"
var _mood_t := 0.0
var _ola_next := 14.0
var _ola_t := -1.0               # posição da onda (0..1); -1 = sem onda
var _mascot: AnimatedSprite2D
var _mascot_base := Vector2(980.0, 664.0)
var _mascot_action_t := 0.0

# — OFERTA DE ITEM ("ache o Wally"): UM torcedor oferece o power-up — o
#   jogador precisa ACHAR e clicar nele. 3 apresentações:
#   "cadeira"  → torcedor levanta uma CADEIRA (meme de armar confusão);
#                exclusiva do item cadeira-explosiva 🪑
#   "corredor" → torcedor invasor corre pela faixa FORA do campo segurando
#                o ícone do item
#   "placa"    → torcedor na arquibancada ergue uma plaquinha com o símbolo
const OFFER_LIFE := 14.0         # a oferta expira (o torcedor desiste)
const ITEM_ICONS := {"bomba": "💣", "raio": "⚡", "ima": "🧲", "ouro": "👟", "cadeira": "🪑"}
var _offer_kind := ""            # "" = sem oferta ativa
var _offer_anim := ""            # "cadeira" | "corredor" | "placa"
var _offer_seat := -1            # índice do fã ofertante (cadeira/placa)
var _offer_pos := Vector2.ZERO   # posição atual (o corredor se move)
var _offer_t := 0.0
var _offer_dir := 1.0            # direção do corredor
var _offer_side := "baixo"       # faixa do corredor: "baixo" | "esq" | "dir"
var _offer_var := 0              # espécie do torcedor corredor (variedade)
var _offer_icon: Label = null    # emoji do item (corredor/placa)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2                   # sobre o bg do estádio, sob confete/cut-ins
	_tex = load(TEX_PATH) if ResourceLoader.exists(TEX_PATH) else null
	if _tex == null: return
	_build_seats()
	_build_mascot()

func _build_seats() -> void:
	var cx := FIELD.get_center()
	# arquibancadas de cima e de baixo: largura inteira (inclui cantos)
	for off_i in [2, 1, 0]:       # fileira do fundo primeiro (a da frente cobre)
		var off: float = ROW_OFF[off_i]
		var x := FIELD.position.x - 34.0 + fmod(off_i * 7.0, SEAT_STEP)
		while x <= FIELD.end.x + 34.0:
			_add_seat(Vector2(x, FIELD.position.y - off), cx)
			_add_seat(Vector2(x, FIELD.end.y + off + 4.0), cx)
			x += SEAT_STEP
	# laterais: só entre as arquibancadas de cima/baixo
	for off_i in [2, 1, 0]:
		var off: float = ROW_OFF[off_i]
		var y := FIELD.position.y + 14.0 + fmod(off_i * 7.0, SEAT_STEP)
		while y <= FIELD.end.y - 6.0:
			_add_seat(Vector2(FIELD.position.x - off, y), cx)
			_add_seat(Vector2(FIELD.end.x + off, y), cx)
			y += SEAT_STEP

func _add_seat(pos: Vector2, cx: Vector2) -> void:
	pos.x += randf_range(-3.0, 3.0)
	pos.y += randf_range(-1.5, 1.5)
	_seats.append({
		"p": pos,
		"v": randi() % N_VAR,
		"ph": randf(),
		# posição angular no perímetro (0..1) — a ola varre isso
		"t": fposmod(pos.angle_to_point(cx) + PI, TAU) / TAU,
	})

## Mascote: BONECÃO próprio da torcida (assets/stadium/mascot_sheet.png,
## gerado em tools/gen_stadium.py) — de propósito com visual diferente das
## feras de campo (reusar spritesheet de jogador confundia: parecia um
## "jogador bugado na torcida").
func _build_mascot() -> void:
	var p := "res://assets/stadium/mascot_sheet.png"
	if not ResourceLoader.exists(p): return
	var tex: Texture2D = load(p)
	if tex == null: return
	var frames := SpriteFrames.new()
	frames.add_animation("dance")
	frames.set_animation_speed("dance", 6.0)
	frames.set_animation_loop("dance", true)
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 24, 0, 24, 24)
		frames.add_frame("dance", at)
	frames.add_animation("throw")           # arremesso: braços pro alto 2x
	frames.set_animation_speed("throw", 12.0)
	frames.set_animation_loop("throw", false)
	for i in [2, 0, 2]:
		var at2 := AtlasTexture.new()
		at2.atlas = tex
		at2.region = Rect2(i * 24, 0, 24, 24)
		frames.add_frame("throw", at2)
	if frames.has_animation("default"): frames.remove_animation("default")
	_mascot = AnimatedSprite2D.new()
	_mascot.sprite_frames = frames
	_mascot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mascot.scale = Vector2(1.7, 1.7)
	_mascot.position = _mascot_base
	_mascot.z_index = 6
	_mascot.play("dance")
	add_child(_mascot)

# ==========================================================================
#  REAÇÕES (o Match chama)
# ==========================================================================
func goal_home() -> void:
	_mood = "cheer"
	_mood_t = 3.4
	_ola_t = -1.0
	# chuva de confete caindo das arquibancadas
	for i in 6:
		var x := randf_range(FIELD.position.x + 60.0, FIELD.end.x - 60.0)
		var y := FIELD.position.y - 26.0 if i % 2 == 0 else FIELD.end.y + 26.0
		ConfettiFX.burst(self, Vector2(x, y), 26, 210.0)
	if _mascot != null:
		_mascot.play("throw")
		_mascot_action_t = 3.0 / 12.0

func goal_away() -> void:
	_mood = "sad"
	_mood_t = 2.8

func ooh() -> void:
	if _mood == "":
		_mood = "ooh"
		_mood_t = 0.9

## De onde o mascote arremessa os itens do inventário (fallback: banco).
func mascot_pos() -> Vector2:
	return _mascot.position if _mascot != null else Vector2(640.0, 700.0)

## Animação de arremesso do mascote (o "kick" vira o lançamento).
func mascot_throw() -> void:
	if _mascot == null: return
	_mascot.play("throw")
	_mascot_action_t = 3.0 / 12.0

# ==========================================================================
#  OFERTA DE ITEM (o Match agenda; o jogador caça o ofertante e clica)
# ==========================================================================
func offer_start(kind: String) -> void:
	_offer_kind = kind
	_offer_t = 0.0
	_offer_anim = "cadeira" if kind == "cadeira" else String(["corredor", "placa"].pick_random())
	if _seats.is_empty() and _offer_anim != "corredor":
		_offer_anim = "corredor"      # sem assentos (textura ausente): só o corredor
	if _offer_anim == "corredor":
		_offer_seat = -1
		_offer_var = randi() % N_VAR
		_offer_dir = 1.0 if randf() < 0.5 else -1.0
		# só embaixo/esquerda/direita: no topo o PLACAR tapava o torcedor
		_offer_side = String(["baixo", "esq", "dir"].pick_random())
		match _offer_side:
			"baixo":
				_offer_pos = Vector2(randf_range(FIELD.position.x + 80.0, FIELD.end.x - 80.0), FIELD.end.y + 12.0)
			"esq":
				_offer_pos = Vector2(FIELD.position.x - 8.0, randf_range(FIELD.position.y + 70.0, FIELD.end.y - 70.0))
			"dir":
				_offer_pos = Vector2(FIELD.end.x + 8.0, randf_range(FIELD.position.y + 70.0, FIELD.end.y - 70.0))
	else:
		# SÓ a arquibancada de BAIXO: em cima ficava fora da tela/atrás do
		# placar, e nas laterais o usuário reportou que era difícil demais ver.
		var cands: Array = []
		for i in _seats.size():
			if (_seats[i]["p"] as Vector2).y > FIELD.end.y:
				cands.append(i)
		_offer_seat = int(cands.pick_random()) if not cands.is_empty() else 0
		_offer_pos = _seats[_offer_seat]["p"] as Vector2
	if _offer_anim != "cadeira":
		_offer_icon = Label.new()
		_offer_icon.text = String(ITEM_ICONS.get(kind, "❓"))
		_offer_icon.add_theme_font_size_override("font_size", 13)
		_offer_icon.z_index = 20
		add_child(_offer_icon)
	# a DEIXA sonora: cada tipo de ofertante tem seu alerta próprio
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null: sfx.play("offer_" + _offer_anim)

func offer_active() -> bool:
	return _offer_kind != ""

## O clique (mundo) acertou o ofertante? (checagem sem consumir)
func offer_hit(world: Vector2) -> bool:
	return _offer_kind != "" and world.distance_to(_offer_pos + Vector2(0.0, -12.0)) < 30.0

## Consome a oferta e devolve o kind (o Match guarda no inventário).
func offer_take() -> String:
	var k := _offer_kind
	_offer_end()
	return k

func _offer_end() -> void:
	_offer_kind = ""
	_offer_seat = -1
	if _offer_icon != null:
		_offer_icon.queue_free()
		_offer_icon = null

# ==========================================================================
#  LOOP
# ==========================================================================
func _process(delta: float) -> void:
	if _tex == null: return
	_t += delta
	if _mood_t > 0.0:
		_mood_t -= delta
		if _mood_t <= 0.0: _mood = ""
	# ola mexicana: varre o perímetro de tempos em tempos (só com a torcida calma)
	if _ola_t >= 0.0:
		_ola_t += delta / OLA_DUR
		if _ola_t > 1.0 + OLA_W * 4.0:
			_ola_t = -1.0
			_ola_next = randf_range(16.0, 30.0)
	elif _mood == "":
		_ola_next -= delta
		if _ola_next <= 0.0:
			_ola_t = 0.0
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null: sfx.play("crowd_ola", 0.6)
	_update_offer(delta)
	_update_mascot(delta)
	queue_redraw()

func _update_offer(delta: float) -> void:
	if _offer_kind == "": return
	_offer_t += delta
	if _offer_t >= OFFER_LIFE:      # ninguém pegou: o torcedor desiste
		_offer_end()
		return
	if _offer_anim == "corredor":
		# invasor corre pela faixa fora-de-campo, indo e voltando
		if _offer_side == "baixo":
			_offer_pos.x += _offer_dir * 105.0 * delta
			if _offer_pos.x > FIELD.end.x - 30.0: _offer_dir = -1.0
			elif _offer_pos.x < FIELD.position.x + 30.0: _offer_dir = 1.0
		else:                        # laterais: corre na vertical
			_offer_pos.y += _offer_dir * 95.0 * delta
			if _offer_pos.y > FIELD.end.y - 24.0: _offer_dir = -1.0
			elif _offer_pos.y < FIELD.position.y + 44.0: _offer_dir = 1.0
	if _offer_icon != null:
		if _offer_anim == "placa":
			_offer_icon.position = _offer_pos + Vector2(-8.0, -56.0)
		else:                        # corredor: ícone na mão, acima da cabeça
			_offer_icon.position = _offer_pos + Vector2(-8.0, -36.0 - absf(sin(_t * 9.0)) * 3.0)

func _update_mascot(delta: float) -> void:
	if _mascot == null: return
	var hop := 4.0
	var speed := 3.6
	if _mood == "cheer":
		hop = 9.0; speed = 8.0
	_mascot.position.y = _mascot_base.y - absf(sin(_t * speed)) * hop
	_mascot.flip_h = sin(_t * 1.7) > 0.0
	if _mascot_action_t > 0.0:
		_mascot_action_t -= delta
		if _mascot_action_t <= 0.0 and _mascot.animation != "dance":
			_mascot.play("dance")

func _draw() -> void:
	if _tex == null: return
	var size := Vector2(FW * SC, FH * SC)
	for si in _seats.size():
		var s: Dictionary = _seats[si]
		var ph: float = s["ph"]
		var frame := 0
		var dy := 0.0
		var tint := Color.WHITE
		if si == _offer_seat and _offer_kind != "":
			# o OFERTANTE: de pé, braços pra cima, pulando mais que os vizinhos
			frame = 2
			dy = -3.0 - 2.5 * absf(sin(_t * 6.0))
			var p0: Vector2 = s["p"]
			draw_texture_rect_region(_tex,
				Rect2(Vector2(p0.x - size.x * 0.5, p0.y - size.y + dy), size),
				Rect2(2 * FW, s["v"] * FH, FW, FH))
			_draw_offer(p0, dy)
			continue
		match _mood:
			"cheer":
				var w := sin(_t * 9.0 + ph * TAU)
				frame = 2 if w > -0.35 else 1
				dy = -absf(w) * 4.0
			"sad":
				frame = 0
				dy = 2.0
				tint = Color(0.62, 0.62, 0.68)
			"ooh":
				frame = 1 if ph > 0.35 else 0
				dy = -1.0
			_:
				# vida ociosa: bob suave + fã aleatório se empolgando sozinho
				var b := sin(_t * 2.4 + ph * TAU)
				frame = 1 if b > 0.74 else 0
				if fmod(_t * 0.23 + ph * 7.0, 1.0) < 0.035: frame = 2
				# ola: janela da onda levanta todo mundo em sequência
				if _ola_t >= 0.0:
					var d: float = absf(fposmod(s["t"] - _ola_t, 1.0))
					d = minf(d, 1.0 - d)
					var e := clampf(1.0 - d / OLA_W, 0.0, 1.0)
					if e > 0.2:
						frame = 2
						dy = -e * 5.0
		var p: Vector2 = s["p"]
		draw_texture_rect_region(_tex,
			Rect2(Vector2(p.x - size.x * 0.5, p.y - size.y + dy), size),
			Rect2(frame * FW, s["v"] * FH, FW, FH), tint)
	# corredor invasor: não é um assento — corre pela faixa fora-de-campo
	if _offer_kind != "" and _offer_anim == "corredor":
		var rf := 1 if int(_t * 10.0) % 2 == 0 else 0
		var hop := absf(sin(_t * 10.0)) * 2.5
		var face := 1.0
		if _offer_side == "baixo":
			face = 1.0 if _offer_dir >= 0.0 else -1.0
		elif _offer_side == "dir":
			face = -1.0                # nas laterais, encara o campo
		draw_set_transform(_offer_pos, 0.0, Vector2(face, 1.0))
		draw_texture_rect_region(_tex,
			Rect2(Vector2(-size.x * 0.5, -size.y - hop), size),
			Rect2(rf * FW, _offer_var * FH, FW, FH))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Extras do ofertante sentado: plaquinha erguida OU cadeira (meme) balançando.
func _draw_offer(p: Vector2, dy: float) -> void:
	if _offer_anim == "placa":
		# cabo + plaquinha branca (o ícone-Label do item fica por cima dela)
		draw_line(p + Vector2(0.0, -16.0 + dy), p + Vector2(0.0, -40.0), Color(0.55, 0.42, 0.28), 2.0)
		var board := Rect2(p + Vector2(-13.0, -58.0), Vector2(26.0, 20.0))
		draw_rect(board, Color(0.93, 0.91, 0.86))
		draw_rect(board, Color(0.25, 0.18, 0.10), false, 1.5)
	elif _offer_anim == "cadeira":
		# a CADEIRA erguida balançando (meme de "pega a cadeira!") — explosiva
		var cp := p + Vector2(0.0, -30.0 + dy)
		draw_set_transform(cp, sin(_t * 5.0) * 0.35, Vector2.ONE)
		var wood := Color(0.55, 0.36, 0.18)
		var wood2 := Color(0.42, 0.27, 0.13)
		draw_rect(Rect2(-8.0, -3.0, 16.0, 4.0), wood)          # assento
		draw_rect(Rect2(5.0, -14.0, 3.0, 11.0), wood2)         # encosto
		draw_rect(Rect2(-7.0, 1.0, 3.0, 7.0), wood2)           # perna
		draw_rect(Rect2(4.0, 1.0, 3.0, 7.0), wood2)            # perna
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# pulso vermelho: aviso de que ESSA cadeira explode
		var a := 0.35 + 0.3 * sin(_t * 8.0)
		draw_arc(cp, 14.0, 0, TAU, 20, Color(1.0, 0.3, 0.2, a), 1.5)

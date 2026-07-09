## Helpers de UI (cores + widgets) — todos static. Estilo gótico/dourado.
class_name UI

const STONE  := Color("17110b")
const PANEL  := Color("241a10")
const PANEL2 := Color("120c07")
const BRONZE := Color("7a5a26")
const GOLD   := Color("d8b25a")
const GOLD2  := Color("f3da93")
const RUNE   := Color("e7d8b4")
const RUNE2  := Color("a8916a")
const HOME   := Color("3f86ad")
const AWAY   := Color("e07a3a")

static func sbf(bg: Color, border: Color, bw: int = 2, radius: int = 10, ph: int = 10, pv: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = ph; s.content_margin_right = ph
	s.content_margin_top = pv;  s.content_margin_bottom = pv
	return s

static func lbl(txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

static func clbl(txt: String, sz: int, col: Color) -> Label:
	var l := lbl(txt, sz, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func framed(bg: Color = PANEL, border: Color = BRONZE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbf(bg, border, 2, 11, 12, 10))
	return p

static func gold_btn(txt: String, fsize: int = 15) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color("1a1206"))
	b.add_theme_color_override("font_hover_color", Color("1a1206"))
	b.add_theme_color_override("font_pressed_color", Color("1a1206"))
	b.add_theme_stylebox_override("normal",  sbf(GOLD, Color("8a6a2a"), 1, 9, 14, 10))
	b.add_theme_stylebox_override("hover",   sbf(GOLD2, Color("8a6a2a"), 1, 9, 14, 10))
	b.add_theme_stylebox_override("pressed", sbf(Color("a87f2e"), Color("8a6a2a"), 1, 9, 14, 10))
	b.add_theme_stylebox_override("disabled", sbf(Color("4a3a20"), Color("3c2b12"), 1, 9, 14, 10))
	hoverify(b)
	return b

# ==========================================================================
#  JUICE (estilo Balatro) — pop elástico, hover e contador animado
# ==========================================================================

## Pop elástico: o nó nasce miúdo/transparente e ASSENTA com bounce.
## Chamar depois do add_child. 'delay' escalona cartas em sequência.
static func pop_in(n: Control, delay: float = 0.0) -> void:
	n.scale = Vector2(0.6, 0.6)
	n.modulate.a = 0.0
	var tw := n.create_tween()
	tw.tween_interval(maxf(delay, 0.02))          # espera o layout medir o nó
	tw.tween_callback(func(): n.pivot_offset = n.size / 2.0)
	tw.tween_property(n, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Mini-pop no hover (cresce ~6% e volta). Idempotente por botão.
static func hoverify(b: Control, amount: float = 1.06) -> void:
	if b.has_meta("hoverified"): return
	b.set_meta("hoverified", true)
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size / 2.0
		_retween(b, Vector2.ONE * amount, 0.08))
	b.mouse_exited.connect(func(): _retween(b, Vector2.ONE, 0.10))

static func _retween(b: Control, to: Vector2, dur: float) -> void:
	if b.has_meta("hover_tw"):
		var old: Variant = b.get_meta("hover_tw")
		if old is Tween and (old as Tween).is_valid(): (old as Tween).kill()
	var tw := b.create_tween()
	tw.tween_property(b, "scale", to, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("hover_tw", tw)

## Contador animado (ticker do Balatro): o texto ROLA do valor anterior até 'to'.
## Seguro pra chamar todo frame: só inicia um tween quando o valor MUDA.
static func count_to(l: Label, to: int, prefix: String = "", suffix: String = "", dur: float = 0.4) -> void:
	if not l.has_meta("cnt"):                     # primeira chamada: mostra seco
		l.set_meta("cnt", to)
		l.text = prefix + str(to) + suffix
		return
	var from: int = int(l.get_meta("cnt"))
	if from == to: return                         # sem mudança: não mexe no texto
	l.set_meta("cnt", to)
	if l.has_meta("cnt_tw"):
		var old: Variant = l.get_meta("cnt_tw")
		if old is Tween and (old as Tween).is_valid(): (old as Tween).kill()
	var tw := l.create_tween()
	tw.tween_method(func(v: float): l.text = prefix + str(int(round(v))) + suffix,
		float(from), float(to), dur)
	l.set_meta("cnt_tw", tw)

## Pílula de Tier (I..V) colorida pela cor do tier (paleta de raridade).
## Ex.: "TIER III" em azul. Usada na loja e na preparação.
static func tier_badge(tier: int, label_prefix: String = "TIER ") -> Control:
	var t := clampi(tier, 1, 5)
	var c: Color = GameState.tier_color(t)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbf(c.darkened(0.55), c, 1, 7, 7, 2))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := lbl(label_prefix + GameState.TIER_NAMES[t - 1], 10, c.lightened(0.4))
	p.add_child(l)
	return p

static func bg_rect(col: Color = STONE) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r

## Carrega uma textura se existir; senão null (seguro p/ arte ainda ausente).
static func tex(path: String) -> Texture2D:
	return load(path) if path != "" and ResourceLoader.exists(path) else null

## Ícone visual: TextureRect com a arte (escala mantendo proporção) OU, se faltar
## o PNG, um Label com o emoji de fallback. px = tamanho-alvo do ícone.
static func icon(path: String, px: Vector2, fallback: String, col: Color = Color.WHITE) -> Control:
	var t := tex(path)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = px
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var l := clbl(fallback, int(px.y * 0.55), col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

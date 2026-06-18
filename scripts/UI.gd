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
	return b

static func bg_rect(col: Color = STONE) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r

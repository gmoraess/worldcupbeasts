extends Control
## Loja pós-partida (estilo Brotato). Abre ao fim de toda partida vencida.
## • 5 ofertas comuns RERROLLÁVEIS (figura de besta / gear / pacote)
## • 3 slots de RELÍQUIA fixos (fora do reroll)
## • 2 slots de CONSUMÍVEL fixos (fora do reroll)
## • Reroll por ouro (só mexe nas 5 comuns). Faixa de elenco mostra o Tier atual.
signal shop_done
signal organize_team

const ConfettiFX = preload("res://scripts/fx/Confetti.gd")

var _gold_shown := -1           # último ouro exibido (o ticker rola a partir dele)

var main_offers: Array = []     # 5 itens {"kind","id"}; "sold" = já comprado
var relic_off: Array = []       # 3 ids de relíquia
var cons_off: Array = []        # 2 ids de consumível
var reroll_count := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_offers = GameState.shop_main_offers(5)
	relic_off = GameState.relic_offers(3)
	cons_off = GameState.consumable_offers(2)
	_build()

func reroll_cost() -> int:
	return 5 + reroll_count * 3

# ==========================================================================
#  LAYOUT
# ==========================================================================
func _build() -> void:
	for c in get_children(): c.queue_free()
	add_child(UI.bg_rect())
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root.add_theme_constant_override(s, 18)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)

	col.add_child(_topbar())

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(main)

	# — esquerda: mercado (5 comuns) + faixa de elenco —
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.1
	main.add_child(left)
	left.add_child(UI.lbl("⚒  MERCADO", 15, UI.GOLD2))
	var shelf := HBoxContainer.new()
	shelf.add_theme_constant_override("separation", 10)
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(shelf)
	for i in main_offers.size():
		var mc := _main_card(i)
		shelf.add_child(mc)
		UI.pop_in(mc, i * 0.05)          # cartas assentam em cascata (Balatro)
	left.add_child(UI.lbl("ELENCO  ·  cópias sobem o Tier (I→V)", 11, UI.RUNE2))
	left.add_child(_roster_strip())

	# — direita: relíquias (3) + consumíveis (2) —
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	main.add_child(right)
	right.add_child(UI.lbl("🛡  RELÍQUIAS  ·  fora do reroll", 13, UI.GOLD2))
	for i in relic_off.size():
		right.add_child(_relic_card(i))
	if relic_off.is_empty():
		right.add_child(UI.lbl("Estoque esgotado.", 11, UI.RUNE2))
	right.add_child(UI.lbl("🧪  CONSUMÍVEIS  ·  fora do reroll", 13, UI.GOLD2))
	for i in cons_off.size():
		right.add_child(_cons_card(i))

	# — rodapé: organizar time · subir a torre —
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	var org := UI.gold_btn("⚙ Organizar Time", 14)
	org.pressed.connect(func(): organize_team.emit())
	foot.add_child(org)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var leave := UI.gold_btn("Subir a Torre →", 15)
	leave.pressed.connect(func(): shop_done.emit())
	foot.add_child(leave)

func _topbar() -> Control:
	var pnl := UI.framed(UI.PANEL2, UI.GOLD)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	pnl.add_child(h)
	h.add_child(UI.clbl("🛒  LOJA", 24, UI.GOLD2))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	if _gold_shown < 0: _gold_shown = GameState.gold
	var gl := UI.clbl("🪙 %d" % _gold_shown, 22, UI.GOLD2)
	gl.set_meta("cnt", _gold_shown)      # rola do valor anterior (a tela rebuilda)
	UI.count_to(gl, GameState.gold, "🪙 ", "", 0.35)
	_gold_shown = GameState.gold
	h.add_child(gl)
	var rc := reroll_cost()
	var rr := UI.gold_btn("⟳ Reroll  🪙 %d" % rc, 14)
	rr.disabled = GameState.gold < rc
	rr.pressed.connect(func():
		if GameState.gold >= rc:
			GameState.gold -= rc
			reroll_count += 1
			main_offers = GameState.shop_main_offers(5)
			_build())
	h.add_child(rr)
	return pnl

# ==========================================================================
#  CARTAS DO MERCADO (5 comuns rerolláveis)
# ==========================================================================
func _main_card(idx: int) -> Control:
	var item: Dictionary = main_offers[idx]
	var kind: String = item.get("kind", "sold")
	var box := UI.framed()
	box.custom_minimum_size = Vector2(146, 206)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind == "sold":
		box.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL2, Color("2a1f12"), 1, 11, 10, 8))
		var cc := CenterContainer.new(); cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cc.add_child(UI.clbl("VENDIDO", 12, UI.RUNE2))
		box.add_child(cc)
		return box

	var accent: Color
	var icon_node: Control
	var title: String
	var sub: String
	var badge: Control = null
	match kind:
		"figure":
			var id: String = item["id"]
			var data: Dictionary = GameState.POOL[id]
			var owned: bool = GameState.copies.has(id)
			var t: int = GameState.tier_of(id) if owned else 1
			accent = GameState.tier_color(t) if owned else GameState.rarity_color(id)
			icon_node = UI.icon("res://assets/beasts/%s.png" % id, Vector2(96, 100), data["crest"])
			title = data["nome"]
			if owned and t < GameState.TIER_MAX:
				sub = "Tier %s → %s" % [GameState.TIER_NAMES[t - 1], GameState.TIER_NAMES[t]]
				badge = UI.tier_badge(t)
			elif owned:
				sub = "Tier MÁX"
				badge = UI.tier_badge(t)
			else:
				sub = "NOVA · %s" % data["papel"]
		"gear":
			var g: Dictionary = GameState.GEAR[item["id"]]
			accent = Color("5fc96b")
			icon_node = UI.clbl(g["ic"], 52, Color.WHITE)
			title = g["nome"]; sub = g["desc"]
		_:  # pack
			accent = UI.GOLD2
			icon_node = UI.clbl("🎴", 56, UI.GOLD2)
			title = "Pacote"; sub = "Escolha 1 de 3"

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	box.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL, accent, 2, 11, 8, 8))
	var icc := CenterContainer.new(); icc.add_child(icon_node)
	v.add_child(icc)
	v.add_child(UI.clbl(title, 13, UI.GOLD2))
	var subl := UI.clbl(sub, 10, accent.lightened(0.2))
	subl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(subl)
	if badge != null:
		var bcc := CenterContainer.new(); bcc.add_child(badge); v.add_child(bcc)
	var cost: int = GameState.shop_cost(kind, item.get("id", ""))
	var b := UI.gold_btn("🪙 %d" % cost, 13)
	b.disabled = GameState.gold < cost
	b.pressed.connect(func(): _buy_main(idx))
	v.add_child(b)
	return box

func _buy_main(idx: int) -> void:
	var item: Dictionary = main_offers[idx]
	var kind: String = item.get("kind", "")
	var cost: int = GameState.shop_cost(kind, item.get("id", ""))
	if GameState.gold < cost: return
	match kind:
		"figure": GameState.buy_figure(item["id"])
		"gear":   GameState.buy_gear(item["id"])
		"pack":
			var picks: Array = GameState.buy_pack()
			main_offers[idx] = {"kind": "sold"}
			_show_pack_reveal(picks)
			return
	main_offers[idx] = {"kind": "sold"}
	_build()

# ==========================================================================
#  RELÍQUIAS (3 fixas) e CONSUMÍVEIS (2 fixos)
# ==========================================================================
func _relic_card(idx: int) -> Control:
	var id: String = relic_off[idx]
	if id == "":
		return _sold_row()
	var r: Dictionary = GameState.RELICS[id]
	var cost: int = GameState.shop_cost("relic")
	return _buy_row(r["ic"], r["name"], r["desc"], UI.BRONZE, cost,
		func(): GameState.buy_relic(id); relic_off[idx] = ""; _build())

func _cons_card(idx: int) -> Control:
	var id: String = cons_off[idx]
	if id == "":
		return _sold_row()
	var c: Dictionary = GameState.cons_info(id)
	var accent: Color = UI.GOLD2 if c.get("tipo", "") == "pontuacao" else UI.HOME
	var cost: int = GameState.shop_cost("cons")
	return _buy_row(c["ic"], c["nome"], c["desc"], accent, cost,
		func(): GameState.buy_consumable(id); cons_off[idx] = ""; _build())

func _buy_row(ic: String, nome: String, desc: String, accent: Color, cost: int, on_buy: Callable) -> Control:
	var box := UI.framed()
	box.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL, accent, 2, 10, 10, 7))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	box.add_child(h)
	var icc := CenterContainer.new(); icc.custom_minimum_size = Vector2(38, 0)
	icc.add_child(UI.clbl(ic, 24, Color.WHITE))
	h.add_child(icc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.lbl(nome, 13, UI.GOLD2))
	var d := UI.lbl(desc, 10, UI.RUNE2)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	h.add_child(v)
	var b := UI.gold_btn("🪙 %d" % cost, 12)
	b.disabled = GameState.gold < cost
	b.pressed.connect(on_buy)
	h.add_child(b)
	return box

func _sold_row() -> Control:
	var box := UI.framed(UI.PANEL2, Color("2a1f12"))
	box.add_child(UI.clbl("vendido", 11, UI.RUNE2))
	return box

# ==========================================================================
#  FAIXA DE ELENCO (feedback de Tier)
# ==========================================================================
func _roster_strip() -> Control:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 92)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	sc.add_child(h)
	var seen: Array = []
	for id in (GameState.titulares + GameState.reservas):
		if seen.has(id): continue
		seen.append(id)
		h.add_child(_roster_chip(id))
	return sc

func _roster_chip(id: String) -> Control:
	var t: int = GameState.tier_of(id)
	var box := UI.framed(UI.PANEL, GameState.tier_color(t))
	box.add_theme_stylebox_override("panel", UI.sbf(UI.PANEL, GameState.tier_color(t), 2, 9, 6, 5))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	box.add_child(v)
	var icc := CenterContainer.new()
	icc.add_child(UI.icon("res://assets/beasts/%s.png" % id, Vector2(40, 44), GameState.POOL[id]["crest"]))
	v.add_child(icc)
	var bcc := CenterContainer.new(); bcc.add_child(UI.tier_badge(t, "")); v.add_child(bcc)
	return box

# ==========================================================================
#  OVERLAY DE REVELAÇÃO DO PACOTE
# ==========================================================================
func _show_pack_reveal(picks: Array) -> void:
	var lay := CanvasLayer.new(); lay.layer = 50
	add_child(lay)
	var dim := UI.bg_rect(Color(0, 0, 0, 0.72))
	lay.add_child(dim)
	# 🎉 estouro de confete na abertura do pacote
	Sfx.play("shimmer")
	var vp := get_viewport_rect().size
	ConfettiFX.burst(lay, Vector2(vp.x * 0.5, vp.y * 0.38), 90, 520.0)
	ConfettiFX.burst(lay, Vector2(vp.x * 0.32, vp.y * 0.5), 40, 380.0)
	ConfettiFX.burst(lay, Vector2(vp.x * 0.68, vp.y * 0.5), 40, 380.0)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lay.add_child(cc)
	var pnl := UI.framed(UI.PANEL2, UI.GOLD2)
	cc.add_child(pnl)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	pnl.add_child(v)
	v.add_child(UI.clbl("✨ PACOTE ABERTO", 22, UI.GOLD2))
	if picks.is_empty():
		v.add_child(UI.clbl("Pool esgotado — sem novas figurinhas.", 12, UI.RUNE2))
		var ok := UI.gold_btn("Continuar →", 14)
		ok.pressed.connect(func(): lay.queue_free(); _build())
		v.add_child(ok)
		return
	v.add_child(UI.clbl("Escolha 1 fera pro banco de reservas.", 12, UI.RUNE2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for id in picks:
		var data: Dictionary = GameState.POOL[id]
		var rcor: Color = GameState.rarity_color(id)
		var card := Button.new()
		card.add_theme_stylebox_override("normal", UI.sbf(UI.PANEL, rcor, 3, 12, 8, 8))
		card.add_theme_stylebox_override("hover", UI.sbf(UI.PANEL2, UI.GOLD2, 3, 12, 8, 8))
		card.add_theme_stylebox_override("pressed", UI.sbf(UI.PANEL2, UI.GOLD, 3, 12, 8, 8))
		card.custom_minimum_size = Vector2(132, 178)
		card.pressed.connect(func(): GameState.recruit(id); lay.queue_free(); _build())
		var cv := VBoxContainer.new()
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		var icc := CenterContainer.new(); icc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icc.add_child(UI.icon("res://assets/beasts/%s.png" % id, Vector2(92, 100), data["crest"]))
		cv.add_child(icc)
		cv.add_child(UI.clbl(data["nome"], 12, UI.GOLD2))
		cv.add_child(UI.clbl("%s · %s" % [GameState.RARITY[GameState.rarity(id)]["nome"], data["papel"]], 10, rcor))
		row.add_child(card)
		UI.hoverify(card)
		UI.pop_in(card, row.get_child_count() * 0.09)   # revelação em cascata

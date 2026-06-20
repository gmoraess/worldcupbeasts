extends Control
## Tela de Preparação (Doc 2 §4 + Doc 3 §6.3) — montar o time antes da partida:
## trocar titulares por reservas, equipar GEAR por jogador, ver sinergias ativas.
## "Iniciar" funciona com a escalação atual (pulável). A capitã é fixa.
signal prep_done

var standalone := false  # true = aberta pelo mapa (botão "Voltar"), não inicia partida
var sel_slot := -1       # slot de titular selecionado
var mode := ""           # "" | "swap" | "gear"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	for c in get_children(): c.queue_free()
	add_child(UI.bg_rect())
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root.add_theme_constant_override(s, 20)
	add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)

	# topo: título + sinergias + iniciar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	top.add_child(UI.clbl("⚙ PREPARAÇÃO", 26, UI.GOLD2))
	var syn := UI.lbl("Sinergias: " + _synergy_text(), 13, UI.RUNE)
	syn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(syn)
	var go := UI.gold_btn("← VOLTAR AO MAPA" if standalone else "INICIAR PARTIDA →", 16)
	go.pressed.connect(func(): prep_done.emit())
	top.add_child(go)
	if not standalone:
		col.add_child(UI.clbl("vs %s  ·  alvo %d  ·  ⚠ %s" % [GameState.enemy_name(), GameState.target(), GameState.debuff().get("nome", "—")], 12, Color("ff8a6b")))

	# 5 titulares
	for i in GameState.titulares.size():
		col.add_child(_starter_row(i))

	# painel contextual (trocar fera / equipar gear)
	if mode == "swap":
		col.add_child(_chooser_swap())
	elif mode == "gear":
		col.add_child(_chooser_gear())

func _starter_row(i: int) -> Control:
	var id: String = GameState.titulares[i]
	var data: Dictionary = GameState.POOL[id]
	var box := UI.framed()
	box.custom_minimum_size = Vector2(0, 70)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	box.add_child(h)
	h.add_child(UI.icon("res://assets/beasts/%s.png" % id, Vector2(48, 56), data["crest"]))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap := "  ⭐" if id == GameState.capita else ""
	v.add_child(UI.lbl("%s [%s]%s" % [data["nome"], GameState.FORMATION[i], cap], 14, UI.GOLD2))
	var g: String = GameState.equipped[i]
	var gtxt := "Gear: —" if g == "" else "Gear: %s %s" % [GameState.GEAR[g]["ic"], GameState.GEAR[g]["nome"]]
	v.add_child(UI.lbl(gtxt, 11, UI.RUNE2))
	h.add_child(v)
	var bg := UI.gold_btn("Equipar", 12)
	bg.pressed.connect(func(): sel_slot = i; mode = "gear"; _build())
	h.add_child(bg)
	if id != GameState.capita:
		var bs := UI.gold_btn("Trocar", 12)
		bs.pressed.connect(func(): sel_slot = i; mode = "swap"; _build())
		h.add_child(bs)
	return box

func _chooser_swap() -> Control:
	var box := UI.framed(UI.PANEL2, UI.GOLD)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); box.add_child(v)
	v.add_child(UI.clbl("Trocar por uma reserva:", 13, UI.GOLD2))
	if GameState.reservas.is_empty():
		v.add_child(UI.lbl("Sem reservas. Recrute na loja.", 11, UI.RUNE2))
	for rid in GameState.reservas:
		var b := UI.gold_btn("%s %s [%s]" % [GameState.POOL[rid]["crest"], GameState.POOL[rid]["nome"], GameState.POOL[rid]["papel"]], 12)
		b.pressed.connect(func(): GameState.swap_titular(sel_slot, rid); mode = ""; sel_slot = -1; _build())
		v.add_child(b)
	var cancel := UI.gold_btn("Cancelar", 12)
	cancel.pressed.connect(func(): mode = ""; sel_slot = -1; _build())
	v.add_child(cancel)
	return box

func _chooser_gear() -> Control:
	var box := UI.framed(UI.PANEL2, UI.GOLD)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); box.add_child(v)
	v.add_child(UI.clbl("Equipar gear neste jogador:", 13, UI.GOLD2))
	if GameState.equipped[sel_slot] != "":
		var rb := UI.gold_btn("Remover gear atual", 12)
		rb.pressed.connect(func(): GameState.unequip_gear(sel_slot); mode = ""; sel_slot = -1; _build())
		v.add_child(rb)
	if GameState.gear_inv.is_empty():
		v.add_child(UI.lbl("Inventário de gear vazio.", 11, UI.RUNE2))
	for gid in GameState.gear_inv:
		var data: Dictionary = GameState.GEAR[gid]
		var b := UI.gold_btn("%s %s — %s" % [data["ic"], data["nome"], data["desc"]], 12)
		b.pressed.connect(func(): GameState.equip_gear(sel_slot, gid); mode = ""; sel_slot = -1; _build())
		v.add_child(b)
	var cancel := UI.gold_btn("Cancelar", 12)
	cancel.pressed.connect(func(): mode = ""; sel_slot = -1; _build())
	v.add_child(cancel)
	return box

func _synergy_text() -> String:
	var act: Array = GameState.active_synergies()
	if act.is_empty(): return "nenhuma"
	var parts: Array = []
	for s in act: parts.append("%s (%d)" % [s["nome"], s["n"]])
	return ", ".join(parts)

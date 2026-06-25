extends Control
## Recompensa de abertura: o jogo SEMPRE começa escolhendo 1 entre:
##   🎴 Pacote de figurinhas (revela 3 feras, escolhe 1)
##   🛡 Relíquia (escolhe 1 de 3)
##   🃏 3 cartas consumíveis (ganha as 3)
## Depois segue direto pra torre/partida.

signal reward_done

var stage := "choose"     # "choose" | "pack" | "relic"
var options: Array = []   # ids revelados no sub-passo

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	for c in get_children(): c.queue_free()
	add_child(UI.bg_rect())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	cc.add_child(col)
	match stage:
		"choose": _build_choose(col)
		"pack":   _build_pack(col)
		"relic":  _build_relic(col)

func _build_choose(col: VBoxContainer) -> void:
	col.add_child(UI.clbl("🎁  RECOMPENSA INICIAL", 28, UI.GOLD2))
	col.add_child(UI.clbl("Escolha como começar sua jornada.", 13, UI.RUNE2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(_opt("🎴", "Pacote de\nfigurinhas", "Revela 3 feras,\nvocê escolhe 1", func(): stage = "pack"; options = GameState.open_pack(3); _build()))
	row.add_child(_opt("🛡", "Relíquia", "Escolhe 1\nde 3 relíquias", func(): stage = "relic"; options = GameState.random_relic_choices(3); _build()))
	row.add_child(_opt("🃏", "3 Cartas", "Ganha 3 cartas\nconsumíveis", _grant_cards))

func _opt(ic: String, titulo: String, desc: String, cb: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(180, 220)
	b.add_theme_stylebox_override("normal", UI.sbf(UI.PANEL, UI.BRONZE, 2, 12, 10, 10))
	b.add_theme_stylebox_override("hover", UI.sbf(UI.PANEL2, UI.GOLD2, 2, 12, 10, 10))
	b.pressed.connect(cb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.clbl(ic, 56, UI.GOLD2))
	v.add_child(UI.clbl(titulo, 17, UI.GOLD2))
	v.add_child(UI.clbl(desc, 11, UI.RUNE2))
	b.add_child(v)
	return b

func _grant_cards() -> void:
	for id in GameState.consumable_offers(3):
		GameState.consumables.append(id)
	reward_done.emit()

func _build_pack(col: VBoxContainer) -> void:
	col.add_child(UI.clbl("✨ Escolha 1 fera pro elenco", 24, UI.GOLD2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for id in options:
		var data: Dictionary = GameState.POOL[id]
		var rcor: Color = GameState.rarity_color(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 210)
		b.add_theme_stylebox_override("normal", UI.sbf(UI.PANEL, rcor, 3, 12, 8, 8))
		b.add_theme_stylebox_override("hover", UI.sbf(UI.PANEL2, UI.GOLD2, 3, 12, 8, 8))
		b.pressed.connect(func(): GameState.recruit(id); reward_done.emit())
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icc := CenterContainer.new(); icc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icc.add_child(UI.icon("res://assets/beasts/%s.png" % id, Vector2(112, 130), data["crest"]))
		v.add_child(icc)
		v.add_child(UI.clbl(data["nome"], 13, UI.GOLD2))
		v.add_child(UI.clbl("%s · %s" % [GameState.RARITY[GameState.rarity(id)]["nome"], data["papel"]], 11, rcor))
		b.add_child(v)
		row.add_child(b)

func _build_relic(col: VBoxContainer) -> void:
	col.add_child(UI.clbl("🛡 Escolha 1 relíquia", 24, UI.GOLD2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for id in options:
		var r: Dictionary = GameState.RELICS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 150)
		b.add_theme_stylebox_override("normal", UI.sbf(UI.PANEL, UI.BRONZE, 2, 12, 10, 10))
		b.add_theme_stylebox_override("hover", UI.sbf(UI.PANEL2, UI.GOLD2, 2, 12, 10, 10))
		b.pressed.connect(func(): GameState.add_relic(id); reward_done.emit())
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 6)
		v.add_child(UI.clbl(r["ic"], 40, Color.WHITE))
		v.add_child(UI.clbl(r["name"], 14, UI.GOLD2))
		var d := UI.clbl(r["desc"], 11, UI.RUNE2)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(170, 0)
		v.add_child(d)
		b.add_child(v)
		row.add_child(b)

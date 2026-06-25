extends Control
## Tela inicial: banner com os retratos das feras + título + menu
## (Jogar · Continuar · Configurações · Sair). Compõe os PNGs existentes.

signal play_pressed
signal continue_pressed
signal settings_pressed
signal quit_pressed

# feras em destaque no banner (retratos que já existem em assets/beasts)
const SHOWCASE := ["cuirass", "zab", "zak", "foot", "lobo", "urso", "rinoceronte", "arara"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.bg_rect())
	# leve clarão dourado de fundo
	var glow := UI.bg_rect(Color(0.10, 0.07, 0.03, 1.0))
	add_child(glow)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	add_child(col)

	# — TÍTULO —
	col.add_child(UI.clbl("WORLD CUP", 56, UI.GOLD2))
	var sub := UI.clbl("B E A S T S", 40, UI.GOLD)
	col.add_child(sub)
	col.add_child(UI.clbl("⚽  a copa dos mil anos  ⚽", 14, UI.RUNE2))

	# — BANNER DE PERSONAGENS (mosaico dos retratos) —
	col.add_child(_showcase())

	# — MENU —
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", 9)
	col.add_child(menu)

	menu.add_child(_menu_btn("▶  Jogar", func(): play_pressed.emit()))
	var cont := _menu_btn("↻  Continuar", func(): continue_pressed.emit())
	cont.disabled = not GameState.has_save()
	cont.modulate.a = 1.0 if not cont.disabled else 0.5
	menu.add_child(cont)
	menu.add_child(_menu_btn("⚙  Configurações", func(): settings_pressed.emit()))
	menu.add_child(_menu_btn("✕  Sair", func(): quit_pressed.emit()))

	col.add_child(UI.clbl("v0.4 · protótipo", 10, UI.RUNE2))

func _showcase() -> Control:
	var frame := UI.framed(UI.PANEL, UI.BRONZE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	frame.add_child(row)
	for id in SHOWCASE:
		var path := "res://assets/beasts/%s.png" % id
		if not ResourceLoader.exists(path):
			continue
		var card := UI.framed(UI.PANEL2, UI.GOLD.darkened(0.2))
		var cc := CenterContainer.new()
		cc.add_child(UI.icon(path, Vector2(86, 100), "?"))
		card.add_child(cc)
		row.add_child(card)
	return frame

func _menu_btn(txt: String, cb: Callable) -> Button:
	var b := UI.gold_btn(txt, 20)
	b.custom_minimum_size = Vector2(300, 46)
	b.pressed.connect(cb)
	return b

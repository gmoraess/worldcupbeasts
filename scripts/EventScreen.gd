extends Control
## Evento narrativo — escolha com efeito (ouro / relíquia / nada).
signal event_done

const EVENTS := [
	{"title": "O Oráculo do Campo", "text": "Uma mascote feiticeira oferece um presente — confiar é arriscar.",
		"choices": [{"label": "Aceitar a bênção (+1 relíquia)", "effect": "relic"},
					{"label": "Recusar (nada acontece)", "effect": "nothing"}]},
	{"title": "Patrocinador das Sombras", "text": "Ouro fácil, sem explicação.",
		"choices": [{"label": "Aceitar (+15 ouro)", "effect": "gold", "val": 15},
					{"label": "Desconfiar (nada)", "effect": "nothing"}]},
	{"title": "A Torcida Imortal", "text": "A multidão vibra. Você aproveita o momento.",
		"choices": [{"label": "Erguer a taça aos céus (+10 ouro)", "effect": "gold", "val": 10},
					{"label": "Buscar uma relíquia no vestiário (+1 relíquia)", "effect": "relic"}]},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.stone_bg())
	var ev: Dictionary = EVENTS[randi() % EVENTS.size()]
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	cc.add_child(col)
	col.add_child(UI.clbl("❓ " + ev["title"], 22, UI.GOLD2))
	var t := UI.clbl(ev["text"], 13, UI.RUNE)
	t.custom_minimum_size = Vector2(460, 0)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	for ch in ev["choices"]:
		var b := UI.gold_btn(ch["label"])
		b.pressed.connect(func(): _apply(ch))
		col.add_child(b)

func _apply(ch: Dictionary) -> void:
	match ch.get("effect", "nothing"):
		"gold": GameState.gold += ch.get("val", 0)
		"relic":
			var c: Array = GameState.random_relic_choices(1)
			if not c.is_empty(): GameState.add_relic(c[0])
	event_done.emit()

extends Control
## Configurações clássicas: tela cheia, vsync, volumes (geral/música/efeitos).
## Cada mudança é aplicada e salva na hora (Settings.gd).

signal closed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.bg_rect())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := UI.framed(UI.PANEL2, UI.GOLD)
	cc.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(460, 0)
	panel.add_child(col)

	col.add_child(UI.clbl("⚙  CONFIGURAÇÕES", 26, UI.GOLD2))

	col.add_child(_toggle("Tela cheia", bool(Settings.get_val("fullscreen", false)),
		func(on): Settings.set_val("fullscreen", on); Settings.apply_fullscreen(on)))
	col.add_child(_toggle("VSync (sincronia vertical)", bool(Settings.get_val("vsync", true)),
		func(on): Settings.set_val("vsync", on); Settings.apply_vsync(on)))

	col.add_child(_sep())
	col.add_child(_slider("Volume geral", float(Settings.get_val("vol_master", 0.9)),
		func(v): Settings.set_val("vol_master", v); Settings.apply_volume("master", v)))
	col.add_child(_slider("Volume música", float(Settings.get_val("vol_music", 0.8)),
		func(v): Settings.set_val("vol_music", v); Settings.apply_volume("music", v)))
	col.add_child(_slider("Volume efeitos", float(Settings.get_val("vol_sfx", 0.9)),
		func(v): Settings.set_val("vol_sfx", v); Settings.apply_volume("sfx", v)))
	col.add_child(UI.clbl("(áudio entra numa próxima etapa — os volumes já ficam salvos)", 10, UI.RUNE2))

	col.add_child(_sep())
	var back := UI.gold_btn("Voltar", 16)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): closed.emit())
	col.add_child(back)

func _row(label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := UI.lbl(label, 15, UI.RUNE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	return h

func _toggle(label: String, on: bool, cb: Callable) -> Control:
	var h := _row(label)
	var c := CheckButton.new()
	c.button_pressed = on
	c.add_theme_color_override("font_color", UI.RUNE)
	c.toggled.connect(func(v): cb.call(v))
	h.add_child(c)
	return h

func _slider(label: String, val: float, cb: Callable) -> Control:
	var h := _row(label)
	var s := HSlider.new()
	s.min_value = 0.0; s.max_value = 1.0; s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(200, 22)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := UI.lbl("%d%%" % int(val * 100.0), 13, UI.GOLD2)
	pct.custom_minimum_size = Vector2(46, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v):
		pct.text = "%d%%" % int(v * 100.0)
		cb.call(v))
	h.add_child(s)
	h.add_child(pct)
	return h

func _sep() -> Control:
	var r := ColorRect.new()
	r.color = UI.BRONZE
	r.custom_minimum_size = Vector2(0, 2)
	return r

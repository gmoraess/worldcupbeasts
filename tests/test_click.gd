## Regressão: CLICAR num power-up do gramado leva ele pro inventário.
## Simula o clique pelo pipeline REAL de input (Input.parse_input_event) —
## pega exatamente o bug do Main engolindo cliques (mouse_filter STOP).
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== SMOKE DE CLIQUE (power-up → inventário) ===")
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs := root.get_node("GameState")
	gs.start_run("foot")
	main._on_beast()
	await process_frame
	main._on_difficulty("normal")
	await process_frame
	main.current.reward_done.emit()
	await process_frame
	main._show_match()
	await process_frame
	await process_frame
	var m = main.current

	# força um power-up e CLICA nele (evento de mouse de verdade)
	m._spawn_powerup()
	await process_frame
	assert(m._powerup != null, "power-up deveria ter spawnado")
	var screen: Vector2 = m.get_viewport().get_canvas_transform() * (m._powerup.position as Vector2)
	print("  [debug] item=%s screen=%s over=%s drag=%d" % [m._powerup.position, screen, m.over, m._inv_drag])
	_click(screen)
	await process_frame
	await process_frame
	if m._inventory.size() != 1:
		print("  [debug] Controls cobrindo o ponto (filtro != IGNORE):")
		_probe(root, screen)
	assert(m._inventory.size() == 1, "clique no item deveria guardar no inventário (algum Control engolindo cliques? ver Main.mouse_filter)")
	print("  clique no item: OK (inventário = %s)" % [m._inventory])

	# o fly-to-slot leva 0.38s; espera preencher o slot visual
	for i in 40: await process_frame

	# ARRASTA o slot 0 e solta no meio do campo → item consumido + arremesso
	m._inv_drag_start(0)
	assert(m._inv_drag == 0, "arrasto deveria estar ativo")
	var mid_scr: Vector2 = m.get_viewport().get_canvas_transform() * Vector2(640.0, 360.0)
	var ev_up := InputEventMouseButton.new()
	ev_up.button_index = MOUSE_BUTTON_LEFT
	ev_up.pressed = false
	ev_up.position = mid_scr
	ev_up.global_position = mid_scr
	root.push_input(ev_up, true)
	await process_frame
	await process_frame
	assert(m._inventory.is_empty(), "soltar no campo deveria consumir o item")
	assert(m._inv_drag == -1, "arrasto deveria ter terminado")
	assert(is_equal_approx(Engine.time_scale, 1.0), "time_scale deveria voltar ao normal")
	print("  arrastar e soltar no campo: OK (item consumido, tempo normal)")
	print("=== CLICK OK ===")
	quit()

## Lista os Controls visíveis cujo rect cobre o ponto e que não são IGNORE —
## os suspeitos de engolir o clique antes do _unhandled_input.
func _probe(node: Node, pt: Vector2) -> void:
	if node is Control:
		var c := node as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pt) \
				and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("    → %s filter=%d" % [c.get_path(), c.mouse_filter])
	for ch in node.get_children():
		_probe(ch, pt)

## push_input percorre o pipeline REAL (_input → GUI → _unhandled_input) e
## funciona em headless — Input.parse_input_event NÃO dispatcha sem janela.
func _click(screen: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen
	ev.global_position = screen
	# in_local_coords=true: pula a transform janela→viewport (degenerada no
	# headless, corrompia a posição do evento)
	root.push_input(ev, true)

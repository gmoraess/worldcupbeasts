## Regressão do crash "fecha ao ir pra próxima partida": joga 3 partidas seguidas
## subindo a torre, esperando frames extras pra QUALQUER timer pós-gol disparar.
## Antes, o await create_timer disparava na partida já liberada → segfault.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== LOOP (regressão de crash) ===")
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var gs := root.get_node("GameState")
	gs.start_run("zab")                 # zab faz muitos gols → muitos timers pós-gol
	main._on_difficulty("facil")
	await process_frame
	main.current.reward_done.emit()
	await process_frame

	for i in 3:
		main._show_match()
		await process_frame
		await process_frame
		var m = main.current
		m._target = 15                  # vence (faz gols → agenda timers pós-gol)
		m.clock = 20.0
		var safety := 0
		while is_instance_valid(m) and not m.over and safety < 25000:
			safety += 1
			await process_frame
		# espera ~5s de frames: aqui os timers pós-gol da partida liberada disparariam
		for _f in 320:
			await process_frame
		var sc = main.current
		print("  partida %d ok · degrau agora %d · tela=%s" % [i, gs.rung, ("FREED" if not is_instance_valid(sc) else sc.get_class())])
		# venceu → ShopScreen (sobe a torre); senão (vida_extra/derrota) encerra o loop
		if is_instance_valid(sc) and sc.has_signal("shop_done"):
			sc.shop_done.emit()
			await process_frame
		else:
			print("  (não venceu este — caminho vida-extra/derrota)")
			break

	print("=== LOOP OK (sem crash) ===")
	quit()

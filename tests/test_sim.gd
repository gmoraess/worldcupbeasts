## Smoke/bias test: roda matchups curtos e confirma que os stats enviesam o placar.
## Uso: godot --headless --path . --script tests/test_sim.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== TESTE DE VIÉS (stats → física) ===")
	var weak := {"fin": 0.7, "ctrl": 0.7, "des": 0.7, "def": 0.7, "spd": 0.8, "sta": 0.8}
	var strong := {"fin": 1.4, "ctrl": 1.35, "des": 1.3, "def": 1.35, "spd": 1.3, "sta": 1.3}
	await _play("foot", weak, "Foot (artilheiro) vs FRACO")
	await _play("cuirass", strong, "Cuirass (tanque)  vs FORTE")
	await _play("zak", {"fin": 1.0, "ctrl": 1.0, "des": 1.0, "def": 1.0, "spd": 1.0, "sta": 1.0}, "Zak vs neutro")
	print("=== FIM ===")
	quit()

func _play(beast_id: String, enemy_stats: Dictionary, label: String) -> void:
	var gs := root.get_node("GameState")
	gs.start_run(beast_id)
	gs.current_node = {"type": "partida", "enemy": {"name": "X", "stats": enemy_stats}}
	var m = load("res://scenes/Match.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.clock = 25.0          # partida curta pro teste
	var safety := 0
	while not m.over and safety < 20000:
		safety += 1
		await process_frame
	print("  %s  ->  %d x %d  (você x inimigo)" % [label, m.score["home"], m.score["away"]])
	m.queue_free()
	await process_frame

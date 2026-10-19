extends SceneTree

const OBJECTIVES := preload("res://tests/level_objectives_helper.gd")
const COIN := preload("res://cenas/coin.tscn")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)


func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func coins(level: Node2D) -> Array[Node]:
	var result: Array[Node] = []
	for coin in get_nodes_in_group("coins"):
		if level.is_ancestor_of(coin):
			result.append(coin)
	return result


func freeze_player(level: Node2D) -> void:
	level.mario.set_physics_process(false)
	level.mario.damage_area.monitoring = false
	for enemy in level.get_node("Inimigos").get_children():
		enemy.queue_free()


func check_locked(main: Node2D, level: Node2D, description: String) -> void:
	main._on_entrada_fase_2(main.mario)
	check(not main.trocando_de_fase, "Entrada bloqueada: " + description)
	main._ir_para_fase_2()
	check(main.fase_atual == level, "Troca direta tambem respeita os objetivos: " + description)


func _run() -> void:
	var main := load("res://cenas/main.tscn").instantiate() as Node2D
	main.get_node("level01").intro_enabled = false
	root.add_child(main)
	var level: Node2D = main.fase_atual
	freeze_player(level)
	await frames(3)
	var initial_total: int = coins(level).size()
	check(initial_total == 5 and level.total_coins == 5, "Primeira fase exige exatamente cinco moedas")
	check(level.total_coins == initial_total and initial_total > 0 and level.total_boxes > 0,
		"Objetivos contam todas as moedas e caixas da fase")
	check_locked(main, level, "nenhum item coletado")
	var outsider := CharacterBody2D.new()
	main._on_entrada_fase_2(outsider)
	check(not main.trocando_de_fase, "Outro corpo nao aciona a troca")
	outsider.free()
	for coin in coins(level):
		coin._on_body_entered(main.mario)
		coin._on_body_entered(main.mario)
	check(level.collected_coins == initial_total and level.hud.collected_coins == initial_total,
		"Fase e HUD contam cada moeda uma vez")
	await frames(20)
	check(level.total_coins == initial_total and coins(level).is_empty(),
		"Remover moedas coletadas nao reduz o total exigido")
	check_locked(main, level, "todas as moedas, mas faltam caixas")
	level._restart_level()
	await frames(3)
	level = main.fase_atual
	freeze_player(level)
	check(level.collected_coins == 0 and level.activated_boxes == 0 and not level.has_completed_objectives(),
		"Reinicio zera progresso e bloqueia novamente a saida")
	await OBJECTIVES.activate_boxes(level)
	check(level.activated_boxes == level.total_boxes and level.collected_coins == 0,
		"Todas as caixas podem ser ativadas antes das moedas")
	check_locked(main, level, "todas as caixas, mas faltam moedas")
	# Itens de outra arvore nao pertencem aos objetivos desta fase.
	var outside_coin := COIN.instantiate() as Area2D
	outside_coin.position = Vector2(-10000, -10000)
	root.add_child(outside_coin)
	check(level.total_coins == initial_total, "Moeda fora da fase nao aumenta a exigencia")
	outside_coin.queue_free()
	var last_coin := COIN.instantiate() as Area2D
	last_coin.position = Vector2(-10000, -10000)
	level.add_child(last_coin)
	check(level.total_coins == initial_total + 1, "Moeda criada durante o jogo tambem precisa ser coletada")
	for coin in coins(level):
		if coin != last_coin:
			coin._on_body_entered(main.mario)
	check_locked(main, level, "falta somente a ultima moeda")
	var entrance := level.get_node("EntradaFase2") as Area2D
	main.mario.global_position = entrance.global_position
	main.mario.velocity = Vector2.ZERO
	await frames(4)
	check(entrance.overlaps_body(main.mario) and main.fase_atual == level,
		"Contato fisico com a saida permanece bloqueado antes da ultima coleta")
	main.mario.set_lives(2)
	last_coin._on_body_entered(main.mario)
	check(level.has_completed_objectives() and main.trocando_de_fase,
		"Ultima coleta dentro da saida agenda a passagem automaticamente")
	# A condicao deve continuar verdadeira quando a chamada adiada executar.
	var extra_coin := COIN.instantiate() as Area2D
	extra_coin.position = Vector2(-10000, -10000)
	level.add_child(extra_coin)
	await frames(3)
	check(main.fase_atual == level and not main.trocando_de_fase,
		"Troca adiada revalida objetivos e cancela se ainda faltar uma moeda")
	extra_coin._on_body_entered(main.mario)
	main._on_entrada_fase_2(main.mario)
	await frames(3)
	check(main.fase_atual.scene_file_path.ends_with("level_02.tscn") and not is_instance_valid(level),
		"Todas as moedas e caixas liberam a fase 2")
	check(main.find_children("Mario", "CharacterBody2D", true, false).size() == 1 and main.mario.lives == 2,
		"Passagem acontece uma vez e conserva as vidas")
	level = main.fase_atual
	freeze_player(level)
	check(level.collected_coins == 0 and level.activated_boxes == 0 and not level.has_completed_objectives(),
		"Fase 2 inicia com seus proprios objetivos incompletos")
	coins(level)[0]._on_body_entered(main.mario)
	level._restart_level()
	await frames(3)
	check(main.fase_atual.collected_coins == 0 and main.fase_atual.activated_boxes == 0,
		"Reiniciar a fase 2 tambem restaura os objetivos")
	main.queue_free()
	await frames(3)
	for child in root.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.queue_free()
	await frames(2)
	print("LEVEL PROGRESSION FAILURES: ", failures)
	quit(1 if failures else 0)

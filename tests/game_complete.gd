extends SceneTree

const OBJECTIVES := preload("res://tests/level_objectives_helper.gd")
const COIN := preload("res://cenas/coin.tscn")
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

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

func make_level() -> Node2D:
	var level := load("res://cenas/level_02.tscn").instantiate() as Node2D
	level.intro_enabled = false
	root.add_child(level)
	current_scene = level
	level.mario.set_physics_process(false)
	for enemy in level.get_node("Inimigos").get_children():
		enemy.queue_free()
	return level

func collect_coins(level: Node2D) -> void:
	for coin in get_nodes_in_group("coins"):
		if level.is_ancestor_of(coin):
			coin._on_body_entered(level.mario)

func complete_sequentially(level: Node2D) -> void:
	# Respeita cada transformacao, como no percurso real entre as caixas.
	for block in get_nodes_in_group("question_blocks"):
		if not level.is_ancestor_of(block):
			continue
		block.activate_from_below()
		if level.mario.is_growing:
			level.mario.set_physics_process(true)
			for index in 160:
				await frames(1)
				if not level.mario.is_growing:
					break
			level.mario.set_physics_process(false)
		await frames(2)
	collect_coins(level)

func tap_ui(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func run() -> void:
	root.size = Vector2i(1152, 648)
	if "--test-exit" in OS.get_cmdline_user_args():
		var menu := load("res://cenas/game_complete.tscn").instantiate() as CanvasLayer
		root.add_child(menu)
		menu.exit_requested.connect(func() -> void: print("VICTORY EXIT REQUESTED"))
		menu.exit_button.grab_focus()
		await tap_ui(&"ui_accept")
		await frames(5)
		check(false, "Sair encerra o processo")
		quit(1)
		return
	var level := make_level()
	var mario: CharacterBody2D = level.mario
	var portal := level.get_node("PortalFinal") as Area2D
	check(level.total_coins == 4 and level.total_boxes == 4, "Final exige as quatro moedas e quatro caixas atuais da fase 2")
	check(portal.position == Vector2(2928, -128), "Detector fica dentro do portal desenhado no fim da fase 2")
	mario.position = portal.position
	await frames(3)
	check(portal.overlaps_body(mario) and not level.is_game_complete, "Portal permanece bloqueado sem objetivos")
	collect_coins(level)
	await frames(2)
	check(not level.is_game_complete, "Todas as moedas sem caixas nao terminam o jogo")
	level.queue_free()
	await frames(2)
	level = make_level()
	mario = level.mario
	portal = level.get_node("PortalFinal")
	mario.position = Vector2(-10000, -10000)
	await OBJECTIVES.activate_boxes(level)
	check(not level.is_game_complete and level.activated_boxes == 4, "Todas as caixas sem moedas nao terminam o jogo")
	collect_coins(level)
	await frames(3)
	check(level.has_completed_objectives() and not level.is_game_complete, "Objetivos completos fora do portal nao terminam o jogo")
	var outsider := CharacterBody2D.new()
	root.add_child(outsider)
	level._on_final_portal_entered(outsider)
	check(not level._completion_pending, "Outro corpo nao pode finalizar a aventura")
	outsider.queue_free()
	# Mantem o controle do agendamento para exercitar a revalidacao adiada.
	level.set_physics_process(false)
	mario.position = portal.position
	level.is_intro_playing = true
	await frames(3)
	check(not level.is_game_complete, "Abertura bloqueia conclusao mesmo com objetivos e contato")
	level.is_intro_playing = false
	mario.is_dead = true
	level._on_final_portal_entered(mario)
	check(not level._completion_pending, "Mario morto nao pode vencer")
	mario.is_dead = false
	level._on_final_portal_entered(mario)
	check(level._completion_pending, "Contato valido agenda a tela final")
	var extra := COIN.instantiate() as Area2D
	extra.position = Vector2(-10000, -10000)
	level.add_child(extra)
	await frames(2)
	check(not level.is_game_complete and not level._completion_pending, "Nova moeda pendente cancela a conclusao adiada")
	extra._on_body_entered(mario)
	# Retorna ao trajeto para atravessar o portal com movimento real.
	mario.position = portal.position + Vector2(-110, 38)
	mario.velocity = Vector2.ZERO
	mario.set_physics_process(true)
	level.set_physics_process(true)
	Input.action_press("move_right")
	for index in 90:
		if level.is_game_complete:
			break
		await frames(1)
	Input.action_release("move_right")
	check(level.is_game_complete and not paused, "Atravessar o portal com todos os objetivos mostra a vitoria")
	check(level.process_mode == Node.PROCESS_MODE_DISABLED and level.completion_screen.can_process(), "Cenario congela enquanto o menu de vitoria responde")
	var menu: CanvasLayer = level.completion_screen
	check(menu.victory_music.playing and menu.victory_music.can_process(), "Vitoria toca musica mesmo com a fase congelada no F6")
	check(menu.stats.text.contains("05/05") and menu.stats.text.contains("04/04"), "Tela final mostra todos os objetivos concluidos")
	check(menu.restart_button.has_focus(), "Jogar novamente recebe foco inicial")
	level._on_final_portal_entered(mario)
	level._complete_game()
	check(level.completion_screen == menu, "Conclusao repetida nao cria menus duplicados")
	await tap_ui(&"ui_down")
	check(menu.exit_button.has_focus(), "Seta seleciona Sair do jogo")
	await tap_ui(&"ui_up")
	check(menu.restart_button.has_focus(), "Seta volta para Jogar novamente")
	for size in [Vector2i(640, 360), Vector2i(1920, 1080), Vector2i(1152, 648)]:
		root.size = size
		await frames(2)
		var visible := root.get_visible_rect().size
		check(menu.card.position.x >= 0 and menu.card.position.y >= 0 and (menu.card.position + menu.CARD_SIZE * menu.card.scale).x <= visible.x + 1 and (menu.card.position + menu.CARD_SIZE * menu.card.scale).y <= visible.y + 1, "Menu cabe na janela " + str(size))
	# Mouse real no botao Jogar novamente.
	var point: Vector2 = menu.restart_button.get_global_transform_with_canvas() * (menu.restart_button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)
	await frames(4)
	var main := current_scene as Node2D
	check(main.scene_file_path == "res://cenas/main.tscn" and main.fase_atual.scene_file_path == "res://cenas/level_01.tscn", "Jogar novamente reinicia pela primeira fase, inclusive no F6")
	check(main.mario.lives == 3 and main.fase_atual.collected_coins == 0 and main.fase_atual.activated_boxes == 0, "Nova aventura restaura vidas e todos os objetivos")
	check(main.get_node("Music").playing, "Reiniciar volta a tocar a musica normal da aventura")
	# Percurso normal pelo Main: fase 1, fase 2, vitoria e nova aventura.
	for index in 300:
		if not main.fase_atual.is_intro_playing:
			break
		await frames(1)
	main.mario.set_physics_process(false)
	main.mario.global_position = Vector2(-10000, -10000)
	await frames(2)
	await complete_sequentially(main.fase_atual)
	main.mario.global_position = main.fase_atual.get_node("EntradaFase2").global_position
	await frames(4)
	check(main.fase_atual.scene_file_path == "res://cenas/level_02.tscn", "Percurso pelo Main continua chegando a fase 2")
	for index in 300:
		if not main.fase_atual.is_intro_playing:
			break
		await frames(1)
	main.mario.set_physics_process(false)
	main.mario.global_position = Vector2(-10000, -10000)
	await frames(2)
	for enemy in main.fase_atual.get_node("Inimigos").get_children():
		enemy.queue_free()
	await complete_sequentially(main.fase_atual)
	await frames(2)
	main.mario.global_position = main.fase_atual.get_node("PortalFinal").global_position
	await frames(4)
	check(main.fase_atual.is_game_complete, "Aventura normal tambem termina no portal da fase 2")
	check(not main.get_node("Music").playing and main.fase_atual.completion_screen.victory_music.playing, "Vitoria substitui a musica da fase sem sobrepor os temas")
	var old_victory_music: AudioStreamPlayer = main.fase_atual.completion_screen.victory_music
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/game_complete_preview.png")
	await tap_ui(&"ui_accept")
	await frames(4)
	main = current_scene
	check(not is_instance_valid(old_victory_music) and main.get_node("Music").playing, "Nova aventura remove o tema de vitoria e restaura a musica da fase")
	check(main.fase_atual.scene_file_path == "res://cenas/level_01.tscn" and main.get_child_count() == 2, "Enter em Jogar novamente substitui a aventura anterior sem duplicar cenas")
	main.queue_free()
	await frames(2)
	check(not paused, "Sair da tela final nao deixa o jogo pausado")
	print("GAME COMPLETE FAILURES: ", failures)
	quit(failures)

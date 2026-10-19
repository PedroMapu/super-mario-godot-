extends SceneTree

var failures := 0
var capture := false


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
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


func screenshot(filename: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename)


func tap_ui(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)


func click_button(button: Button) -> void:
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)


func check_menu(number: String) -> void:
	root.size = Vector2i(1152, 648)
	var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
	level.intro_enabled = false
	root.add_child(level)
	current_scene = level
	var mario: CharacterBody2D = level.mario
	await frames(3)
	mario.set_physics_process(false)
	level.get_node("Coin")._on_body_entered(mario)
	var block: Node
	for candidate in get_nodes_in_group("question_blocks"):
		if level.is_ancestor_of(candidate) and not candidate.activated.is_connected(mario.grow):
			block = candidate
			break
	block.activate_from_below()
	mario.death_pause = 0.0
	mario.death_respawn_delay = 0.01
	mario.set_physics_process(true)
	mario.die()
	for index in 300:
		await frames(1)
		if level.is_game_over:
			break
	check(level.is_game_over and mario.is_dead and not paused, "Morte real mostra Game Over na fase " + number)
	var menu: CanvasLayer = level.game_over_screen
	check(level.process_mode == Node.PROCESS_MODE_DISABLED and menu.can_process(), "Mundo congela e menu continua respondendo")
	check(menu.restart_button.has_focus() and not menu.restart_button.disabled and not menu.exit_button.disabled,
		"Botao de reiniciar recebe foco inicial e os dois botoes estao ativos")
	check(menu.stats.text.contains("FASE " + number) and menu.stats.text.contains("MOEDAS 01/")
		and menu.stats.text.contains("CAIXAS 01/"), "Game Over mostra progresso da fase correta")
	var enemy := level.get_node("Inimigos").get_child(0) as CharacterBody2D
	var enemy_position := enemy.position
	await frames(180)
	check(is_instance_valid(mario) and level.is_game_over and enemy.position == enemy_position,
		"Game Over aguarda escolha sem reinicio automatico nem movimento de inimigos")
	await screenshot("game_over_" + number + ".png")
	await tap_ui(&"ui_down")
	check(menu.exit_button.has_focus() and menu.pointer.position.y == menu.exit_button.position.y + 8,
		"Seta para baixo seleciona Sair com cursor pixelado")
	await tap_ui(&"ui_up")
	check(menu.restart_button.has_focus(), "Seta para cima retorna ao botao Reiniciar")
	for size in [Vector2i(640, 480), Vector2i(800, 1000), Vector2i(1920, 1080)]:
		root.size = size
		await frames(2)
		var bounds: Rect2 = menu.card.get_global_rect()
		check(root.get_visible_rect().encloses(bounds) and menu.card.scale.x == floorf(menu.card.scale.x),
			"Tela cabe na janela com escala inteira de pixels: " + str(size))
	var replacements: Array[Node2D] = []
	level.restarted.connect(func(replacement: Node2D) -> void: replacements.append(replacement))
	# O mesmo sinal do clique confirma a acao; cliques duplos nao duplicam fases.
	if number == "01":
		menu.restart_button.pressed.emit()
		menu.restart_button.pressed.emit()
	else:
		root.size = Vector2i(1152, 648)
		await frames(2)
		await click_button(menu.restart_button)
	await frames(4)
	check(replacements.size() == 1 and not is_instance_valid(level), "Reiniciar troca a fase uma unica vez")
	var replacement: Node2D = replacements[0]
	replacement.mario.set_physics_process(false)
	check(replacement.scene_file_path.ends_with("level_" + number + ".tscn") and replacement.mario.lives == 3,
		"Reiniciar conserva a fase atual e restaura tres vidas")
	check(replacement.collected_coins == 0 and replacement.activated_boxes == 0 and not replacement.is_game_over,
		"Reiniciar restaura moedas, caixas e remove o menu")
	check(current_scene == replacement and not paused, "F6 conserva a cena atual e nao deixa pausa presa")
	replacement.queue_free()
	await frames(3)


func check_five_coins() -> void:
	var level := load("res://cenas/level_01.tscn").instantiate() as Node2D
	level.intro_enabled = false
	root.add_child(level)
	level.mario.set_physics_process(false)
	for enemy in level.get_node("Inimigos").get_children():
		enemy.queue_free()
	await frames(3)
	await preload("res://tests/level_objectives_helper.gd").activate_boxes(level)
	check(level.total_coins == 5 and level.activated_boxes == level.total_boxes,
		"Primeira fase tem cinco moedas reais e todas as caixas podem ser ativadas")
	for name in ["Coin", "Coin2", "Coin3", "Coin4"]:
		level.get_node(name)._on_body_entered(level.mario)
	check(level.collected_coins == 4 and not level.has_completed_objectives(), "Quatro moedas nao liberam a passagem, mesmo com todas as caixas")
	var fifth := level.get_node("Coin5") as Area2D
	level.mario.global_position = fifth.global_position - Vector2(0, 60)
	level.mario.velocity = Vector2.ZERO
	level.mario.set_physics_process(true)
	for index in 60:
		await frames(1)
		if fifth.is_collected:
			break
	level.mario.set_physics_process(false)
	check(fifth.is_collected and not level.mario.is_dead, "Quinta moeda pode ser coletada por contato fisico antes da queda fatal")
	check(level.collected_coins == 5 and level.has_completed_objectives(), "Cinco moedas e todas as caixas liberam a passagem")
	level.queue_free()
	await frames(3)


func _run() -> void:
	if "--test-exit" in OS.get_cmdline_user_args():
		var menu := load("res://cenas/game_over.tscn").instantiate() as CanvasLayer
		root.add_child(menu)
		menu.exit_requested.connect(func() -> void: print("EXIT BUTTON REQUESTED"))
		menu.exit_button.grab_focus()
		await tap_ui(&"ui_accept")
		await process_frame
		return
	for number in ["01", "02"]:
		await check_menu(number)
	await check_five_coins()
	print("GAME OVER FAILURES: ", failures)
	quit(1 if failures else 0)

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


func save_frame(index: int) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	screenshot.save_png("res://.godot/intro_frames/%03d.png" % index)


func check_level(number: String) -> void:
	root.size = Vector2i(1152, 648)
	var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
	root.add_child(level)
	current_scene = level
	var mario: CharacterBody2D = level.mario
	var start: Vector2 = mario.global_position
	var resting_spawn := start
	var enemy := level.get_node("Inimigos").get_child(0) as CharacterBody2D
	var enemy_start := enemy.position
	var intro: CanvasLayer = level.intro
	check(level.is_intro_playing and level.process_mode == Node.PROCESS_MODE_DISABLED and not paused,
		"Abertura pausa apenas a fase, sem pausar a arvore: " + number)
	check(intro.stage == intro.Stage.BLACK and intro.iris_radius == 0 and not intro.runner.visible,
		"Comeca totalmente preto, antes de Mario entrar")
	Input.action_press("move_left")
	Input.action_press("jump")
	var running_frames := {}
	var saw_running := false
	var saw_reveal := false
	var stayed_frozen := true
	var ran_to_right := true
	var previous_x := -INF
	var frame_index := 0
	for index in 200:
		await frames(1)
		if not level.is_intro_playing:
			break
		stayed_frozen = stayed_frozen and mario.global_position.x == start.x and enemy.position == enemy_start
		if intro.stage == intro.Stage.RUNNING:
			if not saw_running:
				resting_spawn = mario.global_position
				check(intro._spawn_prepared and absf(mario._feet_position().y + 32.0) < 0.1,
					"Corrida chega ao chao abaixo do marcador de spawn")
			saw_running = true
			running_frames[intro.runner.frame] = true
			ran_to_right = ran_to_right and intro.runner.position.x >= previous_x
			previous_x = intro.runner.position.x
			if index == 15:
				check(not mario.sprite.visible and intro.iris_radius == 0, "Corrida aparece sobre preto, sem revelar o mapa")
		if intro.stage == intro.Stage.REVEALING:
			if not saw_reveal:
				check(intro.runner.position.is_equal_approx(mario.sprite.get_global_transform_with_canvas().origin),
					"Mario chega exatamente ao spawn antes da iris abrir")
				saw_reveal = true
				Input.action_release("move_left")
				Input.action_release("jump")
			if index == 100:
				check(intro.iris_center.is_equal_approx(mario.body_shape.get_global_transform_with_canvas().origin),
					"Centro da iris acompanha Mario")
		if saw_running:
			stayed_frozen = stayed_frozen and mario.global_position.is_equal_approx(resting_spawn)
		if capture and number == "01" and index % 3 == 0:
			await save_frame(frame_index)
			frame_index += 1
	Input.action_release("move_left")
	Input.action_release("jump")
	check(saw_running and ran_to_right and running_frames.size() > 1, "Mario entra correndo da esquerda com animacao real")
	check(saw_reveal and stayed_frozen, "Controles e inimigos ficam parados durante corrida e revelacao")
	check(not level.is_intro_playing and level.process_mode == Node.PROCESS_MODE_INHERIT and mario.sprite.visible,
		"Revelacao termina restaurando jogador e processamento da fase")
	check(not is_instance_valid(intro) or intro.is_queued_for_deletion(), "Mascara e ator da abertura sao removidos")
	check(mario.global_position.distance_to(resting_spawn) < 1 and mario._spawn_position == start and mario.lives == mario.MAX_LIVES
		and level.collected_coins == 0 and level.activated_boxes == 0, "Abertura nao altera spawn, vidas ou objetivos")
	if capture and number == "01":
		await save_frame(frame_index)
	var x := mario.position.x
	Input.action_press("move_right")
	await frames(8)
	Input.action_release("move_right")
	check(mario.position.x > x, "Controles funcionam depois da abertura")
	level.queue_free()
	await frames(3)


func check_resize_and_cancel() -> void:
	var level := load("res://cenas/level_01.tscn").instantiate() as Node2D
	root.add_child(level)
	var intro: CanvasLayer = level.intro
	await frames(90)
	for size in [Vector2i(800, 1000), Vector2i(1800, 600)]:
		root.size = size
		await frames(2)
		var view_size := root.get_visible_rect().size
		check(intro.iris.size == view_size
			and intro.iris.material.get_shader_parameter("viewport_size") == view_size
			and absf(view_size.aspect() - Vector2(size).aspect()) < 0.001,
			"Mascara usa pixels e cobre a janela ao redimensionar: " + str(size))
		check(intro.iris_center.is_equal_approx(level.mario.body_shape.get_global_transform_with_canvas().origin),
			"Redimensionar conserva Mario no centro da abertura")
	intro.queue_free()
	await frames(2)
	check(not level.is_intro_playing and level.process_mode == Node.PROCESS_MODE_INHERIT and level.mario.sprite.visible,
		"Cancelar a abertura restaura visibilidade e controles")
	level.queue_free()
	await frames(2)


func check_transition_and_restart() -> void:
	root.size = Vector2i(1152, 648)
	var main := load("res://cenas/main.tscn").instantiate() as Node2D
	root.add_child(main)
	check(main.fase_atual.is_intro_playing and main.get_node("Music").playing, "Musica continua durante a abertura")
	await frames(155)
	main.mario.set_physics_process(false)
	await preload("res://tests/level_objectives_helper.gd").complete(main.fase_atual)
	main.mario.set_lives(2)
	main._on_entrada_fase_2(main.mario)
	await frames(3)
	var second: Node2D = main.fase_atual
	check(second.scene_file_path.ends_with("level_02.tscn") and second.is_intro_playing and main.mario.lives == 2,
		"Fase 2 tambem inicia com abertura e conserva vidas")
	second._restart_level()
	await frames(3)
	check(not is_instance_valid(second) and main.fase_atual.is_intro_playing,
		"Reiniciar durante a abertura cria uma sequencia nova")
	await frames(155)
	check(not paused and not main.fase_atual.is_intro_playing and main.mario.sprite.visible,
		"Reinicio nao deixa pausa nem mascara presas")
	var dying_mario: CharacterBody2D = main.mario
	dying_mario.death_pause = 0.0
	dying_mario.death_respawn_delay = 0.01
	dying_mario.die()
	for index in 300:
		await frames(1)
		if main.fase_atual.is_game_over:
			break
	check(main.fase_atual.is_game_over, "Morte termina em Game Over antes de reiniciar")
	main.fase_atual.game_over_screen.restart_button.pressed.emit()
	await frames(3)
	check(not is_instance_valid(dying_mario) and main.fase_atual.is_intro_playing and not paused,
		"Morte real reinicia a fase com outra abertura")
	await frames(155)
	check(not main.fase_atual.is_intro_playing and main.mario.sprite.visible and main.mario.lives == 3,
		"Abertura do respawn termina normalmente com vidas restauradas")
	main.queue_free()
	await frames(3)


func _run() -> void:
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/intro_frames"))
	for number in ["01", "02"]:
		await check_level(number)
	await check_resize_and_cancel()
	await check_transition_and_restart()
	print("LEVEL INTRO FAILURES: ", failures)
	quit(1 if failures else 0)

extends SceneTree

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


func _run() -> void:
	root.size = Vector2i(640, 480)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 100)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 32)
	shape.shape = rectangle
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(0, 58)
	root.add_child(mario)
	var camera := mario.get_node("Camera2D") as Camera2D
	camera.set_map_bounds(Rect2(-1000, -500, 2000, 1000))
	var enemy := load("res://cenas/goomba.tscn").instantiate() as CharacterBody2D
	enemy.position = Vector2(200, 76)
	root.add_child(enemy)
	await frames(4)
	var frames_resource: SpriteFrames = mario.sprite.sprite_frames
	var original_animation_names := frames_resource.get_animation_names()
	var original_idle := frames_resource.get_frame_texture(&"small_idle", 0)
	var starts: Array = []
	var respawns: Array = []
	mario.death_started.connect(func() -> void: starts.append(true))
	mario.respawned.connect(func() -> void: respawns.append(true))
	var death_position := mario.global_position
	var enemy_position := enemy.global_position
	camera.force_update_scroll()
	var camera_center := camera.get_screen_center_position()
	mario.set_lives(2)
	mario.take_enemy_damage(enemy)
	check(mario.is_dead and starts.size() == 1 and paused, "Dano inicia morte e pausa o mundo uma unica vez")
	check(not mario.sprite.visible and mario.get_node("DeathPose").texture == mario.death_texture, "Pose de morte separada substitui visualmente a animacao")
	check(frames_resource == mario.sprite.sprite_frames and frames_resource.get_animation_names() == original_animation_names and frames_resource.get_frame_texture(&"small_idle", 0) == original_idle, "SpriteFrames e quadros existentes permanecem intactos")
	mario.take_enemy_damage(enemy)
	mario.die()
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(8)
	check(starts.size() == 1 and mario.global_position.is_equal_approx(death_position), "Contatos repetidos nao reiniciam morte; breve pausa antes do salto")
	check(mario.collision_layer == 0 and mario.collision_mask == 0 and mario.body_shape.disabled and not mario.damage_area.monitoring, "Corpo e area de dano ficam desativados")
	var coin := load("res://cenas/coin.tscn").instantiate() as Area2D
	root.add_child(coin)
	coin._on_body_entered(mario)
	check(not coin.is_collected and not mario.is_in_group("player"), "Mario morto nao coleta moedas")
	await frames(24)
	check(mario.velocity.y < 0.0 and mario.global_position.y < death_position.y and is_equal_approx(mario.global_position.x, death_position.x), "Mario salta verticalmente mesmo com movimento e salto pressionados")
	check(enemy.global_position.is_equal_approx(enemy_position), "Inimigos ficam parados durante a morte")
	check(camera.get_screen_center_position().is_equal_approx(camera_center), "Camera permanece fixa durante o salto de morte")
	Input.action_release("move_right")
	Input.action_release("jump")
	var passed_floor := false
	for index in 180:
		await frames(1)
		passed_floor = passed_floor or (mario.is_dead and mario.global_position.y > 150.0)
		if not mario.is_dead:
			break
	check(passed_floor, "Queda da morte atravessa o chao sem pousar")
	check(not mario.is_dead and not paused and respawns.size() == 1, "Ao sair da tela, espera e respawna sem deixar o jogo pausado")
	check(mario.global_position.distance_to(death_position) < 3.0 and mario._damage_grace > 0.0, "Mario isolado retorna ao spawn com protecao temporaria")
	await frames(3)
	check(mario.collision_layer == 1 and mario.collision_mask == 62 and not mario.body_shape.disabled and mario.damage_area.monitoring and mario.is_in_group("player"), "Respawn restaura colisao, dano e coleta")
	check(mario.sprite.visible and not camera.top_level and camera.position == Vector2.ZERO, "Respawn restaura sprite e acompanhamento da camera")
	mario.queue_free()
	enemy.queue_free()
	coin.queue_free()
	floor_body.queue_free()
	await frames(3)

	# Contato real com perigo usa a mesma sequencia.
	mario = load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	root.add_child(mario)
	var hazard := Area2D.new()
	hazard.collision_layer = 128
	hazard.collision_mask = 0
	var hazard_shape := CollisionShape2D.new()
	var hazard_rectangle := RectangleShape2D.new()
	hazard_rectangle.size = Vector2(80, 80)
	hazard_shape.shape = hazard_rectangle
	hazard.add_child(hazard_shape)
	root.add_child(hazard)
	await frames(4)
	check(mario.is_dead and paused, "Contato fisico real com perigo tambem inicia morte")
	mario.queue_free()
	hazard.queue_free()
	await frames(3)
	check(not paused, "Remover Mario durante a morte libera a pausa do mundo")

	# Reinicia a fase atual inteira, sem voltar da fase 2 para a fase 1.
	var main := load("res://cenas/main.tscn").instantiate() as Node2D
	root.add_child(main)
	await frames(3)
	for phase in [1, 2]:
		var level: Node2D = main.fase_atual
		var old_mario: CharacterBody2D = main.mario
		old_mario.death_pause = 0.0
		old_mario.death_respawn_delay = 0.1
		# Altera o estado real de um bloco e remove um inimigo para verificar o reset.
		var ground := level.get_node("Mundo/Ground")
		if phase == 1:
			ground.get_node("QuestionBlock_45_-9").activate_from_below()
			level.get_node("Inimigos/Goomba").queue_free()
		old_mario.die()
		check(old_mario.is_dead, "Morte inicia na fase " + str(phase))
		main._on_entrada_fase_2(old_mario)
		check(not main.trocando_de_fase, "Mario morto nao aciona troca de fase")
		for index in 300:
			await frames(1)
			if not is_instance_valid(old_mario):
				break
		var replacement: Node2D = main.fase_atual
		check(not is_instance_valid(level) and not is_instance_valid(old_mario) and replacement.scene_file_path.ends_with("level_0%d.tscn" % phase), "Reinicio substitui somente a fase atual: " + str(phase))
		var new_mario: CharacterBody2D = main.mario
		new_mario.set_physics_process(false)
		check(new_mario == replacement.get_node("Mario") and new_mario.global_position.distance_to(replacement.get_node("PlayerSpawn").global_position) < 5.0 and not paused, "Main usa novo Mario no PlayerSpawn da fase " + str(phase))
		check(main.find_children("Mario", "CharacterBody2D", true, false).size() == 1 and new_mario.get_node("Camera2D").is_current(), "Reinicio conserva unico Mario e camera ativa na fase " + str(phase))
		if phase == 1:
			check(not replacement.get_node("Mundo/Ground/QuestionBlock_45_-9").used and replacement.has_node("Inimigos/Goomba"), "Reinicio restaura bloco usado e inimigo removido")
			main.get_node("level01/EntradaFase2").body_entered.emit(new_mario)
			await frames(3)
			check(main.fase_atual.scene_file_path.ends_with("level_02.tscn"), "Portal continua funcionando depois da morte na fase 1")
	main.queue_free()
	await frames(3)

	# F6: a propria fase e a cena atual, sem Main para atualizar referencias.
	var standalone := load("res://cenas/level_02.tscn").instantiate() as Node2D
	root.add_child(standalone)
	current_scene = standalone
	var falling_mario := standalone.get_node("Mario") as CharacterBody2D
	falling_mario.global_position.y = falling_mario.fall_death_y + 1.0
	await frames(2)
	check(falling_mario.is_dead, "Cair abaixo do mapa causa morte automaticamente")
	falling_mario.death_pause = 0.0
	falling_mario.death_respawn_delay = 0.1
	for index in 300:
		await frames(1)
		if not is_instance_valid(standalone):
			break
	check(not is_instance_valid(standalone) and current_scene != null and current_scene.scene_file_path.ends_with("level_02.tscn") and not paused, "Fase executada com F6 reinicia e atualiza current_scene")
	if current_scene != null:
		current_scene.queue_free()
	await frames(3)
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

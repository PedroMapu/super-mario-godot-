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


func full_hearts(hud: CanvasLayer) -> int:
	var count := 0
	for heart in hud.hearts.get_children():
		if heart.texture == hud.HEART_FULL:
			count += 1
	return count


func screenshot(filename: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename)


func _run() -> void:
	root.size = Vector2i(1152, 648)
	# Inclui caixa manual longe da camera e caixa em outro nivel na arvore.
	var level := load("res://cenas/level_01.tscn").instantiate() as Node2D
	var extra := load("res://cenas/question_block.tscn").instantiate() as StaticBody2D
	extra.position = Vector2(3500, -150)
	level.add_child(extra)
	var other_level := load("res://cenas/level_02.tscn").instantiate() as Node2D
	root.add_child(other_level)
	other_level.mario.set_physics_process(false)
	root.add_child(level)
	level.mario.set_physics_process(false)
	await frames(2)
	var hud: CanvasLayer = level.hud
	check(level.total_boxes == 4 and level.activated_boxes == 0 and hud.boxes_label.text == "0 / 4", "Total inclui todos os tiles e caixa manual fora da tela, sem somar outra fase")
	check(level.mario.lives == 3 and full_hearts(hud) == 3, "HUD inicia com tres coracoes cheios")
	check(hud.layer > 0 and hud.hearts.get_child_count() == 3, "HUD fica sobre o mapa com tres posicoes de coracao")
	var block := level.get_node("Mundo/Ground/QuestionBlock_45_-9") as StaticBody2D
	block.activate_from_below()
	block.activate_from_below()
	check(level.activated_boxes == 1 and hud.boxes_label.text == "1 / 4", "Caixa conta uma vez mesmo com cabecadas repetidas")
	await frames(20)
	check(is_instance_valid(block) and block.used and block.sprite.texture == block.used_texture and not block.get_node("CollisionShape2D").disabled, "Caixa ativada conserva visual usado e colisao solida")
	extra.activate_from_below()
	for candidate in get_nodes_in_group("question_blocks"):
		if level.is_ancestor_of(candidate):
			candidate.activate_from_below()
	check(hud.boxes_label.text == "4 / 4" and level.total_boxes == 4, "Contador atinge total sem reduzir denominador")
	level.queue_free()
	other_level.queue_free()
	await frames(2)

	var main := load("res://cenas/main.tscn").instantiate() as Node2D
	root.add_child(main)
	main.mario.set_physics_process(false)
	await frames(2)
	level = main.fase_atual
	hud = level.hud
	await screenshot("hud_three_hearts.png")
	var mario: CharacterBody2D = main.mario
	var koopa := level.get_node("Inimigos/Koopa") as CharacterBody2D
	var goomba := level.get_node("Inimigos/Goomba") as CharacterBody2D
	koopa.on_player_contact(mario, false)
	check(mario.lives == 2 and full_hearts(hud) == 2 and not mario.is_dead and not paused, "Dano lateral do Koopa remove uma vida e atualiza HUD sem pausar")
	goomba.on_player_contact(mario, false)
	check(mario.lives == 2, "Segundo inimigo no mesmo contato nao causa dano durante protecao")
	await screenshot("hud_two_hearts.png")
	mario._damage_grace = 0.0
	goomba.on_player_contact(mario, false)
	check(mario.lives == 0 and full_hearts(hud) == 0 and mario.is_dead and paused, "Goomba tira duas vidas restantes e dispara morte com HUD vazio")
	mario.take_enemy_damage(goomba)
	check(mario.lives == 0, "Dano fatal repetido nao deixa vidas negativas")
	mario.death_pause = 0.0
	mario.death_respawn_delay = 0.01
	mario.set_physics_process(true)
	for index in 300:
		await frames(1)
		if not is_instance_valid(mario):
			break
	check(not is_instance_valid(mario) and main.mario.lives == 3 and full_hearts(main.fase_atual.hud) == 3 and not paused, "Morte reinicia a fase com tres vidas e HUD conectado ao novo Mario")
	check(main.fase_atual.hud.boxes_label.text == "0 / 3", "Reinicio restaura contador e todas as caixas da fase")
	mario = main.mario
	mario.set_physics_process(false)
	goomba = main.fase_atual.get_node("Inimigos/Goomba") as CharacterBody2D
	mario.take_enemy_damage(goomba)
	check(mario.lives == 1 and not mario.is_dead and full_hearts(main.fase_atual.hud) == 1, "Goomba deixa Mario com uma vida quando inicia com tres")
	await screenshot("hud_one_heart.png")
	main._ir_para_fase_2()
	main.mario.set_physics_process(false)
	await frames(2)
	check(main.mario.lives == 1 and full_hearts(main.fase_atual.hud) == 1, "Troca para fase 2 preserva vida restante e atualiza coracoes")
	var expected_total := 0
	for candidate in get_nodes_in_group("question_blocks"):
		if main.fase_atual.is_ancestor_of(candidate):
			expected_total += 1
	check(main.fase_atual.hud.boxes_label.text == "0 / %d" % expected_total, "Nova fase calcula seu proprio total de caixas")
	for window_size in [Vector2i(640, 480), Vector2i(320, 480), Vector2i(1600, 900)]:
		root.size = window_size
		await frames(2)
		var panel := main.fase_atual.hud.get_node("Margin/Panel") as Control
		check(panel.get_global_rect().end.x <= root.get_visible_rect().size.x and panel.get_global_rect().position == Vector2(16, 16), "HUD permanece fixo e cabe na janela " + str(window_size))
	main.queue_free()
	await frames(2)
	# Casco movendo usa o dano do Koopa; pisao e chute nao custam vidas.
	mario = load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	root.add_child(mario)
	mario.set_physics_process(false)
	koopa = load("res://cenas/koompa.tscn").instantiate() as CharacterBody2D
	root.add_child(koopa)
	koopa.set_physics_process(false)
	koopa.on_player_contact(mario, true)
	check(mario.lives == 3, "Pisao no Koopa nao custa vida")
	koopa.contact_grace = 0.0
	koopa.on_player_contact(mario, false)
	check(mario.lives == 2, "Casco em movimento remove uma vida")
	koopa.state = koopa.State.SHELL_IDLE
	koopa.contact_grace = 0.0
	mario._damage_grace = 0.0
	koopa.on_player_contact(mario, false)
	check(mario.lives == 2, "Chutar casco parado nao custa vida")
	mario.queue_free()
	koopa.queue_free()
	await frames(2)
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

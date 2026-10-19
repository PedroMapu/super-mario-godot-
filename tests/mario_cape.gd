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

func finish_transformation(mario: CharacterBody2D) -> void:
	for index in 160:
		if not mario.is_growing:
			return
		await frames(1)
	check(false, "Transformacao termina sem prender a pausa")

func _run() -> void:
	var level := load("res://cenas/level_02.tscn").instantiate() as Node2D
	level.intro_enabled = false
	root.add_child(level)
	var mario: CharacterBody2D = level.mario
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames(2)
	var target := level.get_node("CaixasInterrogacao/QuestionBlock_34_-12") as StaticBody2D
	var ground := level.get_node("Mundo/Ground") as TileMapLayer
	check(ground.local_to_map(ground.to_local(target.global_position)) == Vector2i(57, -10), "Caixa instanciada da fase 2 fica no tile (57, -10)")
	var original_total: int = level.total_boxes
	# A cabeca atinge a caixa real de baixo para cima, sem acionar por chamada direta.
	mario.position = target.position + Vector2(0, 65)
	mario.velocity = Vector2(0, -400)
	for index in 30:
		if target.used:
			break
		await frames(1)
	check(target.used and mario.is_growing and paused, "Batida real na caixa inicia a transformacao e pausa o mundo")
	check(mario.sprite.animation == &"small_to_cape", "Transformacao usa animacao de giro do Mario pequeno")
	check(level.activated_boxes == 1 and level.total_boxes == original_total, "Caixa de capa conta uma vez no objetivo da fase")
	var frozen_position := mario.position
	Input.action_press("move_right")
	await frames(8)
	check(mario.position == frozen_position, "Transformacao bloqueia movimento")
	Input.action_release("move_right")
	await finish_transformation(mario)
	mario.set_physics_process(false)
	check(mario.has_cape and not mario.is_big and mario.cape.visible and not paused, "Transformacao termina no Mario pequeno com capa e libera o jogo")
	check(mario.body_shape.shape.size == mario._small_body_size, "Capa preserva a colisao pequena")
	target.activate_from_below()
	check(not mario.is_growing and level.activated_boxes == 1, "Caixa usada nao transforma ou conta de novo")
	# Isola a fisica de planar das plataformas do mapa.
	level.remove_child(mario)
	root.add_child(mario)
	level.queue_free()
	await frames(2)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 500)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 32)
	collision.shape = rectangle
	floor_body.add_child(collision)
	root.add_child(floor_body)
	mario.fall_death_y = 2000
	mario.position = Vector2(0, 50)
	mario.velocity = Vector2(0, 300)
	mario.set_physics_process(true)
	Input.action_press("jump")
	Input.action_press("move_right")
	await frames(30)
	check(mario.is_gliding and mario.velocity.y > 0.0 and mario.velocity.y <= mario.glide_fall_speed + 0.1, "Segurar pulo limita a queda sem gerar voo ou subida")
	check(mario.sprite.animation == &"small_glide" and mario.cape.animation == &"glide", "Planar anima o corpo pequeno e a capa")
	check(mario.position.x > 40, "Mario pode dirigir horizontalmente enquanto plana")
	Input.action_release("move_right")
	Input.action_release("jump")
	await frames(10)
	check(not mario.is_gliding and mario.velocity.y > mario.glide_fall_speed + 70.0, "Soltar pulo devolve a gravidade normal")
	Input.action_press("jump")
	Input.action_press("move_left")
	await frames(18)
	check(mario.is_gliding and mario.sprite.flip_h and mario.cape.flip_h and mario.cape.position.x > 0, "Reabrir a capa e virar para esquerda funciona durante a descida")
	Input.action_release("move_left")
	for index in 500:
		if mario.is_on_floor():
			break
		await frames(1)
	check(mario.is_on_floor() and not mario.is_gliding and mario.cape.visible, "Pousar encerra planar e conserva a capa")
	Input.action_release("jump")
	await frames(1)
	Input.action_press("jump")
	await frames(2)
	check(mario.velocity.y < 0 and not mario.is_gliding and mario.sprite.animation == &"small_jump", "Salto sobe normalmente antes de planar")
	Input.action_release("jump")
	mario.set_physics_process(false)
	mario.is_swimming = true
	mario.velocity.y = 50
	Input.action_press("jump")
	mario._update_vertical_velocity(1.0 / 60.0)
	check(not mario.is_gliding, "Dentro da agua conserva a natacao sem planar")
	Input.action_release("jump")
	mario._respawn()
	check(not mario.has_cape and not mario.cape.visible and not mario.is_gliding, "Reiniciar remove a capa e o estado de planar")
	mario.position = Vector2(0, 458)
	mario.set_physics_process(true)
	await frames(2)
	mario.grow()
	await finish_transformation(mario)
	mario.set_physics_process(false)
	var feet: Vector2 = mario._feet_position()
	mario.equip_cape()
	mario.set_physics_process(true)
	await finish_transformation(mario)
	mario.set_physics_process(false)
	check(mario.has_cape and not mario.is_big and mario._feet_position().is_equal_approx(feet), "Mario grande vira pequeno com capa sem deslocar os pes")
	check(mario.body_shape.shape.size == mario._small_body_size and not mario._big_body_applied, "Transformar o grande restaura colisao pequena sem travar")
	mario.grow()
	check(not mario.is_growing, "Crescimento nao substitui o poder da capa")
	mario.die()
	check(mario.is_dead and not mario.cape.visible and not mario.is_gliding, "Morte esconde a capa e cancela planar")
	mario._respawn()
	mario.equip_cape()
	mario.queue_free()
	await frames(2)
	check(not paused, "Remover Mario durante a transformacao nao deixa o jogo pausado")
	floor_body.queue_free()
	await frames(2)
	print("CAPE FAILURES: ", failures)
	quit(failures)

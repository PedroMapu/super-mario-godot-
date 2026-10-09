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


func spawn_block(position: Vector2) -> StaticBody2D:
	var block := load("res://cenas/question_block.tscn").instantiate() as StaticBody2D
	block.position = position
	root.add_child(block)
	return block


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 216)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(3000, 32)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var block := spawn_block(Vector2(400, 80))
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(400, 150)
	mario.jump_velocity = -570.0
	root.add_child(mario)
	var activations: Array = []
	block.activated.connect(func() -> void: activations.append(true))
	await frames(20)
	check(mario.is_on_floor() and not block.used, "Bloco permanece intacto antes do salto")
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	for index in 60:
		if block.used:
			break
		await frames(1)
	check(block.used and activations.size() == 1, "Batida real da cabeca por baixo ativa o bloco uma vez")
	check(mario.velocity.y >= 0.0, "Colisao do bloco interrompe a subida do Mario")
	await frames(3)
	check(block.sprite.position.y < -1.0, "Imagem do bloco sobe durante a animacao")
	check(block.position == Vector2(400, 80) and not block.get_node("CollisionShape2D").disabled, "Colisao do bloco continua fixa e solida durante a animacao")
	await frames(20)
	check(block.sprite.position.is_equal_approx(Vector2.ZERO), "Imagem retorna a posicao inicial")
	check(block.sprite.texture == block.used_texture, "Bloco assume aparencia de usado")
	block.activate_from_below()
	await frames(3)
	check(activations.size() == 1 and block.sprite.position.is_equal_approx(Vector2.ZERO), "Bloco usado nao reinicia a animacao")

	var side_block := spawn_block(Vector2(800, 160))
	mario.position = Vector2(730, 174)
	mario.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await frames(25)
	Input.action_release("move_right")
	check(mario.is_on_wall() and not side_block.used, "Contato lateral real nao ativa o bloco")

	var top_block := spawn_block(Vector2(1100, 160))
	mario.position = Vector2(1100, 50)
	mario.velocity = Vector2.ZERO
	await frames(40)
	check(mario.is_on_floor() and not top_block.used, "Pousar em cima nao ativa o bloco")
	check(absf(mario._feet_position().y - 144.0) < 0.2, "Mario consegue ficar sobre o bloco")
	mario.queue_free()
	block.queue_free()
	side_block.queue_free()
	top_block.queue_free()
	floor_body.queue_free()
	await frames(2)

	# Confere a integracao com os tiles ja pintados em ambas as fases.
	for scene_path in ["res://cenas/level_01.tscn", "res://cenas/level_02.tscn"]:
		var level := load(scene_path).instantiate() as Node2D
		var ground := level.get_node("Mundo/Ground") as TileMapLayer
		var expected_cells: Array[Vector2i] = []
		for cell in ground.get_used_cells():
			if ground.get_cell_atlas_coords(cell) in [Vector2i(27, 15), Vector2i(1, 30)]:
				expected_cells.append(cell)
		var original_cell_count := ground.get_used_cells().size()
		var original_bounds: Rect2 = level.get_map_bounds()
		level.position = Vector2(128, 64)
		root.add_child(level)
		level.get_node("Mario").set_physics_process(false)
		await frames(2)
		var blocks := ground.get_children()
		check(blocks.size() == expected_cells.size(), "Fase converte todos os blocos pintados: " + scene_path)
		var correctly_replaced := true
		for cell in expected_cells:
			var replacement := ground.get_node("QuestionBlock_%d_%d" % [cell.x, cell.y]) as StaticBody2D
			correctly_replaced = correctly_replaced and ground.get_cell_source_id(cell) == -1
			correctly_replaced = correctly_replaced and replacement.position.is_equal_approx(ground.map_to_local(cell))
			correctly_replaced = correctly_replaced and replacement.collision_layer == 32 and not replacement.used
		check(correctly_replaced, "Blocos mantem posicao e camada de colisao, sem tile duplicado: " + scene_path)
		check(ground.get_used_cells().size() == original_cell_count - expected_cells.size(), "Outros tiles permanecem intactos: " + scene_path)
		check(level.get_map_bounds() == Rect2(original_bounds.position + level.position, original_bounds.size), "Conversao preserva dimensoes atuais do mapa: " + scene_path)
		if scene_path.contains("01"):
			check(expected_cells.size() == 3, "Tres blocos de interrogaçao da fase 1 ficam interativos")
		level.queue_free()
		await frames(2)
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

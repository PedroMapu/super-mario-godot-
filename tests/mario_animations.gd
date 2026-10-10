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
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 100)
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(2000, 32)
	floor_shape.shape = floor_rectangle
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(0, 20)
	root.add_child(mario)
	var sprite := mario.get_node("Animacao") as AnimatedSprite2D
	# Verifica a selecao durante o movimento, preservando os frames montados no editor.
	await frames(30)
	check(mario.is_on_floor() and sprite.animation == &"small_idle", "Ao pousar parado, Mario usa idle")
	Input.action_press("move_right")
	await frames(20)
	check(sprite.animation == &"small_walk" and not sprite.flip_h and mario.velocity.x > 0.0, "Movimento para direita usa walk na direcao correta")
	Input.action_release("move_right")
	await frames(20)
	check(sprite.animation == &"small_idle" and not sprite.flip_h, "Ao parar para direita, idle preserva direcao")
	Input.action_press("move_left")
	await frames(20)
	check(sprite.animation == &"small_walk" and sprite.flip_h and mario.velocity.x < 0.0, "Movimento para esquerda usa walk espelhado")
	Input.action_release("move_left")
	await frames(20)
	check(sprite.animation == &"small_idle" and sprite.flip_h, "Ao parar para esquerda, idle preserva direcao")
	mario.velocity.x = -30.0
	sprite.flip_h = false
	mario._update_animation(0.0)
	check(sprite.animation == &"small_walk" and sprite.flip_h, "Desaceleracao sem input acompanha velocidade horizontal")
	mario.velocity.x = 0.0
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(mario.velocity.y < 0.0 and sprite.animation == &"small_jump", "Salto real usa jump enquanto sobe")
	for index in 60:
		await frames(1)
		if mario.velocity.y > 0.0:
			break
	var fall_animation := &"small_fall" if sprite.sprite_frames.has_animation(&"small_fall") else &"small_jump"
	check(mario.velocity.y > 0.0 and sprite.animation == fall_animation, "Descida real usa fall ou pose de salto quando fall nao existe")
	await frames(30)
	check(mario.is_on_floor() and sprite.animation == &"small_idle" and sprite.flip_h, "Pouso restaura idle com direcao preservada")

	var water := TileMapLayer.new()
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	water.tile_set = tile_set
	water.add_to_group("water")
	for x in range(-3, 4):
		for y in range(5, 13):
			water.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	root.add_child(water)
	mario.global_position = Vector2(0, 200)
	mario.velocity = Vector2.ZERO
	await frames(2)
	check(mario.is_swimming and sprite.animation == &"small_swim_down" and mario.velocity.y > 0.0, "Mario solto na agua afunda usando swim_down")
	Input.action_press("move_right")
	await frames(12)
	check(mario.is_swimming and sprite.animation == &"small_swim_sides" and not sprite.flip_h and mario.velocity.x > 0.0, "Nado para direita seleciona swim_sides mesmo afundando")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await frames(12)
	check(mario.is_swimming and sprite.animation == &"small_swim_sides" and sprite.flip_h and mario.velocity.x < 0.0, "Nado para esquerda seleciona swim_sides espelhado")
	Input.action_release("move_left")
	await frames(12)
	check(sprite.animation == &"small_swim_down" and mario.velocity.y > 0.0 and is_zero_approx(mario.velocity.x), "Soltar movimento lateral restaura descida natural")

	# Apertar baixo deve vencer uma velocidade inicial de subida e acelerar o mergulho.
	mario.velocity.y = mario.swim_impulse
	Input.action_press("move_down")
	await frames(16)
	check(mario.velocity.y > mario.WATER_FALL_SPEED and sprite.animation == &"small_swim_down", "Baixo mergulha mais rapido que o afundamento natural")
	Input.action_press("move_right")
	await frames(10)
	check(sprite.animation == &"small_swim_down" and mario.velocity.x > 0.0 and mario.velocity.y > 0.0, "Baixo tem prioridade na animacao durante mergulho diagonal")
	Input.action_release("move_down")
	Input.action_release("move_right")

	# O comando de mergulho so atua dentro da agua.
	mario.global_position = Vector2(500, 58)
	mario.velocity = Vector2.ZERO
	Input.action_press("move_down")
	await frames(2)
	check(not mario.is_swimming and mario.is_on_floor() and sprite.animation == &"small_idle", "Baixo em terra nao ativa nado nem altera o repouso")
	Input.action_release("move_down")
	mario.queue_free()
	water.queue_free()
	floor_body.queue_free()
	await frames(2)
	print("MARIO ANIMATIONS FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

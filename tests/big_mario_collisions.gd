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


func obstacle(parent: Node, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.position = center
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	parent.add_child(body)


func player(world: Node) -> CharacterBody2D:
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(0, 174)
	world.add_child(mario)
	await frames(5)
	mario.grow()
	await frames(90)
	return mario


func visual_bounds(mario: CharacterBody2D) -> Rect2:
	var sprite := mario.get_node("Animacao") as AnimatedSprite2D
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var used := texture.get_image().get_used_rect()
	var origin := Vector2(used.position) - texture.get_size() * 0.5 + sprite.offset
	if sprite.flip_h:
		origin.x = texture.get_width() * 0.5 - used.end.x + sprite.offset.x
	return Rect2(sprite.to_global(origin), Vector2(used.size) * sprite.global_scale)


func shape_bounds(shape: CollisionShape2D) -> Rect2:
	var rectangle := shape.shape as RectangleShape2D
	return Rect2(shape.to_global(-rectangle.size * 0.5), rectangle.size * shape.global_scale)


func check_geometry() -> void:
	var world := Node2D.new()
	root.add_child(world)
	obstacle(world, Vector2(0, 216), Vector2(2000, 32))
	var mario := await player(world)
	var small_body: Vector2 = mario._small_body_size
	var small_damage: Vector2 = mario._small_damage_size
	check(mario.is_big and mario._big_body_applied and mario.is_on_floor(), "Crescimento real termina com corpo grande apoiado")
	for flipped in [false, true]:
		mario.sprite.flip_h = flipped
		var visible := visual_bounds(mario)
		var body := shape_bounds(mario.body_shape)
		var damage := shape_bounds(mario.damage_shape)
		check(absf(body.position.y - visible.position.y) < 0.2, "Topo do corpo acompanha o chapeu parado: espelhado=" + str(flipped))
		check(absf(body.end.y - visible.end.y) < 0.2 and absf(body.end.y - 200) < 0.2,
			"Pes visuais e fisicos apoiam no mesmo piso")
		check(visible.grow(0.1).encloses(damage), "Area de dano fica dentro do sprite: espelhado=" + str(flipped))
		check(visible.grow(0.1).encloses(body), "Corpo fica dentro do contorno visivel parado")
	# A mesma geometria deve parar nas paredes dos dois lados, sem penetracao.
	obstacle(world, Vector2(316, 100), Vector2(32, 200))
	obstacle(world, Vector2(-316, 100), Vector2(32, 200))
	for direction in ["move_right", "move_left"]:
		mario.position = Vector2(0, 174)
		mario.velocity = Vector2.ZERO
		Input.action_press(direction)
		await frames(90)
		Input.action_release(direction)
		var body := shape_bounds(mario.body_shape)
		check(mario.is_on_wall() and mario.is_on_floor(), "Mario grande para na parede sem perder apoio: " + direction)
		check(body.position.x >= -300.1 and body.end.x <= 300.1, "Colisor nao atravessa parede: " + direction)
	mario._respawn()
	check(mario.body_shape.shape.size == small_body and mario.damage_shape.shape.size == small_damage,
		"Respawn restaura corpo e area de dano pequenos")
	world.queue_free()
	await frames(2)


func check_passage(gap: float, should_pass: bool) -> void:
	var world := Node2D.new()
	root.add_child(world)
	obstacle(world, Vector2(0, 216), Vector2(2000, 32))
	var mario := await player(world)
	# Cresce antes de entrar: a passagem deve ser testada com o corpo grande.
	obstacle(world, Vector2(160, 200 - gap - 16), Vector2(120, 32))
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	check(mario.is_on_floor() and not mario.is_dead, "Passagem conserva apoio e vida: vao=" + str(gap))
	check(mario.position.x > 250 if should_pass else mario.position.x < 100 and mario.is_on_wall(),
		"Atravessa somente passagem com altura suficiente: vao=" + str(gap))
	# Retorna para fora do teto e salta verticalmente contra ele.
	mario.position = Vector2(160, 174) if should_pass else Vector2(0, 174)
	mario.velocity = Vector2.ZERO
	await frames(3)
	Input.action_press("jump")
	var hit_ceiling := false
	for index in 12:
		await frames(1)
		hit_ceiling = hit_ceiling or mario.is_on_ceiling()
	Input.action_release("jump")
	if should_pass:
		check(hit_ceiling, "Salto bate no teto proximo sem atravessar")
	await frames(100)
	check(mario.is_on_floor() and not mario.is_dead, "Mario volta ao chao depois do salto")
	world.queue_free()
	await frames(2)


func check_hazards() -> void:
	var world := Node2D.new()
	root.add_child(world)
	obstacle(world, Vector2(0, 216), Vector2(2000, 32))
	var mario := await player(world)
	await frames(45) # Aguarda a protecao temporaria do crescimento terminar.
	var hazard := Area2D.new()
	hazard.collision_layer = 128
	hazard.collision_mask = 0
	hazard.position = mario.position + Vector2(0, -34)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 2)
	collision.shape = rectangle
	hazard.add_child(collision)
	world.add_child(hazard)
	await frames(4)
	check(not mario.is_dead and mario.lives == mario.MAX_LIVES,
		"Perigo acima do chapeu nao causa dano por uma caixa invisivel")
	hazard.position = mario.damage_shape.global_position
	await frames(4)
	check(mario.is_dead, "Contato real dentro do corpo continua detectando perigo")
	mario._respawn()
	world.queue_free()
	await frames(2)


func _run() -> void:
	await check_geometry()
	await check_passage(58, true)
	await check_passage(54, false)
	await check_hazards()
	for child in root.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.queue_free()
	await frames(2)
	print("BIG MARIO COLLISIONS FAILURES: ", failures)
	quit(1 if failures else 0)

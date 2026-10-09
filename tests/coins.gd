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


func spawn_coin(position: Vector2) -> Area2D:
	var coin := load("res://cenas/coin.tscn").instantiate() as Area2D
	coin.position = position
	root.add_child(coin)
	return coin


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 96)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 32)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(-90, 54)
	root.add_child(mario)
	var damage_events: Array = []
	mario.enemy_contact.connect(func(_source: Node2D) -> void: damage_events.append(true))
	mario.hazard_contact.connect(func(_source: Node2D) -> void: damage_events.append(true))
	var coin := spawn_coin(Vector2(0, 50))
	var second_coin := spawn_coin(Vector2(250, 50))
	var collectors: Array[CharacterBody2D] = []
	coin.collected.connect(func(player: CharacterBody2D) -> void: collectors.append(player))
	check(coin.sprite.is_playing() and coin.sprite.sprite_frames.get_frame_count(&"spin") == 6, "Moeda inicia girando com os seis recortes existentes")
	check(coin.collision_layer == 0 and coin.collision_mask == 1, "Moeda monitora o jogador sem ser um obstaculo")

	# Um outro corpo na camada do jogador ainda nao deve coletar a moeda.
	var other_body := CharacterBody2D.new()
	other_body.collision_layer = 1
	other_body.position = Vector2(0, 50)
	var other_shape := CollisionShape2D.new()
	var other_rectangle := RectangleShape2D.new()
	other_rectangle.size = Vector2(10, 10)
	other_shape.shape = other_rectangle
	other_body.add_child(other_shape)
	root.add_child(other_body)
	await frames(3)
	check(not coin.is_collected and collectors.is_empty(), "Outro corpo nao coleta a moeda")
	other_body.queue_free()
	await frames(2)
	check(mario.is_in_group("player"), "Mario se identifica no grupo de jogadores")
	Input.action_press("move_right")
	for index in 60:
		await frames(1)
		if is_instance_valid(coin) and coin.is_collected:
			break
	Input.action_release("move_right")
	check(is_instance_valid(coin) and coin.is_collected and collectors.size() == 1 and collectors[0] == mario, "Passagem real do Mario coleta e emite o sinal uma vez")
	if is_instance_valid(coin):
		coin._on_body_entered(mario)
	await frames(3)
	check(collectors.size() == 1, "Contatos repetidos nao duplicam a coleta")
	check(is_instance_valid(coin) and not coin.monitoring and coin.collision_shape.disabled, "Area da moeda e desativada ao coletar")
	check(is_instance_valid(coin) and coin.sprite.position.y < 0.0 and coin.sprite.modulate.a > 0.0 and coin.sprite.modulate.a < 1.0, "Moeda sobe levemente e perde opacidade durante a coleta")
	check(not second_coin.is_collected and second_coin.sprite.modulate.a == 1.0 and not second_coin.collision_shape.disabled, "Coletar uma instancia nao altera as outras moedas")
	await frames(18)
	check(not is_instance_valid(coin), "Moeda e removida ao terminar a animacao")
	check(damage_events.is_empty() and mario._damage_grace == 0.0, "Coleta nao causa dano ao Mario")

	# Uma moeda tambem pode ser coletada com Mario ja sobre sua posicao.
	mario.set_physics_process(false)
	mario.position = Vector2(500, 50)
	var spawned_coin := spawn_coin(Vector2(500, 50))
	spawned_coin.collect_rise = 4.0
	spawned_coin.collect_duration = 0.1
	# A sincronizacao do teleporte e o body_entered chegam em passos distintos da fisica.
	await frames(4)
	check(is_instance_valid(spawned_coin) and spawned_coin.is_collected, "Moeda criada sobre Mario tambem detecta o contato")
	await frames(10)
	check(not is_instance_valid(spawned_coin), "Duracao personalizada da coleta funciona")
	mario.position = Vector2(250, 50)
	await frames(4)
	check(second_coin.is_collected, "Mario consegue coletar a proxima moeda independentemente")
	await frames(18)
	check(not is_instance_valid(second_coin), "Segunda moeda tambem desaparece ao concluir a coleta")
	mario.queue_free()
	floor_body.queue_free()
	await frames(2)
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

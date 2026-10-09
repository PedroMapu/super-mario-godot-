extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)


func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func spawn(scene_path: String, position: Vector2) -> CharacterBody2D:
	var body := load(scene_path).instantiate() as CharacterBody2D
	body.position = position
	root.add_child(body)
	return body


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 100)
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 32)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var wall := StaticBody2D.new()
	wall.collision_layer = 16
	wall.position = Vector2(-100, 50)
	var wall_shape := CollisionShape2D.new()
	var wall_rectangle := RectangleShape2D.new()
	wall_rectangle.size = Vector2(16, 100)
	wall_shape.shape = wall_rectangle
	wall.add_child(wall_shape)
	root.add_child(wall)

	for scene_path in ["res://cenas/goomba.tscn", "res://cenas/koompa.tscn"]:
		var patrol_enemy := spawn(scene_path, Vector2(400, 72))
		patrol_enemy.patrol_amplitude = 24.0
		patrol_enemy.walk_speed = 120.0
		var visited_left := false
		var visited_right := false
		var crossed_center := false
		var stayed_in_bounds := true
		for index in 160:
			await frames(1)
			var offset: float = patrol_enemy.global_position.x - 400.0
			visited_left = visited_left or offset < -23.0
			visited_right = visited_right or offset > 23.0
			crossed_center = crossed_center or (visited_left and offset > 0.0)
			stayed_in_bounds = stayed_in_bounds and absf(offset) <= 24.01
		check(visited_left and visited_right and crossed_center, "Patrulha passa pelo centro e chega aos dois extremos: " + scene_path)
		check(stayed_in_bounds, "Patrulha respeita amplitude sem deriva: " + scene_path)
		patrol_enemy.queue_free()
		await frames(2)

	var stationary := spawn("res://goomba.tscn", Vector2(400, 76))
	stationary.patrol_amplitude = 0.0
	await frames(10)
	check(is_equal_approx(stationary.global_position.x, 400.0) and stationary.is_on_floor(), "Amplitude zero para caminhada e mantem gravidade")
	stationary.patrol_amplitude = 0.5
	stationary.walk_speed = 50000.0
	var fast_in_bounds := true
	for index in 10:
		await frames(1)
		fast_in_bounds = fast_in_bounds and absf(stationary.global_position.x - 400.0) <= 0.51
	check(fast_in_bounds, "Velocidade alta nao ultrapassa amplitude pequena")
	stationary.queue_free()
	await frames(2)

	var goomba := spawn("res://cenas/goomba.tscn", Vector2(-75, 76))
	await frames(50)
	check(goomba.is_on_floor(), "Goomba colide com o chao")
	check(goomba.direction == 1, "Goomba inverte ao bater na parede")
	check(goomba.sprite.is_playing(), "Animacao de caminhada toca")
	goomba.queue_free()
	await frames(2)

	var mario := spawn("res://cenas/mario.tscn", Vector2(300, 20))
	goomba = spawn("res://cenas/goomba.tscn", Vector2(300, 76))
	goomba.walk_speed = 0.0
	await frames(20)
	check(goomba.defeated, "Pisao real do Mario derrota o Goomba")
	check(goomba.sprite.animation == &"goomba_flat", "Pisao mostra Goomba achatado")
	check(mario.velocity.y < 0.0, "Mario rebate apos o pisao")
	await frames(45)
	check(not is_instance_valid(goomba), "Goomba achatado desaparece")
	mario.queue_free()
	await frames(2)

	mario = spawn("res://cenas/mario.tscn", Vector2(300, 20))
	var koopa := spawn("res://cenas/koompa.tscn", Vector2(300, 72))
	koopa.walk_speed = 0.0
	await frames(20)
	check(koopa.state == koopa.State.SHELL_MOVING, "Pisao real transforma Koopa em casco deslizando")
	check(koopa.body_shape.shape.size == Vector2(14, 12), "Colisor encolhe no casco")
	check(koopa.collision_layer == 8, "Casco usa camada propria")
	mario.set_physics_process(false)
	koopa.contact_grace = 0.0
	koopa.on_player_contact(mario, true)
	check(koopa.state == koopa.State.SHELL_IDLE, "Pisao para o casco automatico")
	mario.position = koopa.position + Vector2(-20, 0)
	koopa.contact_grace = 0.0
	koopa.on_player_contact(mario, false)
	check(koopa.state == koopa.State.SHELL_MOVING and koopa.direction == 1, "Mario chuta casco para longe")
	goomba = spawn("res://goomba.tscn", Vector2(koopa.position.x + 70, 76))
	goomba.walk_speed = 0.0
	await frames(18)
	check(goomba.defeated, "Casco em movimento derrota outro inimigo")
	koopa.contact_grace = 0.0
	koopa.on_player_contact(mario, true)
	check(koopa.state == koopa.State.SHELL_IDLE, "Novo pisao para o casco")
	koopa.queue_free()
	mario.queue_free()
	await frames(2)

	mario = spawn("res://cenas/mario.tscn", Vector2(500, 71))
	goomba = spawn("res://cenas/goomba.tscn", Vector2(540, 76))
	goomba.walk_speed = 0.0
	var contacts: Array = []
	mario.enemy_contact.connect(func(source: Node2D) -> void: contacts.append(source))
	Input.action_press("move_right")
	await frames(18)
	Input.action_release("move_right")
	check(not contacts.is_empty(), "Contato lateral causa dano")
	check(not mario.is_dead and mario.lives == 1, "Contato lateral com Goomba remove duas vidas sem matar Mario com tres")
	check(mario._damage_grace > 0.0, "Dano concede protecao temporaria")
	check(not goomba.defeated, "Contato lateral nao achata Goomba")
	mario.queue_free()
	goomba.queue_free()
	await frames(2)

	mario = spawn("res://cenas/mario.tscn", Vector2(600, 71))
	koopa = spawn("res://koompa.tscn", Vector2(640, 72))
	koopa.stomp(mario)
	koopa.stomp(mario)
	await frames(2)
	Input.action_press("move_right")
	await frames(18)
	Input.action_release("move_right")
	check(koopa.state == koopa.State.SHELL_MOVING, "Contato lateral real chuta casco parado")
	koopa.queue_free()
	mario.queue_free()
	await frames(2)

	mario = spawn("res://cenas/mario.tscn", Vector2(600, 71))
	koopa = spawn("res://cenas/koompa.tscn", Vector2(650, 72))
	koopa.stomp(mario)
	await frames(2)
	koopa.state = koopa.State.SHELL_MOVING
	koopa.direction = -1
	var shell_contacts: Array = []
	mario.enemy_contact.connect(func(source: Node2D) -> void: shell_contacts.append(source))
	await frames(15)
	check(not shell_contacts.is_empty(), "Casco em movimento causa dano lateral")
	# O mundo pausa durante a morte; encerra a sequencia antes de testar a parede.
	mario._respawn()
	mario.set_physics_process(false)
	koopa.position = Vector2(-65, 78)
	koopa.direction = -1
	await frames(8)
	check(koopa.direction == 1, "Casco rebate na parede")
	koopa.queue_free()
	mario.queue_free()
	await frames(2)

	mario = spawn("res://cenas/mario.tscn", Vector2(450, 71))
	mario.set_physics_process(false)
	koopa = spawn("res://cenas/koompa.tscn", Vector2(500, 0))
	koopa.direction = 1
	koopa.patrol_amplitude = 1.0
	koopa.shell_speed = 80.0
	koopa.stomp(mario)
	check(koopa.shell_duration == 4.0, "Casco tem 4 segundos antes das piscadas por padrao")
	await frames(120)
	check(koopa.is_on_floor() and koopa.position.x > 600.0, "Casco desliza com gravidade alem dos limites da patrulha")
	koopa.stomp(mario)
	var paused_x: float = koopa.position.x
	await frames(10)
	check(is_equal_approx(koopa.position.x, paused_x), "Pisao mantem casco parado durante a vida util")
	koopa.contact_grace = 0.0
	koopa.on_player_contact(mario, false)
	await frames(100)
	check(is_instance_valid(koopa) and koopa.sprite.visible, "Casco permanece visivel antes dos 4 segundos")
	var blinking_started_x: float = koopa.position.x
	var saw_hidden := false
	var saw_visible := false
	for index in 50:
		await frames(1)
		if is_instance_valid(koopa):
			saw_hidden = saw_hidden or not koopa.sprite.visible
			saw_visible = saw_visible or koopa.sprite.visible
	check(saw_hidden and saw_visible, "Casco alterna visibilidade depois dos 4 segundos")
	check(is_instance_valid(koopa) and koopa.position.x > blinking_started_x, "Casco continua deslizando durante as piscadas")
	await frames(30)
	check(not is_instance_valid(koopa), "Casco desaparece apos piscar; parar e chutar nao reiniciam o tempo")
	mario.queue_free()
	await frames(2)

	for scene_path in ["res://goomba.tscn", "res://koompa.tscn", "res://cenas/goomba.tscn", "res://cenas/koompa.tscn"]:
		var enemy := spawn(scene_path, Vector2(800, 0))
		check(enemy.get_node("Colisao").shape != null, "Cena reutilizavel: " + scene_path)
		enemy.queue_free()
	var level := load("res://cenas/level_01.tscn").instantiate() as Node2D
	root.add_child(level)
	await frames(2)
	check(level.has_node("Inimigos/Goomba") and level.has_node("Inimigos/Koopa"), "Fase 1 inclui Goomba e Koopa")
	level.queue_free()
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

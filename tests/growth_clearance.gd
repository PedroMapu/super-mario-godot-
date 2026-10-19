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
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	parent.add_child(body)


func check_low_ceiling(gap: float) -> void:
	var world := Node2D.new()
	root.add_child(world)
	obstacle(world, Vector2(0, 216), Vector2(2000, 32))
	obstacle(world, Vector2(0, 200 - gap - 16), Vector2(64, 32))
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(0, 174)
	world.add_child(mario)
	await frames(5)
	mario.grow()
	await frames(90)
	check(mario.is_big and not mario.is_growing and not paused, "Transformacao termina sob teto com vao de " + str(gap))
	check(not mario._big_body_applied and mario.is_on_floor(), "Colisor aguarda folga sem prender entre piso e teto: " + str(gap))
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	await frames(20)
	check(mario.position.x > 200 and mario.is_on_floor(), "Mario sai andando debaixo do teto: " + str(gap))
	check(mario._big_body_applied and absf(mario._feet_position().y - 200) < 0.2,
		"Corpo expande ao sair do teto e conserva apoio dos pes: " + str(gap))
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(mario.velocity.y < 0 and mario.sprite.animation == &"big_jump", "Mario continua pulando depois de sair do teto")
	await frames(100)
	check(mario.is_on_floor() and mario.sprite.animation == &"big_idle", "Salto termina sem travar depois de crescer")
	world.queue_free()
	await frames(2)


func check_growth_block() -> void:
	var level := load("res://cenas/level_01.tscn").instantiate() as Node2D
	level.intro_enabled = false
	root.add_child(level)
	var mario: CharacterBody2D = level.mario
	mario.set_physics_process(false)
	for enemy in level.get_node("Inimigos").get_children():
		enemy.queue_free()
	await frames(3)
	var block := level.get_node("Mundo/Ground/QuestionBlock_53_-9") as StaticBody2D
	mario.global_position = block.global_position + Vector2(0, 50)
	mario.velocity = Vector2(0, -270)
	mario.set_physics_process(true)
	await frames(90)
	check(mario.is_big and not mario.is_growing, "Cabecada na caixa real termina o crescimento")
	check(mario.is_on_floor() and mario._big_body_applied,
		"Na fase 1, o corpo cabe entre a caixa e a plataforma sem travar")
	var start_x := mario.position.x
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(mario.position.x > start_x + 40 and mario._big_body_applied,
		"Mario sai da caixa real andando com corpo grande sem prender")
	level.queue_free()
	await frames(2)


func _run() -> void:
	for gap in [56.0, 56.1]:
		await check_low_ceiling(gap)
	await check_growth_block()
	print("GROWTH CLEARANCE FAILURES: ", failures)
	quit(1 if failures else 0)

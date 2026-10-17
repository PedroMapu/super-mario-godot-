extends SceneTree

const ENEMY_SCALE := Vector2(2.25, 2.25)
const FLOOR_TOP := 200.0

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


func spawn_enemy(scene_path: String) -> CharacterBody2D:
	var enemy := load(scene_path).instantiate() as CharacterBody2D
	enemy.scale = ENEMY_SCALE
	enemy.position = Vector2(300, 100)
	enemy.walk_speed = 0.0
	root.add_child(enemy)
	return enemy


func collision_bottom(enemy: CharacterBody2D) -> float:
	var shape := enemy.get_node("Colisao") as CollisionShape2D
	var rectangle := shape.shape as RectangleShape2D
	return shape.to_global(Vector2(0, rectangle.size.y * 0.5)).y


func _run() -> void:
	for number in ["01", "02"]:
		var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
		var enemies := level.get_node("Inimigos").get_children()
		check(not enemies.is_empty(), "Fase " + number + " tem inimigos para conferir")
		for enemy: CharacterBody2D in enemies:
			check(enemy.scale == ENEMY_SCALE, "Escala 2.25 na fase " + number + ": " + enemy.name)
			var shape := enemy.get_node("Colisao") as CollisionShape2D
			var sprite := enemy.get_child(0) as AnimatedSprite2D
			check(shape.scale == Vector2.ONE and sprite.scale == Vector2.ONE,
				"Sprite e colisao herdam a mesma escala: " + enemy.name)
		if number == "02":
			check(level.get_node("Inimigos/Goomba4").scale == level.get_node("Inimigos/Goomba6").scale,
				"Goombas 4 e 6 mantem a escala de referencia")
		level.free()

	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(300, FLOOR_TOP + 16.0)
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(2000, 32)
	floor_shape.shape = floor_rectangle
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	for scene_path in ["res://cenas/goomba.tscn", "res://cenas/koompa.tscn"]:
		var enemy := spawn_enemy(scene_path)
		await frames(45)
		check(enemy.is_on_floor() and absf(collision_bottom(enemy) - FLOOR_TOP) < 0.2,
			"Inimigo ampliado apoia os pes no chao: " + scene_path)
		var shape := enemy.get_node("Colisao") as CollisionShape2D
		var rectangle := shape.shape as RectangleShape2D
		var query := PhysicsRayQueryParameters2D.create(
			shape.global_position - Vector2(100, 0), shape.global_position + Vector2(100, 0), 4)
		var hit := root.world_2d.direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.x - (shape.global_position.x - rectangle.size.x * 2.25 * 0.5)) < 0.2,
			"Fisica usa a largura ampliada do colisor: " + scene_path)
		query = PhysicsRayQueryParameters2D.create(
			shape.global_position - Vector2(0, 100), shape.global_position + Vector2(0, 100), 4)
		hit = root.world_2d.direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - enemy.collision_top()) < 0.2,
			"Topo usado pelo pisao coincide com a colisao real: " + scene_path)

		var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
		mario.position = Vector2(enemy.position.x, enemy.collision_top() - 80.0)
		root.add_child(mario)
		for index in 45:
			await frames(1)
			if enemy.defeated or (enemy.has_method("_transform_into_shell") and enemy.state != enemy.State.WALKING):
				break
		check(mario.velocity.y < 0.0, "Mario rebate em pisao real no inimigo ampliado: " + scene_path)
		if enemy.has_method("_transform_into_shell"):
			check(enemy.state == enemy.State.SHELL_MOVING, "Koopa ampliado vira casco ao receber pisao")
			mario.set_physics_process(false)
			await frames(2)
			check(absf(collision_bottom(enemy) - FLOOR_TOP) < 0.2,
				"Casco ampliado mantem os pes na altura do chao")
			check(shape.shape.size == Vector2(14, 12) and shape.global_scale == ENEMY_SCALE,
				"Colisao do casco acompanha a escala 2.25")
		else:
			check(enemy.defeated, "Pisao real derrota Goomba ampliado")
		enemy.queue_free()
		mario.queue_free()
		await frames(2)

	var goomba := spawn_enemy("res://cenas/goomba.tscn")
	await frames(45)
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(210, FLOOR_TOP - 26.0)
	root.add_child(mario)
	Input.action_press("move_right")
	await frames(25)
	Input.action_release("move_right")
	check(mario.lives == 1 and not goomba.defeated, "Contato lateral com Goomba ampliado causa dano sem pisao")
	mario.queue_free()
	goomba.queue_free()
	await frames(2)
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

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
	var level := load("res://cenas/level_02.tscn").instantiate() as Node2D
	level.intro_enabled = false
	root.add_child(level)
	var mario := level.get_node("Mario") as CharacterBody2D
	mario.set_physics_process(false)
	for enemy in level.get_node("Inimigos").get_children():
		enemy.queue_free()
	var layer := level.get_node("Mundo/perigos") as TileMapLayer
	await frames(3)
	var continuous_floor := true
	for column in range(37, 60):
		var cell := Vector2i(column, -2)
		var top := layer.to_global(layer.map_to_local(cell) - Vector2(16, 16))
		var supported := true
		var harmless := true
		for pixel in range(32):
			var point := top + Vector2(pixel + 0.5, 0)
			var query := PhysicsRayQueryParameters2D.create(point - Vector2(0, 1), point + Vector2(0, 1), 2)
			var hit := root.world_2d.direct_space_state.intersect_ray(query)
			supported = supported and not hit.is_empty()
			if not hit.is_empty():
				supported = supported and absf(hit.position.y - top.y) < 0.1
			query.collision_mask = 128
			harmless = harmless and root.world_2d.direct_space_state.intersect_ray(query).is_empty()
		check(supported, "Chao continuo em toda a largura do tile " + str(cell))
		check(harmless, "Tile nao usa colisao de perigo: " + str(cell))
		continuous_floor = continuous_floor and supported and harmless
	# Evita iniciar a morte/pausa da fase quando o piso ainda estiver quebrado.
	if continuous_floor:
		for column in range(37, 60):
			var center := layer.to_global(layer.map_to_local(Vector2i(column, -2)))
			mario.global_position = center - Vector2(0, 16 + 26 + 48)
			mario.velocity = Vector2.ZERO
			mario.set_physics_process(true)
			await frames(40)
			check(mario.is_on_floor() and absf(mario._feet_position().y - (center.y - 16)) < 0.5,
				"Mario pousa e permanece apoiado em " + str(Vector2i(column, -2)))
			check(not mario.is_dead and mario.lives == mario.MAX_LIVES, "Pouso conserva as vidas do Mario")
			mario.set_physics_process(false)
		for direction in ["move_left", "move_right"]:
			mario.velocity = Vector2.ZERO
			var start_x := mario.global_position.x
			mario.set_physics_process(true)
			Input.action_press(direction)
			var stayed_on_floor := true
			for index in 160:
				await frames(1)
				stayed_on_floor = stayed_on_floor and mario.is_on_floor() and not mario.is_dead
			Input.action_release(direction)
			mario.set_physics_process(false)
			check(stayed_on_floor and absf(mario.global_position.x - start_x) > 32 * 21,
				"Mario percorre o trecho sem cair: " + direction)
	level.queue_free()
	await frames(2)
	print("Failures: ", failures)
	quit(1 if failures else 0)

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


func check_lava(layer: TileMapLayer, expected_count: int, mask: int) -> void:
	check(layer.get_used_cells().size() == expected_count, "Todas as celulas de lava preservadas: " + str(layer.name))
	var aligned := true
	var supported := true
	for cell in layer.get_used_cells():
		var center := layer.to_global(layer.map_to_local(cell))
		var expected_center: Vector2 = layer.get_parent().to_global(Vector2(cell) * 32 + Vector2(16, 16))
		aligned = aligned and center.is_equal_approx(expected_center)
		# Centro e duas bordas: verifica area real de colisao sem criar lacunas.
		for offset in [-15.5, 0.0, 15.5]:
			var query := PhysicsRayQueryParameters2D.create(center + Vector2(offset, -18), center + Vector2(offset, 18), mask)
			var hit := root.world_2d.direct_space_state.intersect_ray(query)
			supported = supported and not hit.is_empty()
			if not hit.is_empty():
				supported = supported and hit.collider == layer and absf(hit.position.y - (center.y - 16)) < 0.01
	check(aligned, "Lava ocupa os mesmos tiles de 32 px: " + str(layer.name))
	check(supported, "Colisao real conserva topo, largura e camada: " + str(layer.name))


func _run() -> void:
	for number in ["01", "02"]:
		var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
		level.position = Vector2(128, 64)
		root.add_child(level)
		var mario := level.get_node("Mario") as CharacterBody2D
		mario.set_physics_process(false)
		for enemy in level.get_node("Inimigos").get_children():
			enemy.queue_free()
		await frames(3)
		var lava := level.get_node("Mundo/Lava") as TileMapLayer
		check_lava(lava, 15 if number == "01" else 51, 128)
		if number == "01":
			check_lava(level.get_node("Mundo/LavaGround"), 35, 16)
			var water := level.get_node("Mundo/agua") as TileMapLayer
			check(water.get_used_cells().size() == 84 and not water.collision_enabled, "Agua conserva area de nado sem colisao solida")
			var surface := water.to_global(water.map_to_local(Vector2i(97, 6))) - Vector2(0, 16)
			mario.global_position = surface - Vector2(0, 30)
			check(not mario._is_in_water(), "Acima da superficie, Mario permanece fora da agua")
			mario.global_position = surface - Vector2(0, 14)
			check(mario._is_in_water(), "Entrada na agua continua detectada pelos pes")
			mario.velocity = Vector2.ZERO
			mario.set_physics_process(true)
			await frames(12)
			check(mario.is_swimming and not mario.is_dead and mario.velocity.y <= mario.WATER_FALL_SPEED, "Mario nada na agua nova com a fisica original")
			mario.set_physics_process(false)
		# AreaDano real, com o mesmo contato fatal da lava anterior.
		var first_cell := lava.get_used_cells()[0]
		mario.global_position = lava.to_global(lava.map_to_local(first_cell)) - Vector2(0, 26)
		await frames(4)
		check(mario.is_dead, "Lava continua causando morte ao contato na fase " + number)
		level.queue_free()
		await frames(3)
	print("Falhas: ", failures)
	quit(1 if failures else 0)

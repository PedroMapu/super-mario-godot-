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


func check_passage(mario: CharacterBody2D, top: Vector2, description: String) -> void:
	# Usa o colisor real do Mario, atravessando toda a espessura por baixo.
	mario.global_position = top + Vector2(0, 80)
	var passed := true
	for index in 20:
		await frames(1)
		mario.velocity = Vector2(0, -600)
		mario.move_and_slide()
		passed = passed and not mario.is_on_ceiling()
		if mario._feet_position().y < top.y - 4:
			break
	check(passed and mario._feet_position().y < top.y - 4, "Atravessa por baixo sem bater a cabeca: " + description)
	for index in 20:
		await frames(1)
		mario.velocity = Vector2(0, 600)
		mario.move_and_slide()
		if mario.is_on_floor():
			break
	check(mario.is_on_floor() and absf(mario._feet_position().y - top.y) < 0.5, "Pousa somente no topo: " + description)
	for index in 3:
		await frames(1)
		mario.velocity = Vector2(0, 100)
		mario.move_and_slide()
	check(mario.is_on_floor() and absf(mario._feet_position().y - top.y) < 0.5, "Permanece apoiado por cima: " + description)


func _run() -> void:
	for number in ["01", "02"]:
		var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
		root.add_child(level)
		var mario := level.get_node("Mario") as CharacterBody2D
		var normal_mask := mario.collision_mask
		mario.set_physics_process(false)
		mario.get_node("AreaDano").monitoring = false
		mario.collision_mask = 2
		for enemy in level.get_node("Inimigos").get_children():
			enemy.queue_free()
		await frames(3)
		var count := 0
		for platform in get_nodes_in_group("falling_platforms"):
			if not level.is_ancestor_of(platform):
				continue
			count += 1
			await check_passage(mario, platform.global_position + Vector2(32, -16), number + "/" + str(platform.name))
			check(platform.state == platform.State.IDLE, "Atravessar por baixo nao ativa desabamento")
			mario._check_platform_contacts()
			check(platform.state == platform.State.SHAKING, "Pousar por cima continua ativando desabamento")
			platform.reset_platform()
		check(count == (8 if number == "01" else 3), "Todas as plataformas laranjas verificadas na fase " + number)
		if number == "02":
			mario.get_node("AreaDano").monitoring = true
			var hazards := level.get_node("Mundo/perigos") as TileMapLayer
			var roof_count := 0
			for cell in hazards.get_used_cells():
				var atlas := hazards.get_cell_atlas_coords(cell)
				if atlas.y != 18 or atlas.x < 3 or atlas.x > 5:
					continue
				roof_count += 1
				await check_passage(mario, hazards.to_global(hazards.map_to_local(cell)), "teto " + str(cell))
			check(roof_count == 23, "Toda a largura do teto com pilares foi verificada")
			# O trecho final nao possui caixas de bonus no caminho do salto.
			mario.collision_mask = normal_mask
			await check_passage(mario, hazards.to_global(hazards.map_to_local(Vector2i(59, -8))), "teto com mascara normal do Mario")
			mario.velocity = Vector2.ZERO
			mario.set_physics_process(true)
			await frames(60)
			check(mario.is_on_floor(), "Fisica normal do Mario mantem apoio no teto")
			check(not mario.is_dead and mario.lives == mario.MAX_LIVES, "O teto nao causa dano com as colisoes normais do Mario")
		level.queue_free()
		await frames(3)
	print("Failures: ", failures)
	quit(1 if failures else 0)

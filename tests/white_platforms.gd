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


func _check_motion_and_rider(axis: Vector2) -> void:
	var platform := load("res://cenas/white_platform.tscn").instantiate() as AnimatableBody2D
	platform.position = Vector2(300, 200)
	platform.eixo = axis
	platform.amplitude = 32.0
	platform.periodo = 3.0
	root.add_child(platform)
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(300, 110)
	root.add_child(mario)
	var landed := false
	for index in 90:
		await frames(1)
		if mario.is_on_floor():
			landed = true
			break
	check(landed and not mario.is_dead, "Mario pousa na plataforma oscilante: " + str(axis))
	var relative_x: float = mario.global_position.x - platform.global_position.x
	var carried := true
	var moved_left := false
	var moved_right := false
	for index in 360:
		await frames(1)
		var displacement: Vector2 = platform.position - platform._center
		carried = carried and mario.is_on_floor() and not mario.is_dead
		carried = carried and absf(mario._feet_position().y - (platform.global_position.y - 16.0)) < 0.5
		carried = carried and absf(mario.global_position.x - platform.global_position.x - relative_x) < 1.0
		carried = carried and displacement.length() <= platform.amplitude + 0.1
		moved_left = moved_left or displacement.dot(axis) < -31.0
		moved_right = moved_right or displacement.dot(axis) > 31.0
	check(carried and moved_left and moved_right, "Colisao e Mario acompanham ida e volta completa dentro da amplitude: " + str(axis))
	paused = true
	var paused_position := platform.position
	await frames(12)
	check(platform.position == paused_position, "Oscilacao respeita pausa: " + str(axis))
	paused = false
	await frames(12)
	check(platform.position != paused_position, "Oscilacao continua depois da pausa: " + str(axis))
	platform.amplitude = 0.0
	await frames(2)
	check(platform.position.is_equal_approx(platform._center), "Amplitude zero deixa a plataforma parada no centro")
	mario.queue_free()
	platform.queue_free()
	await frames(2)


func _check_level() -> void:
	var level := load("res://cenas/level_02.tscn").instantiate() as Node2D
	root.add_child(level)
	current_scene = level
	var mario := level.get_node("Mario") as CharacterBody2D
	mario.set_physics_process(false)
	var platforms := level.get_node("PlataformasBrancas").get_children()
	check(platforms.size() == 4, "Fase 2 tem quatro plataformas brancas editaveis na cena")
	var tile_count := 0
	for layer in level.get_node("Mundo").get_children():
		if not layer is TileMapLayer:
			continue
		for cell in layer.get_used_cells():
			var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
			if atlas.y == 28 and atlas.x >= 6 and atlas.x <= 8:
				tile_count += 1
	check(tile_count == 0, "Tiles brancos antigos foram substituidos, sem imagens ou colisoes duplicadas")
	for platform in platforms:
		check(platform is AnimatableBody2D and platform.collision_layer == 2 and not platform.is_in_group("hazards"),
			"Plataforma branca tem colisao de chao segura: " + platform.name)
		var editable := 0
		for property in platform.get_property_list():
			if property.name in ["amplitude", "periodo", "eixo", "fase_inicial"] and property.usage & PROPERTY_USAGE_EDITOR:
				editable += 1
		check(editable == 4, "Amplitude, periodo, eixo e fase disponiveis no Inspetor: " + platform.name)
	await frames(4)
	var platform := platforms[0] as AnimatableBody2D
	mario.global_position = platform.global_position + Vector2(0, -80)
	mario.velocity = Vector2.ZERO
	mario.set_physics_process(true)
	var landed := false
	for index in 90:
		await frames(1)
		if mario.is_on_floor():
			landed = true
			break
	check(landed and not mario.is_dead, "Mario pousa na plataforma branca da fase 2 sobre os perigos")
	var safe := true
	for index in 300:
		await frames(1)
		safe = safe and not mario.is_dead and mario.is_on_floor()
	check(safe, "Mario permanece apoiado durante mais de um ciclo na fase 2")
	var replacements: Array[Node2D] = []
	level.restarted.connect(func(replacement: Node2D) -> void: replacements.append(replacement))
	level._restart_level()
	await frames(4)
	check(replacements.size() == 1 and replacements[0].get_node("PlataformasBrancas").get_child_count() == 4,
		"Reinicio da fase restaura as quatro plataformas oscilantes")
	replacements[0].queue_free()
	await frames(2)


func _run() -> void:
	await _check_motion_and_rider(Vector2.RIGHT)
	await _check_motion_and_rider(Vector2.DOWN)
	await _check_level()
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

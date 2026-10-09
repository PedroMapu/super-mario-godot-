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


func view_is_inside(camera: Camera2D, bounds: Rect2) -> bool:
	var view_size := camera.get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - view_size * 0.5, view_size)
	return bounds.grow(0.1).encloses(view)


func _run() -> void:
	for scene_path in ["res://cenas/level_01.tscn", "res://cenas/level_02.tscn"]:
		root.size = Vector2i(1152, 648)
		var level := load(scene_path).instantiate() as Node2D
		# Confere tambem limites em coordenadas globais ao mover a fase.
		level.position = Vector2(128, 64)
		root.add_child(level)
		var mario := level.get_node("Mario") as CharacterBody2D
		mario.set_physics_process(false)
		var camera := mario.get_node("Camera2D") as Camera2D
		camera.make_current()
		var spawn_position: Vector2 = level.get_node("PlayerSpawn").global_position
		check(mario.global_position.is_equal_approx(spawn_position), "Mario inicia no PlayerSpawn: " + scene_path)
		check(mario.jump_velocity == -570.0, "Fase preserva o salto do Mario: " + scene_path)
		var bounds: Rect2 = level.get_map_bounds()
		# A fase 1 agora inclui chao ate a linha 14 (15 tiles de 32px).
		var expected_bottom := 480.0 if scene_path.contains("01") else 352.0
		check(bounds == Rect2(Vector2(-384, -448) + level.position, Vector2(5760, expected_bottom + 448)), "Limites incluem tiles e agua da fase: " + scene_path)
		check(camera.limit_left == ceili(bounds.position.x) and camera.limit_top == ceili(bounds.position.y) and camera.limit_right == floori(bounds.end.x) and camera.limit_bottom == floori(bounds.end.y), "Camera recebe limites da fase: " + scene_path)
		await frames(2)
		check(camera.position == Vector2.ZERO and camera.is_current(), "Camera acompanha Mario sem deslocamento: " + scene_path)
		for window_size in [Vector2i(1152, 648), Vector2i(640, 1400), Vector2i(9000, 1600)]:
			root.size = window_size
			await frames(2)
			var all_inside := true
			for corner in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y), bounds.position - Vector2(100, 100), bounds.end + Vector2(100, 100)]:
				mario.global_position = corner
				camera.force_update_scroll()
				await frames(2)
				all_inside = all_inside and view_is_inside(camera, bounds)
			check(all_inside, "Camera nao mostra fora do mapa nas bordas, janela " + str(window_size) + ": " + scene_path)
		mario._respawn()
		camera.force_update_scroll()
		await frames(2)
		check(mario.global_position.is_equal_approx(spawn_position) and view_is_inside(camera, bounds), "Respawn conserva ponto inicial e limites da camera: " + scene_path)
		level.queue_free()
		await frames(2)

	root.size = Vector2i(1152, 648)
	var main := load("res://cenas/main.tscn").instantiate() as Node2D
	root.add_child(main)
	await frames(2)
	check(main.find_children("Mario", "CharacterBody2D", true, false).size() == 1, "Main inicia com um unico Mario dentro da fase 1")
	var old_mario: CharacterBody2D = main.mario
	var portal := main.get_node("level01/EntradaFase2") as Area2D
	# Usa o sinal real da entrada, acionando a troca adiada entre fases.
	portal.body_entered.emit(old_mario)
	await frames(3)
	check(not main.has_node("level01") and main.has_node("Level02/Mario"), "Entrada troca fase 1 por fase 2 com seu Mario")
	check(not is_instance_valid(old_mario) and main.find_children("Mario", "CharacterBody2D", true, false).size() == 1, "Troca remove o Mario antigo e evita jogadores duplicados")
	var next_camera := main.mario.get_node("Camera2D") as Camera2D
	check(main.mario == main.get_node("Level02/Mario") and next_camera.is_current(), "Main usa o Mario e a camera da fase 2")
	check(view_is_inside(next_camera, main.get_node("Level02").get_map_bounds()), "Camera permanece dentro do mapa depois da transicao")
	main.queue_free()
	await frames(2)
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

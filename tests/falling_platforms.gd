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


func platforms_in(level: Node) -> Array[Node]:
	var platforms: Array[Node] = []
	for platform in get_nodes_in_group("falling_platforms"):
		if level.is_ancestor_of(platform):
			platforms.append(platform)
	return platforms


func collisions_disabled(platform: Node) -> bool:
	for child in platform.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			if not child.disabled:
				return false
	return true


func _run() -> void:
	root.size = Vector2i(1152, 648)
	for scene_path in ["res://cenas/level_01.tscn", "res://cenas/level_02.tscn"]:
		var level := load(scene_path).instantiate() as Node2D
		root.add_child(level)
		current_scene = level
		var mario := level.get_node("Mario") as CharacterBody2D
		mario.set_physics_process(false)
		await frames(3)
		var platforms := platforms_in(level)
		var expected_count := 8 if scene_path.contains("01") else 3
		check(platforms.size() == expected_count, "Todas as plataformas sao convertidas: " + scene_path)
		if platforms.size() < 2:
			quit(1)
			return
		var platform = platforms[0]
		var other = platforms[1]
		var original_position: Vector2 = platform.position
		check(platform.get_node("Visuals").get_child_count() == 6, "Cada plataforma preserva seus seis tiles")

		# Movimentos reais contra a lateral e a parte inferior nao ativam.
		mario.global_position = platform.global_position + Vector2(-32, 0)
		mario.velocity = Vector2(270, 0)
		mario._fall_velocity = 0.0
		mario.move_and_slide()
		mario._check_platform_contacts()
		check(mario.get_slide_collision_count() > 0 and platform.state == platform.State.IDLE, "Contato lateral nao inicia contagem")
		var underside := 32.0 if scene_path.contains("01") else 48.0
		mario.global_position = platform.global_position + Vector2(32, underside + 18.0)
		mario.velocity = Vector2(0, -570)
		mario._fall_velocity = -570.0
		mario.move_and_slide()
		mario._check_platform_contacts()
		check(mario.get_slide_collision_count() > 0 and platform.state == platform.State.IDLE, "Cabecada nao inicia contagem")

		mario.global_position = platform.global_position + Vector2(32, -50)
		mario.velocity = Vector2.ZERO
		mario.set_physics_process(true)
		for index in 60:
			await frames(1)
			if platform.state != platform.State.IDLE:
				break
		mario.set_physics_process(false)
		check(mario.is_on_floor() and platform.state == platform.State.SHAKING, "Pouso real do Mario inicia o tremor")
		await frames(30)
		check(platform.get_node("Visuals").position != Vector2.ZERO and platform.position == original_position, "Imagem treme com colisao firme")
		var elapsed: float = platform._elapsed
		platform.start_collapse()
		check(platform._elapsed == elapsed, "Pousar novamente nao reinicia o prazo")
		mario.global_position = level.get_node("PlayerSpawn").global_position
		await frames(48)
		check(platform.state == platform.State.SHAKING and not collisions_disabled(platform), "Plataforma ainda sustenta antes de 1,5 segundo")
		for index in 20:
			await frames(1)
			if platform.state == platform.State.FALLING:
				break
		check(platform.state == platform.State.FALLING and absf(platform._elapsed - 1.5) < 0.035, "Queda comeca em 1,5 segundo mesmo apos Mario sair")
		await frames(6)
		check(collisions_disabled(platform), "Colisao some ao iniciar a queda")
		check(platform.position.x == original_position.x and platform.position.y > original_position.y and platform.position.y < original_position.y + 24.0, "Queda curta e vertical")
		check(other.state == other.State.IDLE, "Outra plataforma mantem contagem independente")
		await frames(12)
		check(not platform.get_node("Visuals").visible and platform.has_node("Debris") and platform.get_node("Debris").get_child_count() == 24, "Destruicao divide os tiles em 24 fragmentos")
		for index in 40:
			await frames(1)
			if platform.state == platform.State.DESTROYED:
				break
		check(platform.state == platform.State.DESTROYED and not platform.has_node("Debris"), "Fragmentos desaparecem e plataforma fica destruida")
		check(platform._elapsed == 0.0, "Prazo de retorno comeca depois de terminar a destruicao")
		await frames(239)
		check(platform.state == platform.State.DESTROYED and not platform.get_node("Visuals").visible and collisions_disabled(platform), "Plataforma fica ausente antes de completar quatro segundos")
		await frames(2)
		check(platform.state == platform.State.IDLE and platform.position == original_position and platform.get_node("Visuals").visible and not collisions_disabled(platform) and platform._elapsed == 0.0, "Apos quatro segundos, restaura posicao, imagem, colisao e contagem")
		check(other.state == other.State.IDLE, "Retorno de uma plataforma nao ativa as outras")

		mario.global_position = platform.global_position + Vector2(32, -50)
		mario.velocity = Vector2.ZERO
		mario.set_physics_process(true)
		for index in 60:
			await frames(1)
			if platform.state != platform.State.IDLE:
				break
		mario.set_physics_process(false)
		check(mario.is_on_floor() and platform.state == platform.State.SHAKING, "Mario pode pousar e ativar novamente a plataforma restaurada")
		mario.global_position = level.get_node("PlayerSpawn").global_position
		for index in 160:
			await frames(1)
			if platform.state == platform.State.DESTROYED:
				break
		check(platform.state == platform.State.DESTROYED, "Segundo ciclo tambem termina em destruicao")

		var restart_result := {"level": null}
		level.restarted.connect(func(replacement: Node2D) -> void: restart_result["level"] = replacement)
		other.start_collapse()
		mario.set_physics_process(true)
		mario.die()
		var paused_elapsed: float = other._elapsed
		var paused_respawn_elapsed: float = platform._elapsed
		await frames(10)
		check(other._elapsed == paused_elapsed, "Morte pausa a contagem das plataformas")
		check(platform._elapsed == paused_respawn_elapsed, "Morte pausa tambem o prazo de retorno")
		for index in 360:
			await frames(1)
			if restart_result["level"] != null:
				break
		var replacement := restart_result["level"] as Node2D
		check(replacement != null, "Morte real reinicia a fase")
		if replacement != null:
			var restored := platforms_in(replacement)
			var all_restored := restored.size() == expected_count
			for restored_platform in restored:
				all_restored = all_restored and restored_platform.state == restored_platform.State.IDLE and restored_platform._elapsed == 0.0 and restored_platform.get_node("Visuals").visible and not collisions_disabled(restored_platform) and restored_platform.position == restored_platform._rest_position
			check(all_restored, "Reinicio restaura plataformas, posicoes, colisoes e contagens: " + scene_path)
			replacement.queue_free()
		else:
			paused = false
			level.queue_free()
		await frames(3)
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

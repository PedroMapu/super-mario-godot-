extends SceneTree

var failures := 0
var capture := false


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
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


func save_capture(filename: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")


func check_animation(layer: TileMapLayer, expected_count: int) -> void:
	var visuals := layer.get_node("SurfaceAnimation")
	check(visuals.get_child_count() == expected_count, "Superficies animadas: " + str(layer.name))
	if expected_count == 0:
		return
	var sprite := visuals.get_child(0) as AnimatedSprite2D
	check(sprite.is_playing() and sprite.sprite_frames.get_frame_count(&"flow") == 4, "Usa quatro quadros do sprite em loop: " + str(layer.name))
	var cells_before := layer.tile_map_data.duplicate()
	var initial_frame := sprite.frame
	await frames(18)
	check(sprite.frame != initial_frame, "Ondas e bolhas mudam de quadro: " + str(layer.name))
	var coherent := true
	for child: AnimatedSprite2D in visuals.get_children():
		var cell := layer.local_to_map(child.position)
		var neighbor := visuals.get_node_or_null("Flow_%d_%d" % [cell.x + 1, cell.y]) as AnimatedSprite2D
		if neighbor != null:
			coherent = coherent and neighbor.frame == (child.frame + 1) % 4
	check(coherent, "Tiles vizinhos conservam a sequencia das ondas: " + str(layer.name))
	paused = true
	var paused_frame := sprite.frame
	var paused_progress := sprite.frame_progress
	await frames(18)
	check(sprite.frame == paused_frame and is_equal_approx(sprite.frame_progress, paused_progress), "Animacao fica parada durante a pausa: " + str(layer.name))
	paused = false
	await frames(18)
	check(sprite.frame != paused_frame, "Animacao volta depois da pausa: " + str(layer.name))
	check(layer.tile_map_data == cells_before, "Animacao preserva os tiles e colisores: " + str(layer.name))


func _run() -> void:
	root.size = Vector2i(1152, 648)
	for number in ["01", "02"]:
		var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
		level.intro_enabled = false
		root.add_child(level)
		var mario := level.get_node("Mario") as CharacterBody2D
		mario.set_physics_process(false)
		mario.get_node("AreaDano").monitoring = false
		for enemy in level.get_node("Inimigos").get_children():
			enemy.set_physics_process(false)
		await frames(3)
		var lava := level.get_node("Mundo/Lava") as TileMapLayer
		await check_animation(lava, 15 if number == "01" else 51)
		var water := level.get_node("Mundo/agua") as TileMapLayer
		await check_animation(water, 24 if number == "01" else 0)
		if number == "01":
			await check_animation(level.get_node("Mundo/LavaGround"), 35)
			mario.global_position = Vector2(3180, 160)
		else:
			mario.global_position = Vector2(920, -130)
		var camera := mario.get_node("Camera2D") as Camera2D
		camera.make_current()
		camera.force_update_scroll()
		await frames(3)
		await save_capture("liquid_motion_" + number + "_a")
		await frames(14)
		await save_capture("liquid_motion_" + number + "_b")
		var shared_tiles := load("res://Cenario/liquids/lava_hazard.tres") as TileSet
		var shared_source := shared_tiles.get_source(0) as TileSetAtlasSource
		check(shared_source.get_tile_data(Vector2i(9, 2), 0).modulate.a == 1.0, "Paleta original continua visivel no editor e em outras instancias")
		level._restart_level()
		await frames(3)
		var replacement := root.get_child(root.get_child_count() - 1)
		var replacement_lava := replacement.get_node("Mundo/Lava/SurfaceAnimation")
		check(replacement_lava.get_child_count() == (15 if number == "01" else 51) and (replacement_lava.get_child(0) as AnimatedSprite2D).is_playing(), "Reinicio restaura a animacao da fase " + number)
		replacement.queue_free()
		await frames(3)
	print("Falhas: ", failures)
	quit(1 if failures else 0)

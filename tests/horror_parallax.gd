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
		await process_frame
		await physics_frame


func save_capture(filename: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty() and image.save_png("res://.godot/" + filename) == OK, "Captura visual: " + filename)


func _run() -> void:
	var palettes: Array[Color] = []
	for number in ["01", "02"]:
		root.size = Vector2i(1152, 648)
		var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
		root.add_child(level)
		current_scene = level
		var mario := level.get_node("Mario") as CharacterBody2D
		mario.set_physics_process(false)
		var camera := mario.get_node("Camera2D") as Camera2D
		camera.make_current()
		await frames(4)
		var background := level.get_node("HorrorParallax") as CanvasLayer
		check(background.layer < 0, "Fundo fica atras do mundo na fase " + number)
		palettes.append(background.sky_tint)
		var sky := background.get_node("Sky") as Parallax2D
		var distant := background.get_node("DistantGraves") as Parallax2D
		var near := background.get_node("NearGraves") as Parallax2D
		var fog := background.get_node("Fog") as ColorRect
		var material := fog.material as ShaderMaterial
		await save_capture("horror_level_" + number + ".png")
		var positions := Vector3(sky.position.x, distant.position.x, near.position.x)
		mario.global_position.x += 400.0
		camera.force_update_scroll()
		await frames(3)
		var movement := (Vector3(sky.position.x, distant.position.x, near.position.x) - positions).abs()
		check(movement.x > 0.0 and movement.x < movement.y and movement.y < movement.z, "Camadas criam profundidade quando a camera anda na fase " + number)
		await save_capture("horror_level_" + number + "_scrolled.png")
		var elapsed_before: float = material.get_shader_parameter("elapsed")
		await frames(3)
		check(float(material.get_shader_parameter("elapsed")) > elapsed_before, "Nevoa se move na fase " + number)
		paused = true
		var paused_time: float = material.get_shader_parameter("elapsed")
		await frames(3)
		check(is_equal_approx(float(material.get_shader_parameter("elapsed")), paused_time), "Nevoa respeita a pausa da morte na fase " + number)
		paused = false
		for window_size in [Vector2i(640, 1400), Vector2i(2400, 500), Vector2i(1152, 648)]:
			root.size = window_size
			await frames(3)
			var sky_image := sky.get_node("Image") as Sprite2D
			var drawn_height := sky_image.texture.get_height() * sky_image.scale.y
			# canvas_items pode manter o viewport logico enquanto estica a janela.
			var view_size := root.get_visible_rect().size
			check(is_equal_approx(drawn_height, view_size.y) and sky.repeat_size.x * sky.repeat_times >= view_size.x and fog.size == view_size, "Fundo cobre janela " + str(window_size) + " na fase " + number)
		var replacements: Array[Node2D] = []
		level.restarted.connect(func(replacement: Node2D) -> void: replacements.append(replacement))
		level._restart_level()
		await frames(3)
		check(replacements.size() == 1 and replacements[0].has_node("HorrorParallax"), "Reinicio restaura o parallax da fase " + number)
		replacements[0].queue_free()
		await frames(2)
	check(palettes[0] != palettes[1], "As fases usam atmosferas com cores distintas")
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

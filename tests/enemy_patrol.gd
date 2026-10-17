extends SceneTree

const FLOOR_MASK := 2 | 16 | 512
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


func feet(enemy: CharacterBody2D) -> Vector2:
	var shape := enemy.get_node("Colisao") as CollisionShape2D
	var rectangle := shape.shape as RectangleShape2D
	return shape.to_global(Vector2(0, rectangle.size.y * 0.5))


func _check_levels() -> void:
	for number in ["01", "02"]:
		var level := load("res://cenas/level_" + number + ".tscn").instantiate() as Node2D
		root.add_child(level)
		var mario := level.get_node("Mario") as CharacterBody2D
		mario.set_physics_process(false)
		mario.collision_layer = 0
		mario.collision_mask = 0
		mario.get_node("AreaDano").monitoring = false
		var enemies := level.get_node("Inimigos").get_children()
		var origins: Array[Vector2] = []
		var floors: Array[float] = []
		for enemy: CharacterBody2D in enemies:
			origins.append(enemy.global_position)
			floors.append(feet(enemy).y)
			enemy.set_physics_process(false)
		await frames(6)
		for index in enemies.size():
			var enemy := enemies[index] as CharacterBody2D
			var shape := enemy.get_node("Colisao") as CollisionShape2D
			var rectangle := shape.shape as RectangleShape2D
			var margin: float = rectangle.size.x * enemy.global_scale.x * 0.5 + enemy.EDGE_MARGIN
			var left: float = origins[index].x - enemy.patrol_amplitude - margin
			var right: float = origins[index].x + enemy.patrol_amplitude + margin
			var safe := true
			var sample_x := left
			while sample_x <= right:
				var query := PhysicsRayQueryParameters2D.create(
					Vector2(sample_x, floors[index] - 64.0), Vector2(sample_x, floors[index] + 1.0), FLOOR_MASK)
				var hit := root.world_2d.direct_space_state.intersect_ray(query)
				if hit.is_empty() or absf(hit.position.y - floors[index]) > 0.1:
					safe = false
					print("Trecho inseguro: ", number, "/", enemy.name, " x=", sample_x, " piso=", floors[index], " hit=", hit.get("position", Vector2.INF))
					break
				sample_x += minf(1.0, right - sample_x) if sample_x < right else 1.0
			check(safe, "Todo o trecho configurado tem apoio na mesma altura, incluindo o colisor: " + number + "/" + enemy.name)
			enemy.set_physics_process(true)
		var stayed_safe: Array[bool] = []
		var moved: Array[bool] = []
		stayed_safe.resize(enemies.size())
		stayed_safe.fill(true)
		moved.resize(enemies.size())
		moved.fill(false)
		for frame in 2400:
			await frames(1)
			for index in enemies.size():
				var enemy := enemies[index] as CharacterBody2D
				if not is_instance_valid(enemy):
					stayed_safe[index] = false
					continue
				stayed_safe[index] = stayed_safe[index] and absf(feet(enemy).y - floors[index]) < 0.5
				stayed_safe[index] = stayed_safe[index] and absf(enemy.global_position.x - origins[index].x) <= enemy.patrol_amplitude + 0.5
				if frame > 3:
					stayed_safe[index] = stayed_safe[index] and enemy.is_on_floor()
				moved[index] = moved[index] or absf(enemy.global_position.x - origins[index].x) > 2.0
		for index in enemies.size():
			check(stayed_safe[index] and moved[index], "40 segundos patrulhando sem cair, mudar de altura ou ultrapassar limites: " + number + "/" + str(index))
		level.queue_free()
		await frames(2)


func platform(parent: Node2D, position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = position
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	parent.add_child(body)
	return body


func _check_edges() -> void:
	for scenario in ["buraco", "degrau", "casco", "passo_rapido", "plataforma_estreita", "plataforma_desmontavel"]:
		var world := Node2D.new()
		root.add_child(world)
		platform(world, Vector2(0, 216), Vector2(240, 32))
		if scenario == "degrau":
			platform(world, Vector2(240, 248), Vector2(240, 32))
		elif scenario == "plataforma_desmontavel":
			platform(world, Vector2(240, 216), Vector2(240, 32)).add_to_group("falling_platforms")
		elif scenario == "passo_rapido":
			# Uma abertura de dois pixels ainda precisa ser detectada num passo de 50px.
			platform(world, Vector2(241, 216), Vector2(238, 32))
		elif scenario == "plataforma_estreita":
			world.get_child(0).queue_free()
			platform(world, Vector2(0, 216), Vector2(38, 32))
		var path := "res://cenas/koompa.tscn" if scenario == "casco" else "res://cenas/goomba.tscn"
		var enemy := load(path).instantiate() as CharacterBody2D
		enemy.scale = Vector2(2.25, 2.25)
		enemy.position = Vector2(0, 150)
		enemy.patrol_amplitude = 500.0
		enemy.walk_speed = 0.0
		enemy.direction = 1
		world.add_child(enemy)
		await frames(45)
		var initial_y := feet(enemy).y
		if scenario == "casco":
			enemy.shell_duration = 30.0
			enemy._transform_into_shell()
			await frames(2)
		else:
			enemy.walk_speed = 3000.0 if scenario == "passo_rapido" else 180.0
		var safe := true
		var turned := false
		for index in 360:
			await frames(1)
			safe = safe and enemy.is_on_floor() and absf(feet(enemy).y - initial_y) < 0.5
			safe = safe and absf(enemy.position.x) < 120.0
			turned = turned or enemy.direction == -1
		check(safe and turned, "Inverte antes da borda sem cair: " + scenario)
		world.queue_free()
		await frames(2)


func _run() -> void:
	await _check_levels()
	await _check_edges()
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

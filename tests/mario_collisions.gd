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


func obstacle(position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.position = position
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	body.add_child(collision)
	root.add_child(body)


func _run() -> void:
	# Piso em y=100, parede em x=300 e passagem com 42px de altura.
	obstacle(Vector2(0, 116), Vector2(2000, 32))
	obstacle(Vector2(316, 50), Vector2(32, 100))
	obstacle(Vector2(160, 42), Vector2(100, 32))
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	mario.position = Vector2(0, 30)
	root.add_child(mario)
	await frames(40)
	check(mario.is_on_floor(), "Mario pousa sobre o piso")
	check(absf(mario._feet_position().y - 100.0) < 0.15, "Pe visual e base fisica terminam no piso")
	check(absf(mario.position.y - 74.0) < 0.15, "Origem conserva pes locais em y=26")
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	check(mario.position.x > 210.0, "Mario atravessa uma passagem de 42px sem prender no teto")
	check(mario.is_on_wall() and absf(mario.position.x - 286.0) < 0.2, "Caixa centrada para na parede sem atravessar")
	mario.set_physics_process(false)

	# Testa o calculo de pes com geometria modificada e escala de uma instancia.
	var collision := mario.get_node("Colisao") as CollisionShape2D
	collision.shape = collision.shape.duplicate()
	collision.shape.size = Vector2(20, 30)
	collision.position = Vector2(3, 5)
	mario.scale = Vector2(1.5, 1.5)
	var expected_feet: Vector2 = mario.to_global(Vector2(3, 20))
	check(mario._feet_position().is_equal_approx(expected_feet), "Consulta dos pes acompanha tamanho, centro e escala da instancia")
	collision.shape.size = Vector2(28, 40)
	collision.position = Vector2(0, 6)
	mario.scale = Vector2.ONE

	# Agua com uma unica celula de y=96 ate y=128; somente os pes entram.
	var water := TileMapLayer.new()
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas := TileSetAtlasSource.new()
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	water.tile_set = tile_set
	water.add_to_group("water")
	water.set_cell(Vector2i(0, 3), 0, Vector2i.ZERO)
	root.add_child(water)
	mario.position = Vector2(16, 74)
	check(mario._is_in_water(), "Agua e detectada quando os pes entram antes do centro do corpo")
	mario.position = Vector2(16, 69)
	check(not mario._is_in_water(), "Mario sobre a superficie permanece fora da agua")
	mario.position = Vector2(64, 74)
	check(not mario._is_in_water(), "Celulas vazias ao lado da agua permanecem secas")

	# Contato com perigo no piso chega pela mesma caixa ajustada.
	water.queue_free()
	mario.position = Vector2(-300, 74)
	var contacts: Array[Node2D] = []
	mario.hazard_contact.connect(func(source: Node2D) -> void: contacts.append(source))
	var hazard := Area2D.new()
	hazard.collision_layer = 128
	hazard.collision_mask = 0
	hazard.position = Vector2(-300, 99)
	var hazard_shape := CollisionShape2D.new()
	var hazard_rectangle := RectangleShape2D.new()
	hazard_rectangle.size = Vector2(8, 4)
	hazard_shape.shape = hazard_rectangle
	hazard.add_child(hazard_shape)
	root.add_child(hazard)
	await frames(3)
	check(not contacts.is_empty(), "AreaDano detecta perigo encostando nos pes")
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)

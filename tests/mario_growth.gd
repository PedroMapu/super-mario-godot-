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


func measure_jump_height(mario: CharacterBody2D) -> float:
	var start_feet: float = mario._feet_position().y
	var highest_feet := start_feet
	var jump_audio: AudioStreamPlayer = mario.jump_sound
	jump_audio.stop()
	Input.action_press("jump")
	await frames(1)
	var expected_sound: AudioStream = mario.BIG_JUMP_SOUND if mario.is_big else mario.SMALL_JUMP_SOUND
	check(jump_audio.playing and jump_audio.stream == expected_sound, "Salto real toca o efeito grave do big ou agudo do small conforme tamanho")
	check(is_equal_approx(jump_audio.stream.get_length(), 0.22) and jump_audio.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Som de pulo e curto e sem loop")
	var playback := jump_audio.get_stream_playback()
	await frames(2)
	check(jump_audio.get_stream_playback() == playback, "Segurar pulo nao reinicia o som")
	Input.action_release("jump")
	await frames(1)
	jump_audio.stop()
	Input.action_press("jump")
	await frames(1)
	check(not jump_audio.playing, "Apertar pulo no ar nao toca som sem um novo salto")
	Input.action_release("jump")
	var valid_air_animation := true
	var saw_ascent := false
	var saw_descent := false
	for index in 120:
		highest_feet = minf(highest_feet, mario._feet_position().y)
		if mario.is_on_floor() and index > 0:
			break
		if mario.is_big and not mario.is_on_floor():
			var expected_animation := &"big_jump" if mario.velocity.y < 0.0 else &"big_fall"
			valid_air_animation = valid_air_animation and mario.sprite.animation == expected_animation
			saw_ascent = saw_ascent or mario.velocity.y < 0.0
			saw_descent = saw_descent or mario.velocity.y >= 0.0
		await frames(1)
	check(mario.is_on_floor(), "Mario retorna ao piso depois do salto")
	if mario.is_big:
		check(valid_air_animation and saw_ascent and saw_descent, "Salto grande usa big_jump na subida e big_fall na descida inteira")
		check(mario.sprite.animation == &"big_idle", "Pousar parado restaura big_idle")
	return start_feet - highest_feet


func _run() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector2(0, 216)
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(500, 32)
	floor_shape.shape = floor_rectangle
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var scene := load("res://cenas/mario.tscn") as PackedScene
	var mario := scene.instantiate() as CharacterBody2D
	var other := scene.instantiate() as CharacterBody2D
	mario.position = Vector2(0, 174)
	other.position = Vector2(1000, 100)
	root.add_child(mario)
	root.add_child(other)
	await frames(2)
	var small_jump_height := await measure_jump_height(mario)
	mario.set_physics_process(false)
	other.set_physics_process(false)
	var sprite := mario.get_node("Animacao") as AnimatedSprite2D
	var original_frames := sprite.sprite_frames
	var original_growth_pose := original_frames.get_frame_texture(&"small_to_big", 0)
	var original_count := original_frames.get_frame_count(&"small_to_big")
	sprite.play(&"small_walk")
	sprite.frame = 1
	sprite.flip_h = true
	var current_pose := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var start_position := mario.position
	var feet := mario._feet_position() as Vector2
	mario.velocity = Vector2(-90, 0)
	mario.grow()
	mario.set_physics_process(true)
	check(mario.is_growing and paused and sprite.animation == &"small_to_big", "Crescimento inicia small_to_big e pausa o mundo")
	var growth_audio: AudioStreamPlayer = mario.growth_sound
	check(growth_audio.playing and growth_audio.can_process(), "Som de crescimento toca mesmo com o mundo pausado")
	check(is_equal_approx(growth_audio.stream.get_length(), 0.8) and growth_audio.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Efeito dura 0,8 segundo e nao repete em loop")
	check(sprite.sprite_frames.get_frame_texture(&"small_to_big", 0) == current_pose, "Primeiro quadro conserva o sprite em uso")
	check(sprite.sprite_frames.get_frame_texture(&"small_to_big", 1) == original_growth_pose, "Transicao usa o recorte small_to_big do editor")
	check(sprite.flip_h, "Transformacao conserva direcao")
	check(original_frames.get_frame_count(&"small_to_big") == original_count and other.sprite.sprite_frames == original_frames, "Transformacao preserva recursos do editor e outros Marios")
	var growth_playback := growth_audio.get_stream_playback()
	mario.grow()
	check(growth_audio.get_stream_playback() == growth_playback, "Chamar grow novamente nao reinicia nem duplica o som")
	Input.action_press("move_right")
	await frames(10)
	check(mario.position == start_position and mario.velocity == Vector2.ZERO, "Comandos e movimento ficam bloqueados durante crescimento")
	var enemy := Node2D.new()
	root.add_child(enemy)
	mario.take_enemy_damage(enemy)
	check(mario.lives == mario.MAX_LIVES, "Crescimento protege contra dano")
	for index in 100:
		if mario.is_big:
			break
		await frames(1)
	check(mario.is_big and mario.is_growing and sprite.animation == &"big_idle", "Fim da animacao mostra big_idle antes de devolver controle")
	check(mario._feet_position().is_equal_approx(feet), "Transformacao conserva os pes")
	Input.action_release("move_right")
	for index in 20:
		if not mario.is_growing:
			break
		await frames(1)
	mario.set_physics_process(false)
	check(not paused and not mario.is_growing and mario.velocity.x == -90.0, "Fim restaura pausa e movimento anteriores")
	check(not growth_audio.playing, "Som termina junto com a transformacao")
	check(mario.body_shape.shape.size.y == mario.BIG_BODY_HEIGHT and mario._feet_position().is_equal_approx(feet), "Corpo cresce mantendo base dos pes")
	mario._update_animation(-1.0)
	check(sprite.animation == &"big_walk" and sprite.flip_h, "Movimento apos crescimento usa big_walk")
	mario.velocity = Vector2.ZERO
	mario._update_animation(0.0)
	check(sprite.animation == &"big_idle", "Mario grande parado no chao conserva big_idle")
	mario.set_physics_process(true)
	await frames(2)
	var big_jump_height := await measure_jump_height(mario)
	check(big_jump_height > small_jump_height, "Mario grande pula mais alto que Mario pequeno")
	check(absf(big_jump_height - mario.big_jump_height) < 8.0, "Salto grande alcanca a altura configurada em pixels")
	mario.big_jump_height = 150.0
	var adjusted_jump_height := await measure_jump_height(mario)
	check(adjusted_jump_height < big_jump_height and absf(adjusted_jump_height - 150.0) < 8.0, "Alterar Big Jump Height modifica a altura real do salto")
	mario.set_physics_process(false)
	mario._respawn()
	check(not mario.is_big and not mario.is_growing and mario.body_shape.shape.size == mario._small_body_size and sprite.offset == mario._small_sprite_offset, "Respawn restaura Mario pequeno e suas colisoes")
	check(sprite.sprite_frames == original_frames, "Respawn restaura frames originais para a proxima transformacao")
	mario.set_physics_process(true)
	await frames(2)
	await measure_jump_height(mario)
	mario.set_physics_process(false)
	mario.grow()
	mario.die()
	check(mario.is_dead and not mario.is_growing, "Morte interrompe a transformacao")
	check(not growth_audio.playing, "Morte interrompe o som de crescimento")
	mario._respawn()
	check(not paused and not mario.is_big, "Morte durante crescimento nao deixa mundo pausado")
	mario.grow()
	mario._respawn()
	check(not growth_audio.playing and not paused, "Respawn durante crescimento interrompe o som e restaura o mundo")
	mario.grow()
	mario.queue_free()
	other.queue_free()
	enemy.queue_free()
	floor_body.queue_free()
	await frames(2)
	check(not paused, "Remover Mario durante crescimento restaura pausa")

	# A cabecada usa a colisao real do bloco em (53, -9) da fase 1.
	var level := load("res://cenas/level_01.tscn").instantiate() as Node2D
	level.intro_enabled = false
	root.add_child(level)
	var player := level.get_node("Mario") as CharacterBody2D
	player.set_physics_process(false)
	# Compara saltos reais das duas fases no mesmo piso, longe do cenario.
	var jump_floor := StaticBody2D.new()
	jump_floor.collision_layer = 2
	jump_floor.position = Vector2(-10000, 216)
	var jump_shape := CollisionShape2D.new()
	var jump_rectangle := RectangleShape2D.new()
	jump_rectangle.size = Vector2(500, 32)
	jump_shape.shape = jump_rectangle
	jump_floor.add_child(jump_shape)
	root.add_child(jump_floor)
	player.global_position = Vector2(-10000, 174)
	player.set_physics_process(true)
	await frames(2)
	var phase_one_jump_height := await measure_jump_height(player)
	var phase_one_jump_velocity: float = player.jump_velocity
	player.set_physics_process(false)
	var ground := level.get_node("Mundo/Ground") as TileMapLayer
	var block := ground.get_node("QuestionBlock_53_-9") as StaticBody2D
	check(block != null, "Caixa de crescimento existe na celula (53, -9)")
	var ordinary: StaticBody2D
	for child in ground.get_children():
		if child != block and child.has_method("activate_from_below"):
			ordinary = child
			break
	ordinary.activate_from_below()
	check(not player.is_growing and not player.is_big, "Outras caixas da fase 1 nao fazem Mario crescer")
	player.global_position = block.global_position + Vector2(0, 50)
	player.velocity = Vector2(0, -200)
	player.set_physics_process(true)
	for index in 30:
		if block.used:
			break
		await frames(1)
	check(block.used and player.is_growing, "Cabecada real na caixa (53, -9) inicia crescimento")
	var phase_one_growth_frames: int = player.sprite.sprite_frames.get_frame_count(&"small_to_big")
	check(level.activated_boxes == 2, "Caixa especial continua contando no HUD uma unica vez")
	for index in 100:
		if not player.is_growing:
			break
		await frames(1)
	player.set_physics_process(false)
	check(player.is_big and not player._big_body_applied, "Sob a caixa, crescimento aguarda espaco para expandir colisao")
	player.global_position = Vector2(-10000, -10000)
	player._try_expand_body()
	check(player._big_body_applied, "Ao sair do teto, colisao assume tamanho grande")
	level.queue_free()
	await frames(2)
	var second_level := load("res://cenas/level_02.tscn").instantiate() as Node2D
	second_level.intro_enabled = false
	root.add_child(second_level)
	second_level.mario.set_physics_process(false)
	var second_player: CharacterBody2D = second_level.mario
	check(second_player.jump_velocity == phase_one_jump_velocity and not second_player.is_big, "Fase 2 inicia pequena com o mesmo impulso de salto da fase 1")
	second_player.global_position = Vector2(-10000, 174)
	second_player.set_physics_process(true)
	await frames(2)
	var phase_two_jump_height := await measure_jump_height(second_player)
	check(absf(phase_two_jump_height - phase_one_jump_height) < 0.1, "Salto pequeno das duas fases alcanca a mesma altura real")
	second_player.set_physics_process(false)
	jump_floor.queue_free()
	var second_block := second_level.get_node("CaixasInterrogacao/QuestionBlock_17_-5") as StaticBody2D
	var second_ground := second_level.get_node("Mundo/Ground") as TileMapLayer
	check(second_ground.local_to_map(second_ground.to_local(second_block.global_position)) == Vector2i(17, -11), "Caixa de crescimento da fase 2 ocupa o tile (17, -11)")
	second_player.global_position = second_block.global_position + Vector2(0, 50)
	second_player.velocity = Vector2(0, -200)
	second_player.set_physics_process(true)
	for index in 30:
		if second_block.used:
			break
		await frames(1)
	check(second_block.used and second_player.is_growing and paused, "Cabecada real na caixa (17, -11) inicia crescimento e pausa o mundo")
	check(second_player.sprite.animation == &"small_to_big" and second_player.sprite.sprite_frames.get_frame_count(&"small_to_big") == phase_one_growth_frames, "Fase 2 usa a mesma sequencia small_to_big da fase 1")
	var second_feet: Vector2 = second_player._feet_position()
	for index in 120:
		if not second_player.is_growing:
			break
		await frames(1)
	second_player.set_physics_process(false)
	check(second_player.is_big and not second_player.is_growing and not paused, "Caixa da fase 2 termina em Mario grande e devolve controle")
	check(second_player._feet_position().is_equal_approx(second_feet), "Crescimento da fase 2 conserva a base dos pes")
	second_block.activate_from_below()
	check(second_level.activated_boxes == 1 and not second_player.is_growing, "Caixa usada da fase 2 conta uma vez e nao repete transformacao")
	# Agua isolada do mapa: verifica as animacoes depois de um crescimento real.
	var water := TileMapLayer.new()
	water.position = Vector2(-10000, -1000)
	var water_tiles := TileSet.new()
	water_tiles.tile_size = Vector2i(32, 32)
	var water_atlas := TileSetAtlasSource.new()
	water_atlas.texture = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	water_atlas.texture_region_size = Vector2i(32, 32)
	water_atlas.create_tile(Vector2i.ZERO)
	water_tiles.add_source(water_atlas, 0)
	water.tile_set = water_tiles
	water.add_to_group("water")
	for x in range(-6, 7):
		for y in range(-10, 21):
			water.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	root.add_child(water)
	var swimmer: CharacterBody2D = second_level.mario
	swimmer.global_position = water.global_position
	swimmer.velocity = Vector2.ZERO
	swimmer.set_physics_process(true)
	await frames(2)
	var swim_sprite: AnimatedSprite2D = swimmer.sprite
	check(swimmer.is_big and swimmer.is_swimming and swim_sprite.animation == &"big_swim_down", "Mario grande afunda na agua com animacao de nado")
	Input.action_press("move_right")
	var seen_frames := {}
	for index in 24:
		await frames(1)
		seen_frames[swim_sprite.frame] = true
	check(swim_sprite.animation == &"big_swim_sides" and not swim_sprite.flip_h and swimmer.velocity.x > 0.0, "Mario grande nada para a direita com as poses grandes")
	check(seen_frames.size() == 3, "Bracada avanca pelos tres frames durante o nado real")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await frames(12)
	check(swim_sprite.animation == &"big_swim_sides" and swim_sprite.flip_h and swimmer.velocity.x < 0.0, "Mario grande espelha a bracada ao nadar para a esquerda")
	Input.action_release("move_left")
	await frames(12)
	check(swim_sprite.animation == &"big_swim_down", "Soltar a direcao restaura o nado de descida")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(swimmer.velocity.y < 0.0 and swim_sprite.animation == &"big_swim_up" and swim_sprite.flip_h, "Impulso na agua usa nado de subida e conserva direcao")
	Input.action_press("move_down")
	Input.action_press("move_right")
	await frames(16)
	check(swimmer.velocity.y > swimmer.WATER_FALL_SPEED and swim_sprite.animation == &"big_swim_down", "Mergulho diagonal do Mario grande prioriza animacao de descida")
	Input.action_release("move_down")
	Input.action_release("move_right")
	swimmer.global_position = Vector2(-9000, -1000)
	swimmer.velocity = Vector2.ZERO
	await frames(2)
	check(not swimmer.is_swimming and swim_sprite.animation == &"big_fall", "Sair da agua no ar usa a pose de queda do Mario grande")
	water.queue_free()
	second_level.queue_free()
	await frames(2)
	for child in root.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.queue_free()
	await frames(2)
	print("MARIO GROWTH FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

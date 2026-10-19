extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func run() -> void:
	var mario := load("res://cenas/mario.tscn").instantiate() as CharacterBody2D
	root.add_child(mario)
	mario.set_physics_process(false)
	var koopa := load("res://cenas/koompa.tscn").instantiate() as CharacterBody2D
	root.add_child(koopa)
	koopa.set_physics_process(false)
	koopa.position = Vector2(80, 0)
	var sound: AudioStreamPlayer = mario.damage_sound
	check(not sound.playing, "Mario inicia sem disparar som de dano")
	check(is_equal_approx(sound.stream.get_length(), 0.28) and sound.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Efeito de dano e curto e nao repete")
	koopa.on_player_contact(mario, false)
	check(mario.lives == 2 and sound.playing, "Contato lateral com Koopa tira vida e toca dano")
	var playback := sound.get_stream_playback()
	mario.take_enemy_damage(koopa)
	check(mario.lives == 2 and sound.get_stream_playback() == playback, "Invulnerabilidade impede dano e repeticao do efeito")
	sound.stop()
	mario.take_enemy_damage(koopa)
	check(not sound.playing, "Contato ignorado nao dispara som")
	mario._damage_grace = 0.0
	mario.take_enemy_damage(koopa)
	check(mario.lives == 1 and sound.playing, "Novo golpe valido toca o efeito novamente")
	mario._damage_grace = 0.0
	mario.take_enemy_damage(koopa)
	check(mario.is_dead and sound.playing and sound.can_process() and paused, "Golpe fatal toca dano mesmo durante a pausa da morte")
	mario._respawn()
	check(not sound.playing and not paused, "Respawn interrompe o efeito anterior")
	mario._damage_grace = 0.0
	mario.grow()
	mario.take_enemy_damage(koopa)
	check(mario.lives == 3 and not sound.playing, "Transformacao protegida nao produz som de dano")
	mario._respawn()
	var victory := load("res://cenas/game_complete.tscn").instantiate() as CanvasLayer
	root.add_child(victory)
	var music: AudioStreamPlayer = victory.victory_music
	check(music.playing and music.can_process(), "Menu toca a musica de vitoria automaticamente")
	check(music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.stream.loop_end > 0 and music.stream.get_length() > 10.0, "Musica de vitoria tem loop configurado para o tema completo")
	var imported := load("res://Mario/vitoria_mario.wav") as AudioStreamWAV
	check(imported.loop_mode == AudioStreamWAV.LOOP_DISABLED and music.stream != imported, "Loop do menu preserva o recurso original")
	paused = true
	check(music.can_process(), "Musica continua ativa com o mundo pausado")
	paused = false
	victory.queue_free()
	mario.queue_free()
	koopa.queue_free()
	await frames(2)
	for child in root.get_children():
		if child is AudioStreamPlayer:
			child.queue_free()
	await frames(2)
	check(not is_instance_valid(music), "Remover a tela final encerra seu player de musica")
	print("FEEDBACK AUDIO FAILURES: ", failures)
	quit(failures)

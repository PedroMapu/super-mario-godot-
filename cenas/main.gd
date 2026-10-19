extends Node2D

const FASE_2 := preload("res://cenas/level_02.tscn")

@onready var fase_atual: Node2D = $level01
@onready var mario: CharacterBody2D = $level01/Mario

var trocando_de_fase := false


func _ready() -> void:
	_start_music()
	_connect_level(fase_atual)


func _start_music() -> void:
	var music := $Music as AudioStreamPlayer
	var music_stream := music.stream as AudioStreamMP3
	if music_stream != null:
		music_stream.loop = true
	music.play()


func _connect_level(level: Node2D) -> void:
	fase_atual = level
	mario = level.get_node("Mario")
	level.restarted.connect(_connect_level)
	level.coins_changed.connect(_on_objectives_changed)
	level.boxes_changed.connect(_on_objectives_changed)
	level.game_completed.connect(_on_game_completed)
	var entrance := level.get_node_or_null("EntradaFase2") as Area2D
	if entrance != null:
		entrance.body_entered.connect(_on_entrada_fase_2)
	trocando_de_fase = false


func _on_game_completed() -> void:
	($Music as AudioStreamPlayer).stop()


func _on_entrada_fase_2(corpo: Node2D) -> void:
	if corpo != mario or trocando_de_fase or mario.is_dead or fase_atual.is_intro_playing or fase_atual.is_game_over or not fase_atual.has_completed_objectives():
		return

	trocando_de_fase = true
	call_deferred("_ir_para_fase_2")


func _on_objectives_changed(_completed: int, _total: int) -> void:
	var entrance := fase_atual.get_node_or_null("EntradaFase2") as Area2D
	if entrance != null and entrance.overlaps_body(mario):
		_on_entrada_fase_2(mario)


func _ir_para_fase_2() -> void:
	# Revalida na troca adiada: morrer ou surgir outra moeda pode bloquear a saida.
	if mario.is_dead or fase_atual.is_intro_playing or fase_atual.is_game_over or not fase_atual.has_completed_objectives():
		trocando_de_fase = false
		return
	var remaining_lives: int = mario.lives
	var play_intro: bool = fase_atual.intro_enabled
	remove_child(fase_atual)
	fase_atual.queue_free()

	var fase_2 := FASE_2.instantiate() as Node2D
	fase_2.intro_enabled = play_intro
	add_child(fase_2)
	move_child(fase_2, 0)
	_connect_level(fase_2)
	mario.set_lives(remaining_lives)

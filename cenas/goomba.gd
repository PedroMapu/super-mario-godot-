extends "res://cenas/enemy.gd"

@export var flattened_duration := 0.6


func get_contact_damage() -> int:
	return 2


func _start_animation() -> void:
	sprite.play(&"goomba_walk")


func stomp(_player: CharacterBody2D) -> void:
	defeated = true
	_play_defeat_sound()
	velocity = Vector2.ZERO
	sprite.play(&"goomba_flat")
	_disable_collisions()
	get_tree().create_timer(flattened_duration).timeout.connect(queue_free)

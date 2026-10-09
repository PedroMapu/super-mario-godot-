extends Area2D

signal collected(player: CharacterBody2D)

const COLLECT_SOUND := preload("res://Mario/moeda_coletada.wav")
const EFFECT_AUDIO := preload("res://cenas/effect_audio.gd")

@export_range(0.0, 64.0, 1.0, "suffix:px") var collect_rise := 10.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var collect_duration := 0.24

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if is_collected or not body is CharacterBody2D or not body.is_in_group("player"):
		return
	is_collected = true
	EFFECT_AUDIO.play_at(self, COLLECT_SOUND)
	# O sinal chega durante a fisica; desativa a area de forma adiada.
	set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	collected.emit(body)
	_animate_collection()


func _animate_collection() -> void:
	sprite.stop()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", sprite.position.y - collect_rise, collect_duration)
	tween.tween_property(sprite, "modulate:a", 0.0, collect_duration)
	tween.chain().tween_callback(queue_free)

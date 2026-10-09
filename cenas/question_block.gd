extends StaticBody2D

signal activated

const BUMP_SOUND := preload("res://Mario/bloco_interrogacao.wav")
const EFFECT_AUDIO := preload("res://cenas/effect_audio.gd")

@export_range(0.0, 32.0, 1.0, "suffix:px") var bump_height := 8.0
@export_range(0.01, 1.0, 0.01, "suffix:s") var rise_duration := 0.08
@export_range(0.01, 1.0, 0.01, "suffix:s") var return_duration := 0.14
@export var used_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var used := false


func _ready() -> void:
	add_to_group("question_blocks")


func activate_from_below() -> void:
	if used:
		return
	used = true
	EFFECT_AUDIO.play_at(self, BUMP_SOUND)
	activated.emit()
	_animate_bump()


func _animate_bump() -> void:
	var rest_position := sprite.position
	# So a imagem sobe: a superficie de colisao continua solida e estavel.
	var tween := create_tween()
	tween.tween_property(
		sprite, "position", rest_position + Vector2(0, -bump_height), rise_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_show_used_texture)
	tween.tween_property(
		sprite, "position", rest_position, return_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _show_used_texture() -> void:
	if used_texture != null:
		sprite.texture = used_texture

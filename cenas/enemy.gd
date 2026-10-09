extends CharacterBody2D

const DEFEAT_SOUND := preload("res://Mario/inimigo_derrotado.wav")
const EFFECT_AUDIO := preload("res://cenas/effect_audio.gd")
const CONTACT_GRACE_DURATION := 0.18
const WALL_NORMAL_THRESHOLD := 0.5
const FALL_DESPAWN_Y := 2000.0
const DEFEAT_RISE := 24.0
const DEFEAT_DURATION := 0.3

@export var walk_speed := 35.0
@export_range(-1, 1, 2) var direction: int = -1

@export_group("Patrulha")
## Distancia para cada lado da posicao inicial, em pixels. Zero impede a caminhada.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:px") var patrol_amplitude := 96.0
@export_group("")

@onready var sprite: AnimatedSprite2D = get_child(0) as AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $Colisao

var defeated := false
var contact_grace := 0.0
var _patrol_center_x := 0.0


func _ready() -> void:
	direction = -1 if direction < 0 else 1
	_patrol_center_x = global_position.x
	_start_animation()


func _physics_process(delta: float) -> void:
	if defeated:
		return
	contact_grace = maxf(0.0, contact_grace - delta)
	velocity.y += get_gravity().y * delta
	velocity.x = _horizontal_velocity(delta)
	move_and_slide()
	_resolve_slide_collisions()
	if _uses_patrol():
		_update_patrol_direction()
	sprite.flip_h = direction > 0
	if global_position.y > FALL_DESPAWN_Y:
		queue_free()


func _resolve_slide_collisions() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var other := collision.get_collider()
		if _is_moving_shell() and other is Node and other.is_in_group("enemies"):
			if other.has_method("hit_by_shell"):
				other.hit_by_shell()
		elif absf(collision.get_normal().x) > WALL_NORMAL_THRESHOLD:
			direction = 1 if collision.get_normal().x > 0.0 else -1


func _start_animation() -> void:
	pass


func _movement_speed() -> float:
	return walk_speed


func _uses_patrol() -> bool:
	return true


func _horizontal_velocity(delta: float) -> float:
	if not _uses_patrol():
		return direction * _movement_speed()
	if patrol_amplitude <= 0.0:
		return 0.0
	_update_patrol_direction()
	var target_x := _patrol_center_x + direction * patrol_amplitude
	# Limita o passo ate a extremidade, mantendo move_and_slide e suas colisoes.
	var distance := absf(target_x - global_position.x)
	return direction * minf(_movement_speed(), distance / delta)


func _update_patrol_direction() -> void:
	if global_position.x <= _patrol_center_x - patrol_amplitude:
		direction = 1
	elif global_position.x >= _patrol_center_x + patrol_amplitude:
		direction = -1


func _is_moving_shell() -> bool:
	return false


func _play_defeat_sound() -> void:
	EFFECT_AUDIO.play_at(self, DEFEAT_SOUND)


func collision_top() -> float:
	var rectangle := body_shape.shape as RectangleShape2D
	return body_shape.global_position.y - rectangle.size.y * global_scale.y * 0.5


func on_player_contact(player: CharacterBody2D, from_above: bool) -> void:
	if defeated or contact_grace > 0.0:
		return
	if from_above:
		contact_grace = CONTACT_GRACE_DURATION
		stomp(player)
		player.bounce_from_enemy()
	else:
		player.take_enemy_damage(self)


func get_contact_damage() -> int:
	return 1


func stomp(_player: CharacterBody2D) -> void:
	pass


func hit_by_shell() -> void:
	if defeated:
		return
	defeated = true
	_play_defeat_sound()
	velocity = Vector2.ZERO
	_disable_collisions()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y - DEFEAT_RISE, DEFEAT_DURATION)
	tween.tween_property(sprite, "modulate:a", 0.0, DEFEAT_DURATION)
	tween.chain().tween_callback(queue_free)


func _disable_collisions() -> void:
	# Contatos podem chegar durante a fisica; altera as colisoes de forma adiada.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	body_shape.set_deferred("disabled", true)

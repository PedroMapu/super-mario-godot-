extends "res://cenas/enemy.gd"

enum State { WALKING, SHELL_IDLE, SHELL_MOVING }

const SHELL_COLLISION_LAYER := 8
const SHELL_COLLISION_SIZE := Vector2(14, 12)
const SHELL_COLLISION_POSITION := Vector2(0, 6)
const MIN_BLINK_INTERVAL := 0.01

@export_group("Casco")
@export var shell_speed := 300.0
## Tempo desde a transformacao ate comecar a piscar. Chutes nao reiniciam o tempo.
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var shell_duration := 4.0
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:s") var shell_blink_duration := 1.0
@export_range(0.01, 1.0, 0.01, "or_greater", "suffix:s") var shell_blink_interval := 0.1

var state := State.WALKING
var _shell_elapsed := 0.0


func _physics_process(delta: float) -> void:
	if not defeated and state != State.WALKING:
		_shell_elapsed += delta
		if _shell_elapsed >= shell_duration + shell_blink_duration:
			queue_free()
			return
		if _shell_elapsed >= shell_duration:
			var blink_step := int(
				(_shell_elapsed - shell_duration) / maxf(shell_blink_interval, MIN_BLINK_INTERVAL)
			)
			sprite.visible = blink_step % 2 == 1
	super._physics_process(delta)


func _start_animation() -> void:
	sprite.play(&"koopa_walk")
	# Cada instancia precisa de sua propria forma ao encolher para o casco.
	body_shape.shape = body_shape.shape.duplicate()


func _movement_speed() -> float:
	match state:
		State.SHELL_IDLE:
			return 0.0
		State.SHELL_MOVING:
			return shell_speed
	return walk_speed


func _is_moving_shell() -> bool:
	return state == State.SHELL_MOVING


func _uses_patrol() -> bool:
	return state == State.WALKING


func stomp(player: CharacterBody2D) -> void:
	match state:
		State.WALKING:
			_transform_into_shell()
		State.SHELL_IDLE:
			_kick(player)
		State.SHELL_MOVING:
			state = State.SHELL_IDLE
			velocity.x = 0.0


func _transform_into_shell() -> void:
	_play_defeat_sound()
	state = State.SHELL_MOVING
	_shell_elapsed = 0.0
	sprite.visible = true
	sprite.play(&"koopa_shell")
	# O sprite do casco mantem os pes na mesma altura do Koopa.
	var rectangle := body_shape.shape as RectangleShape2D
	rectangle.set_deferred("size", SHELL_COLLISION_SIZE)
	body_shape.set_deferred("position", SHELL_COLLISION_POSITION)
	set_deferred("collision_layer", SHELL_COLLISION_LAYER)
	velocity.x = direction * shell_speed


func on_player_contact(player: CharacterBody2D, from_above: bool) -> void:
	if defeated or contact_grace > 0.0:
		return
	if state == State.SHELL_IDLE and not from_above:
		_kick(player)
		return
	super.on_player_contact(player, from_above)


func _kick(player: CharacterBody2D) -> void:
	direction = 1 if player.global_position.x <= global_position.x else -1
	state = State.SHELL_MOVING
	velocity.x = direction * shell_speed
	contact_grace = CONTACT_GRACE_DURATION

extends CharacterBody2D

signal enemy_contact(source: Node2D)
signal hazard_contact(source: Node2D)
signal respawned
signal death_started
signal death_finished
signal lives_changed(lives: int)

const MAX_LIVES := 3
const DAMAGE_INVULNERABILITY := 1.2
const DAMAGE_BLINK_INTERVAL := 0.08
const DAMAGE_BLINK_ALPHA := 0.35
const HURT_DURATION := 0.18
const HURT_PUSH_SPEED := 180.0
const HURT_JUMP_VELOCITY := -160.0
const RESPAWN_INVULNERABILITY := 0.6

const MOVEMENT_ACCELERATION := 1100.0
const ANIMATION_MOVEMENT_THRESHOLD := 5.0
const GROWTH_ANIMATION := &"small_to_big"
const GROWTH_FPS := 10.0
const GROWTH_IDLE_DURATION := 0.15
const BIG_BODY_HEIGHT := 64.0
const SMALL_JUMP_SOUND := preload("res://Mario/jump_small.wav")
const BIG_JUMP_SOUND := preload("res://Mario/jump_big.wav")

const CONTACT_NORMAL_THRESHOLD := 0.5
const STOMP_TOLERANCE := 4.0
const ENEMY_COLLISION_LAYER := 3
const HAZARD_COLLISION_LAYER := 8

const WATER_FEET_INSET := 2.0
const WATER_GRAVITY_SCALE := 0.25
const WATER_FALL_SPEED := 90.0

const DEATH_OFFSCREEN_MARGIN := 64.0
const DEATH_SOUND := preload("res://Mario/morte_mario.wav")
const DEATH_SCREAM := preload("res://Mario/grito_mario.wav")

@export var move_speed := 270.0

@export_group("Salto")
@export var jump_velocity := -270.0
## Altura do salto do Mario grande em pixels. Aumente para pular mais alto.
@export_range(1.0, 1000.0, 5.0, "or_greater", "suffix:px") var big_jump_height := 220.0
@export_group("")

@export var swim_speed := 110.0
@export var swim_impulse := -145.0
@export var enemy_bounce_velocity := -220.0

@export_group("Morte")
@export_range(0.0, 1.0, 0.05, "suffix:s") var death_pause := 0.3
@export var death_jump_velocity := -360.0
@export_range(1.0, 3000.0, 10.0, "or_greater") var death_gravity := 980.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var death_respawn_delay := 0.6
## Limite de queda. As fases configuram este valor a partir do mapa.
@export var fall_death_y := 2000.0
@export_group("")

@onready var sprite: AnimatedSprite2D = $Animacao
@onready var damage_area: Area2D = $AreaDano
@onready var body_shape: CollisionShape2D = $Colisao
@onready var damage_shape: CollisionShape2D = $AreaDano/ColisaoDano
@onready var growth_sound: AudioStreamPlayer = $GrowthSound
@onready var jump_sound: AudioStreamPlayer = $JumpSound

var is_big := false
var is_growing := false
var _growth_idle_time := 0.0
var _growth_velocity := Vector2.ZERO
var _growth_tree_paused := false
var _growth_process_mode: ProcessMode
var _small_sprite_offset := Vector2.ZERO
var _base_sprite_frames: SpriteFrames
var _small_body_position := Vector2.ZERO
var _small_body_size := Vector2.ZERO
var _small_damage_position := Vector2.ZERO
var _small_damage_size := Vector2.ZERO
var _big_body_applied := false

var is_swimming := false
var _spawn_position := Vector2.ZERO
var _respawn_pending := false
var _feet_before_move := 0.0
var _fall_velocity := 0.0
var _damage_grace := 0.0
var lives := MAX_LIVES
var _hurt_time := 0.0
var is_dead := false
var _death_time := 0.0
var _death_falling := false
var _death_offscreen := false
var _death_finishing := false
var _saved_collision_layer := 0
var _saved_collision_mask := 0
var _saved_process_mode: ProcessMode
var _saved_tree_paused := false
var _saved_sprite_visible := true
var _saved_sprite_z_index := 0
var _saved_camera_top_level := false
var _saved_camera_transform := Transform2D.IDENTITY


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	damage_area.body_entered.connect(_on_damage_contact)
	damage_area.area_entered.connect(_on_damage_contact)
	# Cada Mario conserva suas formas e os recursos do editor permanecem intactos.
	body_shape.shape = body_shape.shape.duplicate()
	damage_shape.shape = damage_shape.shape.duplicate()
	_small_sprite_offset = sprite.offset
	_base_sprite_frames = sprite.sprite_frames
	_small_body_position = body_shape.position
	_small_body_size = (body_shape.shape as RectangleShape2D).size
	_small_damage_position = damage_shape.position
	_small_damage_size = (damage_shape.shape as RectangleShape2D).size
	sprite.animation_finished.connect(_on_growth_animation_finished)
	sprite.frame_changed.connect(_align_sprite_to_feet)
	sprite.animation_changed.connect(_align_sprite_to_feet)
	sprite.play(&"small_idle")


func _exit_tree() -> void:
	# Evita deixar o jogo pausado se a cena for removida durante a morte.
	if is_dead:
		get_tree().paused = _saved_tree_paused
	elif is_growing:
		get_tree().paused = _growth_tree_paused


func _physics_process(delta: float) -> void:
	if is_dead:
		_process_death(delta)
		return
	if is_growing:
		if _growth_idle_time > 0.0:
			_growth_idle_time = maxf(0.0, _growth_idle_time - delta)
			if _growth_idle_time == 0.0:
				_finish_growth()
		return
	if global_position.y > fall_death_y:
		die()
		return
	_update_damage_feedback(delta)
	if is_big and not _big_body_applied:
		_try_expand_body()
	is_swimming = _is_in_water()
	var input_direction := Input.get_axis("move_left", "move_right")
	_update_horizontal_velocity(input_direction, delta)
	_update_vertical_velocity(delta)

	_feet_before_move = _feet_position().y
	_fall_velocity = velocity.y
	move_and_slide()
	_check_block_contacts()
	if is_growing:
		return
	_check_enemy_contacts()
	if not is_dead:
		_check_platform_contacts()
		_update_animation(input_direction)


func _update_damage_feedback(delta: float) -> void:
	_damage_grace = maxf(0.0, _damage_grace - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	# Pisca enquanto protegido, sem alterar os frames das animacoes.
	var blink_hidden := _damage_grace > 0.0 and int(_damage_grace / DAMAGE_BLINK_INTERVAL) % 2 == 0
	sprite.modulate.a = DAMAGE_BLINK_ALPHA if blink_hidden else 1.0


func _update_horizontal_velocity(input_direction: float, delta: float) -> void:
	var target_speed := swim_speed if is_swimming else move_speed
	if _hurt_time <= 0.0:
		velocity.x = move_toward(
			velocity.x, input_direction * target_speed, MOVEMENT_ACCELERATION * delta
		)


func _update_vertical_velocity(delta: float) -> void:
	if is_swimming:
		if Input.is_action_pressed("move_down"):
			velocity.y = move_toward(velocity.y, swim_speed, MOVEMENT_ACCELERATION * delta)
		else:
			velocity.y += get_gravity().y * WATER_GRAVITY_SCALE * delta
			velocity.y = minf(velocity.y, WATER_FALL_SPEED)
			if Input.is_action_just_pressed("jump"):
				velocity.y = swim_impulse
	else:
		if not is_on_floor():
			velocity.y += get_gravity().y * delta
		if Input.is_action_just_pressed("jump") and is_on_floor():
			if is_big:
				velocity.y = -sqrt(2.0 * absf(get_gravity().y) * big_jump_height)
			else:
				velocity.y = jump_velocity
			jump_sound.stream = BIG_JUMP_SOUND if is_big else SMALL_JUMP_SOUND
			jump_sound.play()


func _check_block_contacts() -> void:
	if _fall_velocity >= 0.0:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y <= CONTACT_NORMAL_THRESHOLD:
			continue
		var block := collision.get_collider() as Node
		if block != null and block.has_method("activate_from_below"):
			block.activate_from_below()


func _check_platform_contacts() -> void:
	if _fall_velocity < 0.0:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().y >= -CONTACT_NORMAL_THRESHOLD:
			continue
		var platform := collision.get_collider() as Node
		if platform != null and platform.has_method("start_collapse"):
			platform.start_collapse()


func _feet_position() -> Vector2:
	var rectangle := body_shape.shape as RectangleShape2D
	return body_shape.to_global(Vector2(0, rectangle.size.y * 0.5))


func _is_in_water() -> bool:
	# Consulta dentro dos pes; acompanha ajustes de tamanho e escala do colisor.
	var water_probe := _feet_position() - body_shape.global_transform.y.normalized() * WATER_FEET_INSET
	for node in get_tree().get_nodes_in_group("water"):
		if node is TileMapLayer:
			var water_layer := node as TileMapLayer
			var cell := water_layer.local_to_map(water_layer.to_local(water_probe))
			if water_layer.get_cell_source_id(cell) != -1:
				return true
	return false


func _update_animation(input_direction: float) -> void:
	if is_dead or is_growing:
		return
	if input_direction != 0.0:
		sprite.flip_h = input_direction < 0.0
	elif absf(velocity.x) > ANIMATION_MOVEMENT_THRESHOLD:
		sprite.flip_h = velocity.x < 0.0

	var animation := _select_animation(input_direction)
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


func _select_animation(input_direction: float) -> StringName:
	if is_big and is_swimming:
		if Input.is_action_pressed("move_down"):
			return &"big_swim_down"
		if input_direction != 0.0:
			return &"big_swim_sides"
		if velocity.y < 0.0:
			return &"big_swim_up"
		return &"big_swim_down"
	var small_animation := _select_small_animation(input_direction)
	if not is_big:
		return small_animation
	var big_animation := StringName(String(small_animation).replace("small_", "big_"))
	if sprite.sprite_frames.has_animation(big_animation):
		return big_animation
	# Enquanto nao houver outras poses grandes, conserva o Mario grande.
	return &"big_idle"


func _select_small_animation(input_direction: float) -> StringName:
	if is_swimming:
		if Input.is_action_pressed("move_down") or (input_direction == 0.0 and velocity.y > 0.0):
			return &"small_swim_down"
		return &"small_swim_sides"
	if not is_on_floor():
		if velocity.y < 0.0 or not sprite.sprite_frames.has_animation(&"small_fall"):
			return &"small_jump"
		return &"small_fall"
	if absf(velocity.x) > ANIMATION_MOVEMENT_THRESHOLD:
		return &"small_walk"
	return &"small_idle"


func grow() -> void:
	if is_dead or is_growing or is_big or _respawn_pending:
		return
	if not sprite.sprite_frames.has_animation(GROWTH_ANIMATION):
		return
	jump_sound.stop()
	var current_pose := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var frames := sprite.sprite_frames.duplicate() as SpriteFrames
	# A pose small_to_big montada no editor vira a etapa intermediaria classica.
	# Animacoes com varios frames ja montados sao reproduzidas como estao.
	if frames.get_frame_count(GROWTH_ANIMATION) == 1:
		var growth_pose := frames.get_frame_texture(GROWTH_ANIMATION, 0)
		var big_pose := frames.get_frame_texture(&"big_idle", 0)
		frames.clear(GROWTH_ANIMATION)
		for pose in [current_pose, growth_pose, current_pose, growth_pose, big_pose, current_pose, growth_pose, big_pose]:
			frames.add_frame(GROWTH_ANIMATION, pose)
		frames.set_animation_speed(GROWTH_ANIMATION, GROWTH_FPS)
	frames.set_animation_loop(GROWTH_ANIMATION, false)
	is_growing = true
	_growth_idle_time = 0.0
	_growth_velocity = velocity
	velocity = Vector2.ZERO
	_growth_tree_paused = get_tree().paused
	_growth_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	sprite.modulate.a = 1.0
	sprite.sprite_frames = frames
	sprite.play(GROWTH_ANIMATION)
	growth_sound.play()
	_align_sprite_to_feet()


func _on_growth_animation_finished() -> void:
	if not is_growing or sprite.animation != GROWTH_ANIMATION:
		return
	is_big = true
	sprite.play(&"big_idle")
	_growth_idle_time = GROWTH_IDLE_DURATION


func _finish_growth() -> void:
	growth_sound.stop()
	get_tree().paused = _growth_tree_paused
	process_mode = _growth_process_mode
	is_growing = false
	velocity = _growth_velocity
	_damage_grace = maxf(_damage_grace, RESPAWN_INVULNERABILITY)
	_try_expand_body()


func _align_sprite_to_feet() -> void:
	if not is_growing and not is_big and not is_dead:
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var feet_y := _small_body_position.y + _small_body_size.y * 0.5
	sprite.offset.y = (feet_y - sprite.position.y) / sprite.scale.y - texture.get_height() * 0.5


func _try_expand_body() -> void:
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(_small_body_size.x, BIG_BODY_HEIGHT)
	var feet_y := _small_body_position.y + _small_body_size.y * 0.5
	var center := Vector2(_small_body_position.x, feet_y - BIG_BODY_HEIGHT * 0.5)
	var query := PhysicsShapeQueryParameters2D.new()
	var probe := rectangle.duplicate() as RectangleShape2D
	# O repouso de move_and_slide pode penetrar alguns centesimos no piso.
	probe.size -= Vector2(0.2, 0.2)
	query.shape = probe
	query.transform = global_transform * Transform2D(0.0, center)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	# Ao bater sob a caixa, espera sair do teto para aumentar o corpo sem prender.
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return
	(body_shape.shape as RectangleShape2D).size = rectangle.size
	body_shape.position = center
	var extra_height := BIG_BODY_HEIGHT - _small_body_size.y
	(damage_shape.shape as RectangleShape2D).size = _small_damage_size + Vector2(0, extra_height)
	damage_shape.position = _small_damage_position - Vector2(0, extra_height * 0.5)
	_big_body_applied = true


func _on_damage_contact(source: Node2D) -> void:
	if is_growing or _respawn_pending or _damage_grace > 0.0:
		return
	# Contatos dos inimigos sao resolvidos apos o movimento, incluindo pisoes.
	if source.has_method("on_player_contact"):
		return

	var is_hazard := source.is_in_group("hazards")
	var is_enemy := source.is_in_group("enemies")

	# As camadas 8 e 3 tambem identificam perigos e inimigos.
	var collision_object := source as CollisionObject2D
	if collision_object != null:
		if collision_object.get_collision_layer_value(HAZARD_COLLISION_LAYER):
			is_hazard = true
		if collision_object.get_collision_layer_value(ENEMY_COLLISION_LAYER):
			is_enemy = true

	if is_hazard:
		hazard_contact.emit(source)
		die()
	elif is_enemy:
		take_enemy_damage(source)


func _check_enemy_contacts() -> void:
	if _respawn_pending or _damage_grace > 0.0:
		return
	var handled: Array[Node2D] = []
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var source := collision.get_collider() as Node2D
		if source != null and source.has_method("on_player_contact"):
			var from_above := (
				_fall_velocity > 0.0 and collision.get_normal().y < -CONTACT_NORMAL_THRESHOLD
			)
			source.on_player_contact(self, from_above)
			handled.append(source)
			if is_dead or _damage_grace > 0.0:
				return
	for source in damage_area.get_overlapping_bodies():
		if source in handled or not source.has_method("on_player_contact"):
			continue
		var from_above: bool = (
			_fall_velocity > 0.0 and _feet_before_move <= source.collision_top() + STOMP_TOLERANCE
		)
		source.on_player_contact(self, from_above)
		if is_dead or _damage_grace > 0.0:
			return


func bounce_from_enemy() -> void:
	if is_dead:
		return
	velocity.y = enemy_bounce_velocity


func take_enemy_damage(source: Node2D) -> void:
	if is_dead or is_growing or _respawn_pending or _damage_grace > 0.0:
		return
	var damage := 1
	if source.has_method("get_contact_damage"):
		damage = maxi(1, source.get_contact_damage())
	lives = maxi(0, lives - damage)
	_damage_grace = DAMAGE_INVULNERABILITY
	lives_changed.emit(lives)
	enemy_contact.emit(source)
	if lives == 0:
		die()
		return
	var push_direction := -1.0 if global_position.x < source.global_position.x else 1.0
	velocity = Vector2(push_direction * HURT_PUSH_SPEED, HURT_JUMP_VELOCITY)
	_hurt_time = HURT_DURATION


func set_lives(value: int) -> void:
	lives = clampi(value, 0, MAX_LIVES)
	lives_changed.emit(lives)


func die() -> void:
	if is_dead:
		return
	growth_sound.stop()
	jump_sound.stop()
	if is_growing:
		get_tree().paused = _growth_tree_paused
		process_mode = _growth_process_mode
		is_growing = false
	if lives != 0:
		set_lives(0)
	is_dead = true
	sprite.modulate.a = 1.0
	_play_death_scream()
	_play_death_sound()
	_respawn_pending = true
	is_swimming = false
	_death_time = 0.0
	_death_falling = false
	_death_offscreen = false
	_death_finishing = false
	velocity = Vector2.ZERO
	_save_death_state()
	_disable_death_contacts()
	_freeze_camera()
	_play_death_animation()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	death_started.emit()


func _save_death_state() -> void:
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	_saved_process_mode = process_mode
	_saved_tree_paused = get_tree().paused
	_saved_sprite_visible = sprite.visible
	_saved_sprite_z_index = sprite.z_index


func _disable_death_contacts() -> void:
	remove_from_group("player")
	# Interrompe os contatos; as formas sao desativadas fora do sinal de fisica.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	body_shape.set_deferred("disabled", true)
	damage_area.set_deferred("monitoring", false)


func _freeze_camera() -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		_saved_camera_top_level = camera.top_level
		_saved_camera_transform = camera.transform
		var camera_global := camera.global_transform
		camera.top_level = true
		camera.global_transform = camera_global
		camera.force_update_scroll()


func _play_death_animation() -> void:
	# Reproduz os frames de mario_death montados no editor, inclusive com o mundo pausado.
	sprite.offset = _small_sprite_offset
	sprite.z_index = 100
	sprite.show()
	sprite.play(&"mario_death")
	sprite.set_frame_and_progress(0, 0.0)
	_align_sprite_to_feet()


func _play_death_sound() -> void:
	_play_global_sound(DEATH_SOUND, -10.0)


func _play_death_scream() -> void:
	_play_global_sound(DEATH_SCREAM, -1.0)


func _play_global_sound(stream: AudioStream, volume_db: float) -> void:
	var sound_player := AudioStreamPlayer.new()
	sound_player.stream = stream
	sound_player.volume_db = volume_db
	sound_player.process_mode = Node.PROCESS_MODE_ALWAYS
	sound_player.finished.connect(sound_player.queue_free)
	get_tree().root.add_child(sound_player)
	sound_player.play()


func _process_death(delta: float) -> void:
	if _death_finishing:
		return
	_death_time += delta
	if _death_offscreen:
		if _death_time >= death_respawn_delay:
			_death_finishing = true
			call_deferred("_finish_death")
		return
	if not _death_falling:
		if _death_time < death_pause:
			return
		_death_falling = true
		velocity.y = death_jump_velocity
	# Movimento direto ignora piso, teto, agua e inimigos durante a morte.
	velocity.y += death_gravity * delta
	global_position += velocity * delta
	var screen_bottom := _screen_bottom()
	if velocity.y > 0.0 and global_position.y > screen_bottom + DEATH_OFFSCREEN_MARGIN:
		_death_offscreen = true
		_death_time = 0.0
		sprite.hide()


func _screen_bottom() -> float:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null and camera.is_current():
		return (
			camera.get_screen_center_position().y
			+ camera.get_viewport_rect().size.y / (2.0 * camera.zoom.y)
		)
	return fall_death_y


func _finish_death() -> void:
	get_tree().paused = _saved_tree_paused
	process_mode = _saved_process_mode
	if death_finished.get_connections().is_empty():
		_respawn()
	else:
		death_finished.emit()


func _respawn() -> void:
	growth_sound.stop()
	jump_sound.stop()
	if is_dead:
		_restore_after_death()
	if is_growing:
		get_tree().paused = _growth_tree_paused
		process_mode = _growth_process_mode
	is_growing = false
	is_big = false
	_big_body_applied = false
	_growth_idle_time = 0.0
	sprite.offset = _small_sprite_offset
	sprite.sprite_frames = _base_sprite_frames
	(body_shape.shape as RectangleShape2D).size = _small_body_size
	body_shape.position = _small_body_position
	(damage_shape.shape as RectangleShape2D).size = _small_damage_size
	damage_shape.position = _small_damage_position
	global_position = _spawn_position
	velocity = Vector2.ZERO
	is_swimming = false
	_damage_grace = RESPAWN_INVULNERABILITY
	_hurt_time = 0.0
	sprite.modulate.a = 1.0
	set_lives(MAX_LIVES)
	_respawn_pending = false
	_update_animation(0.0)
	var active_camera := get_node_or_null("Camera2D") as Camera2D
	if active_camera != null:
		active_camera.reset_smoothing()
		active_camera.force_update_scroll()
	respawned.emit()


func _restore_after_death() -> void:
	get_tree().paused = _saved_tree_paused
	process_mode = _saved_process_mode
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	body_shape.set_deferred("disabled", false)
	damage_area.set_deferred("monitoring", true)
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.top_level = _saved_camera_top_level
		camera.transform = _saved_camera_transform
	sprite.visible = _saved_sprite_visible
	sprite.z_index = _saved_sprite_z_index
	add_to_group("player")
	is_dead = false


func set_spawn_position(spawn_position: Vector2) -> void:
	_spawn_position = spawn_position
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_swimming = false

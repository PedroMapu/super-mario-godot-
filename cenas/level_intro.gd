extends CanvasLayer

signal finished

enum Stage { BLACK, RUNNING, ARRIVAL, REVEALING, FINISHED }

const BLACK_DURATION := 0.16
const ARRIVAL_DURATION := 0.12

@onready var iris: ColorRect = $Iris
@onready var runner: AnimatedSprite2D = $Runner

var stage := Stage.BLACK
var run_duration := 1.05
var reveal_duration := 1.0
var iris_radius := 0.0
var iris_center := Vector2.ZERO
var _elapsed := 0.0
var _level: Node2D
var _mario: CharacterBody2D
var _level_process_mode: ProcessMode
var _sprite_was_visible := true
var _restored := false
var _spawn_prepared := false
var _walk_animation: StringName
var _idle_animation: StringName


func start(level: Node2D, mario: CharacterBody2D, run_time: float, reveal_time: float) -> void:
	_level = level
	_mario = mario
	run_duration = maxf(0.1, run_time)
	reveal_duration = maxf(0.1, reveal_time)
	_level_process_mode = level.process_mode
	_sprite_was_visible = mario.sprite.visible
	# Pausa apenas esta fase; a musica e outras cenas continuam independentes.
	level.process_mode = Node.PROCESS_MODE_DISABLED
	mario.sprite.hide()
	runner.sprite_frames = mario.sprite.sprite_frames
	runner.centered = mario.sprite.centered
	runner.offset = mario.sprite.offset
	runner.flip_h = false
	_walk_animation = &"big_walk" if mario.is_big else &"small_walk"
	_idle_animation = &"big_idle" if mario.is_big else &"small_idle"
	runner.speed_scale = 1.6
	runner.play(_walk_animation)
	mario.get_node("Camera2D").force_update_scroll()
	_refresh_visuals()


func _process(delta: float) -> void:
	if not is_instance_valid(_mario) or stage == Stage.FINISHED:
		return
	_elapsed += delta
	match stage:
		Stage.BLACK:
			_prepare_spawn()
			if _elapsed >= BLACK_DURATION:
				stage = Stage.RUNNING
				_elapsed = 0.0
				runner.show()
		Stage.RUNNING:
			if _elapsed >= run_duration:
				stage = Stage.ARRIVAL
				_elapsed = 0.0
				runner.play(_idle_animation)
		Stage.ARRIVAL:
			if _elapsed >= ARRIVAL_DURATION:
				stage = Stage.REVEALING
				_elapsed = 0.0
	_refresh_visuals()
	if stage == Stage.REVEALING and _elapsed >= reveal_duration:
		_finish()


func _prepare_spawn() -> void:
	if _spawn_prepared:
		return
	# Os marcadores podem ficar ligeiramente acima do piso. Resolve a queda
	# inicial sob o preto para a corrida terminar apoiada, sem mexer no marcador.
	var feet: Vector2 = _mario._feet_position()
	var query := PhysicsRayQueryParameters2D.create(feet - Vector2(0, 1), feet + Vector2(0, 128), 2 | 16 | 32 | 128)
	var hit := _mario.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y > -0.5:
		return
	var source := hit.collider as Node
	if source != null and source.is_in_group("hazards"):
		return
	_mario.global_position.y += maxf(0.0, hit.position.y - feet.y)
	_mario.velocity = Vector2.ZERO
	_spawn_prepared = true
	_mario.get_node("Camera2D").force_update_scroll()


func _refresh_visuals() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	iris.size = viewport_size
	var target: Transform2D = _mario.sprite.get_global_transform_with_canvas()
	runner.transform = target
	if stage == Stage.BLACK or stage == Stage.RUNNING:
		var texture := runner.sprite_frames.get_frame_texture(_walk_animation, 0)
		var start_x := -texture.get_width() * absf(target.get_scale().x)
		var progress := clampf(_elapsed / run_duration, 0.0, 1.0) if stage == Stage.RUNNING else 0.0
		runner.position.x = lerpf(start_x, target.origin.x, progress)
	iris_center = _mario.body_shape.get_global_transform_with_canvas().origin
	iris_radius = 0.0
	if stage == Stage.REVEALING:
		var farthest_corner := 0.0
		for corner in [Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)]:
			farthest_corner = maxf(farthest_corner, iris_center.distance_to(corner))
		iris_radius = (farthest_corner + 4.0) * smoothstep(0.0, 1.0, _elapsed / reveal_duration)
	var material := iris.material as ShaderMaterial
	material.set_shader_parameter("viewport_size", viewport_size)
	material.set_shader_parameter("iris_center", iris_center)
	material.set_shader_parameter("iris_radius", iris_radius)


func _restore_level() -> void:
	if _restored:
		return
	_restored = true
	if is_instance_valid(_mario):
		_mario.sprite.visible = _sprite_was_visible
	if is_instance_valid(_level):
		_level.process_mode = _level_process_mode


func _finish() -> void:
	stage = Stage.FINISHED
	_mario.sprite.flip_h = false
	_mario.sprite.play(_idle_animation)
	_restore_level()
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	# Remover/reiniciar uma fase durante a abertura nao deixa estado preso.
	_restore_level()

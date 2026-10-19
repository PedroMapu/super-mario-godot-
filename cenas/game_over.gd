extends CanvasLayer

signal restart_requested
signal exit_requested

const CARD_SIZE := Vector2(384, 256)

@onready var background: ColorRect = $Background
@onready var card: Control = $Card
@onready var restart_button: Button = $Card/Restart
@onready var exit_button: Button = $Card/Exit
@onready var pointer: Polygon2D = $Card/Pointer
@onready var stats: Label = $Card/Stats
@onready var portrait: Sprite2D = $Card/Portrait

var _action_taken := false


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_viewport)
	restart_button.pressed.connect(_on_restart_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	for button: Button in [restart_button, exit_button]:
		button.focus_entered.connect(_point_at.bind(button))
		button.mouse_entered.connect(button.grab_focus)
	_fit_viewport()
	restart_button.grab_focus()


func bind_level(level: Node2D) -> void:
	var stage := level.scene_file_path.get_file().get_basename().trim_prefix("level_")
	stats.text = "FASE %s\nMOEDAS %02d/%02d\nCAIXAS %02d/%02d" % [
		stage, level.collected_coins, level.total_coins, level.activated_boxes, level.total_boxes]
	portrait.texture = level.mario.sprite.sprite_frames.get_frame_texture(&"mario_death", 0)


func _fit_viewport() -> void:
	var view_size := get_viewport().get_visible_rect().size
	background.size = view_size
	var available_scale := minf(view_size.x / CARD_SIZE.x, view_size.y / CARD_SIZE.y)
	var pixel_scale := maxf(1.0, floorf(minf(3.0, available_scale)))
	pixel_scale = minf(pixel_scale, available_scale)
	card.scale = Vector2.ONE * pixel_scale
	card.position = ((view_size - CARD_SIZE * pixel_scale) * 0.5).floor()


func _point_at(button: Button) -> void:
	pointer.position.y = button.position.y + 8.0


func _lock_buttons() -> bool:
	if _action_taken:
		return false
	_action_taken = true
	restart_button.disabled = true
	exit_button.disabled = true
	return true


func _on_restart_pressed() -> void:
	if _lock_buttons():
		restart_requested.emit()


func _on_exit_pressed() -> void:
	if _lock_buttons():
		exit_requested.emit()
		get_tree().quit()

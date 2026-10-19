extends CanvasLayer

const HUD_SIZE := Vector2(320, 40)

@onready var strip: Control = $Strip
@onready var lives_label: Label = $Strip/Lives/Count
@onready var boxes_label: Label = $Strip/Boxes/Count
@onready var coins_label: Label = $Strip/Coins/Count
@onready var stage_label: Label = $Strip/Stage/Count

var collected_coins := 0
var _level: Node2D


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()


func _fit_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	# Integer scaling keeps the bitmap font and frame sharp. Tiny windows fit too.
	var available_scale := minf(viewport_size.x / HUD_SIZE.x, viewport_size.y / 240.0)
	var pixel_scale := maxf(1.0, floorf(minf(3.0, available_scale)))
	pixel_scale = minf(pixel_scale, viewport_size.x / HUD_SIZE.x)
	strip.scale = Vector2.ONE * pixel_scale
	strip.position = Vector2(floorf((viewport_size.x - HUD_SIZE.x * pixel_scale) * 0.5), 12.0 * pixel_scale)


func bind_level(level: Node2D) -> void:
	_level = level
	level.boxes_changed.connect(update_boxes)
	level.coins_changed.connect(update_coins)
	level.mario.lives_changed.connect(update_lives)
	update_boxes(level.activated_boxes, level.total_boxes)
	update_lives(level.mario.lives)
	# Scene filenames work with F6 and with instances renamed inside main.
	stage_label.text = level.scene_file_path.get_file().get_basename().trim_prefix("level_")
	update_coins(level.collected_coins, level.total_coins)


func update_coins(collected: int, _total: int) -> void:
	collected_coins = collected
	coins_label.text = "×%02d" % collected_coins


func update_boxes(activated: int, total: int) -> void:
	boxes_label.text = "%d/%d" % [activated, total]


func update_lives(lives: int) -> void:
	lives_label.text = "×%02d" % maxi(0, lives)

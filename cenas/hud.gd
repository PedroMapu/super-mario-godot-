extends CanvasLayer

const HEART_FULL := preload("res://Cenario/hud/heart_full.svg")
const HEART_EMPTY := preload("res://Cenario/hud/heart_empty.svg")

@onready var boxes_label: Label = $Margin/Panel/Padding/Rows/Boxes/Count
@onready var hearts: HBoxContainer = $Margin/Panel/Padding/Rows/Lives/Hearts


func bind_level(level: Node2D) -> void:
	level.boxes_changed.connect(update_boxes)
	level.mario.lives_changed.connect(update_lives)
	update_boxes(level.activated_boxes, level.total_boxes)
	update_lives(level.mario.lives)


func update_boxes(activated: int, total: int) -> void:
	boxes_label.text = "%d / %d" % [activated, total]


func update_lives(lives: int) -> void:
	for index in hearts.get_child_count():
		var heart := hearts.get_child(index) as TextureRect
		heart.texture = HEART_FULL if index < lives else HEART_EMPTY

extends "res://cenas/game_over.gd"

var _celebration_time := 0.0
@onready var victory_music: AudioStreamPlayer = $VictoryMusic


func _ready() -> void:
	super._ready()
	# Cada menu controla seu loop sem modificar o recurso importado compartilhado.
	var music := victory_music.stream.duplicate() as AudioStreamWAV
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = roundi(music.get_length() * music.mix_rate)
	victory_music.stream = music
	victory_music.play()
	# A mesma fonte e os mesmos controles do Game Over, com cores de vitoria.
	var frame := ($Card/Frame as Panel).get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	frame.bg_color = Color("101c2b")
	frame.border_color = Color("f8c850")
	($Card/Frame as Panel).add_theme_stylebox_override("panel", frame)
	for button: Button in [restart_button, exit_button]:
		var normal := button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		normal.bg_color = Color("173c46")
		normal.border_color = Color("367c80")
		button.add_theme_stylebox_override("normal", normal)
		var hover := button.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
		hover.bg_color = Color("285e5e")
		button.add_theme_stylebox_override("hover", hover)


func bind_level(level: Node2D) -> void:
	stats.text = "FASE 02 CONCLUIDA\nMOEDAS %02d/%02d\nCAIXAS %02d/%02d" % [
		level.collected_coins, level.total_coins, level.activated_boxes, level.total_boxes]
	var victory_pose := AtlasTexture.new()
	victory_pose.atlas = preload("res://Mario/Small.png")
	victory_pose.region = Rect2(168, 44, 16, 20)
	portrait.texture = victory_pose


func _process(delta: float) -> void:
	_celebration_time += delta
	portrait.position.y = 113.0 + floorf(sin(_celebration_time * 4.0) * 2.0)
	$Card/Stars.modulate.a = 0.65 + 0.35 * absf(sin(_celebration_time * 3.0))

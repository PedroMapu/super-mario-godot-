extends Node2D

signal restarted(replacement: Node2D)
signal boxes_changed(activated: int, total: int)
signal coins_changed(collected: int, total: int)
signal game_completed

const QUESTION_BLOCK_SCENE := preload("res://cenas/question_block.tscn")
const QUESTION_TILES := [Vector2i(27, 15), Vector2i(1, 30)]
const HUD_SCENE := preload("res://cenas/hud.tscn")
const COIN_SCRIPT := preload("res://cenas/coin.gd")
const INTRO_SCENE := preload("res://cenas/level_intro.tscn")
const GAME_OVER_SCENE := preload("res://cenas/game_over.tscn")
const GAME_COMPLETE_SCENE := preload("res://cenas/game_complete.tscn")
const FALL_DEATH_MARGIN := 64.0
const FALLING_PLATFORM_SCENE := preload("res://cenas/falling_platform.tscn")
const PLATFORM_ATLAS_ORIGIN := Vector2i(9, 21)
const PLATFORM_ATLAS_SIZE := Vector2i(3, 2)
const ENEMY_SUPPORT_LAYER := 512

@export var enemy_supports_enabled := false
@export var growth_block_cells: Array[Vector2i] = []
@export var cape_block_cells: Array[Vector2i] = []
@export var is_final_level := false

@export_group("Abertura")
@export var intro_enabled := true
@export_range(0.1, 5.0, 0.05, "suffix:s") var intro_run_duration := 1.05
@export_range(0.1, 5.0, 0.05, "suffix:s") var intro_reveal_duration := 1.0
@export_group("")

var total_boxes := 0
var activated_boxes := 0
var total_coins := 0
var collected_coins := 0
var hud: CanvasLayer
var is_intro_playing := false
var intro: CanvasLayer
var is_game_over := false
var game_over_screen: CanvasLayer
var is_game_complete := false
var completion_screen: CanvasLayer
var _completion_pending := false

@onready var mario: CharacterBody2D = $Mario
@onready var camera: Camera2D = $Mario/Camera2D


func _ready() -> void:
	mario.set_spawn_position($PlayerSpawn.global_position)
	var bounds := get_map_bounds()
	camera.set_map_bounds(bounds)
	mario.fall_death_y = bounds.end.y + FALL_DEATH_MARGIN
	mario.death_finished.connect(_show_game_over)
	_setup_question_blocks()
	_setup_falling_platforms()
	_setup_enemy_supports()
	_register_question_blocks()
	_register_coins()
	_setup_hud()
	_setup_intro()
	_setup_final_portal()


func _setup_final_portal() -> void:
	if not is_final_level:
		return
	var portal := get_node("PortalFinal") as Area2D
	portal.body_entered.connect(_on_final_portal_entered)


func _physics_process(_delta: float) -> void:
	# Inclui o ultimo item coletado dentro do portal e o fim de uma transformacao.
	if is_final_level and has_completed_objectives():
		_on_final_portal_entered(mario)


func _can_complete_game() -> bool:
	if not is_final_level or is_game_complete or is_game_over or is_intro_playing:
		return false
	if mario.is_dead or mario.is_growing or get_tree().paused or not has_completed_objectives():
		return false
	var portal := get_node_or_null("PortalFinal") as Area2D
	return portal != null and portal.overlaps_body(mario)


func _on_final_portal_entered(body: Node2D) -> void:
	if body != mario or _completion_pending or not _can_complete_game():
		return
	_completion_pending = true
	call_deferred("_complete_game")


func _complete_game() -> void:
	_completion_pending = false
	# Revalida fora dos sinais de fisica antes de congelar a fase.
	if not _can_complete_game():
		return
	is_game_complete = true
	mario.velocity = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED
	completion_screen = GAME_COMPLETE_SCENE.instantiate() as CanvasLayer
	add_child(completion_screen)
	completion_screen.bind_level(self)
	completion_screen.restart_requested.connect(_on_play_again)
	game_completed.emit()


func _on_play_again() -> void:
	call_deferred("_restart_game")


func _restart_game() -> void:
	# Reinicia a aventura pela primeira fase, inclusive ao executar a fase 2 com F6.
	get_tree().change_scene_to_file("res://cenas/main.tscn")


func _setup_intro() -> void:
	if not intro_enabled:
		return
	is_intro_playing = true
	intro = INTRO_SCENE.instantiate() as CanvasLayer
	add_child(intro)
	intro.finished.connect(_on_intro_finished)
	intro.tree_exiting.connect(_on_intro_finished)
	intro.start(self, mario, intro_run_duration, intro_reveal_duration)


func _on_intro_finished() -> void:
	is_intro_playing = false


func _show_game_over() -> void:
	if is_game_over or is_game_complete:
		return
	is_game_over = true
	# A animacao de morte terminou. Aguarda uma escolha sem mover o mundo.
	process_mode = Node.PROCESS_MODE_DISABLED
	game_over_screen = GAME_OVER_SCENE.instantiate() as CanvasLayer
	add_child(game_over_screen)
	game_over_screen.bind_level(self)
	game_over_screen.restart_requested.connect(_on_game_over_restart)


func _on_game_over_restart() -> void:
	# A troca remove este menu; executa fora do callback do botao.
	call_deferred("_restart_level")


func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(hud)
	hud.bind_level(self)


func _register_question_blocks() -> void:
	# Inclui as caixas convertidas de tiles e as instancias colocadas no editor.
	for block in get_tree().get_nodes_in_group("question_blocks"):
		if not is_ancestor_of(block):
			continue
		var ground := $Mundo/Ground as TileMapLayer
		var cell := ground.local_to_map(ground.to_local(block.global_position))
		if cell in cape_block_cells:
			block.activated.connect(mario.equip_cape)
		elif cell in growth_block_cells:
			block.activated.connect(mario.grow)
		total_boxes += 1
		if block.used:
			activated_boxes += 1
		block.activated.connect(_on_box_activated)


func _on_box_activated() -> void:
	activated_boxes += 1
	boxes_changed.emit(activated_boxes, total_boxes)


func _register_coins() -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		_watch_coin(coin)
	get_tree().node_added.connect(_watch_coin)


func _watch_coin(node: Node) -> void:
	if node.get_script() != COIN_SCRIPT or not is_ancestor_of(node):
		return
	if node.collected.is_connected(_on_coin_collected):
		return
	node.collected.connect(_on_coin_collected)
	total_coins += 1
	if node.is_collected:
		collected_coins += 1
	coins_changed.emit(collected_coins, total_coins)


func _on_coin_collected(player: CharacterBody2D) -> void:
	if player != mario:
		return
	collected_coins += 1
	coins_changed.emit(collected_coins, total_coins)


func has_completed_objectives() -> bool:
	return collected_coins >= total_coins and activated_boxes >= total_boxes


func _restart_level() -> void:
	if scene_file_path.is_empty():
		if is_instance_valid(game_over_screen):
			game_over_screen.queue_free()
		is_game_over = false
		process_mode = Node.PROCESS_MODE_INHERIT
		for platform in get_tree().get_nodes_in_group("falling_platforms"):
			if is_ancestor_of(platform):
				platform.reset_platform()
		mario._respawn()
		return
	var tree := get_tree()
	var was_current_scene := tree.current_scene == self
	var parent := get_parent()
	var index := get_index()
	var replacement := load(scene_file_path).instantiate() as Node2D
	replacement.intro_enabled = intro_enabled
	replacement.name = name
	replacement.transform = transform
	parent.remove_child(self)
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	if was_current_scene:
		tree.current_scene = replacement
	restarted.emit(replacement)
	queue_free()


func _setup_question_blocks() -> void:
	var ground := $Mundo/Ground as TileMapLayer
	if ground.tile_set == null:
		return
	for cell in ground.get_used_cells():
		var atlas_coords := ground.get_cell_atlas_coords(cell)
		if atlas_coords not in QUESTION_TILES:
			continue
		var source := ground.tile_set.get_source(ground.get_cell_source_id(cell)) as TileSetAtlasSource
		if source == null:
			continue
		var block := _create_question_block(ground, cell, source, atlas_coords)
		# Substitui apenas o tile de interrogaçao durante o jogo, sem redesenhar a fase.
		ground.erase_cell(cell)
		ground.add_child(block)


func _create_question_block(
	ground: TileMapLayer, cell: Vector2i, source: TileSetAtlasSource, atlas_coords: Vector2i
) -> StaticBody2D:
	var block := QUESTION_BLOCK_SCENE.instantiate() as StaticBody2D
	block.name = "QuestionBlock_%d_%d" % [cell.x, cell.y]
	block.position = ground.map_to_local(cell)
	var texture := AtlasTexture.new()
	texture.atlas = source.texture
	texture.region = source.get_tile_texture_region(atlas_coords)
	block.get_node("Sprite2D").texture = texture
	return block


func _setup_falling_platforms() -> void:
	for child in $Mundo.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for cell in layer.get_used_cells():
			if layer.get_cell_atlas_coords(cell) != PLATFORM_ATLAS_ORIGIN:
				continue
			var source_id := layer.get_cell_source_id(cell)
			var cells: Array[Vector2i] = []
			for row in PLATFORM_ATLAS_SIZE.y:
				for column in PLATFORM_ATLAS_SIZE.x:
					var offset := Vector2i(column, row)
					var neighbor := cell + offset
					if layer.get_cell_source_id(neighbor) == source_id and layer.get_cell_atlas_coords(neighbor) == PLATFORM_ATLAS_ORIGIN + offset:
						cells.append(neighbor)
			var platform := FALLING_PLATFORM_SCENE.instantiate() as StaticBody2D
			platform.name = "FallingPlatform_%d_%d" % [cell.x, cell.y]
			platform.configure_from_tiles(layer, cells)
			for platform_cell in cells:
				layer.erase_cell(platform_cell)
			layer.add_child(platform)


func _setup_enemy_supports() -> void:
	if not enemy_supports_enabled:
		return
	# Pilares e pontes decorativas precisam de apoio para os inimigos da fase 2.
	# A camada propria conserva as regras existentes de contato do Mario.
	for child in $Mundo.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null or layer.name not in [&"Ground", &"perigos"]:
			continue
		var supports := StaticBody2D.new()
		supports.name = "EnemySupports"
		supports.collision_layer = ENEMY_SUPPORT_LAYER
		supports.collision_mask = 0
		for cell in layer.get_used_cells():
			var atlas := layer.get_cell_atlas_coords(cell)
			var support_rect := Rect2()
			if atlas.x >= 3 and atlas.x <= 5 and atlas.y == 18:
				support_rect = Rect2(0, 16, 32, 16)
			elif atlas.x >= 3 and atlas.x <= 5 and atlas.y == 20:
				support_rect = Rect2(0, 0, 32, 32)
			elif layer.name == &"Ground" and atlas.y == 26 and atlas.x >= 9 and atlas.x <= 11:
				# A faixa horizontal visivel da ponte fica 22 pixels abaixo do tile.
				match atlas.x:
					9: support_rect = Rect2(14, 22, 18, 4)
					10: support_rect = Rect2(0, 22, 32, 4)
					11: support_rect = Rect2(0, 22, 20, 4)
			if not support_rect.has_area():
				continue
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = support_rect.size
			shape.shape = rectangle
			shape.one_way_collision = atlas.x >= 3 and atlas.x <= 5 and atlas.y == 18
			shape.one_way_collision_margin = 1.0
			shape.position = layer.map_to_local(cell) - Vector2(layer.tile_set.tile_size) * 0.5
			shape.position += support_rect.get_center()
			supports.add_child(shape)
		if supports.get_child_count() > 0:
			layer.add_child(supports)
		else:
			supports.free()


func get_map_bounds() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for child in $Mundo.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var used_cells := layer.get_used_rect()
		if not used_cells.has_area():
			continue
		var layer_bounds := _get_layer_bounds(layer, used_cells)
		bounds = bounds.merge(layer_bounds) if has_bounds else layer_bounds
		has_bounds = true
	return bounds


func _get_layer_bounds(layer: TileMapLayer, used_cells: Rect2i) -> Rect2:
	var tile_size := Vector2(layer.tile_set.tile_size)
	var local_bounds := Rect2(Vector2(used_cells.position) * tile_size, Vector2(used_cells.size) * tile_size)
	var bounds := Rect2(layer.to_global(local_bounds.position), Vector2.ZERO)
	# Usa os quatro cantos para incluir tambem camadas rotacionadas ou escaladas.
	bounds = bounds.expand(layer.to_global(local_bounds.end))
	bounds = bounds.expand(layer.to_global(Vector2(local_bounds.end.x, local_bounds.position.y)))
	bounds = bounds.expand(layer.to_global(Vector2(local_bounds.position.x, local_bounds.end.y)))
	return bounds

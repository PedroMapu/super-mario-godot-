extends Node2D

signal restarted(replacement: Node2D)
signal boxes_changed(activated: int, total: int)

const QUESTION_BLOCK_SCENE := preload("res://cenas/question_block.tscn")
const QUESTION_TILES := [Vector2i(27, 15), Vector2i(1, 30)]
const HUD_SCENE := preload("res://cenas/hud.tscn")
const FALL_DEATH_MARGIN := 64.0
const FALLING_PLATFORM_SCENE := preload("res://cenas/falling_platform.tscn")
const PLATFORM_ATLAS_ORIGIN := Vector2i(9, 21)
const PLATFORM_ATLAS_SIZE := Vector2i(3, 2)
const ENEMY_SUPPORT_LAYER := 512

@export var enemy_supports_enabled := false
@export var growth_block_cells: Array[Vector2i] = []

var total_boxes := 0
var activated_boxes := 0
var hud: CanvasLayer

@onready var mario: CharacterBody2D = $Mario
@onready var camera: Camera2D = $Mario/Camera2D


func _ready() -> void:
	mario.set_spawn_position($PlayerSpawn.global_position)
	var bounds := get_map_bounds()
	camera.set_map_bounds(bounds)
	mario.fall_death_y = bounds.end.y + FALL_DEATH_MARGIN
	mario.death_finished.connect(_restart_level)
	_setup_question_blocks()
	_setup_falling_platforms()
	_setup_enemy_supports()
	_register_question_blocks()
	_setup_hud()


func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate() as CanvasLayer
	add_child(hud)
	hud.bind_level(self)


func _register_question_blocks() -> void:
	# Inclui as caixas convertidas de tiles e as instancias colocadas no editor.
	for block in get_tree().get_nodes_in_group("question_blocks"):
		if not is_ancestor_of(block):
			continue
		total_boxes += 1
		if block.used:
			activated_boxes += 1
		block.activated.connect(_on_box_activated)


func _on_box_activated() -> void:
	activated_boxes += 1
	boxes_changed.emit(activated_boxes, total_boxes)


func _restart_level() -> void:
	if scene_file_path.is_empty():
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
	if cell in growth_block_cells:
		block.activated.connect(mario.grow)
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

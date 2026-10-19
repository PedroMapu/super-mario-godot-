extends RefCounted


static func complete(level: Node2D) -> void:
	var tree := level.get_tree()
	for coin in tree.get_nodes_in_group("coins"):
		if level.is_ancestor_of(coin):
			coin._on_body_entered(level.mario)
	await activate_boxes(level)


static func activate_boxes(level: Node2D) -> void:
	var tree := level.get_tree()
	for block in tree.get_nodes_in_group("question_blocks"):
		if level.is_ancestor_of(block):
			block.activate_from_below()
	# A caixa especial inicia uma transformacao real, inclusive nos testes
	# que deixam o jogador parado para isolar a camera e o HUD.
	var was_processing: bool = level.mario.is_physics_processing()
	if level.mario.is_growing:
		level.mario.set_physics_process(true)
		for index in 120:
			await tree.physics_frame
			await tree.process_frame
			if not level.mario.is_growing:
				break
	level.mario.set_physics_process(was_processing)

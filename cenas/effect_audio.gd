extends RefCounted

const DEFAULT_VOLUME_DB := -4.0


## O efeito acompanha o dono e e removido quando a reproducao termina.
static func play_at(owner: Node, stream: AudioStream, volume_db: float = DEFAULT_VOLUME_DB) -> void:
	var sound_player := AudioStreamPlayer2D.new()
	sound_player.stream = stream
	sound_player.volume_db = volume_db
	owner.add_child(sound_player)
	sound_player.finished.connect(sound_player.queue_free)
	sound_player.play()

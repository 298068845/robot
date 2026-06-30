extends SceneTree

func _initialize() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var root := scene.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	root.queue_free()
	quit(0)


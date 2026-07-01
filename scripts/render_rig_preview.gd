extends SceneTree

const Rig = preload("res://scripts/male_tinpet_cutout_rig.gd")

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(260, 640)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(viewport.size)
	viewport.add_child(bg)

	var rig := Rig.new()
	rig.position = Vector2(130, 500)
	viewport.add_child(rig)
	await process_frame
	await process_frame
	rig.play_action("walk")

	for i in range(10):
		rig.t = 1.2 * float(i) / 9.0
		rig._pose()
		await process_frame
		await process_frame
		var img := viewport.get_texture().get_image()
		if img != null:
			img.save_png("user://rig_preview_%02d.png" % [i + 1])
	print(ProjectSettings.globalize_path("user://"))
	quit(0)

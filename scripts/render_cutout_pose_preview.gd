extends SceneTree

const Rig = preload("res://scripts/male_tinpet_cutout_rig.gd")
const AutoComparePanel = preload("res://scripts/auto_compare_panel.gd")

func _initialize() -> void:
	var panel := AutoComparePanel.new()
	get_root().add_child(panel)
	await process_frame

	var stand := await _render_pose(panel, "stand", 0.0)
	var walk := await _render_pose(panel, "walk", 0.0)
	var stand_path := OS.get_user_data_dir().path_join("cutout_stand_preview.png")
	var walk_path := OS.get_user_data_dir().path_join("cutout_walk_preview_01.png")
	stand.save_png(stand_path)
	walk.save_png(walk_path)
	print(stand_path)
	print(walk_path)
	quit(0)

func _render_pose(panel: AutoComparePanel, action: String, time: float) -> Image:
	var rig := Rig.new()
	panel.viewport.add_child(rig)
	await process_frame
	rig.position = Vector2(130, 500)
	rig.play_action(action)
	rig.t = time
	rig._pose()
	var parts := rig.get_part_render_snapshot()
	var img: Image = panel._make_sprite_proxy_image(parts)
	rig.queue_free()
	return img

extends SceneTree

const AutoComparePanel = preload("res://scripts/auto_compare_panel.gd")

func _initialize() -> void:
	var panel := AutoComparePanel.new()
	get_root().add_child(panel)
	await process_frame
	await process_frame
	panel.ref_points = panel._load_ref_points()
	var ref_sheet := Image.new()
	if ref_sheet.load(panel.REF_SHEET_PATH) != OK:
		push_error("Could not load reference sheet.")
		quit(1)
		return
	var out_dir := OS.get_user_data_dir()
	for i in range(10):
		var ref_img := panel._crop_reference(ref_sheet, i)
		var render: Dictionary = await panel._render_rig_frame(i)
		var rig_img: Image = render["image"]
		var score: float = panel._compare_images(ref_img, rig_img, panel.ref_points[i], render["points"])
		var ref_mask := panel._foreground_mask(ref_img, false)
		var rig_mask := panel._foreground_mask(rig_img, false)
		panel._apply_focus_mask(ref_mask, ref_img.get_width(), ref_img.get_height(), panel._points_focus_rect(panel.ref_points[i], ref_img.get_size(), 42.0))
		panel._apply_focus_mask(rig_mask, rig_img.get_width(), rig_img.get_height(), panel._points_focus_rect(render["points"], rig_img.get_size(), 42.0))
		var ref_bbox := panel._mask_bbox(ref_mask, ref_img.get_width(), ref_img.get_height())
		var rig_bbox := panel._mask_bbox(rig_mask, rig_img.get_width(), rig_img.get_height())
		var ref_path := out_dir.path_join("visual_ref_%02d.png" % [i + 1])
		var rig_path := out_dir.path_join("visual_rig_%02d.png" % [i + 1])
		var ref_mask_path := out_dir.path_join("visual_ref_mask_%02d.png" % [i + 1])
		var rig_mask_path := out_dir.path_join("visual_rig_mask_%02d.png" % [i + 1])
		ref_img.save_png(ref_path)
		rig_img.save_png(rig_path)
		_save_mask(ref_mask, ref_img.get_width(), ref_img.get_height(), ref_mask_path)
		_save_mask(rig_mask, rig_img.get_width(), rig_img.get_height(), rig_mask_path)
		print("frame %02d visual=%.1f ref_bbox=%s rig_bbox=%s ref=%s rig=%s ref_mask=%s rig_mask=%s" % [i + 1, score, str(ref_bbox), str(rig_bbox), ref_path, rig_path, ref_mask_path, rig_mask_path])
	quit(0)

func _save_mask(mask: PackedByteArray, w: int, h: int, path: String) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for y in h:
		for x in w:
			if mask[y * w + x] == 1:
				img.set_pixel(x, y, Color.BLACK)
	img.save_png(path)

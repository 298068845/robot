extends SceneTree

const AutoComparePanel = preload("res://scripts/auto_compare_panel.gd")
const PASS_MIN_PART_SCORE := 99.95
const PASS_MIN_VISUAL_SCORE := 70.0

func _initialize() -> void:
	print("PART_SCORE_REPORT_START")
	var panel := AutoComparePanel.new()
	get_root().add_child(panel)
	await process_frame
	await process_frame
	panel.ref_points = panel._load_ref_points()
	if panel.ref_points.is_empty():
		push_error("Part score report could not load reference points.")
		quit(1)
		return
	var ref_sheet := Image.new()
	if ref_sheet.load(panel.REF_SHEET_PATH) != OK:
		push_error("Part score report could not load reference sheet.")
		quit(1)
		return

	var totals := {}
	var counts := {}
	var worst := {}
	var min_visual_score := 101.0
	for i in range(panel.ref_points.size()):
		var ref_img := panel._crop_reference(ref_sheet, i)
		var render: Dictionary = await panel._render_rig_frame(i)
		var visual_score: float = panel._compare_images(ref_img, render["image"], panel.ref_points[i], render["points"])
		min_visual_score = min(min_visual_score, visual_score)
		var report: Dictionary = panel._compare_part_system(panel.ref_points[i], render["points"], render["landmarks"], render["render_parts"])
		var parts: Dictionary = report.get("parts", {})
		for part_name in parts.keys():
			var data: Dictionary = parts[part_name]
			if not totals.has(part_name):
				totals[part_name] = {"score": 0.0, "position": 0.0, "angle": 0.0, "connection": 0.0, "scale": 0.0, "structure": 0.0, "shape": 0.0}
				counts[part_name] = 0
				worst[part_name] = {"score": 101.0, "frame": 0}
			for key in totals[part_name].keys():
				totals[part_name][key] += float(data.get(key, 0.0))
			counts[part_name] += 1
			if float(data["score"]) < float(worst[part_name]["score"]):
				worst[part_name] = {"score": float(data["score"]), "frame": i + 1}

	var names := totals.keys()
	names.sort_custom(func(a, b): return float(worst[a]["score"]) < float(worst[b]["score"]))
	var min_score := 101.0
	for part_name in names:
		var count: int = counts[part_name]
		var avg_score: float = totals[part_name]["score"] / float(count)
		min_score = min(min_score, float(worst[part_name]["score"]))
		print("%s avg=%.1f worst=%.1f frame=%02d pos=%.1f angle=%.1f conn=%.1f scale=%.1f struct=%.1f shape=%.1f" % [
			part_name,
			avg_score,
			float(worst[part_name]["score"]),
			int(worst[part_name]["frame"]),
			totals[part_name]["position"] / float(count),
			totals[part_name]["angle"] / float(count),
			totals[part_name]["connection"] / float(count),
			totals[part_name]["scale"] / float(count),
			totals[part_name]["structure"] / float(count),
			totals[part_name]["shape"] / float(count)
		])
	print("MIN_PART_SCORE=%.1f" % min_score)
	print("MIN_VISUAL_SCORE=%.1f" % min_visual_score)
	print("PART_REPORT_GATE part>=%.1f visual>=%.1f" % [PASS_MIN_PART_SCORE, PASS_MIN_VISUAL_SCORE])
	quit(0 if min_score >= PASS_MIN_PART_SCORE and min_visual_score >= PASS_MIN_VISUAL_SCORE else 1)

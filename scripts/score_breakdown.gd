extends SceneTree

const Rig = preload("res://scripts/male_tinpet_cutout_rig.gd")
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"

func _initialize() -> void:
	var frames := _load_ref_points()
	var rig := Rig.new()
	get_root().add_child(rig)
	await process_frame
	rig.play_action("walk")

	var sums := {}
	var worst := {}
	var counts := {}
	for i in range(frames.size()):
		rig.t = 1.2 * float(i) / float(max(1, frames.size() - 1))
		rig._pose()
		var ref_frame: Dictionary = frames[i]
		var rig_points := rig.get_compare_points()
		var ref_bbox := _reference_points_bbox(ref_frame, rig_points)
		var rig_bbox := _rig_points_bbox(ref_frame, rig_points)
		for key in ref_frame.keys():
			if not rig_points.has(key):
				continue
			var ref_p := Vector2(float(ref_frame[key][0]), float(ref_frame[key][1]))
			var rig_p: Vector2 = rig_points[key]
			var mapped := Vector2(
				ref_bbox.position.x + ((rig_p.x - rig_bbox.position.x) / max(1.0, rig_bbox.size.x)) * ref_bbox.size.x,
				ref_bbox.position.y + ((rig_p.y - rig_bbox.position.y) / max(1.0, rig_bbox.size.y)) * ref_bbox.size.y
			)
			var dist := ref_p.distance_to(mapped)
			sums[key] = float(sums.get(key, 0.0)) + dist
			counts[key] = int(counts.get(key, 0)) + 1
			if not worst.has(key) or dist > worst[key]["dist"]:
				worst[key] = {"dist": dist, "frame": i + 1}

	var names := sums.keys()
	names.sort_custom(func(a, b): return float(sums[b]) / float(counts[b]) < float(sums[a]) / float(counts[a]))
	for key in names:
		var avg := float(sums[key]) / float(counts[key])
		print("%s avg=%.2f worst=%.2f frame=%02d" % [key, avg, worst[key]["dist"], worst[key]["frame"]])
	quit(0)

func _load_ref_points() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REF_POINTS_PATH))
	if parsed is Dictionary and parsed.has("frames") and parsed["frames"] is Array:
		return parsed["frames"]
	return []

func _reference_points_bbox(ref_frame: Dictionary, rig_points: Dictionary) -> Rect2:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	var found := false
	for key in ref_frame.keys():
		if not rig_points.has(key):
			continue
		var p := Vector2(float(ref_frame[key][0]), float(ref_frame[key][1]))
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
		found = true
	if not found:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _rig_points_bbox(ref_frame: Dictionary, rig_points: Dictionary) -> Rect2:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	var found := false
	for key in ref_frame.keys():
		if not rig_points.has(key):
			continue
		var p: Vector2 = rig_points[key]
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
		found = true
	if not found:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

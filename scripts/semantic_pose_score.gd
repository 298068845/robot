extends SceneTree

const Rig = preload("res://scripts/male_tinpet_sprite_rig.gd")
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"

func _initialize() -> void:
	var frames := _load_ref_points()
	var rig := Rig.new()
	get_root().add_child(rig)
	await process_frame

	var errors := {}
	for i in range(frames.size()):
		rig.t = 1.2 * float(i) / float(max(1, frames.size() - 1))
		rig._pose()
		var ref_frame: Dictionary = frames[i]
		var rig_points := rig.get_compare_points()
		var landmarks := rig.get_part_landmark_positions()
		var ref_bbox := _reference_points_bbox(ref_frame, rig_points)
		var rig_bbox := _rig_points_bbox(ref_frame, rig_points)
		for part_name in landmarks.keys():
			var part: Dictionary = landmarks[part_name]
			for landmark_name in part.keys():
				var ref_key := _ref_key_for_landmark(String(part_name), String(landmark_name))
				if ref_key == "" or not ref_frame.has(ref_key):
					continue
				var ref_p := Vector2(float(ref_frame[ref_key][0]), float(ref_frame[ref_key][1]))
				var rig_p: Vector2 = part[landmark_name]
				var mapped := _map_point_to_reference(rig_p, ref_bbox, rig_bbox)
				var dist := ref_p.distance_to(mapped)
				var key := "%s.%s->%s" % [part_name, landmark_name, ref_key]
				if not errors.has(key):
					errors[key] = []
				errors[key].append(dist)

	var names := errors.keys()
	names.sort_custom(func(a, b): return _avg(errors[b]) < _avg(errors[a]))
	for key in names:
		var values: Array = errors[key]
		var worst := 0.0
		for value in values:
			worst = max(worst, float(value))
		print("%s avg=%.2f worst=%.2f" % [key, _avg(values), worst])
	quit(0)

func _ref_key_for_landmark(part_name: String, landmark_name: String) -> String:
	if part_name.begins_with("far_"):
		match landmark_name:
			"shoulder":
				return "far_shoulder"
			"elbow":
				return "far_elbow"
			"wrist":
				return "far_wrist"
			"hand":
				return "far_hand"
			"hip":
				return ""
	if part_name.begins_with("near_"):
		match landmark_name:
			"knee":
				return "near_knee"
			"ankle":
				return "near_ankle"
			"toe":
				return "near_toe"
	if part_name.begins_with("far_"):
		match landmark_name:
			"knee":
				return "far_knee"
			"ankle":
				return "far_ankle"
			"toe":
				return "far_toe"
	match landmark_name:
		"head":
			return "head"
		"neck":
			return "neck"
		"torso":
			return "torso"
		"shoulder":
			return "shoulder"
		"elbow":
			return "elbow"
		"wrist":
			return "wrist"
		"hand":
			return "hand"
		"hip":
			return "hip"
	return ""

func _avg(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(max(1, values.size()))

func _map_point_to_reference(rig_p: Vector2, ref_bbox: Rect2, rig_bbox: Rect2) -> Vector2:
	if ref_bbox.size.x <= 1 or rig_bbox.size.x <= 1:
		return Vector2.ZERO
	return Vector2(
		ref_bbox.position.x + ((rig_p.x - rig_bbox.position.x) / max(1.0, rig_bbox.size.x)) * ref_bbox.size.x,
		ref_bbox.position.y + ((rig_p.y - rig_bbox.position.y) / max(1.0, rig_bbox.size.y)) * ref_bbox.size.y
	)

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

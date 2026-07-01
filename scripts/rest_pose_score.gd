extends SceneTree

const Rig = preload("res://scripts/male_tinpet_cutout_rig.gd")
const BIND_POSE_PATH := "res://assets/parts/male_tinpet/bind_pose.json"

var render_image_cache: Dictionary = {}

func _initialize() -> void:
	var rig := Rig.new()
	get_root().add_child(rig)
	await process_frame
	rig.play_action("stand")
	rig._pose()

	var bind: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIND_POSE_PATH))
	if not (bind is Dictionary):
		push_error("bind_pose.json is invalid.")
		quit(1)
		return

	var points_score := _score_points(rig, bind)
	var hierarchy_score := _score_hierarchy(rig, bind)
	var part_score := _score_parts(rig, bind)
	var shape_score := _score_shapes(rig, bind)
	var score: float = min(points_score, hierarchy_score, part_score, shape_score)
	print("REST_POSE_SCORE=%.1f points=%.1f hierarchy=%.1f parts=%.1f shape=%.1f" % [score, points_score, hierarchy_score, part_score, shape_score])
	quit(0 if score >= 100.0 else 1)

func _score_points(rig: Node, bind: Dictionary) -> float:
	var bind_points: Dictionary = bind.get("points", {})
	var current: Dictionary = rig.get_bind_pose_points()
	for key in bind_points.keys():
		if not current.has(key):
			print("missing bind point: %s" % key)
			return 0.0
	return 100.0

func _score_hierarchy(rig: Node, bind: Dictionary) -> float:
	var expected: Dictionary = bind.get("hierarchy", {})
	var actual: Dictionary = rig.get_skeleton_hierarchy()
	for key in expected.keys():
		if not actual.has(key):
			print("missing hierarchy parent: %s" % key)
			return 0.0
		var expected_children: Array = expected[key]
		var actual_children: Array = actual[key]
		for child in expected_children:
			if not actual_children.has(child):
				print("missing hierarchy child: %s -> %s" % [key, child])
				return 0.0
	return 100.0

func _score_parts(rig: Node, bind: Dictionary) -> float:
	var expected: Dictionary = bind.get("parts", {})
	var render_parts: Array = rig.get_part_render_snapshot()
	var found := {}
	for part in render_parts:
		if part is Dictionary:
			found[String(part.get("name", ""))] = true
	for key in expected.keys():
		if not found.has(String(key)):
			print("missing part: %s" % key)
			return 0.0
	return 100.0

func _score_shapes(rig: Node, bind: Dictionary) -> float:
	var constraints: Dictionary = bind.get("shape_constraints", {})
	if constraints.is_empty():
		print("missing shape_constraints")
		return 0.0
	var points: Dictionary = rig.get_bind_pose_points()
	var render_parts: Array = rig.get_part_render_snapshot()
	var render_lookup := {}
	for part in render_parts:
		if part is Dictionary:
			render_lookup[String(part.get("name", ""))] = part
	var worst := 100.0
	for part_name in constraints.keys():
		if not render_lookup.has(String(part_name)):
			print("missing shape part: %s" % part_name)
			return 0.0
		var score := _score_single_shape(String(part_name), render_lookup[String(part_name)], constraints[part_name], points)
		worst = min(worst, score)
		print("REST_SHAPE %s %.1f" % [part_name, score])
	return worst

func _score_single_shape(part_name: String, render_part: Dictionary, constraint: Dictionary, points: Dictionary) -> float:
	var axis: Array = constraint.get("height_axis", [])
	if axis.size() < 2:
		return 100.0
	var from_key := String(axis[0])
	var to_key := String(axis[1])
	if not points.has(from_key) or not points.has(to_key):
		return 0.0
	var bbox := _render_part_oriented_bbox(render_part) if bool(constraint.get("oriented_shape", false)) else _render_part_bbox(render_part)
	if bbox.size.x <= 0.1 or bbox.size.y <= 0.1:
		return 0.0
	var axis_len: float = max(1.0, points[from_key].distance_to(points[to_key]))
	var width_ratio := bbox.size.x / axis_len
	var height_ratio := bbox.size.y / axis_len
	var area_ratio := bbox.size.x * bbox.size.y / (axis_len * axis_len)
	var tolerance := float(constraint.get("tolerance", 0.18))
	var width_score := _ratio_score(width_ratio, float(constraint.get("width_ratio", width_ratio)), tolerance)
	var height_score := _ratio_score(height_ratio, float(constraint.get("height_ratio", height_ratio)), tolerance)
	var area_score := _ratio_score(area_ratio, float(constraint.get("area_ratio", area_ratio)), tolerance * 1.6)
	if min(width_score, min(height_score, area_score)) < 99.95:
		print("%s shape ratios width=%.2f height=%.2f area=%.2f" % [part_name, width_ratio, height_ratio, area_ratio])
	return min(width_score, min(height_score, area_score))

func _render_part_bbox(render_part: Dictionary) -> Rect2:
	var src := _part_source_image(String(render_part.get("path", "")))
	if src == null:
		return Rect2()
	var source_box := _part_alpha_bbox(src)
	if source_box.size.x <= 0.0 or source_box.size.y <= 0.0:
		return Rect2()
	var source_size := Vector2(src.get_width(), src.get_height())
	var corners := [
		source_box.position,
		source_box.position + Vector2(source_box.size.x, 0.0),
		source_box.position + Vector2(0.0, source_box.size.y),
		source_box.position + source_box.size
	]
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for corner in corners:
		var p := _render_part_local_to_global(render_part, corner, source_size)
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _render_part_oriented_bbox(render_part: Dictionary) -> Rect2:
	var src := _part_source_image(String(render_part.get("path", "")))
	if src == null:
		return Rect2()
	var source_box := _part_alpha_bbox(src)
	if source_box.size.x <= 0.0 or source_box.size.y <= 0.0:
		return Rect2()
	var scale_value: Vector2 = render_part.get("scale", Vector2.ONE)
	return Rect2(Vector2.ZERO, Vector2(source_box.size.x * abs(scale_value.x), source_box.size.y * abs(scale_value.y)))

func _render_part_local_to_global(render_part: Dictionary, local_point: Vector2, source_size: Vector2) -> Vector2:
	var position: Vector2 = render_part.get("position", Vector2.ZERO)
	var rotation := float(render_part.get("rotation", 0.0))
	var scale_value: Vector2 = render_part.get("scale", Vector2.ONE)
	var flip_h := bool(render_part.get("flip_h", false))
	var local := local_point
	if flip_h:
		local.x = source_size.x - local.x
	local = Vector2(local.x * scale_value.x, local.y * scale_value.y)
	return position + local.rotated(rotation)

func _part_alpha_bbox(src: Image) -> Rect2:
	var min_x := src.get_width()
	var min_y := src.get_height()
	var max_x := 0
	var max_y := 0
	var found := false
	for y in src.get_height():
		for x in src.get_width():
			if src.get_pixel(x, y).a < 0.18:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
			found = true
	if not found:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))

func _part_source_image(path: String) -> Image:
	if path == "":
		return null
	if render_image_cache.has(path):
		return render_image_cache[path]
	var img := Image.new()
	if img.load(path) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	render_image_cache[path] = img
	return img

func _ratio_score(actual: float, expected: float, tolerance: float) -> float:
	if expected <= 0.001:
		return 100.0
	var error: float = abs(log(max(0.001, actual / expected)))
	return _tolerance_score(error, log(1.0 + tolerance), log(1.0 + tolerance * 3.0))

func _tolerance_score(error: float, free_error: float, fail_error: float) -> float:
	if error <= free_error:
		return 100.0
	if fail_error <= free_error:
		return 0.0
	return clamp(1.0 - (error - free_error) / (fail_error - free_error), 0.0, 1.0) * 100.0

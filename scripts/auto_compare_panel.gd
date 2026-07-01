extends PanelContainer

const Rig = preload("res://scripts/male_tinpet_cutout_rig.gd")
const REF_SHEET_PATH := "res://assets/animation/male_tinpet_walk_10f_v1.png"
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"
const ASSET_PART_POSES_PATH := "res://assets/animation/walk_ref_part_poses.json"
const USER_PART_POSES_PATH := "user://walk_ref_part_poses.json"
const BIND_POSE_PATH := "res://assets/parts/male_tinpet/bind_pose.json"
const PASS_AVG_SCORE := 85.0
const PASS_WORST_FRAME_SCORE := 75.0
const PASS_MIN_VISUAL_SCORE := 70.0
const PASS_MIN_JOINT_SCORE := 95.0
const PASS_MIN_STRUCTURE_SCORE := 85.0

var result_label: Label
var run_button: Button
var viewport: SubViewport
var debug_rect: TextureRect
var ref_points: Array = []
var part_pose_frames: Array = []
var render_image_cache: Dictionary = {}
var shape_constraints: Dictionary = {}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 150)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	run_button = Button.new()
	run_button.text = "自动对比"
	run_button.custom_minimum_size = Vector2(120, 34)
	run_button.pressed.connect(_run_compare)
	root.add_child(run_button)

	result_label = Label.new()
	result_label.text = "逐帧对比当前 rig 和走路 10 帧参考图。黄点是参考骨骼点，青点是当前 rig，红线是关节点误差。"
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(280, 92)
	root.add_child(result_label)

	debug_rect = TextureRect.new()
	debug_rect.custom_minimum_size = Vector2(280, 120)
	debug_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	debug_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(debug_rect)

	viewport = SubViewport.new()
	viewport.size = Vector2i(260, 640)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

func _run_compare() -> void:
	run_button.disabled = true
	result_label.text = "正在自动对比..."
	await get_tree().process_frame

	var ref_sheet := Image.new()
	var err := ref_sheet.load(REF_SHEET_PATH)
	if err != OK:
		result_label.text = "参考图加载失败。"
		run_button.disabled = false
		return
	ref_points = _load_ref_points()
	if ref_points.size() != 10:
		result_label.text = "参考骨骼点加载失败。"
		run_button.disabled = false
		return
	part_pose_frames = _load_part_pose_frames()

	var scores: Array[float] = []
	var lines: Array[String] = []
	var worst_index := 0
	var worst_score := 999.0
	var min_visual_score := 101.0
	var min_joint_score := 101.0
	var min_structure_score := 101.0
	var worst_debug: Image
	var has_part_scores := false
	var has_semantic_scores := false
	for i in 10:
		var ref_img := _crop_reference(ref_sheet, i)
		var render: Dictionary = await _render_rig_frame(i)
		var rig_img: Image = render["image"]
		var rig_points: Dictionary = render["points"]
		var rig_part_poses: Dictionary = render["part_poses"]
		var rig_landmarks: Dictionary = render["landmarks"]
		var render_parts: Array = render["render_parts"]
		var silhouette_score := _compare_images(ref_img, rig_img, ref_points[i], rig_points)
		var joint_score := _compare_points(ref_points[i], rig_points, ref_img, rig_img)
		var part_score := _compare_part_poses(i, ref_points[i], rig_points, rig_part_poses)
		var semantic_score := _compare_semantic_landmarks(ref_points[i], rig_points, rig_landmarks)
		var part_system := _compare_part_system(ref_points[i], rig_points, rig_landmarks, render_parts)
		var part_system_score := float(part_system.get("score", semantic_score))
		var structure_score := -1.0
		if part_score >= 0.0:
			has_part_scores = true
			structure_score = min(part_score, part_system_score if part_system_score >= 0.0 else part_score)
		elif semantic_score >= 0.0:
			has_semantic_scores = true
			structure_score = part_system_score
		else:
			structure_score = joint_score
		var score: float = min(silhouette_score, joint_score, structure_score)
		min_visual_score = min(min_visual_score, silhouette_score)
		min_joint_score = min(min_joint_score, joint_score)
		min_structure_score = min(min_structure_score, structure_score)
		lines.append("%02d: %.1f  visual%.1f structure%.1f skeleton%.1f worst_part=%s %.1f" % [
			i + 1,
			score,
			silhouette_score,
			structure_score,
			joint_score,
			String(part_system.get("worst_part", "")),
			float(part_system.get("worst_score", 0.0))
		])
		scores.append(score)
		if score < worst_score:
			worst_score = score
			worst_index = i
			worst_debug = _make_debug_image(ref_img, rig_img, ref_points[i], rig_points)

	var total := 0.0
	for score in scores:
		total += score
	var avg := total / float(scores.size())
	var passed := avg >= PASS_AVG_SCORE \
		and worst_score >= PASS_WORST_FRAME_SCORE \
		and min_visual_score >= PASS_MIN_VISUAL_SCORE \
		and min_joint_score >= PASS_MIN_JOINT_SCORE \
		and min_structure_score >= PASS_MIN_STRUCTURE_SCORE
	var verdict := "通过" if passed else "失败"
	var source_note := "manual-part" if has_part_scores else ("semantic-part" if has_semantic_scores else "skeleton-only")
	var note := "strict gates: avg>=%.1f worst>=%.1f visual>=%.1f skeleton>=%.1f structure>=%.1f source=%s min_visual=%.1f min_skeleton=%.1f min_structure=%.1f" % [
		PASS_AVG_SCORE,
		PASS_WORST_FRAME_SCORE,
		PASS_MIN_VISUAL_SCORE,
		PASS_MIN_JOINT_SCORE,
		PASS_MIN_STRUCTURE_SCORE,
		source_note,
		min_visual_score,
		min_joint_score,
		min_structure_score
	]
	result_label.text = "%s  average %.1f  worst_frame %02d worst %.1f\n%s\n%s" % [verdict, avg, worst_index + 1, worst_score, note, "  ".join(lines)]
	if worst_debug != null:
		debug_rect.texture = ImageTexture.create_from_image(worst_debug)
	run_button.disabled = false

func _load_ref_points() -> Array:
	var text := FileAccess.get_file_as_string(REF_POINTS_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("frames") and parsed["frames"] is Array:
		return parsed["frames"]
	return []

func _load_part_pose_frames() -> Array:
	var path := USER_PART_POSES_PATH
	if not FileAccess.file_exists(path):
		path = ASSET_PART_POSES_PATH
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.has("frames") and parsed["frames"] is Array:
		return parsed["frames"]
	return []

func _crop_reference(sheet: Image, frame_index: int) -> Image:
	var cell_w := sheet.get_width() / 10
	var rect := Rect2i(frame_index * cell_w, 0, cell_w, sheet.get_height())
	var img := sheet.get_region(rect)
	img.convert(Image.FORMAT_RGBA8)
	return img

func _render_rig_frame(frame_index: int) -> Dictionary:
	for child in viewport.get_children():
		child.queue_free()
	await get_tree().process_frame

	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(viewport.size)
	viewport.add_child(bg)

	var rig := Rig.new()
	rig.position = Vector2(130, 500)
	viewport.add_child(rig)
	await get_tree().process_frame
	rig.play_action("walk")
	rig.t = 1.2 * float(frame_index) / 9.0
	rig._pose()
	var points := rig.get_compare_points()
	var part_poses := rig.get_part_pose_snapshot()
	var landmarks := rig.get_part_landmark_positions()
	var render_parts := rig.get_part_render_snapshot()

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image
	if DisplayServer.get_name() == "headless":
		img = _make_sprite_proxy_image(render_parts)
	else:
		img = viewport.get_texture().get_image()
	if img == null:
		img = _make_sprite_proxy_image(render_parts)
	else:
		img.convert(Image.FORMAT_RGBA8)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return {"image": img, "points": points, "part_poses": part_poses, "landmarks": landmarks, "render_parts": render_parts}

func _make_sprite_proxy_image(parts: Array) -> Image:
	var img := Image.create(viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for part in parts:
		if not (part is Dictionary):
			continue
		_draw_part_on_image(img, part)
	return img

func _draw_part_on_image(dst: Image, part: Dictionary) -> void:
	var src := _part_source_image(String(part.get("path", "")))
	if src == null:
		return
	var position: Vector2 = part.get("position", Vector2.ZERO)
	var rotation: float = float(part.get("rotation", 0.0))
	var scale_value: Vector2 = part.get("scale", Vector2.ONE)
	var alpha_scale: float = float(part.get("alpha", 1.0))
	var flip_h := bool(part.get("flip_h", false))
	if abs(scale_value.x) <= 0.001 or abs(scale_value.y) <= 0.001 or alpha_scale <= 0.01:
		return
	var cos_r := cos(rotation)
	var sin_r := sin(rotation)
	var width := src.get_width()
	var height := src.get_height()
	for sy in height:
		for sx in width:
			var sample_x := width - 1 - sx if flip_h else sx
			var color := src.get_pixel(sample_x, sy)
			var alpha := color.a * alpha_scale
			if alpha < 0.18:
				continue
			var local := Vector2(float(sx) * scale_value.x, float(sy) * scale_value.y)
			var dx := int(round(position.x + local.x * cos_r - local.y * sin_r))
			var dy := int(round(position.y + local.x * sin_r + local.y * cos_r))
			if dx >= 0 and dy >= 0 and dx < dst.get_width() and dy < dst.get_height():
				dst.set_pixel(dx, dy, Color.BLACK)

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

func _compare_points(ref_frame: Dictionary, rig_points: Dictionary, ref_img: Image, rig_img: Image) -> float:
	var ref_bbox := _reference_points_bbox(ref_frame, rig_points)
	var rig_bbox := _rig_points_bbox(ref_frame, rig_points)
	if ref_bbox.size.x <= 1 or rig_bbox.size.x <= 1:
		return 0.0
	var total := 0.0
	var count := 0
	for key in ref_frame.keys():
		if not rig_points.has(key):
			continue
		var ref_p := Vector2(float(ref_frame[key][0]), float(ref_frame[key][1]))
		var rig_p: Vector2 = rig_points[key]
		var normalized_rig := Vector2(
			ref_bbox.position.x + ((rig_p.x - rig_bbox.position.x) / max(1.0, rig_bbox.size.x)) * ref_bbox.size.x,
			ref_bbox.position.y + ((rig_p.y - rig_bbox.position.y) / max(1.0, rig_bbox.size.y)) * ref_bbox.size.y
		)
		var dist := ref_p.distance_to(normalized_rig)
		total += clamp(1.0 - dist / 90.0, 0.0, 1.0)
		count += 1
	if count == 0:
		return 0.0
	return total / float(count) * 100.0

func _make_debug_image(ref_img: Image, rig_img: Image, ref_frame: Dictionary, rig_points: Dictionary) -> Image:
	var out := Image.create(ref_img.get_width(), ref_img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	out.blit_rect(ref_img, Rect2i(Vector2i.ZERO, ref_img.get_size()), Vector2i.ZERO)
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
		_draw_line_on_image(out, ref_p, mapped, Color.RED)
		_draw_dot_on_image(out, ref_p, Color.YELLOW)
		_draw_dot_on_image(out, mapped, Color.CYAN)
	return out

func _compare_part_poses(frame_index: int, ref_frame: Dictionary, rig_points: Dictionary, rig_part_poses: Dictionary) -> float:
	if frame_index < 0 or frame_index >= part_pose_frames.size():
		return -1.0
	var frame = part_pose_frames[frame_index]
	if not (frame is Dictionary) or not frame.has("parts") or not (frame["parts"] is Dictionary):
		return -1.0
	var target_parts: Dictionary = frame["parts"]
	if target_parts.is_empty():
		return -1.0

	var ref_bbox := _reference_points_bbox(ref_frame, rig_points)
	var rig_bbox := _rig_points_bbox(ref_frame, rig_points)
	if ref_bbox.size.x <= 1 or rig_bbox.size.x <= 1:
		return 0.0

	var total := 0.0
	var count := 0
	for part_name in target_parts.keys():
		if not rig_part_poses.has(part_name):
			continue
		var target: Variant = target_parts[part_name]
		var current: Variant = rig_part_poses[part_name]
		if not (target is Dictionary) or not (current is Dictionary):
			continue
		var target_pos: Vector2 = _array_to_vec2(target.get("position", [0.0, 0.0]))
		var current_pos: Vector2 = current["position"]
		var mapped_pos := Vector2(
			ref_bbox.position.x + ((current_pos.x - rig_bbox.position.x) / max(1.0, rig_bbox.size.x)) * ref_bbox.size.x,
			ref_bbox.position.y + ((current_pos.y - rig_bbox.position.y) / max(1.0, rig_bbox.size.y)) * ref_bbox.size.y
		)

		var pos_score: float = clamp(1.0 - target_pos.distance_to(mapped_pos) / 50.0, 0.0, 1.0)
		var rot_error: float = abs(_angle_delta_degrees(float(current["rotation"]), float(target.get("rotation", 0.0))))
		var rot_score: float = clamp(1.0 - rot_error / 55.0, 0.0, 1.0)
		var target_scale: float = _array_to_vec2(target.get("scale", [1.0, 1.0])).length() * 0.5
		var current_scale: Vector2 = current["scale"]
		var scale_value := current_scale.length() * 0.5
		var scale_ratio: float = scale_value / max(0.001, target_scale)
		var scale_score: float = clamp(1.0 - abs(log(max(0.001, scale_ratio))) / 0.9, 0.0, 1.0)
		total += pos_score * 0.55 + rot_score * 0.35 + scale_score * 0.10
		count += 1
	if count == 0:
		return -1.0
	return total / float(count) * 100.0

func _compare_semantic_landmarks(ref_frame: Dictionary, rig_points: Dictionary, rig_landmarks: Dictionary) -> float:
	if rig_landmarks.is_empty():
		return -1.0
	var ref_bbox := _reference_points_bbox(ref_frame, rig_points)
	var rig_bbox := _rig_points_bbox(ref_frame, rig_points)
	if ref_bbox.size.x <= 1 or rig_bbox.size.x <= 1:
		return 0.0
	var total := 0.0
	var count := 0
	for part_name in rig_landmarks.keys():
		var part: Dictionary = rig_landmarks[part_name]
		for landmark_name in part.keys():
			var ref_key := _ref_key_for_landmark(String(part_name), String(landmark_name))
			if ref_key == "" or not ref_frame.has(ref_key):
				continue
			var ref_p := Vector2(float(ref_frame[ref_key][0]), float(ref_frame[ref_key][1]))
			var rig_p: Vector2 = part[landmark_name]
			var mapped := Vector2(
				ref_bbox.position.x + ((rig_p.x - rig_bbox.position.x) / max(1.0, rig_bbox.size.x)) * ref_bbox.size.x,
				ref_bbox.position.y + ((rig_p.y - rig_bbox.position.y) / max(1.0, rig_bbox.size.y)) * ref_bbox.size.y
			)
			var dist := ref_p.distance_to(mapped)
			total += clamp(1.0 - dist / 45.0, 0.0, 1.0)
			count += 1
	if count == 0:
		return -1.0
	return total / float(count) * 100.0

func _compare_part_system(ref_frame: Dictionary, rig_points: Dictionary, rig_landmarks: Dictionary, render_parts: Array = []) -> Dictionary:
	if rig_landmarks.is_empty():
		return {"score": -1.0, "worst_part": "", "worst_score": 0.0, "parts": {}}
	_load_shape_constraints()
	var ref_bbox := _reference_points_bbox(ref_frame, rig_points)
	var rig_bbox := _rig_points_bbox(ref_frame, rig_points)
	if ref_bbox.size.x <= 1 or rig_bbox.size.x <= 1:
		return {"score": 0.0, "worst_part": "", "worst_score": 0.0, "parts": {}}

	var part_scores := {}
	var total := 0.0
	var count := 0
	var worst_part := ""
	var worst_score := 101.0
	var render_lookup := _render_part_lookup(render_parts)
	for part_name in rig_landmarks.keys():
		var score_data := _score_single_part(String(part_name), rig_landmarks[part_name], ref_frame, ref_bbox, rig_bbox, render_lookup.get(String(part_name), {}))
		var score := float(score_data.get("score", -1.0))
		if score < 0.0:
			continue
		part_scores[String(part_name)] = score_data
		total += score
		count += 1
		if score < worst_score:
			worst_score = score
			worst_part = String(part_name)
	if count == 0:
		return {"score": -1.0, "worst_part": "", "worst_score": 0.0, "parts": {}}
	return {"score": total / float(count), "worst_part": worst_part, "worst_score": worst_score, "parts": part_scores}

func _score_single_part(part_name: String, landmarks: Dictionary, ref_frame: Dictionary, ref_bbox: Rect2, rig_bbox: Rect2, render_part: Dictionary = {}) -> Dictionary:
	var mapped := {}
	var refs := {}
	for landmark_name in landmarks.keys():
		var ref_key := _ref_key_for_landmark(part_name, String(landmark_name))
		if ref_key == "" or not ref_frame.has(ref_key):
			continue
		refs[String(landmark_name)] = Vector2(float(ref_frame[ref_key][0]), float(ref_frame[ref_key][1]))
		mapped[String(landmark_name)] = _map_rig_point_to_reference(landmarks[landmark_name], ref_bbox, rig_bbox)
	if mapped.is_empty():
		return {"score": -1.0}

	var position_score := _part_position_score(mapped, refs)
	var angle_score := _part_angle_score(part_name, mapped, refs)
	var scale_score := _part_scale_score(part_name, mapped, refs)
	var connection_score := _part_connection_score(mapped, refs)
	var structure_score := _part_structure_score(part_name, mapped, refs, render_part, ref_bbox, rig_bbox)
	var shape_score := _part_shape_score(part_name, render_part, ref_frame, ref_bbox, rig_bbox)
	var score := position_score * 0.22 + angle_score * 0.18 + connection_score * 0.18 + scale_score * 0.10 + structure_score * 0.14 + shape_score * 0.18
	return {"score": score, "position": position_score, "angle": angle_score, "connection": connection_score, "scale": scale_score, "structure": structure_score, "shape": shape_score}

func _part_position_score(mapped: Dictionary, refs: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for key in mapped.keys():
		total += _tolerance_score(mapped[key].distance_to(refs[key]), 12.0, 90.0)
		count += 1
	return total / float(max(1, count))

func _part_angle_score(part_name: String, mapped: Dictionary, refs: Dictionary) -> float:
	var axis := _part_axis_for_score(part_name, mapped)
	if axis.is_empty():
		return 100.0
	var from_key: String = axis[0]
	var to_key: String = axis[1]
	if not mapped.has(from_key) or not mapped.has(to_key) or not refs.has(from_key) or not refs.has(to_key):
		return 100.0
	var current_vec: Vector2 = mapped[to_key] - mapped[from_key]
	var target_vec: Vector2 = refs[to_key] - refs[from_key]
	if current_vec.length() <= 0.01 or target_vec.length() <= 0.01:
		return 100.0
	var err: float = abs(rad_to_deg(_angle_delta(current_vec.angle(), target_vec.angle())))
	return _tolerance_score(err, 6.0, 35.0)

func _part_scale_score(part_name: String, mapped: Dictionary, refs: Dictionary) -> float:
	if part_name == "neck_mesh" or part_name.begins_with("far_"):
		return 100.0
	var axis := _part_axis_for_score(part_name, mapped)
	if axis.is_empty():
		return 100.0
	var from_key: String = axis[0]
	var to_key: String = axis[1]
	if not mapped.has(from_key) or not mapped.has(to_key) or not refs.has(from_key) or not refs.has(to_key):
		return 100.0
	var current_len: float = mapped[from_key].distance_to(mapped[to_key])
	var target_len: float = refs[from_key].distance_to(refs[to_key])
	if current_len <= 0.01 or target_len <= 0.01:
		return 100.0
	return _tolerance_score(abs(log(max(0.001, current_len / target_len))), log(1.18), 0.55)

func _part_connection_score(mapped: Dictionary, refs: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for key in mapped.keys():
		if not _is_connection_landmark(String(key)):
			continue
		total += _tolerance_score(mapped[key].distance_to(refs[key]), 12.0, 65.0)
		count += 1
	if count == 0:
		return 100.0
	return total / float(count)

func _part_structure_score(part_name: String, mapped: Dictionary, refs: Dictionary, render_part: Dictionary, ref_bbox: Rect2, rig_bbox: Rect2) -> float:
	var scores: Array[float] = []
	var corridor := _part_corridor_score(part_name, mapped, refs, render_part, ref_bbox, rig_bbox)
	if corridor >= 0.0:
		scores.append(corridor)
	var foot_anchor := _foot_anchor_score(part_name, mapped, refs)
	if foot_anchor >= 0.0:
		scores.append(foot_anchor)
	var far_arm_region := _far_arm_region_score(part_name, mapped, refs)
	if far_arm_region >= 0.0:
		scores.append(far_arm_region)
	if scores.is_empty():
		return 100.0
	var total := 0.0
	for value in scores:
		total += value
	return total / float(scores.size())

func _part_shape_score(part_name: String, render_part: Dictionary, ref_frame: Dictionary, ref_bbox: Rect2, rig_bbox: Rect2) -> float:
	if not shape_constraints.has(part_name):
		return 100.0
	if render_part.is_empty():
		return 0.0
	var constraint: Dictionary = shape_constraints[part_name]
	var axis: Array = constraint.get("height_axis", [])
	if axis.size() < 2:
		return 100.0
	var from_key := String(axis[0])
	var to_key := String(axis[1])
	if not ref_frame.has(from_key) or not ref_frame.has(to_key):
		return 100.0
	var bbox := _render_part_oriented_bbox_to_reference(render_part, ref_bbox, rig_bbox) if bool(constraint.get("oriented_shape", false)) else _render_part_bbox_to_reference(render_part, ref_bbox, rig_bbox)
	if bbox.size.x <= 0.1 or bbox.size.y <= 0.1:
		return 0.0
	var a := Vector2(float(ref_frame[from_key][0]), float(ref_frame[from_key][1]))
	var b := Vector2(float(ref_frame[to_key][0]), float(ref_frame[to_key][1]))
	var axis_len: float = max(1.0, a.distance_to(b))
	var width_ratio: float = bbox.size.x / axis_len
	var height_ratio: float = bbox.size.y / axis_len
	var area_ratio: float = bbox.size.x * bbox.size.y / (axis_len * axis_len)
	var tolerance: float = float(constraint.get("tolerance", 0.18))
	var width_score: float = _ratio_score(width_ratio, float(constraint.get("width_ratio", width_ratio)), tolerance)
	var height_score: float = _ratio_score(height_ratio, float(constraint.get("height_ratio", height_ratio)), tolerance)
	var area_score: float = _ratio_score(area_ratio, float(constraint.get("area_ratio", area_ratio)), tolerance * 1.6)
	return min(width_score, min(height_score, area_score))

func _part_corridor_score(part_name: String, mapped: Dictionary, refs: Dictionary, render_part: Dictionary, ref_bbox: Rect2, rig_bbox: Rect2) -> float:
	if part_name.ends_with("_foot_mesh"):
		return -1.0
	if render_part.is_empty():
		return -1.0
	var axis := _part_axis_for_score(part_name, mapped)
	if axis.is_empty():
		return -1.0
	var from_key: String = axis[0]
	var to_key: String = axis[1]
	if not refs.has(from_key) or not refs.has(to_key):
		return -1.0
	var center: Vector2 = _render_part_center_to_reference(render_part, ref_bbox, rig_bbox)
	var a: Vector2 = refs[from_key]
	var b: Vector2 = refs[to_key]
	var dist: float = _distance_to_segment(center, a, b)
	var allowed: float = max(24.0, a.distance_to(b) * 0.34)
	if part_name.ends_with("_hand_mesh") or part_name.ends_with("_foot_mesh"):
		allowed = max(34.0, a.distance_to(b) * 0.70)
	if part_name == "torso_mesh":
		allowed = 55.0
	return _tolerance_score(dist, allowed * 0.25, allowed)

func _foot_anchor_score(part_name: String, mapped: Dictionary, refs: Dictionary) -> float:
	if not part_name.ends_with("_foot_mesh") or not mapped.has("ankle") or not mapped.has("toe"):
		return -1.0
	var current_vec: Vector2 = mapped["toe"] - mapped["ankle"]
	var target_vec: Vector2 = refs["toe"] - refs["ankle"]
	if current_vec.length() <= 0.01 or target_vec.length() <= 0.01:
		return 0.0
	var angle_err: float = abs(rad_to_deg(_angle_delta(current_vec.angle(), target_vec.angle())))
	var vertical_ok: float = 100.0 if mapped["ankle"].y < mapped["toe"].y else 25.0
	var angle_score: float = _tolerance_score(angle_err, 8.0, 28.0)
	return min(vertical_ok, angle_score)

func _far_arm_region_score(part_name: String, mapped: Dictionary, refs: Dictionary) -> float:
	if not part_name.begins_with("far_") or not (part_name.ends_with("_hand_mesh") or part_name.ends_with("_forearm_mesh") or part_name.ends_with("_upper_arm_mesh")):
		return -1.0
	if refs.has("wrist") and refs.has("hand") and mapped.has("wrist") and mapped.has("hand"):
		var hand_mid: Vector2 = (mapped["wrist"] + mapped["hand"]) * 0.5
		var ref_mid: Vector2 = (refs["wrist"] + refs["hand"]) * 0.5
		return _tolerance_score(hand_mid.distance_to(ref_mid), 12.0, 60.0)
	if refs.has("elbow") and refs.has("wrist") and mapped.has("elbow") and mapped.has("wrist"):
		var forearm_mid: Vector2 = (mapped["elbow"] + mapped["wrist"]) * 0.5
		var ref_forearm_mid: Vector2 = (refs["elbow"] + refs["wrist"]) * 0.5
		return _tolerance_score(forearm_mid.distance_to(ref_forearm_mid), 12.0, 70.0)
	return -1.0

func _tolerance_score(error: float, free_error: float, fail_error: float) -> float:
	if error <= free_error:
		return 100.0
	if fail_error <= free_error:
		return 0.0
	return clamp(1.0 - (error - free_error) / (fail_error - free_error), 0.0, 1.0) * 100.0

func _render_part_lookup(render_parts: Array) -> Dictionary:
	var lookup := {}
	for part in render_parts:
		if part is Dictionary and part.has("name"):
			lookup[String(part["name"])] = part
	return lookup

func _render_part_center_to_reference(render_part: Dictionary, ref_bbox: Rect2, rig_bbox: Rect2) -> Vector2:
	var path := String(render_part.get("path", ""))
	var src := _part_source_image(path)
	var size := Vector2.ZERO
	if src != null:
		size = Vector2(src.get_width(), src.get_height())
	var scale_value: Vector2 = render_part.get("scale", Vector2.ONE)
	var rotation := float(render_part.get("rotation", 0.0))
	var position: Vector2 = render_part.get("position", Vector2.ZERO)
	var local_center := Vector2(size.x * scale_value.x * 0.5, size.y * scale_value.y * 0.5)
	var center := position + local_center.rotated(rotation)
	return _map_rig_point_to_reference(center, ref_bbox, rig_bbox)

func _render_part_bbox_to_reference(render_part: Dictionary, ref_bbox: Rect2, rig_bbox: Rect2) -> Rect2:
	var src := _part_source_image(String(render_part.get("path", "")))
	if src == null:
		return Rect2()
	var source_box := _part_alpha_bbox(src)
	if source_box.size.x <= 0.0 or source_box.size.y <= 0.0:
		return Rect2()
	var points := [
		source_box.position,
		source_box.position + Vector2(source_box.size.x, 0.0),
		source_box.position + Vector2(0.0, source_box.size.y),
		source_box.position + source_box.size
	]
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in points:
		var mapped := _map_rig_point_to_reference(_render_part_local_to_global(render_part, point, Vector2(src.get_width(), src.get_height())), ref_bbox, rig_bbox)
		min_x = min(min_x, mapped.x)
		min_y = min(min_y, mapped.y)
		max_x = max(max_x, mapped.x)
		max_y = max(max_y, mapped.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _render_part_oriented_bbox_to_reference(render_part: Dictionary, ref_bbox: Rect2, rig_bbox: Rect2) -> Rect2:
	var src := _part_source_image(String(render_part.get("path", "")))
	if src == null:
		return Rect2()
	var source_box := _part_alpha_bbox(src)
	if source_box.size.x <= 0.0 or source_box.size.y <= 0.0:
		return Rect2()
	var scale_value: Vector2 = render_part.get("scale", Vector2.ONE)
	var ref_scale: float = (ref_bbox.size.x / max(1.0, rig_bbox.size.x) + ref_bbox.size.y / max(1.0, rig_bbox.size.y)) * 0.5
	return Rect2(Vector2.ZERO, Vector2(source_box.size.x * abs(scale_value.x) * ref_scale, source_box.size.y * abs(scale_value.y) * ref_scale))

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

func _ratio_score(actual: float, expected: float, tolerance: float) -> float:
	if expected <= 0.001:
		return 100.0
	var error: float = abs(log(max(0.001, actual / expected)))
	return _tolerance_score(error, log(1.0 + tolerance), log(1.0 + tolerance * 3.0))

func _load_shape_constraints() -> void:
	if not shape_constraints.is_empty():
		return
	if not FileAccess.file_exists(BIND_POSE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIND_POSE_PATH))
	if parsed is Dictionary:
		shape_constraints = parsed.get("shape_constraints", {})

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _part_axis_for_score(part_name: String, landmarks: Dictionary) -> Array[String]:
	if part_name == "torso_mesh" and landmarks.has("neck") and landmarks.has("hip"):
		return ["neck", "hip"]
	if landmarks.has("shoulder") and landmarks.has("elbow"):
		return ["shoulder", "elbow"]
	if landmarks.has("elbow") and landmarks.has("wrist"):
		return ["elbow", "wrist"]
	if landmarks.has("wrist") and landmarks.has("hand"):
		return ["wrist", "hand"]
	if landmarks.has("hip") and landmarks.has("knee"):
		return ["hip", "knee"]
	if landmarks.has("knee") and landmarks.has("ankle"):
		return ["knee", "ankle"]
	if landmarks.has("ankle") and landmarks.has("toe"):
		return ["ankle", "toe"]
	if landmarks.has("neck") and landmarks.has("head"):
		return ["neck", "head"]
	if landmarks.has("neck") and landmarks.has("torso"):
		return ["neck", "torso"]
	return []

func _is_connection_landmark(name: String) -> bool:
	return ["neck", "shoulder", "elbow", "wrist", "hip", "knee", "ankle"].has(name)

func _map_rig_point_to_reference(rig_p: Vector2, ref_bbox: Rect2, rig_bbox: Rect2) -> Vector2:
	return Vector2(
		ref_bbox.position.x + ((rig_p.x - rig_bbox.position.x) / max(1.0, rig_bbox.size.x)) * ref_bbox.size.x,
		ref_bbox.position.y + ((rig_p.y - rig_bbox.position.y) / max(1.0, rig_bbox.size.y)) * ref_bbox.size.y
	)

func _angle_delta(a: float, b: float) -> float:
	return atan2(sin(a - b), cos(a - b))

func _ref_key_for_landmark(part_name: String, landmark_name: String) -> String:
	if landmark_name == "center":
		if part_name == "near_shoulder_mesh":
			return "shoulder"
		if part_name == "far_shoulder_mesh":
			return "far_shoulder"
		if part_name == "near_knee_mesh":
			return "near_knee"
		if part_name == "far_knee_mesh":
			return "far_knee"
		if part_name == "near_ankle_mesh":
			return "near_ankle"
		if part_name == "far_ankle_mesh":
			return "far_ankle"
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

func _draw_dot_on_image(img: Image, p: Vector2, color: Color) -> void:
	for y in range(-3, 4):
		for x in range(-3, 4):
			if Vector2(x, y).length() <= 3.0:
				var px := int(p.x) + x
				var py := int(p.y) + y
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, color)

func _draw_line_on_image(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(max(1.0, a.distance_to(b)))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		var px := int(p.x)
		var py := int(p.y)
		if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
			img.set_pixel(px, py, color)

func _array_to_vec2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _angle_delta_degrees(a: float, b: float) -> float:
	var delta := fmod(a - b + 180.0, 360.0)
	if delta < 0.0:
		delta += 360.0
	return delta - 180.0

func _compare_images(ref_img: Image, rig_img: Image, ref_frame: Dictionary = {}, rig_points: Dictionary = {}) -> float:
	var ref_mask := _foreground_mask(ref_img, false)
	var rig_mask := _foreground_mask(rig_img, false)
	if not ref_frame.is_empty():
		_apply_focus_mask(ref_mask, ref_img.get_width(), ref_img.get_height(), _points_focus_rect(ref_frame, ref_img.get_size(), 42.0))
	if not rig_points.is_empty():
		_apply_focus_mask(rig_mask, rig_img.get_width(), rig_img.get_height(), _points_focus_rect(rig_points, rig_img.get_size(), 42.0))
	var ref_bbox := _mask_bbox(ref_mask, ref_img.get_width(), ref_img.get_height())
	var rig_bbox := _mask_bbox(rig_mask, rig_img.get_width(), rig_img.get_height())
	if ref_bbox.size.x <= 1 or rig_bbox.size.x <= 1:
		return 0.0

	var iou := _normalized_iou(ref_mask, ref_img.get_size(), ref_bbox, rig_mask, rig_img.get_size(), rig_bbox)
	var ref_center := ref_bbox.get_center()
	var rig_center := rig_bbox.get_center()
	var center_error := ref_center.distance_to(rig_center * (Vector2(ref_img.get_width(), ref_img.get_height()) / Vector2(rig_img.get_width(), rig_img.get_height())))
	var center_score: float = clamp(1.0 - center_error / 120.0, 0.0, 1.0)
	var ref_aspect: float = ref_bbox.size.x / max(1.0, ref_bbox.size.y)
	var rig_aspect: float = rig_bbox.size.x / max(1.0, rig_bbox.size.y)
	var aspect_score: float = clamp(1.0 - abs(ref_aspect - rig_aspect), 0.0, 1.0)
	return clamp(iou * 70.0 + center_score * 15.0 + aspect_score * 15.0, 0.0, 100.0)

func _points_focus_rect(points: Dictionary, image_size: Vector2i, padding: float) -> Rect2:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	var found := false
	for key in points.keys():
		var p := Vector2.ZERO
		var value = points[key]
		if value is Vector2:
			p = value
		elif value is Array and value.size() >= 2:
			p = Vector2(float(value[0]), float(value[1]))
		else:
			continue
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
		found = true
	if not found:
		return Rect2(Vector2.ZERO, Vector2(image_size))
	var pos := Vector2(max(0.0, min_x - padding), max(0.0, min_y - padding))
	var end := Vector2(min(float(image_size.x - 1), max_x + padding), min(float(image_size.y - 1), max_y + padding))
	return Rect2(pos, end - pos)

func _apply_focus_mask(mask: PackedByteArray, w: int, h: int, focus: Rect2) -> void:
	for y in h:
		for x in w:
			if not focus.has_point(Vector2(x, y)):
				mask[y * w + x] = 0

func _foreground_mask(img: Image, remove_side_border_components: bool) -> PackedByteArray:
	var w := img.get_width()
	var h := img.get_height()
	var ignored_rows := _ground_rows(img)
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []
	for x in w:
		_add_background_seed(img, ignored_rows, visited, queue, x, 0)
		_add_background_seed(img, ignored_rows, visited, queue, x, h - 1)
	for y in h:
		_add_background_seed(img, ignored_rows, visited, queue, 0, y)
		_add_background_seed(img, ignored_rows, visited, queue, w - 1, y)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		_add_background_seed(img, ignored_rows, visited, queue, p.x + 1, p.y)
		_add_background_seed(img, ignored_rows, visited, queue, p.x - 1, p.y)
		_add_background_seed(img, ignored_rows, visited, queue, p.x, p.y + 1)
		_add_background_seed(img, ignored_rows, visited, queue, p.x, p.y - 1)

	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var idx := y * w + x
			mask[idx] = 0 if ignored_rows.has(y) or visited[idx] == 1 else 1
	if remove_side_border_components:
		_remove_side_border_foreground(mask, w, h)
	return mask

func _add_background_seed(img: Image, ignored_rows: Dictionary, visited: PackedByteArray, queue: Array[Vector2i], x: int, y: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if x < 0 or y < 0 or x >= w or y >= h or ignored_rows.has(y):
		return
	var idx := y * w + x
	if visited[idx] == 1:
		return
	if not _is_background_pixel(img.get_pixel(x, y)):
		return
	visited[idx] = 1
	queue.append(Vector2i(x, y))

func _remove_side_border_foreground(mask: PackedByteArray, w: int, h: int) -> void:
	var queue: Array[Vector2i] = []
	for y in h:
		if mask[y * w] == 1:
			queue.append(Vector2i(0, y))
			mask[y * w] = 0
		var right_idx := y * w + w - 1
		if mask[right_idx] == 1:
			queue.append(Vector2i(w - 1, y))
			mask[right_idx] = 0
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for n in [Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y), Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1)]:
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var idx: int = n.y * w + n.x
			if mask[idx] == 1:
				mask[idx] = 0
				queue.append(n)

func _mask_bbox(mask: PackedByteArray, w: int, h: int) -> Rect2:
	var min_x := w
	var min_y := h
	var max_x := 0
	var max_y := 0
	var found := false
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
			found = true
	if not found:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))

func _foreground_bbox(img: Image) -> Rect2:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := 0
	var max_y := 0
	var found := false
	var ignored_rows := _ground_rows(img)
	for y in img.get_height():
		if ignored_rows.has(y):
			continue
		for x in img.get_width():
			if _is_foreground(img.get_pixel(x, y)):
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
				found = true
	if not found:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))

func _ground_rows(img: Image) -> Dictionary:
	var rows := {}
	for y in img.get_height():
		if y < img.get_height() * 0.72:
			continue
		var dark := 0
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r < 0.18 and c.g < 0.18 and c.b < 0.18 and c.a > 0.4:
				dark += 1
		if dark > img.get_width() * 0.12:
			rows[y] = true
	return rows

func _normalized_iou(a_mask: PackedByteArray, a_size: Vector2i, a_box: Rect2, b_mask: PackedByteArray, b_size: Vector2i, b_box: Rect2) -> float:
	var sample_w := 96
	var sample_h := 150
	var inter := 0
	var union := 0
	for y in sample_h:
		for x in sample_w:
			var ax := int(a_box.position.x + (float(x) + 0.5) / float(sample_w) * a_box.size.x)
			var ay := int(a_box.position.y + (float(y) + 0.5) / float(sample_h) * a_box.size.y)
			var bx := int(b_box.position.x + (float(x) + 0.5) / float(sample_w) * b_box.size.x)
			var by := int(b_box.position.y + (float(y) + 0.5) / float(sample_h) * b_box.size.y)
			ax = clamp(ax, 0, a_size.x - 1)
			ay = clamp(ay, 0, a_size.y - 1)
			bx = clamp(bx, 0, b_size.x - 1)
			by = clamp(by, 0, b_size.y - 1)
			var af := a_mask[ay * a_size.x + ax] == 1
			var bf := b_mask[by * b_size.x + bx] == 1
			if af and bf:
				inter += 1
			if af or bf:
				union += 1
	if union == 0:
		return 0.0
	return float(inter) / float(union)

func _is_foreground(c: Color) -> bool:
	if c.a < 0.2:
		return false
	return not (c.r > 0.86 and c.g > 0.86 and c.b > 0.86)

func _is_background_pixel(c: Color) -> bool:
	if c.a < 0.2:
		return true
	return c.r > 0.86 and c.g > 0.86 and c.b > 0.86

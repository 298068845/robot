extends PanelContainer

const Rig = preload("res://scripts/male_tinpet_sprite_rig.gd")
const REF_SHEET_PATH := "res://assets/animation/male_tinpet_walk_10f_v1.png"
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"

var result_label: Label
var run_button: Button
var viewport: SubViewport
var debug_rect: TextureRect
var ref_points: Array = []

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
	viewport.size = Vector2i(260, 360)
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

	var scores: Array[float] = []
	var lines: Array[String] = []
	var worst_index := 0
	var worst_score := 999.0
	var worst_debug: Image
	for i in 10:
		var ref_img := _crop_reference(ref_sheet, i)
		var render: Dictionary = await _render_rig_frame(i)
		var rig_img: Image = render["image"]
		var rig_points: Dictionary = render["points"]
		var silhouette_score := _compare_images(ref_img, rig_img)
		var joint_score := _compare_points(ref_points[i], rig_points, ref_img, rig_img)
		var score: float = silhouette_score * 0.05 + joint_score * 0.95
		scores.append(score)
		lines.append("%02d: %.1f/%.1f" % [i + 1, score, joint_score])
		if score < worst_score:
			worst_score = score
			worst_index = i
			worst_debug = _make_debug_image(ref_img, rig_img, ref_points[i], rig_points)

	var total := 0.0
	for score in scores:
		total += score
	var avg := total / float(scores.size())
	var verdict := "通过" if avg >= 72.0 else "失败"
	result_label.text = "%s  平均 %.1f  最差帧 %02d\n总分/骨骼分: %s" % [verdict, avg, worst_index + 1, "  ".join(lines)]
	if worst_debug != null:
		debug_rect.texture = ImageTexture.create_from_image(worst_debug)
	run_button.disabled = false

func _load_ref_points() -> Array:
	var text := FileAccess.get_file_as_string(REF_POINTS_PATH)
	var parsed = JSON.parse_string(text)
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
	rig.position = Vector2(130, 318)
	viewport.add_child(rig)
	await get_tree().process_frame
	rig.t = 1.2 * float(frame_index) / 9.0
	rig._pose()
	var points := rig.get_compare_points()

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image
	if DisplayServer.get_name() == "headless":
		img = _make_point_proxy_image(points)
	else:
		img = viewport.get_texture().get_image()
	if img == null:
		img = _make_point_proxy_image(points)
	else:
		img.convert(Image.FORMAT_RGBA8)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return {"image": img, "points": points}

func _make_point_proxy_image(points: Dictionary) -> Image:
	var img := Image.create(viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var bones := [
		["head", "neck"], ["neck", "torso"], ["torso", "hip"],
		["shoulder", "elbow"], ["elbow", "wrist"], ["wrist", "hand"],
		["hip", "near_knee"], ["near_knee", "near_ankle"], ["near_ankle", "near_toe"],
		["hip", "far_knee"], ["far_knee", "far_ankle"], ["far_ankle", "far_toe"],
	]
	for bone in bones:
		if points.has(bone[0]) and points.has(bone[1]):
			_draw_line_on_image(img, points[bone[0]], points[bone[1]], Color.BLACK)
	for key in points.keys():
		_draw_dot_on_image(img, points[key], Color.BLACK)
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

func _compare_images(ref_img: Image, rig_img: Image) -> float:
	var ref_bbox := _foreground_bbox(ref_img)
	var rig_bbox := _foreground_bbox(rig_img)
	if ref_bbox.size.x <= 1 or rig_bbox.size.x <= 1:
		return 0.0

	var iou := _normalized_iou(ref_img, ref_bbox, rig_img, rig_bbox)
	var ref_center := ref_bbox.get_center()
	var rig_center := rig_bbox.get_center()
	var center_error := ref_center.distance_to(rig_center * (Vector2(ref_img.get_width(), ref_img.get_height()) / Vector2(rig_img.get_width(), rig_img.get_height())))
	var center_score: float = clamp(1.0 - center_error / 120.0, 0.0, 1.0)
	var ref_aspect: float = ref_bbox.size.x / max(1.0, ref_bbox.size.y)
	var rig_aspect: float = rig_bbox.size.x / max(1.0, rig_bbox.size.y)
	var aspect_score: float = clamp(1.0 - abs(ref_aspect - rig_aspect), 0.0, 1.0)
	return clamp(iou * 70.0 + center_score * 15.0 + aspect_score * 15.0, 0.0, 100.0)

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
		var dark := 0
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r < 0.18 and c.g < 0.18 and c.b < 0.18 and c.a > 0.4:
				dark += 1
		if dark > img.get_width() * 0.55:
			rows[y] = true
	return rows

func _normalized_iou(a_img: Image, a_box: Rect2, b_img: Image, b_box: Rect2) -> float:
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
			var af := _is_foreground(a_img.get_pixel(clamp(ax, 0, a_img.get_width() - 1), clamp(ay, 0, a_img.get_height() - 1)))
			var bf := _is_foreground(b_img.get_pixel(clamp(bx, 0, b_img.get_width() - 1), clamp(by, 0, b_img.get_height() - 1)))
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

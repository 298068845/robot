extends Control

const REF_SHEET_PATH := "res://assets/animation/walk_reference_sheet.png"
const HAND_TRACE_PATH := "res://assets/animation/segmented_reference_annotated.png"
const USER_DATA_PATH := "user://walk_contour_points.json"
const POINTS_PER_PART := 20

const PARTS := [
	{"name": "head", "label": "head", "color": "#ff4646"},
	{"name": "torso", "label": "torso", "color": "#34bdf8"},
	{"name": "outer_upper_arm", "label": "Outer upper arm", "color": "#ff4d6d"},
	{"name": "outer_forearm", "label": "Outer forearm", "color": "#ff7890"},
	{"name": "outer_hand", "label": "Outer hand", "color": "#ffb3c1"},
	{"name": "inner_upper_arm", "label": "Inner upper arm", "color": "#a855ff"},
	{"name": "inner_forearm", "label": "Inner forearm", "color": "#c084fc"},
	{"name": "inner_hand", "label": "Inner hand", "color": "#ddb8ff"},
	{"name": "outer_thigh", "label": "Outer thigh", "color": "#4dff88"},
	{"name": "outer_shin", "label": "Outer shin", "color": "#77ffad"},
	{"name": "outer_foot", "label": "Outer foot", "color": "#25d366"},
	{"name": "inner_thigh", "label": "Inner thigh", "color": "#ff9f43"},
	{"name": "inner_shin", "label": "Inner shin", "color": "#ffbd73"},
	{"name": "inner_foot", "label": "Inner foot", "color": "#f97316"}
]

var ref_sheet := Image.new()
var hand_trace := Image.new()
var frame_texture: ImageTexture
var trace_texture: ImageTexture
var frame_rect := Rect2()
var frame_count := 10
var frame_index := 0
var part_index := 0
var selected_point := -1
var dragging := false
var contour_data := {"version": 1, "source": REF_SHEET_PATH, "frames": []}
var status_label := Label.new()
var frame_label := Label.new()
var part_select := OptionButton.new()
var trace_check := CheckBox.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_images()
	_load_data()
	_build_ui()
	resized.connect(_layout)
	_layout()
	_show_frame(0)

func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(16, 12)
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	var prev_frame := Button.new()
	prev_frame.text = "< frame"
	prev_frame.custom_minimum_size = Vector2(74, 32)
	prev_frame.pressed.connect(func(): _show_frame(frame_index - 1))
	toolbar.add_child(prev_frame)

	var next_frame := Button.new()
	next_frame.text = "frame >"
	next_frame.custom_minimum_size = Vector2(74, 32)
	next_frame.pressed.connect(func(): _show_frame(frame_index + 1))
	toolbar.add_child(next_frame)

	frame_label.custom_minimum_size = Vector2(86, 32)
	toolbar.add_child(frame_label)

	for part in PARTS:
		part_select.add_item(part["label"])
	part_select.selected = part_index
	part_select.item_selected.connect(func(index: int): _select_part(index))
	part_select.custom_minimum_size = Vector2(150, 32)
	toolbar.add_child(part_select)

	var prev_part := Button.new()
	prev_part.text = "< part"
	prev_part.custom_minimum_size = Vector2(66, 32)
	prev_part.pressed.connect(func(): _select_part(wrapi(part_index - 1, 0, PARTS.size())))
	toolbar.add_child(prev_part)

	var next_part := Button.new()
	next_part.text = "part >"
	next_part.custom_minimum_size = Vector2(66, 32)
	next_part.pressed.connect(func(): _select_part(wrapi(part_index + 1, 0, PARTS.size())))
	toolbar.add_child(next_part)

	var copy_button := Button.new()
	copy_button.text = "copy prev"
	copy_button.custom_minimum_size = Vector2(82, 32)
	copy_button.pressed.connect(_copy_previous_frame)
	toolbar.add_child(copy_button)

	var reset_button := Button.new()
	reset_button.text = "reset part"
	reset_button.custom_minimum_size = Vector2(82, 32)
	reset_button.pressed.connect(_reset_current_part)
	toolbar.add_child(reset_button)

	var save_button := Button.new()
	save_button.text = "save"
	save_button.custom_minimum_size = Vector2(64, 32)
	save_button.pressed.connect(_save_data)
	toolbar.add_child(save_button)

	trace_check.text = "show hand trace on frame 1"
	trace_check.button_pressed = true
	trace_check.toggled.connect(func(_enabled: bool): queue_redraw())
	toolbar.add_child(trace_check)

	status_label.position = Vector2(16, 48)
	status_label.custom_minimum_size = Vector2(980, 24)
	add_child(status_label)

func _load_images() -> void:
	if ref_sheet.load(REF_SHEET_PATH) != OK:
		ref_sheet = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	if hand_trace.load(HAND_TRACE_PATH) == OK:
		trace_texture = ImageTexture.create_from_image(hand_trace)

func _load_data() -> void:
	if FileAccess.file_exists(USER_DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(USER_DATA_PATH))
		if parsed is Dictionary and parsed.has("frames"):
			contour_data = parsed
	_ensure_data()

func _ensure_data() -> void:
	if not contour_data.has("frames") or not (contour_data["frames"] is Array):
		contour_data["frames"] = []
	var frames: Array = contour_data["frames"]
	while frames.size() < frame_count:
		frames.append({"parts": {}})
	for i in range(frame_count):
		if not (frames[i] is Dictionary):
			frames[i] = {"parts": {}}
		if not frames[i].has("parts") or not (frames[i]["parts"] is Dictionary):
			frames[i]["parts"] = {}
		var parts: Dictionary = frames[i]["parts"]
		for part in PARTS:
			var name: String = part["name"]
			if not parts.has(name) or not (parts[name] is Array) or parts[name].size() != POINTS_PER_PART:
				parts[name] = _default_points_for_part(name, i)

func _layout() -> void:
	var sheet_frame_size: Vector2 = _source_frame_size()
	var available: Vector2 = Vector2(max(1.0, size.x - 48.0), max(1.0, size.y - 92.0))
	var scale: float = min(available.x / sheet_frame_size.x, available.y / sheet_frame_size.y)
	scale = clampf(scale, 0.8, 2.8)
	frame_rect = Rect2(Vector2(24.0, 82.0), sheet_frame_size * scale)
	queue_redraw()

func _show_frame(index: int) -> void:
	frame_index = wrapi(index, 0, frame_count)
	var frame_w: int = int(ref_sheet.get_width() / frame_count)
	var img: Image = ref_sheet.get_region(Rect2i(frame_index * frame_w, 0, frame_w, ref_sheet.get_height()))
	img.convert(Image.FORMAT_RGBA8)
	frame_texture = ImageTexture.create_from_image(img)
	frame_label.text = "frame %02d" % [frame_index + 1]
	selected_point = -1
	_update_status()
	queue_redraw()

func _select_part(index: int) -> void:
	part_index = clampi(index, 0, PARTS.size() - 1)
	part_select.selected = part_index
	selected_point = -1
	_update_status()
	queue_redraw()

func _draw() -> void:
	if frame_texture != null:
		draw_texture_rect(frame_texture, frame_rect, false)
	if frame_index == 0 and trace_check.button_pressed and trace_texture != null:
		draw_texture_rect(trace_texture, frame_rect, false, Color(1, 1, 1, 0.34))

	for i in range(PARTS.size()):
		_draw_part(i, i == part_index)

func _draw_part(index: int, active: bool) -> void:
	var part: Dictionary = PARTS[index]
	var color: Color = Color(String(part["color"]))
	var points: Array = _points_for(index)
	var mapped: PackedVector2Array = []
	for point in points:
		mapped.append(_frame_to_screen(_array_to_vec2(point)))
	if mapped.size() >= 2:
		for i in range(mapped.size()):
			draw_line(mapped[i], mapped[(i + 1) % mapped.size()], color, 2.0 if active else 1.0)
	for i in range(mapped.size()):
		var radius: float = 4.0 if active else 2.3
		if active and i == selected_point:
			radius = 6.0
		draw_circle(mapped[i], radius, color)
		if active:
			draw_arc(mapped[i], radius + 1.6, 0.0, TAU, 14, Color.WHITE, 0.9)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			selected_point = _nearest_point(event.position)
			dragging = selected_point >= 0
			if dragging:
				_set_selected_point(event.position)
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		_set_selected_point(event.position)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_A:
			_show_frame(frame_index - 1)
		KEY_D:
			_show_frame(frame_index + 1)
		KEY_Q:
			_select_part(wrapi(part_index - 1, 0, PARTS.size()))
		KEY_E:
			_select_part(wrapi(part_index + 1, 0, PARTS.size()))
		KEY_S:
			if event.ctrl_pressed:
				_save_data()

func _nearest_point(screen_pos: Vector2) -> int:
	var points: Array = _points_for(part_index)
	var best: int = -1
	var best_dist: float = 999999.0
	for i in range(points.size()):
		var dist: float = _frame_to_screen(_array_to_vec2(points[i])).distance_to(screen_pos)
		if dist < best_dist and dist <= 20.0:
			best = i
			best_dist = dist
	return best

func _set_selected_point(screen_pos: Vector2) -> void:
	if selected_point < 0:
		return
	var frame_pos: Vector2 = _screen_to_frame(screen_pos)
	var points: Array = _points_for(part_index)
	points[selected_point] = [frame_pos.x, frame_pos.y]
	_update_status()
	queue_redraw()

func _copy_previous_frame() -> void:
	if frame_index <= 0:
		return
	var frames: Array = contour_data["frames"]
	var source: Dictionary = frames[frame_index - 1]["parts"]
	var target: Dictionary = frames[frame_index]["parts"]
	for part in PARTS:
		var name: String = part["name"]
		target[name] = _duplicate_points(source[name])
	_update_status()
	queue_redraw()

func _reset_current_part() -> void:
	var part_name: String = PARTS[part_index]["name"]
	contour_data["frames"][frame_index]["parts"][part_name] = _default_points_for_part(part_name, frame_index)
	selected_point = -1
	_update_status()
	queue_redraw()

func _save_data() -> void:
	contour_data["version"] = 1
	contour_data["source"] = REF_SHEET_PATH
	contour_data["parts"] = PARTS
	var file: FileAccess = FileAccess.open(USER_DATA_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(contour_data, "\t"))
	status_label.text = "saved: %s" % USER_DATA_PATH

func _points_for(index: int) -> Array:
	var part_name: String = PARTS[index]["name"]
	return contour_data["frames"][frame_index]["parts"][part_name]

func _frame_to_screen(point: Vector2) -> Vector2:
	return frame_rect.position + Vector2(
		point.x / max(1.0, _source_frame_size().x) * frame_rect.size.x,
		point.y / max(1.0, _source_frame_size().y) * frame_rect.size.y
	)

func _screen_to_frame(point: Vector2) -> Vector2:
	var local: Vector2 = point - frame_rect.position
	var frame_size: Vector2 = _source_frame_size()
	return Vector2(
		clampf(local.x / max(1.0, frame_rect.size.x) * frame_size.x, 0.0, frame_size.x),
		clampf(local.y / max(1.0, frame_rect.size.y) * frame_size.y, 0.0, frame_size.y)
	)

func _source_frame_size() -> Vector2:
	return Vector2(float(ref_sheet.get_width()) / float(frame_count), float(ref_sheet.get_height()))

func _default_points_for_part(part_name: String, frame: int) -> Array:
	var center: Vector2 = _default_center(part_name, frame)
	var radii: Vector2 = _default_radii(part_name)
	var points: Array = []
	for i in range(POINTS_PER_PART):
		var angle: float = TAU * float(i) / float(POINTS_PER_PART)
		points.append([center.x + cos(angle) * radii.x, center.y + sin(angle) * radii.y])
	return points

func _default_center(part_name: String, frame: int) -> Vector2:
	var phase: float = TAU * float(frame) / float(frame_count)
	var base: Dictionary = {
		"head": Vector2(82, 86),
		"torso": Vector2(78, 176),
		"outer_upper_arm": Vector2(59, 170),
		"outer_forearm": Vector2(50, 224),
		"outer_hand": Vector2(43, 265),
		"inner_upper_arm": Vector2(101, 168),
		"inner_forearm": Vector2(124, 184),
		"inner_hand": Vector2(145, 198),
		"outer_thigh": Vector2(60, 278),
		"outer_shin": Vector2(38, 360),
		"outer_foot": Vector2(42, 436),
		"inner_thigh": Vector2(97, 278),
		"inner_shin": Vector2(116, 360),
		"inner_foot": Vector2(132, 436)
	}
	var point: Vector2 = base.get(part_name, Vector2(80, 220))
	if frame > 0:
		point.x += sin(phase) * 10.0
	return point

func _default_radii(part_name: String) -> Vector2:
	if part_name == "head":
		return Vector2(22, 26)
	if part_name == "torso":
		return Vector2(26, 68)
	if part_name.contains("hand"):
		return Vector2(15, 10)
	if part_name.contains("foot"):
		return Vector2(34, 10)
	if part_name.contains("arm"):
		return Vector2(10, 34)
	if part_name.contains("thigh") or part_name.contains("shin"):
		return Vector2(12, 52)
	return Vector2(16, 16)

func _duplicate_points(points: Array) -> Array:
	var out: Array = []
	for point in points:
		var p: Vector2 = _array_to_vec2(point)
		out.append([p.x, p.y])
	return out

func _array_to_vec2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _update_status() -> void:
	var point_text: String = "-"
	if selected_point >= 0:
		var p: Vector2 = _array_to_vec2(_points_for(part_index)[selected_point])
		point_text = "%02d x=%.1f y=%.1f" % [selected_point + 1, p.x, p.y]
	status_label.text = "Strict contour calibration. Drag points only against the visible frame/hand trace. frame=%02d part=%s point=%s" % [
		frame_index + 1,
		PARTS[part_index]["label"],
		point_text
	]

extends Control

const CANVAS_COLOR := Color(0.96, 0.97, 0.98, 1.0)
const GRID_COLOR := Color(0.86, 0.88, 0.91, 1.0)
const PANEL_COLOR := Color(0.12, 0.14, 0.18, 0.92)
const PANEL_LINE := Color(0.25, 0.28, 0.33, 1.0)
const HANDLE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HANDLE_OUTLINE := Color(0.10, 0.12, 0.15, 1.0)
const ACTIVE_FRAME_COLOR := Color(0.22, 0.48, 0.92, 1.0)
const LINE_WIDTH := 8.0
const HANDLE_RADIUS := 9.0
const HEAD_HANDLE_RADIUS := 24.0
const HIT_RADIUS := 16.0
const SIDEBAR_WIDTH := 292.0
const EXPORT_SIZE := Vector2i(960, 720)

var parts: Array = []
var frames: Array = []
var selected_part := 0
var selected_frame := 0
var drag_part := -1
var drag_endpoint := -1
var dragging_segment := false
var is_playing := false
var last_mouse := Vector2.ZERO
var canvas_rect := Rect2()

var selected_label: Label
var frame_label: Label
var export_label: Label
var play_button: Button
var frame_list: VBoxContainer
var playback_timer: Timer
var speed_slider: HSlider

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	frames.append(_make_frame("动作 1", _make_default_parts()))
	_load_frame(0)
	_build_ui()
	resized.connect(queue_redraw)
	queue_redraw()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(SIDEBAR_WIDTH - 32.0, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "火柴人动作编辑器"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 21)
	root.add_child(title)

	frame_label = Label.new()
	frame_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
	root.add_child(frame_label)

	selected_label = Label.new()
	selected_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(selected_label)

	var playback_row := HBoxContainer.new()
	playback_row.add_theme_constant_override("separation", 8)
	root.add_child(playback_row)

	play_button = Button.new()
	play_button.text = "播放"
	play_button.custom_minimum_size = Vector2(72, 34)
	play_button.pressed.connect(_toggle_playback)
	playback_row.add_child(play_button)

	var prev_button := Button.new()
	prev_button.text = "上一帧"
	prev_button.custom_minimum_size = Vector2(76, 34)
	prev_button.pressed.connect(_select_previous_frame)
	playback_row.add_child(prev_button)

	var next_button := Button.new()
	next_button.text = "下一帧"
	next_button.custom_minimum_size = Vector2(76, 34)
	next_button.pressed.connect(_select_next_frame)
	playback_row.add_child(next_button)

	var speed_label := Label.new()
	speed_label.text = "播放速度"
	speed_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	root.add_child(speed_label)

	speed_slider = HSlider.new()
	speed_slider.min_value = 2.0
	speed_slider.max_value = 12.0
	speed_slider.step = 1.0
	speed_slider.value = 6.0
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.value_changed.connect(_set_playback_speed)
	root.add_child(speed_slider)

	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 8)
	root.add_child(edit_row)

	var duplicate_button := Button.new()
	duplicate_button.text = "复制当前"
	duplicate_button.custom_minimum_size = Vector2(86, 34)
	duplicate_button.pressed.connect(_duplicate_frame)
	edit_row.add_child(duplicate_button)

	var add_button := Button.new()
	add_button.text = "新增模板"
	add_button.custom_minimum_size = Vector2(86, 34)
	add_button.pressed.connect(_add_default_frame)
	edit_row.add_child(add_button)

	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.custom_minimum_size = Vector2(58, 34)
	delete_button.pressed.connect(_delete_frame)
	edit_row.add_child(delete_button)

	var output_row := HBoxContainer.new()
	output_row.add_theme_constant_override("separation", 8)
	root.add_child(output_row)

	var reset_button := Button.new()
	reset_button.text = "重置当前"
	reset_button.custom_minimum_size = Vector2(86, 34)
	reset_button.pressed.connect(_reset_current_frame)
	output_row.add_child(reset_button)

	var export_button := Button.new()
	export_button.text = "导出图片"
	export_button.custom_minimum_size = Vector2(98, 34)
	export_button.pressed.connect(_export_png)
	output_row.add_child(export_button)

	var hint := Label.new()
	hint.text = "右侧画布：拖端点拉伸/缩短；拖线段移动。点击左侧动作可返回修改。"
	hint.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var frame_title := Label.new()
	frame_title.text = "动作顺序"
	frame_title.add_theme_color_override("font_color", Color.WHITE)
	frame_title.add_theme_font_size_override("font_size", 16)
	root.add_child(frame_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 164)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	frame_list = VBoxContainer.new()
	frame_list.add_theme_constant_override("separation", 6)
	scroll.add_child(frame_list)

	export_label = Label.new()
	export_label.text = ""
	export_label.add_theme_color_override("font_color", Color(0.74, 0.86, 1.0))
	export_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(export_label)

	playback_timer = Timer.new()
	playback_timer.wait_time = 1.0 / speed_slider.value
	playback_timer.timeout.connect(_advance_playback)
	add_child(playback_timer)

	_update_ui()

func _make_default_parts() -> Array:
	var default_parts: Array = [
		_part("头部", Vector2(610, 100), Vector2(610, 158), Color(0.94, 0.25, 0.22)),
		_part("身躯", Vector2(610, 158), Vector2(610, 322), Color(0.12, 0.45, 0.90)),
		_part("左手大臂", Vector2(610, 158), Vector2(530, 230), Color(0.10, 0.68, 0.38)),
		_part("左手小臂", Vector2(530, 230), Vector2(474, 300), Color(0.13, 0.78, 0.66)),
		_part("右手大臂", Vector2(610, 158), Vector2(696, 214), Color(0.62, 0.35, 0.95)),
		_part("右手小臂", Vector2(696, 214), Vector2(754, 282), Color(0.82, 0.40, 0.88)),
		_part("左腿大腿", Vector2(610, 322), Vector2(550, 430), Color(0.97, 0.58, 0.12)),
		_part("左腿小腿", Vector2(550, 430), Vector2(520, 555), Color(0.96, 0.74, 0.12)),
		_part("左腿脚掌", Vector2(520, 555), Vector2(455, 575), Color(0.59, 0.43, 0.22)),
		_part("右腿大腿", Vector2(610, 322), Vector2(680, 424), Color(0.90, 0.18, 0.45)),
		_part("右腿小腿", Vector2(680, 424), Vector2(726, 540), Color(0.55, 0.22, 0.78)),
		_part("右腿脚掌", Vector2(726, 540), Vector2(796, 548), Color(0.28, 0.34, 0.42)),
	]
	return _with_default_joints(default_parts)

func _part(part_name: String, a: Vector2, b: Vector2, color: Color) -> Dictionary:
	return {"name": part_name, "a": a, "b": b, "color": color, "joint_a": "", "joint_b": ""}

func _with_default_joints(frame_parts: Array) -> Array:
	var joints := [
		["head_top", "neck"],
		["neck", "pelvis"],
		["neck", "left_elbow"],
		["left_elbow", "left_hand"],
		["neck", "right_elbow"],
		["right_elbow", "right_hand"],
		["pelvis", "left_knee"],
		["left_knee", "left_ankle"],
		["left_ankle", "left_toe"],
		["pelvis", "right_knee"],
		["right_knee", "right_ankle"],
		["right_ankle", "right_toe"],
	]
	for i in range(mini(frame_parts.size(), joints.size())):
		frame_parts[i]["joint_a"] = joints[i][0]
		frame_parts[i]["joint_b"] = joints[i][1]
	return frame_parts

func _make_frame(frame_name: String, frame_parts: Array) -> Dictionary:
	return {"name": frame_name, "parts": _copy_parts(frame_parts)}

func _copy_parts(source: Array) -> Array:
	var copied: Array = []
	for source_part in source:
		var part: Dictionary = source_part
		var copied_part := _part(part["name"], part["a"], part["b"], part["color"])
		copied_part["joint_a"] = part.get("joint_a", "")
		copied_part["joint_b"] = part.get("joint_b", "")
		copied.append(copied_part)
	return copied

func _save_current_frame() -> void:
	if selected_frame < 0 or selected_frame >= frames.size():
		return
	frames[selected_frame]["parts"] = _copy_parts(parts)

func _load_frame(index: int) -> void:
	selected_frame = clampi(index, 0, frames.size() - 1)
	parts = _copy_parts(frames[selected_frame]["parts"])
	selected_part = clampi(selected_part, 0, parts.size() - 1)
	_update_ui()
	queue_redraw()

func _select_frame(index: int) -> void:
	_save_current_frame()
	_load_frame(index)

func _select_previous_frame() -> void:
	_select_frame((selected_frame - 1 + frames.size()) % frames.size())

func _select_next_frame() -> void:
	_select_frame((selected_frame + 1) % frames.size())

func _duplicate_frame() -> void:
	_save_current_frame()
	var insert_at := selected_frame + 1
	frames.insert(insert_at, _make_frame("动作 %d" % (frames.size() + 1), parts))
	_load_frame(insert_at)

func _add_default_frame() -> void:
	_save_current_frame()
	frames.append(_make_frame("动作 %d" % (frames.size() + 1), _make_default_parts()))
	_load_frame(frames.size() - 1)

func _delete_frame() -> void:
	if frames.size() <= 1:
		_reset_current_frame()
		return
	frames.remove_at(selected_frame)
	_load_frame(mini(selected_frame, frames.size() - 1))

func _reset_current_frame() -> void:
	parts = _make_default_parts()
	_save_current_frame()
	selected_part = 0
	_update_ui()
	queue_redraw()

func _toggle_playback() -> void:
	if is_playing:
		_stop_playback()
	else:
		_start_playback()

func _start_playback() -> void:
	_save_current_frame()
	is_playing = true
	play_button.text = "暂停"
	playback_timer.start()

func _stop_playback() -> void:
	is_playing = false
	playback_timer.stop()
	play_button.text = "播放"

func _advance_playback() -> void:
	_load_frame((selected_frame + 1) % frames.size())

func _set_playback_speed(value: float) -> void:
	if playback_timer == null:
		return
	playback_timer.wait_time = 1.0 / value
	if is_playing:
		playback_timer.start()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			drag_part = -1
			drag_endpoint = -1
			dragging_segment = false
	elif event is InputEventMouseMotion and drag_part >= 0:
		_drag_to(event.position)

func _begin_drag(pos: Vector2) -> void:
	if pos.x < SIDEBAR_WIDTH:
		return
	_stop_playback()
	last_mouse = pos
	drag_part = -1
	drag_endpoint = -1
	dragging_segment = false

	var best_distance := HIT_RADIUS
	for i in range(parts.size()):
		var a: Vector2 = parts[i]["a"]
		var b: Vector2 = parts[i]["b"]
		var endpoint_hit_radius := HEAD_HANDLE_RADIUS if _is_head_top_endpoint(i, 0) else HIT_RADIUS
		var da: float = pos.distance_to(a)
		var db: float = pos.distance_to(b)
		if da < maxf(best_distance, endpoint_hit_radius) and da <= endpoint_hit_radius:
			best_distance = da
			drag_part = i
			drag_endpoint = 0
		if db < best_distance:
			best_distance = db
			drag_part = i
			drag_endpoint = 1

	if drag_part == -1:
		for i in range(parts.size() - 1, -1, -1):
			if _distance_to_segment(pos, parts[i]["a"], parts[i]["b"]) <= HIT_RADIUS:
				drag_part = i
				dragging_segment = true
				break

	if drag_part >= 0:
		selected_part = drag_part
		_update_ui()
		queue_redraw()

func _drag_to(pos: Vector2) -> void:
	var clamped := _clamp_to_canvas(pos)
	if dragging_segment:
		var delta: Vector2 = clamped - last_mouse
		_move_endpoint_group_by_delta(drag_part, 0, delta)
		_move_endpoint_group_by_delta(drag_part, 1, delta)
		last_mouse = clamped
	elif drag_endpoint == 0:
		_move_endpoint_group_to(drag_part, 0, clamped)
	elif drag_endpoint == 1:
		_move_endpoint_group_to(drag_part, 1, clamped)
	_save_current_frame()
	_update_ui()
	queue_redraw()

func _draw() -> void:
	canvas_rect = Rect2(Vector2.ZERO, size)
	draw_rect(canvas_rect, CANVAS_COLOR, true)
	_draw_grid()
	draw_rect(Rect2(Vector2(SIDEBAR_WIDTH, 0), Vector2(1, size.y)), PANEL_LINE, true)
	_draw_figure()

func _draw_grid() -> void:
	var step := 40.0
	var x := SIDEBAR_WIDTH
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += step
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(SIDEBAR_WIDTH, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += step

func _draw_figure() -> void:
	for i in range(parts.size()):
		var color: Color = parts[i]["color"]
		var width := LINE_WIDTH
		if i == selected_part and not is_playing:
			draw_line(parts[i]["a"], parts[i]["b"], Color(0.06, 0.07, 0.09), LINE_WIDTH + 5.0, true)
			width = LINE_WIDTH + 1.5
		draw_line(parts[i]["a"], parts[i]["b"], color, width, true)

	_draw_head_marker()

	if is_playing:
		return
	for i in range(parts.size()):
		_draw_handle(parts[i]["a"], i == selected_part, _is_head_top_endpoint(i, 0))
		_draw_handle(parts[i]["b"], i == selected_part, _is_head_top_endpoint(i, 1))

func _draw_head_marker() -> void:
	if parts.is_empty():
		return
	var center: Vector2 = parts[0]["a"]
	draw_circle(center, HEAD_HANDLE_RADIUS + 3.0, HANDLE_OUTLINE)
	draw_circle(center, HEAD_HANDLE_RADIUS, HANDLE_COLOR)

func _draw_handle(pos: Vector2, active: bool, is_head_top: bool) -> void:
	var base_radius := HEAD_HANDLE_RADIUS if is_head_top else HANDLE_RADIUS
	var radius := base_radius + (2.0 if active else 0.0)
	draw_circle(pos, radius + 2.0, HANDLE_OUTLINE)
	draw_circle(pos, radius, HANDLE_COLOR)

func _move_endpoint_group_to(part_index: int, endpoint: int, target: Vector2) -> void:
	var joint_id := _endpoint_joint(part_index, endpoint)
	if joint_id == "":
		_set_endpoint_position(part_index, endpoint, target)
		return
	for i in range(parts.size()):
		if parts[i].get("joint_a", "") == joint_id:
			parts[i]["a"] = target
		if parts[i].get("joint_b", "") == joint_id:
			parts[i]["b"] = target

func _move_endpoint_group_by_delta(part_index: int, endpoint: int, delta: Vector2) -> void:
	var current := _endpoint_position(part_index, endpoint)
	_move_endpoint_group_to(part_index, endpoint, _clamp_to_canvas(current + delta))

func _endpoint_joint(part_index: int, endpoint: int) -> String:
	if part_index < 0 or part_index >= parts.size():
		return ""
	if endpoint == 0:
		return parts[part_index].get("joint_a", "")
	return parts[part_index].get("joint_b", "")

func _endpoint_position(part_index: int, endpoint: int) -> Vector2:
	if endpoint == 0:
		return parts[part_index]["a"]
	return parts[part_index]["b"]

func _set_endpoint_position(part_index: int, endpoint: int, target: Vector2) -> void:
	if endpoint == 0:
		parts[part_index]["a"] = target
	else:
		parts[part_index]["b"] = target

func _is_head_top_endpoint(part_index: int, endpoint: int) -> bool:
	return part_index == 0 and endpoint == 0

func _update_ui() -> void:
	if frame_label != null:
		frame_label.text = "当前动作：%d / %d" % [selected_frame + 1, frames.size()]
	if selected_label != null and not parts.is_empty():
		var part: Dictionary = parts[selected_part]
		var length: float = part["a"].distance_to(part["b"])
		selected_label.text = "当前部位：%s  长度：%d px" % [part["name"], int(round(length))]
	_rebuild_frame_list()

func _rebuild_frame_list() -> void:
	if frame_list == null:
		return
	for child in frame_list.get_children():
		child.queue_free()
	for i in range(frames.size()):
		var button := Button.new()
		button.text = "%02d  %s" % [i + 1, frames[i]["name"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 32)
		if i == selected_frame:
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_pressed_color", Color.WHITE)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			var style := StyleBoxFlat.new()
			style.bg_color = ACTIVE_FRAME_COLOR
			style.set_corner_radius_all(5)
			button.add_theme_stylebox_override("normal", style)
		button.pressed.connect(_select_frame.bind(i))
		frame_list.add_child(button)

func _export_png() -> void:
	_save_current_frame()
	var image := Image.create(EXPORT_SIZE.x, EXPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(CANVAS_COLOR)
	for i in range(parts.size()):
		_raster_line(image, parts[i]["a"], parts[i]["b"], parts[i]["color"], int(LINE_WIDTH))
	if not parts.is_empty():
		_raster_circle(image, Vector2i(roundi(parts[0]["a"].x), roundi(parts[0]["a"].y)), int(HEAD_HANDLE_RADIUS + 3.0), HANDLE_OUTLINE)
		_raster_circle(image, Vector2i(roundi(parts[0]["a"].x), roundi(parts[0]["a"].y)), int(HEAD_HANDLE_RADIUS), HANDLE_COLOR)
	var dir_path := ProjectSettings.globalize_path("res://.tmp")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var export_path := ProjectSettings.globalize_path("res://.tmp/stick_figure_export.png")
	var err: Error = image.save_png(export_path)
	if err == OK:
		export_label.text = "已导出：%s" % export_path
	else:
		export_label.text = "导出失败，错误码：%d" % err

func _raster_line(image: Image, a: Vector2, b: Vector2, color: Color, width: int) -> void:
	var start := Vector2i(roundi(a.x), roundi(a.y))
	var end := Vector2i(roundi(b.x), roundi(b.y))
	var dx: int = abs(end.x - start.x)
	var dy: int = -abs(end.y - start.y)
	var sx: int = 1 if start.x < end.x else -1
	var sy: int = 1 if start.y < end.y else -1
	var err: int = dx + dy
	var point: Vector2i = start
	while true:
		_raster_circle(image, point, width, color)
		if point == end:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			point.x += sx
		if e2 <= dx:
			err += dx
			point.y += sy

func _raster_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	var r2 := radius * radius
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image.get_width():
				continue
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= r2:
				image.set_pixel(x, y, color)

func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment: Vector2 = b - a
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(segment) / length_sq, 0.0, 1.0)
	return point.distance_to(a + segment * t)

func _clamp_to_canvas(pos: Vector2) -> Vector2:
	return Vector2(
		clamp(pos.x, SIDEBAR_WIDTH + 24.0, max(SIDEBAR_WIDTH + 24.0, size.x - 24.0)),
		clamp(pos.y, 24.0, max(24.0, size.y - 24.0))
	)

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
const SIDEBAR_WIDTH := 500.0
const EXPORT_SIZE := Vector2i(960, 720)
const TEXTURE_MANIFEST_PATH := "res://assets/parts/male_tinpet/manifest.json"
const DEFAULT_TEXTURE_DIR := "res://assets/parts/male_tinpet"
const SKIN_ROOT := "res://assets/skins"
const DEFAULT_SKIN_PATH := "res://assets/skins/male_tinpet/skin.json"
const SAVE_PATH := "user://stick_figure_actions.json"
const PART_SLOT_IDS := [
	"head",
	"torso",
	"left_upper_arm",
	"left_forearm",
	"right_upper_arm",
	"right_forearm",
	"left_thigh",
	"left_shin",
	"left_foot",
	"right_thigh",
	"right_shin",
	"right_foot",
	"left_hand",
	"right_hand",
]
const PART_DISPLAY_NAMES := {
	"head": "头部",
	"torso": "躯干",
	"left_upper_arm": "左上臂",
	"left_forearm": "左前臂",
	"right_upper_arm": "右上臂",
	"right_forearm": "右前臂",
	"left_thigh": "左大腿",
	"left_shin": "左小腿",
	"left_foot": "左脚掌",
	"right_thigh": "右大腿",
	"right_shin": "右小腿",
	"right_foot": "右脚掌",
	"left_hand": "左手掌",
	"right_hand": "右手掌",
}

var parts: Array = []
var frames: Array = []
var action_groups: Array = []
var selected_group := 0
var texture_options: Array = []
var texture_cache := {}
var skin_options: Array = []
var current_skin_path := DEFAULT_SKIN_PATH
var current_skin := {}
var lock_first_frame_lengths := false
var locked_part_lengths: Array = []
var selected_part := 0
var selected_frame := 0
var drag_part := -1
var drag_endpoint := -1
var dragging_segment := false
var is_playing := false
var updating_binding_controls := false
var last_mouse := Vector2.ZERO
var canvas_rect := Rect2()

var selected_label: Label
var frame_label: Label
var export_label: Label
var side_panel: PanelContainer
var play_button: Button
var frame_list: VBoxContainer
var playback_timer: Timer
var speed_slider: HSlider
var action_group_picker: OptionButton
var source_group_picker: OptionButton
var skin_picker: OptionButton
var length_lock_button: Button
var bone_picker: OptionButton
var texture_picker: OptionButton
var add_image_button: Button
var clear_image_button: Button
var map_from_first_button: Button
var image_picker_popup: Window
var image_picker_grid: GridContainer
var image_picker_path_edit: LineEdit
var image_picker_folder_dialog: FileDialog
var image_picker_dir := DEFAULT_TEXTURE_DIR
var image_picker_entries: Array = []
var offset_along_spin: SpinBox
var offset_perp_spin: SpinBox
var layer_spin: SpinBox
var opacity_spin: SpinBox
var scale_spin: SpinBox
var rotation_spin: SpinBox
var mirror_check: CheckBox

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_texture_options()
	_load_skin_options()
	_load_skin(current_skin_path)
	_load_project_or_default()
	_center_project_in_demo_area()
	_load_frame(0)
	_build_ui()
	resized.connect(queue_redraw)
	resized.connect(_layout_sidebar)
	queue_redraw()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	side_panel = panel
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(SIDEBAR_WIDTH - 32.0, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(root)

	var title := Label.new()
	title.text = "火柴人动作编辑器"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	frame_label = Label.new()
	frame_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
	root.add_child(frame_label)

	selected_label = Label.new()
	selected_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(selected_label)

	var group_grid := GridContainer.new()
	group_grid.columns = 3
	group_grid.add_theme_constant_override("h_separation", 6)
	group_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(group_grid)

	action_group_picker = OptionButton.new()
	action_group_picker.custom_minimum_size = Vector2(0, 30)
	action_group_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_group_picker.item_selected.connect(_select_action_group)
	group_grid.add_child(action_group_picker)

	var add_group_button := Button.new()
	add_group_button.text = "新建组"
	add_group_button.custom_minimum_size = Vector2(0, 26)
	add_group_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_group_button.pressed.connect(_add_action_group)
	group_grid.add_child(add_group_button)

	var delete_group_button := Button.new()
	delete_group_button.text = "删除组"
	delete_group_button.custom_minimum_size = Vector2(0, 26)
	delete_group_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_group_button.pressed.connect(_delete_action_group)
	group_grid.add_child(delete_group_button)

	bone_picker = OptionButton.new()
	bone_picker.custom_minimum_size = Vector2(0, 32)
	for part in parts:
		bone_picker.add_item(part["name"])
	bone_picker.item_selected.connect(_select_bone_part)
	root.add_child(bone_picker)

	var playback_row := GridContainer.new()
	playback_row.columns = 3
	playback_row.add_theme_constant_override("h_separation", 6)
	playback_row.add_theme_constant_override("v_separation", 4)
	root.add_child(playback_row)

	play_button = Button.new()
	play_button.text = "播放"
	play_button.custom_minimum_size = Vector2(0, 26)
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.pressed.connect(_toggle_playback)
	playback_row.add_child(play_button)

	var prev_button := Button.new()
	prev_button.text = "上一帧"
	prev_button.custom_minimum_size = Vector2(0, 26)
	prev_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_button.pressed.connect(_select_previous_frame)
	playback_row.add_child(prev_button)

	var next_button := Button.new()
	next_button.text = "下一帧"
	next_button.custom_minimum_size = Vector2(0, 26)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var frame_action_grid := GridContainer.new()
	frame_action_grid.columns = 5
	frame_action_grid.add_theme_constant_override("h_separation", 6)
	frame_action_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(frame_action_grid)

	var duplicate_button := Button.new()
	duplicate_button.text = "复制"
	duplicate_button.custom_minimum_size = Vector2(0, 26)
	duplicate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duplicate_button.pressed.connect(_duplicate_frame)
	frame_action_grid.add_child(duplicate_button)

	var add_button := Button.new()
	add_button.text = "新增"
	add_button.custom_minimum_size = Vector2(0, 26)
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.pressed.connect(_add_default_frame)
	frame_action_grid.add_child(add_button)

	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.custom_minimum_size = Vector2(0, 26)
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.pressed.connect(_delete_frame)
	frame_action_grid.add_child(delete_button)

	var reset_button := Button.new()
	reset_button.text = "重置"
	reset_button.custom_minimum_size = Vector2(0, 26)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_reset_current_frame)
	frame_action_grid.add_child(reset_button)

	var export_button := Button.new()
	export_button.text = "导出"
	export_button.custom_minimum_size = Vector2(0, 26)
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(_export_png)
	frame_action_grid.add_child(export_button)

	length_lock_button = Button.new()
	length_lock_button.toggle_mode = true
	length_lock_button.text = "锁定长度"
	length_lock_button.custom_minimum_size = Vector2(0, 26)
	length_lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	length_lock_button.toggled.connect(_toggle_length_lock)
	frame_action_grid.add_child(length_lock_button)

	var binding_title := Label.new()
	binding_title.text = "线条贴图绑定"
	binding_title.add_theme_color_override("font_color", Color.WHITE)
	binding_title.add_theme_font_size_override("font_size", 16)
	root.add_child(binding_title)

	var skin_grid := GridContainer.new()
	skin_grid.columns = 3
	skin_grid.add_theme_constant_override("h_separation", 6)
	skin_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(skin_grid)

	skin_picker = OptionButton.new()
	skin_picker.custom_minimum_size = Vector2(0, 30)
	skin_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_picker.item_selected.connect(_select_skin)
	skin_grid.add_child(skin_picker)

	var apply_skin_button := Button.new()
	apply_skin_button.text = "应用整套"
	apply_skin_button.custom_minimum_size = Vector2(0, 26)
	apply_skin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_skin_button.pressed.connect(_apply_current_skin_to_all_frames)
	skin_grid.add_child(apply_skin_button)

	var apply_part_button := Button.new()
	apply_part_button.text = "应用部件"
	apply_part_button.custom_minimum_size = Vector2(0, 26)
	apply_part_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_part_button.pressed.connect(_apply_current_skin_to_selected_part)
	skin_grid.add_child(apply_part_button)

	texture_picker = OptionButton.new()
	texture_picker.custom_minimum_size = Vector2(0, 32)
	for option in texture_options:
		texture_picker.add_item(option["name"])
	texture_picker.item_selected.connect(_select_binding_texture)
	root.add_child(texture_picker)

	var image_action_grid := GridContainer.new()
	image_action_grid.columns = 3
	image_action_grid.add_theme_constant_override("h_separation", 6)
	image_action_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(image_action_grid)

	add_image_button = Button.new()
	add_image_button.text = "添加图片"
	add_image_button.custom_minimum_size = Vector2(0, 26)
	add_image_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_image_button.pressed.connect(_open_image_file_dialog)
	image_action_grid.add_child(add_image_button)

	clear_image_button = Button.new()
	clear_image_button.text = "清除图片"
	clear_image_button.custom_minimum_size = Vector2(0, 26)
	clear_image_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_image_button.pressed.connect(_clear_selected_texture_option)
	image_action_grid.add_child(clear_image_button)

	map_from_first_button = Button.new()
	map_from_first_button.text = "映射后续"
	map_from_first_button.custom_minimum_size = Vector2(0, 26)
	map_from_first_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_from_first_button.pressed.connect(_map_first_frame_bindings_to_later_frames)
	image_action_grid.add_child(map_from_first_button)

	source_group_picker = OptionButton.new()
	source_group_picker.custom_minimum_size = Vector2(0, 30)
	source_group_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_action_grid.add_child(source_group_picker)

	var copy_source_button := Button.new()
	copy_source_button.text = "复制映射"
	copy_source_button.custom_minimum_size = Vector2(0, 26)
	copy_source_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_source_button.pressed.connect(_copy_first_frame_mapping_from_source_group)
	image_action_grid.add_child(copy_source_button)

	var adjust_grid := GridContainer.new()
	adjust_grid.columns = 3
	adjust_grid.add_theme_constant_override("h_separation", 8)
	adjust_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(adjust_grid)

	offset_along_spin = _make_spin_box(-160.0, 160.0, 1.0)
	offset_along_spin.value_changed.connect(_set_binding_offset_along)
	_add_labeled_control(adjust_grid, "沿线偏移", offset_along_spin)

	offset_perp_spin = _make_spin_box(-160.0, 160.0, 1.0)
	offset_perp_spin.value_changed.connect(_set_binding_offset_perp)
	_add_labeled_control(adjust_grid, "垂直偏移", offset_perp_spin)

	layer_spin = _make_spin_box(-20.0, 20.0, 1.0)
	layer_spin.value_changed.connect(_set_binding_layer)
	_add_labeled_control(adjust_grid, "图层", layer_spin)

	opacity_spin = _make_spin_box(0.15, 1.0, 0.05)
	opacity_spin.value = 0.45
	opacity_spin.value_changed.connect(_set_binding_opacity)
	_add_labeled_control(adjust_grid, "透明度", opacity_spin)

	scale_spin = _make_spin_box(0.1, 4.0, 0.05)
	scale_spin.value = 1.0
	scale_spin.value_changed.connect(_set_binding_scale)
	_add_labeled_control(adjust_grid, "缩放", scale_spin)

	rotation_spin = _make_spin_box(-180.0, 180.0, 1.0)
	rotation_spin.value = 0.0
	rotation_spin.value_changed.connect(_set_binding_rotation)
	_add_labeled_control(adjust_grid, "旋转", rotation_spin)

	mirror_check = CheckBox.new()
	mirror_check.text = "水平镜像"
	mirror_check.toggled.connect(_set_binding_mirror)
	root.add_child(mirror_check)

	var frame_title := Label.new()
	frame_title.text = "动作顺序"
	frame_title.add_theme_color_override("font_color", Color.WHITE)
	frame_title.add_theme_font_size_override("font_size", 16)
	root.add_child(frame_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 56)
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

	_build_image_picker_popup()

	_layout_sidebar()
	_rebuild_skin_picker()
	_rebuild_action_group_pickers()
	_update_ui()

func _make_spin_box(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.custom_minimum_size = Vector2(76, 26)
	return spin

func _add_labeled_control(root: Container, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(56, 0)
	label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)

func _layout_sidebar() -> void:
	if side_panel == null:
		return
	side_panel.size = Vector2(SIDEBAR_WIDTH - 32.0, maxf(120.0, size.y - 32.0))

func _build_image_picker_popup() -> void:
	image_picker_popup = Window.new()
	image_picker_popup.title = "选择图片"
	image_picker_popup.size = Vector2i(640, 420)
	image_picker_popup.unresizable = false
	image_picker_popup.visible = false
	add_child(image_picker_popup)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	image_picker_popup.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title := Label.new()
	title.text = "点击缩略图，直接应用到当前骨骼"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(image_picker_popup.hide)
	header.add_child(close_button)

	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 8)
	root.add_child(path_row)

	image_picker_path_edit = LineEdit.new()
	image_picker_path_edit.text = image_picker_dir
	image_picker_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_picker_path_edit.text_submitted.connect(_set_image_picker_dir)
	path_row.add_child(image_picker_path_edit)

	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.pressed.connect(_refresh_image_picker_dir)
	path_row.add_child(refresh_button)

	var folder_button := Button.new()
	folder_button.text = "选择文件夹"
	folder_button.pressed.connect(_open_image_picker_folder_dialog)
	path_row.add_child(folder_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	image_picker_grid = GridContainer.new()
	image_picker_grid.columns = 5
	image_picker_grid.add_theme_constant_override("h_separation", 10)
	image_picker_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(image_picker_grid)

	image_picker_folder_dialog = FileDialog.new()
	image_picker_folder_dialog.title = "选择图片文件夹"
	image_picker_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	image_picker_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_picker_folder_dialog.dir_selected.connect(_set_image_picker_dir)
	add_child(image_picker_folder_dialog)

func _rebuild_image_picker_grid() -> void:
	if image_picker_grid == null:
		return
	for child in image_picker_grid.get_children():
		child.queue_free()
	image_picker_entries = _scan_image_picker_dir(image_picker_dir)
	if image_picker_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前文件夹没有 PNG/JPG/WebP 图片"
		empty_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
		image_picker_grid.add_child(empty_label)
		return
	for entry in image_picker_entries:
		var path := String(entry.get("path", ""))
		var texture := _get_texture_for_path(path)
		var button := Button.new()
		button.custom_minimum_size = Vector2(112, 116)
		button.text = String(entry.get("name", ""))
		button.clip_text = true
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		if texture != null:
			button.icon = texture
		else:
			button.text = "%s\n加载失败" % String(entry.get("name", ""))
		button.pressed.connect(_pick_image_from_popup.bind(path))
		image_picker_grid.add_child(button)

func _pick_image_from_popup(path: String) -> void:
	_add_custom_texture_option(path)
	if image_picker_popup != null:
		image_picker_popup.hide()

func _scan_image_picker_dir(dir_path: String) -> Array:
	var entries: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return entries
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		var extension := file_name.get_extension().to_lower()
		if not (extension in ["png", "jpg", "jpeg", "webp"]):
			continue
		var path := _join_path(dir_path, file_name)
		entries.append({"name": file_name.get_basename(), "path": path})
	dir.list_dir_end()
	entries.sort_custom(_sort_image_entries)
	return entries

func _sort_image_entries(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0

func _join_path(dir_path: String, file_name: String) -> String:
	var separator := "" if dir_path.ends_with("/") or dir_path.ends_with("\\") else "/"
	return "%s%s%s" % [dir_path, separator, file_name]

func _set_image_picker_dir(dir_path: String) -> void:
	if dir_path.strip_edges() == "":
		return
	image_picker_dir = dir_path.strip_edges()
	if image_picker_path_edit != null:
		image_picker_path_edit.text = image_picker_dir
	_rebuild_image_picker_grid()
	_save_project()

func _refresh_image_picker_dir() -> void:
	if image_picker_path_edit != null:
		_set_image_picker_dir(image_picker_path_edit.text)
	else:
		_rebuild_image_picker_grid()

func _open_image_picker_folder_dialog() -> void:
	if image_picker_folder_dialog == null:
		return
	image_picker_folder_dialog.popup_centered_ratio(0.72)

func _select_bone_part(index: int) -> void:
	if updating_binding_controls:
		return
	if index < 0 or index >= parts.size():
		return
	_save_current_frame()
	selected_part = index
	_update_ui()
	queue_redraw()

func _open_image_file_dialog() -> void:
	if image_picker_popup == null:
		return
	if image_picker_path_edit != null:
		image_picker_path_edit.text = image_picker_dir
	_rebuild_image_picker_grid()
	image_picker_popup.popup_centered()

func _add_custom_texture_option(path: String) -> void:
	var file_name := path.get_file()
	var display_name := file_name.get_basename()
	for i in range(texture_options.size()):
		if String(texture_options[i].get("path", "")) == path:
			_select_texture_option(i)
			if export_label != null:
				export_label.text = "Applied existing image to current bone."
			return
	texture_options.append({"name": display_name, "path": path})
	if texture_picker != null:
		texture_picker.add_item(display_name)
	_select_texture_option(texture_options.size() - 1)
	if export_label != null:
		export_label.text = "Added %s and applied it to the current bone." % display_name

func _select_texture_option(index: int) -> void:
	if texture_picker == null or index < 0 or index >= texture_options.size():
		return
	texture_picker.select(index)
	_apply_selected_texture_to_current_part()
	_update_binding_controls()

func _load_project_or_default() -> void:
	if _load_project():
		return
	action_groups = [_make_action_group("动画组1")]
	selected_group = 0
	frames = action_groups[0]["frames"]
	_save_project()

func _make_action_group(group_name: String) -> Dictionary:
	return {"name": group_name, "frames": [_make_frame("动作 1", _make_default_parts())]}

func _load_project() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var raw := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return false
	action_groups.clear()
	var saved_options = parsed.get("texture_options", [])
	if saved_options is Array and not saved_options.is_empty():
		texture_options.clear()
		for option in saved_options:
			if option is Dictionary:
				texture_options.append({
					"name": String(option.get("name", "")),
					"path": String(option.get("path", "")),
				})
	var groups = parsed.get("action_groups", [])
	if not groups is Array or groups.is_empty():
		return false
	for group in groups:
		if not group is Dictionary:
			continue
		var group_frames: Array = []
		var saved_frames = group.get("frames", [])
		if saved_frames is Array:
			for frame_data in saved_frames:
				if frame_data is Dictionary:
					group_frames.append(_deserialize_frame(frame_data))
		if group_frames.is_empty():
			group_frames.append(_make_frame("动作 1", _make_default_parts()))
		action_groups.append({"name": String(group.get("name", "Action Group %d" % (action_groups.size() + 1))), "frames": group_frames})
	if action_groups.is_empty():
		return false
	selected_group = clampi(int(parsed.get("selected_group", 0)), 0, action_groups.size() - 1)
	current_skin_path = String(parsed.get("current_skin_path", current_skin_path))
	_load_skin(current_skin_path)
	lock_first_frame_lengths = bool(parsed.get("lock_first_frame_lengths", false))
	locked_part_lengths = _deserialize_float_array(parsed.get("locked_part_lengths", []))
	image_picker_dir = String(parsed.get("image_picker_dir", DEFAULT_TEXTURE_DIR))
	frames = action_groups[selected_group]["frames"]
	if lock_first_frame_lengths and locked_part_lengths.is_empty():
		_capture_locked_lengths_from_first_frame()
	return true

func _save_project() -> void:
	if action_groups.is_empty():
		return
	if selected_group >= 0 and selected_group < action_groups.size():
		action_groups[selected_group]["frames"] = _copy_frames(frames)
	var data := {
		"version": 2,
		"selected_group": selected_group,
		"current_skin_path": current_skin_path,
		"lock_first_frame_lengths": lock_first_frame_lengths,
		"locked_part_lengths": locked_part_lengths,
		"image_picker_dir": image_picker_dir,
		"texture_options": texture_options,
		"action_groups": [],
	}
	for group in action_groups:
		var serialized_frames: Array = []
		for frame in group.get("frames", []):
			serialized_frames.append(_serialize_frame(frame))
		data["action_groups"].append({"name": String(group.get("name", "")), "frames": serialized_frames})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func _load_texture_options() -> void:
	texture_options.clear()
	texture_options.append({"name": "No Image", "path": ""})
	var raw := FileAccess.get_file_as_string(TEXTURE_MANIFEST_PATH)
	var parsed = JSON.parse_string(raw)
	if parsed is Array:
		for item in parsed:
			if item is Dictionary and item.has("name") and item.has("file"):
				texture_options.append({
					"name": String(item["name"]),
					"path": "res://%s" % String(item["file"]),
				})
	if texture_options.size() > 1:
		return
	var fallback_names := [
		"head_side",
		"torso_side",
		"upper_arm_tube",
		"forearm_tube",
		"thigh_tube",
		"shin_tube",
		"hand_side",
		"foot_side",
	]
	for texture_name in fallback_names:
		texture_options.append({
			"name": texture_name,
			"path": "res://assets/parts/male_tinpet/%s.png" % texture_name,
		})

func _load_skin_options() -> void:
	skin_options.clear()
	var dir := DirAccess.open(SKIN_ROOT)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if dir.current_is_dir() and not entry.begins_with("."):
				var skin_path := "%s/%s/skin.json" % [SKIN_ROOT, entry]
				if FileAccess.file_exists(skin_path):
					var skin_name := entry
					var raw := FileAccess.get_file_as_string(skin_path)
					var parsed = JSON.parse_string(raw)
					if parsed is Dictionary:
						skin_name = String(parsed.get("display_name", parsed.get("name", entry)))
					skin_options.append({"name": skin_name, "path": skin_path})
			entry = dir.get_next()
		dir.list_dir_end()
	if skin_options.is_empty():
		skin_options.append({"name": "Male Tinpet", "path": DEFAULT_SKIN_PATH})

func _load_skin(path: String) -> bool:
	if path == "":
		path = DEFAULT_SKIN_PATH
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	current_skin_path = path
	current_skin = parsed
	return true

func _rebuild_skin_picker() -> void:
	if skin_picker == null:
		return
	updating_binding_controls = true
	skin_picker.clear()
	var selected_index := 0
	for i in range(skin_options.size()):
		var option: Dictionary = skin_options[i]
		skin_picker.add_item(String(option.get("name", "")))
		if String(option.get("path", "")) == current_skin_path:
			selected_index = i
	if skin_picker.item_count > 0:
		skin_picker.select(selected_index)
	updating_binding_controls = false

func _select_skin(index: int) -> void:
	if updating_binding_controls:
		return
	if index < 0 or index >= skin_options.size():
		return
	var path := String(skin_options[index].get("path", ""))
	if _load_skin(path):
		if export_label != null:
			export_label.text = "Skin selected: %s" % String(skin_options[index].get("name", ""))
		_save_project()

func _apply_current_skin_to_all_frames() -> void:
	if current_skin.is_empty():
		_load_skin(current_skin_path)
	_save_current_frame()
	var applied_count := 0
	for frame in frames:
		var frame_parts: Array = frame.get("parts", [])
		_ensure_required_parts(frame_parts)
		for part_index in range(frame_parts.size()):
			var binding := _binding_from_skin_for_part(frame_parts[part_index], part_index)
			frame_parts[part_index]["binding"] = binding
			if not binding.is_empty():
				applied_count += 1
		frame["parts"] = frame_parts
	_load_frame(selected_frame, false)
	if export_label != null:
		export_label.text = "Applied skin to %d part bindings across %d frames." % [applied_count, frames.size()]
	_save_project()

func _apply_current_skin_to_selected_part() -> void:
	if current_skin.is_empty():
		_load_skin(current_skin_path)
	if selected_part < 0 or selected_part >= parts.size():
		return
	_save_current_frame()
	var current_part: Dictionary = parts[selected_part]
	var slot_id := _part_slot_id(current_part, selected_part)
	var applied_count := 0
	for frame in frames:
		var frame_parts: Array = frame.get("parts", [])
		_ensure_required_parts(frame_parts)
		var target_index := _find_part_index_by_slot_id(frame_parts, slot_id, selected_part)
		if target_index < 0:
			continue
		var binding := _binding_from_skin_for_part(frame_parts[target_index], target_index)
		if binding.is_empty():
			continue
		frame_parts[target_index]["binding"] = binding
		applied_count += 1
		frame["parts"] = frame_parts
	_load_frame(selected_frame, false)
	if export_label != null:
		if applied_count > 0:
			export_label.text = "Applied %s from current skin to %d frames." % [slot_id, applied_count]
		else:
			export_label.text = "Current skin has no usable slot for %s." % slot_id
	_save_project()

func _find_part_index_by_slot_id(frame_parts: Array, slot_id: String, fallback_index: int) -> int:
	for i in range(frame_parts.size()):
		if frame_parts[i] is Dictionary and _part_slot_id(frame_parts[i], i) == slot_id:
			return i
	if fallback_index >= 0 and fallback_index < frame_parts.size():
		return fallback_index
	return -1

func _binding_from_skin_for_part(part: Dictionary, part_index: int) -> Dictionary:
	if current_skin.is_empty():
		return {}
	var slots: Dictionary = current_skin.get("slots", {})
	var slot_id := _part_slot_id(part, part_index)
	if not slots.has(slot_id):
		return {}
	var slot: Dictionary = slots[slot_id]
	var texture_path := _skin_texture_path(slot)
	if texture_path == "":
		return {}
	return {
		"name": String(slot.get("name", texture_path.get_file().get_basename())),
		"path": texture_path,
		"offset": _deserialize_vector2(slot.get("offset", [0.0, 0.0])),
		"layer": int(slot.get("layer", 0)),
		"opacity": float(slot.get("opacity", 0.65)),
		"scale": float(slot.get("scale", 1.0)),
		"rotation": float(slot.get("rotation", 0.0)),
		"mirror": bool(slot.get("mirror", false)),
	}

func _skin_texture_path(slot: Dictionary) -> String:
	var texture := String(slot.get("texture", ""))
	if texture == "":
		return ""
	if texture.begins_with("res://") or texture.begins_with("user://") or texture.is_absolute_path():
		return texture
	var base_dir := String(current_skin.get("base_dir", current_skin_path.get_base_dir()))
	return "%s/%s" % [base_dir.trim_suffix("/"), texture]

func _ensure_part_ids(frame_parts: Array) -> void:
	for i in range(frame_parts.size()):
		if not frame_parts[i] is Dictionary:
			continue
		if String(frame_parts[i].get("id", "")) == "":
			frame_parts[i]["id"] = _part_slot_id(frame_parts[i], i)

func _ensure_required_parts(frame_parts: Array) -> void:
	_ensure_part_ids(frame_parts)
	_apply_standard_part_names(frame_parts)
	_append_missing_hand_part(frame_parts, "left_hand", "left_forearm", "左手掌", Color(0.08, 0.60, 0.56))
	_append_missing_hand_part(frame_parts, "right_hand", "right_forearm", "右手掌", Color(0.76, 0.32, 0.82))
	_ensure_part_ids(frame_parts)
	_apply_standard_part_names(frame_parts)

func _apply_standard_part_names(frame_parts: Array) -> void:
	for i in range(frame_parts.size()):
		if not frame_parts[i] is Dictionary:
			continue
		var slot_id := _part_slot_id(frame_parts[i], i)
		if PART_DISPLAY_NAMES.has(slot_id):
			frame_parts[i]["name"] = String(PART_DISPLAY_NAMES[slot_id])

func _append_missing_hand_part(frame_parts: Array, hand_slot: String, forearm_slot: String, part_name: String, color: Color) -> void:
	if _find_part_index_by_slot_id(frame_parts, hand_slot, -1) >= 0:
		return
	var forearm_index := _find_part_index_by_slot_id(frame_parts, forearm_slot, -1)
	if forearm_index < 0:
		return
	var forearm: Dictionary = frame_parts[forearm_index]
	var wrist: Vector2 = forearm.get("b", Vector2.ZERO)
	var direction: Vector2 = Vector2(forearm.get("b", Vector2.ZERO)) - Vector2(forearm.get("a", Vector2.ZERO))
	if direction.length() <= 0.001:
		direction = Vector2.LEFT if hand_slot == "left_hand" else Vector2.RIGHT
	else:
		direction = direction.normalized()
	var length := 44.0
	var hand := _part(part_name, wrist, wrist + direction * length, color)
	hand["id"] = hand_slot
	hand["joint_a"] = "left_wrist" if hand_slot == "left_hand" else "right_wrist"
	hand["joint_b"] = hand_slot
	frame_parts.append(hand)

func _part_slot_id(part: Dictionary, part_index: int) -> String:
	var saved_id := String(part.get("id", ""))
	if saved_id != "":
		return saved_id
	if part_index >= 0 and part_index < PART_SLOT_IDS.size():
		return String(PART_SLOT_IDS[part_index])
	return String(part.get("name", "part_%d" % part_index))

func _make_default_parts() -> Array:
	var default_parts: Array = [
		_part("头部", Vector2(610, 100), Vector2(610, 158), Color(0.94, 0.25, 0.22)),
		_part("躯干", Vector2(610, 158), Vector2(610, 322), Color(0.12, 0.45, 0.90)),
		_part("左上臂", Vector2(610, 158), Vector2(530, 230), Color(0.10, 0.68, 0.38)),
		_part("左前臂", Vector2(530, 230), Vector2(474, 300), Color(0.13, 0.78, 0.66)),
		_part("右上臂", Vector2(610, 158), Vector2(696, 214), Color(0.62, 0.35, 0.95)),
		_part("右前臂", Vector2(696, 214), Vector2(754, 282), Color(0.82, 0.40, 0.88)),
		_part("左大腿", Vector2(610, 322), Vector2(550, 430), Color(0.97, 0.58, 0.12)),
		_part("左小腿", Vector2(550, 430), Vector2(520, 555), Color(0.96, 0.74, 0.12)),
		_part("左脚掌", Vector2(520, 555), Vector2(455, 575), Color(0.59, 0.43, 0.22)),
		_part("右大腿", Vector2(610, 322), Vector2(680, 424), Color(0.90, 0.18, 0.45)),
		_part("右小腿", Vector2(680, 424), Vector2(726, 540), Color(0.55, 0.22, 0.78)),
		_part("右脚掌", Vector2(726, 540), Vector2(796, 548), Color(0.28, 0.34, 0.42)),
		_part("左手掌", Vector2(474, 300), Vector2(438, 326), Color(0.08, 0.60, 0.56)),
		_part("右手掌", Vector2(754, 282), Vector2(792, 302), Color(0.76, 0.32, 0.82)),
	]
	return _with_default_joints(default_parts)

func _part(part_name: String, a: Vector2, b: Vector2, color: Color) -> Dictionary:
	return {"name": part_name, "a": a, "b": b, "color": color, "joint_a": "", "joint_b": "", "binding": {}}

func _with_default_joints(frame_parts: Array) -> Array:
	var joints := [
		["head_top", "neck"],
		["neck", "pelvis"],
		["neck", "left_elbow"],
		["left_elbow", "left_wrist"],
		["neck", "right_elbow"],
		["right_elbow", "right_wrist"],
		["pelvis", "left_knee"],
		["left_knee", "left_ankle"],
		["left_ankle", "left_toe"],
		["pelvis", "right_knee"],
		["right_knee", "right_ankle"],
		["right_ankle", "right_toe"],
		["left_wrist", "left_hand"],
		["right_wrist", "right_hand"],
	]
	for i in range(mini(frame_parts.size(), joints.size())):
		frame_parts[i]["id"] = String(PART_SLOT_IDS[i])
		frame_parts[i]["joint_a"] = joints[i][0]
		frame_parts[i]["joint_b"] = joints[i][1]
	return frame_parts

func _make_frame(frame_name: String, frame_parts: Array) -> Dictionary:
	_ensure_required_parts(frame_parts)
	return {"name": frame_name, "parts": _copy_parts(frame_parts)}

func _center_project_in_demo_area() -> void:
	var target_center := _demo_area_rect().get_center()
	for group in action_groups:
		var group_frames: Array = group.get("frames", [])
		for frame in group_frames:
			var frame_parts: Array = frame.get("parts", [])
			var bounds := _parts_bounds(frame_parts)
			if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
				continue
			_translate_parts(frame_parts, target_center - bounds.get_center())
	if selected_group >= 0 and selected_group < action_groups.size():
		frames = action_groups[selected_group].get("frames", [])

func _demo_area_rect() -> Rect2:
	var viewport_size := size
	if viewport_size.x <= SIDEBAR_WIDTH or viewport_size.y <= 0.0:
		var project_size := Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
		)
		viewport_size = project_size
	return Rect2(Vector2(SIDEBAR_WIDTH, 0.0), Vector2(maxf(1.0, viewport_size.x - SIDEBAR_WIDTH), maxf(1.0, viewport_size.y)))

func _parts_bounds(frame_parts: Array) -> Rect2:
	if frame_parts.is_empty():
		return Rect2()
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for part in frame_parts:
		for key in ["a", "b"]:
			var point: Vector2 = part[key]
			min_point.x = minf(min_point.x, point.x)
			min_point.y = minf(min_point.y, point.y)
			max_point.x = maxf(max_point.x, point.x)
			max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)

func _translate_parts(frame_parts: Array, delta: Vector2) -> void:
	for part in frame_parts:
		part["a"] = Vector2(part["a"]) + delta
		part["b"] = Vector2(part["b"]) + delta

func _copy_parts(source: Array) -> Array:
	var copied: Array = []
	for i in range(source.size()):
		var source_part = source[i]
		var part: Dictionary = source_part
		var copied_part := _part(part["name"], part["a"], part["b"], part["color"])
		copied_part["id"] = _part_slot_id(part, i)
		copied_part["joint_a"] = part.get("joint_a", "")
		copied_part["joint_b"] = part.get("joint_b", "")
		copied_part["binding"] = _copy_binding(part.get("binding", {}))
		copied.append(copied_part)
	return copied

func _copy_frames(source: Array) -> Array:
	var copied: Array = []
	for frame in source:
		copied.append(_make_frame(String(frame.get("name", "动作 %d" % (copied.size() + 1))), frame.get("parts", [])))
	return copied

func _copy_binding(source) -> Dictionary:
	if not source is Dictionary or source.is_empty():
		return {}
	return {
		"name": String(source.get("name", "")),
		"path": String(source.get("path", "")),
		"offset": source.get("offset", Vector2.ZERO),
		"layer": int(source.get("layer", 0)),
		"opacity": float(source.get("opacity", 0.45)),
		"scale": float(source.get("scale", 1.0)),
		"rotation": float(source.get("rotation", 0.0)),
		"mirror": bool(source.get("mirror", false)),
	}

func _serialize_frame(frame: Dictionary) -> Dictionary:
	var serialized_parts: Array = []
	for part in frame.get("parts", []):
		serialized_parts.append(_serialize_part(part))
	return {"name": String(frame.get("name", "")), "parts": serialized_parts}

func _deserialize_frame(frame_data: Dictionary) -> Dictionary:
	var frame_parts: Array = []
	var saved_parts = frame_data.get("parts", [])
	if saved_parts is Array:
		for part_data in saved_parts:
			if part_data is Dictionary:
				frame_parts.append(_deserialize_part(part_data))
	_ensure_required_parts(frame_parts)
	return {"name": String(frame_data.get("name", "动作 1")), "parts": _copy_parts(frame_parts)}

func _serialize_part(part: Dictionary) -> Dictionary:
	return {
		"id": _part_slot_id(part, -1),
		"name": String(part.get("name", "")),
		"a": _serialize_vector2(part.get("a", Vector2.ZERO)),
		"b": _serialize_vector2(part.get("b", Vector2.ZERO)),
		"color": _serialize_color(part.get("color", Color.WHITE)),
		"joint_a": String(part.get("joint_a", "")),
		"joint_b": String(part.get("joint_b", "")),
		"binding": _serialize_binding(part.get("binding", {})),
	}

func _deserialize_part(part_data: Dictionary) -> Dictionary:
	var part := _part(
		String(part_data.get("name", "")),
		_deserialize_vector2(part_data.get("a", [0.0, 0.0])),
		_deserialize_vector2(part_data.get("b", [0.0, 0.0])),
		_deserialize_color(part_data.get("color", [1.0, 1.0, 1.0, 1.0]))
	)
	part["id"] = String(part_data.get("id", ""))
	part["joint_a"] = String(part_data.get("joint_a", ""))
	part["joint_b"] = String(part_data.get("joint_b", ""))
	part["binding"] = _deserialize_binding(part_data.get("binding", {}))
	return part

func _serialize_binding(binding) -> Dictionary:
	if not binding is Dictionary or binding.is_empty():
		return {}
	var copied := _copy_binding(binding)
	copied["offset"] = _serialize_vector2(copied.get("offset", Vector2.ZERO))
	return copied

func _deserialize_binding(binding_data) -> Dictionary:
	if not binding_data is Dictionary or binding_data.is_empty():
		return {}
	var copied := _copy_binding(binding_data)
	copied["offset"] = _deserialize_vector2(binding_data.get("offset", [0.0, 0.0]))
	return copied

func _serialize_vector2(value) -> Array:
	var vector: Vector2 = value
	return [vector.x, vector.y]

func _deserialize_vector2(value) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _deserialize_float_array(value) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(float(item))
	return result

func _serialize_color(value) -> Array:
	var color: Color = value
	return [color.r, color.g, color.b, color.a]

func _deserialize_color(value) -> Color:
	if value is Array and value.size() >= 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Color.WHITE

func _save_current_frame() -> void:
	if selected_frame < 0 or selected_frame >= frames.size():
		return
	_ensure_required_parts(parts)
	if selected_frame > 0 or lock_first_frame_lengths:
		_normalize_parts_to_first_lengths(parts)
	frames[selected_frame]["parts"] = _copy_parts(parts)
	if selected_group >= 0 and selected_group < action_groups.size():
		action_groups[selected_group]["frames"] = _copy_frames(frames)

func _load_frame(index: int, save_previous := true) -> void:
	if save_previous and selected_frame >= 0 and selected_frame < frames.size() and not parts.is_empty():
		_save_current_frame()
	selected_frame = clampi(index, 0, frames.size() - 1)
	if selected_frame > 0:
		_normalize_frame_to_first_lengths(frames[selected_frame])
	parts = _copy_parts(frames[selected_frame]["parts"])
	_ensure_required_parts(parts)
	selected_part = clampi(selected_part, 0, parts.size() - 1)
	_rebuild_bone_picker()
	_update_ui()
	queue_redraw()

func _select_frame(index: int) -> void:
	_load_frame(index)

func _select_action_group(index: int) -> void:
	if updating_binding_controls:
		return
	if index < 0 or index >= action_groups.size():
		return
	_save_current_frame()
	selected_group = index
	frames = _copy_frames(action_groups[selected_group].get("frames", []))
	selected_frame = 0
	selected_part = 0
	_load_frame(0, false)
	if lock_first_frame_lengths:
		_capture_locked_lengths_from_first_frame()
	_rebuild_action_group_pickers()
	_save_project()

func _add_action_group() -> void:
	_save_current_frame()
	var group_name := "动画组%d" % (action_groups.size() + 1)
	action_groups.append(_make_action_group(group_name))
	selected_group = action_groups.size() - 1
	frames = _copy_frames(action_groups[selected_group]["frames"])
	selected_frame = 0
	selected_part = 0
	_load_frame(0, false)
	if lock_first_frame_lengths:
		_capture_locked_lengths_from_first_frame()
	_rebuild_action_group_pickers()
	_save_project()

func _delete_action_group() -> void:
	if action_groups.size() <= 1:
		frames = _make_action_group("动画组1")["frames"]
		action_groups[0]["frames"] = _copy_frames(frames)
		selected_group = 0
		_load_frame(0, false)
		_rebuild_action_group_pickers()
		_save_project()
		return
	action_groups.remove_at(selected_group)
	selected_group = clampi(selected_group, 0, action_groups.size() - 1)
	frames = _copy_frames(action_groups[selected_group].get("frames", []))
	selected_frame = 0
	selected_part = 0
	_load_frame(0, false)
	if lock_first_frame_lengths:
		_capture_locked_lengths_from_first_frame()
	_rebuild_action_group_pickers()
	_save_project()

func _select_previous_frame() -> void:
	_select_frame((selected_frame - 1 + frames.size()) % frames.size())

func _select_next_frame() -> void:
	_select_frame((selected_frame + 1) % frames.size())

func _duplicate_frame() -> void:
	_save_current_frame()
	var insert_at := selected_frame + 1
	frames.insert(insert_at, _make_frame("动作 %d" % (frames.size() + 1), parts))
	_load_frame(insert_at)
	_save_project()

func _add_default_frame() -> void:
	_save_current_frame()
	frames.append(_make_frame("动作 %d" % (frames.size() + 1), _make_default_parts()))
	_load_frame(frames.size() - 1)
	_save_project()

func _delete_frame() -> void:
	if frames.size() <= 1:
		_reset_current_frame()
		return
	frames.remove_at(selected_frame)
	_load_frame(mini(selected_frame, frames.size() - 1))
	_save_project()

func _reset_current_frame() -> void:
	parts = _make_default_parts()
	_save_current_frame()
	selected_part = 0
	_update_ui()
	queue_redraw()
	_save_project()

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

func _toggle_length_lock(enabled: bool) -> void:
	if updating_binding_controls:
		return
	_save_current_frame()
	lock_first_frame_lengths = enabled
	if lock_first_frame_lengths:
		_capture_locked_lengths_from_first_frame()
		_normalize_parts_to_first_lengths(parts, selected_part)
		_save_current_frame()
		if export_label != null:
			export_label.text = "Initial-frame bone lengths locked. Dragging endpoints now changes direction only."
	else:
		if export_label != null:
			export_label.text = "Initial-frame bone lengths unlocked."
	_update_ui()
	queue_redraw()
	_save_project()

func _capture_locked_lengths_from_first_frame() -> void:
	locked_part_lengths.clear()
	if frames.is_empty():
		return
	var template_parts: Array = frames[0].get("parts", [])
	for part in template_parts:
		if part is Dictionary:
			locked_part_lengths.append(Vector2(part.get("a", Vector2.ZERO)).distance_to(Vector2(part.get("b", Vector2.ZERO))))

func _locked_length_for_part(part_index: int) -> float:
	if not lock_first_frame_lengths:
		return 0.0
	if part_index < 0 or part_index >= locked_part_lengths.size():
		return 0.0
	return float(locked_part_lengths[part_index])

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
		_move_endpoint_group_to(drag_part, 0, _constrain_endpoint_to_first_length(drag_part, 0, clamped))
	elif drag_endpoint == 1:
		_move_endpoint_group_to(drag_part, 1, _constrain_endpoint_to_first_length(drag_part, 1, clamped))
	if selected_frame > 0 or lock_first_frame_lengths:
		_normalize_parts_to_first_lengths(parts, drag_part)
	_save_current_frame()
	_update_ui()
	queue_redraw()
	_save_project()

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
	_draw_bound_textures(-1000000, -1)
	for i in range(parts.size()):
		var color: Color = parts[i]["color"]
		var width := LINE_WIDTH
		if i == selected_part and not is_playing:
			draw_line(parts[i]["a"], parts[i]["b"], Color(0.06, 0.07, 0.09), LINE_WIDTH + 5.0, true)
			width = LINE_WIDTH + 1.5
		draw_line(parts[i]["a"], parts[i]["b"], color, width, true)

	_draw_head_marker()
	_draw_bound_textures(0, 1000000)

	if is_playing:
		return
	for i in range(parts.size()):
		_draw_handle(parts[i]["a"], i == selected_part, _is_head_top_endpoint(i, 0))
		_draw_handle(parts[i]["b"], i == selected_part, _is_head_top_endpoint(i, 1))

func _draw_bound_textures(min_layer: int, max_layer: int) -> void:
	var entries: Array = []
	for i in range(parts.size()):
		var binding: Dictionary = parts[i].get("binding", {})
		if binding.is_empty():
			continue
		var layer := int(binding.get("layer", 0))
		if layer < min_layer or layer > max_layer:
			continue
		entries.append({"part_index": i, "layer": layer})
	entries.sort_custom(_sort_texture_entries)
	for entry in entries:
		_draw_part_texture(entry["part_index"])

func _sort_texture_entries(a: Dictionary, b: Dictionary) -> bool:
	if int(a["layer"]) == int(b["layer"]):
		return int(a["part_index"]) < int(b["part_index"])
	return int(a["layer"]) < int(b["layer"])

func _draw_part_texture(part_index: int) -> void:
	if part_index < 0 or part_index >= parts.size():
		return
	var part: Dictionary = parts[part_index]
	var binding: Dictionary = part.get("binding", {})
	var texture := _get_bound_texture(binding)
	if texture == null:
		return
	var a: Vector2 = part["a"]
	var b: Vector2 = part["b"]
	var segment := b - a
	var length := segment.length()
	if length <= 0.1:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var offset: Vector2 = binding.get("offset", Vector2.ZERO)
	var modulate := Color(1.0, 1.0, 1.0, clampf(float(binding.get("opacity", 0.45)), 0.15, 1.0))
	var manual_scale := maxf(0.1, float(binding.get("scale", 1.0)))
	var manual_rotation := deg_to_rad(float(binding.get("rotation", 0.0)))
	var transform_scale := Vector2(-1.0, 1.0) if bool(binding.get("mirror", false)) else Vector2.ONE
	var midpoint := (a + b) * 0.5
	var angle := segment.angle() + manual_rotation
	if texture_size.x >= texture_size.y:
		var draw_length := length * manual_scale
		var height := maxf(8.0, draw_length * texture_size.y / texture_size.x)
		var rect := Rect2(Vector2(-draw_length * 0.5 + offset.x, -height * 0.5 + offset.y), Vector2(draw_length, height))
		draw_set_transform(midpoint, angle, transform_scale)
		draw_texture_rect(texture, rect, false, modulate)
	else:
		var draw_length := length * manual_scale
		var width := maxf(8.0, draw_length * texture_size.x / texture_size.y)
		var rect := Rect2(Vector2(-width * 0.5 + offset.y, -draw_length * 0.5 + offset.x), Vector2(width, draw_length))
		draw_set_transform(midpoint, angle - PI * 0.5, transform_scale)
		draw_texture_rect(texture, rect, false, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _get_bound_texture(binding: Dictionary) -> Texture2D:
	var path := String(binding.get("path", ""))
	return _get_texture_for_path(path)

func _get_texture_for_path(path: String) -> Texture2D:
	if path == "":
		return null
	if not texture_cache.has(path):
		var texture: Texture2D = null
		var image_path := path
		if path.begins_with("res://") or path.begins_with("user://"):
			image_path = ProjectSettings.globalize_path(path)
		var image := Image.new()
		if image.load(image_path) == OK:
			texture = ImageTexture.create_from_image(image)
		texture_cache[path] = texture
	return texture_cache[path]

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

func _constrain_endpoint_to_first_length(part_index: int, endpoint: int, target: Vector2) -> Vector2:
	if selected_frame <= 0 and not lock_first_frame_lengths:
		return target
	var template_length := _first_frame_part_length(part_index)
	if template_length <= 0.001:
		return target
	var anchor := _endpoint_position(part_index, 1 - endpoint)
	var direction := target - anchor
	if direction.length() <= 0.001:
		direction = _first_frame_part_direction(part_index)
		if endpoint == 0:
			direction = -direction
	else:
		direction = direction.normalized()
	return _clamp_to_canvas(anchor + direction * template_length)

func _normalize_frame_to_first_lengths(frame: Dictionary) -> void:
	var frame_parts: Array = frame.get("parts", [])
	_normalize_parts_to_first_lengths(frame_parts)
	frame["parts"] = frame_parts

func _normalize_parts_to_first_lengths(frame_parts: Array, priority_part := -1) -> void:
	if frame_parts.is_empty() or frames.is_empty():
		return
	if priority_part >= 0 and priority_part < frame_parts.size():
		_normalize_part_to_first_length(frame_parts, priority_part)
	for i in range(frame_parts.size()):
		if i == priority_part:
			continue
		_normalize_part_to_first_length(frame_parts, i)

func _normalize_part_to_first_length(frame_parts: Array, part_index: int) -> void:
	if part_index < 0 or part_index >= frame_parts.size():
		return
	var template_length := _first_frame_part_length(part_index)
	if template_length <= 0.001:
		return
	var a: Vector2 = frame_parts[part_index]["a"]
	var b: Vector2 = frame_parts[part_index]["b"]
	var direction := b - a
	if direction.length() <= 0.001:
		direction = _first_frame_part_direction(part_index)
	else:
		direction = direction.normalized()
	var target_b := _clamp_to_canvas(a + direction * template_length)
	var joint_b := String(frame_parts[part_index].get("joint_b", ""))
	if joint_b == "":
		frame_parts[part_index]["b"] = target_b
		return
	for i in range(frame_parts.size()):
		if String(frame_parts[i].get("joint_a", "")) == joint_b:
			frame_parts[i]["a"] = target_b
		if String(frame_parts[i].get("joint_b", "")) == joint_b:
			frame_parts[i]["b"] = target_b

func _first_frame_part_length(part_index: int) -> float:
	var locked_length := _locked_length_for_part(part_index)
	if locked_length > 0.001:
		return locked_length
	if frames.is_empty():
		return 0.0
	var template_parts: Array = frames[0].get("parts", [])
	if part_index < 0 or part_index >= template_parts.size():
		return 0.0
	return template_parts[part_index]["a"].distance_to(template_parts[part_index]["b"])

func _first_frame_part_direction(part_index: int) -> Vector2:
	if frames.is_empty():
		return Vector2.RIGHT
	var template_parts: Array = frames[0].get("parts", [])
	if part_index < 0 or part_index >= template_parts.size():
		return Vector2.RIGHT
	var direction: Vector2 = template_parts[part_index]["b"] - template_parts[part_index]["a"]
	if direction.length() <= 0.001:
		return Vector2.RIGHT
	return direction.normalized()

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
		frame_label.text = "Frame %d / %d" % [selected_frame + 1, frames.size()]
	if length_lock_button != null:
		updating_binding_controls = true
		length_lock_button.button_pressed = lock_first_frame_lengths
		length_lock_button.text = "长度已锁定" if lock_first_frame_lengths else "锁定长度"
		updating_binding_controls = false
	if selected_label != null and not parts.is_empty():
		var part: Dictionary = parts[selected_part]
		var length: float = part["a"].distance_to(part["b"])
		var binding: Dictionary = part.get("binding", {})
		var binding_name := "Unbound" if binding.is_empty() else String(binding.get("name", ""))
		selected_label.text = "Current part: %s  Length: %d px\nTexture: %s" % [part["name"], int(round(length)), binding_name]
	_update_binding_controls()
	_rebuild_frame_list()

func _update_binding_controls() -> void:
	if texture_picker == null or parts.is_empty():
		return
	updating_binding_controls = true
	if bone_picker != null and bone_picker.item_count == parts.size():
		bone_picker.select(selected_part)
	var part: Dictionary = parts[selected_part]
	var binding: Dictionary = part.get("binding", {})
	if not binding.is_empty():
		var selected_texture := String(binding.get("name", ""))
		var selected_index := texture_picker.selected
		for i in range(texture_options.size()):
			if String(texture_options[i]["name"]) == selected_texture:
				selected_index = i
				break
		if texture_picker.item_count > 0 and selected_index >= 0:
			texture_picker.select(selected_index)
	var has_binding := not binding.is_empty()
	var selected_path := _selected_texture_path()
	if clear_image_button != null:
		clear_image_button.disabled = selected_path == ""
	if offset_along_spin != null:
		offset_along_spin.editable = has_binding
		offset_along_spin.value = float(binding.get("offset", Vector2.ZERO).x)
	if offset_perp_spin != null:
		offset_perp_spin.editable = has_binding
		offset_perp_spin.value = float(binding.get("offset", Vector2.ZERO).y)
	if layer_spin != null:
		layer_spin.editable = has_binding
		layer_spin.value = float(binding.get("layer", 0))
	if opacity_spin != null:
		opacity_spin.editable = has_binding
		opacity_spin.value = float(binding.get("opacity", 0.45))
	if scale_spin != null:
		scale_spin.editable = has_binding
		scale_spin.value = float(binding.get("scale", 1.0))
	if rotation_spin != null:
		rotation_spin.editable = has_binding
		rotation_spin.value = float(binding.get("rotation", 0.0))
	if mirror_check != null:
		mirror_check.disabled = not has_binding
		mirror_check.button_pressed = bool(binding.get("mirror", false))
	updating_binding_controls = false

func _rebuild_bone_picker() -> void:
	if bone_picker == null:
		return
	updating_binding_controls = true
	bone_picker.clear()
	for part in parts:
		bone_picker.add_item(part["name"])
	if not parts.is_empty():
		bone_picker.select(clampi(selected_part, 0, parts.size() - 1))
	updating_binding_controls = false

func _rebuild_action_group_pickers() -> void:
	updating_binding_controls = true
	if action_group_picker != null:
		action_group_picker.clear()
		for group in action_groups:
			action_group_picker.add_item(String(group.get("name", "")))
		if not action_groups.is_empty():
			action_group_picker.select(clampi(selected_group, 0, action_groups.size() - 1))
	if source_group_picker != null:
		source_group_picker.clear()
		for group in action_groups:
			source_group_picker.add_item(String(group.get("name", "")))
		if not action_groups.is_empty():
			source_group_picker.select(0)
	updating_binding_controls = false

func _select_binding_texture(_index: int) -> void:
	if updating_binding_controls:
		return
	_select_texture_option(_index)

func _apply_selected_texture_to_current_part() -> void:
	if texture_picker == null or texture_options.is_empty():
		return
	if selected_part < 0 or selected_part >= parts.size():
		return
	var index := clampi(texture_picker.selected, 0, texture_options.size() - 1)
	var option: Dictionary = texture_options[index]
	if String(option.get("path", "")) == "":
		_clear_current_part_texture()
		return
	var old_binding: Dictionary = parts[selected_part].get("binding", {})
	parts[selected_part]["binding"] = {
		"name": option["name"],
		"path": option["path"],
		"offset": old_binding.get("offset", Vector2.ZERO),
		"layer": int(old_binding.get("layer", 0)),
		"opacity": float(old_binding.get("opacity", 0.45)),
		"scale": float(old_binding.get("scale", 1.0)),
		"rotation": float(old_binding.get("rotation", 0.0)),
		"mirror": bool(old_binding.get("mirror", false)),
	}
	_save_current_frame()
	_update_ui()
	queue_redraw()
	_save_project()

func _clear_current_part_texture() -> void:
	if selected_part < 0 or selected_part >= parts.size():
		return
	parts[selected_part]["binding"] = {}
	_save_current_frame()
	_update_ui()
	queue_redraw()

func _clear_selected_texture_option() -> void:
	if texture_picker == null or texture_options.is_empty():
		return
	var index := texture_picker.selected
	if index <= 0 or index >= texture_options.size():
		return
	var path := String(texture_options[index].get("path", ""))
	texture_options.remove_at(index)
	texture_picker.remove_item(index)
	_clear_bindings_for_texture_path(path)
	texture_picker.select(0)
	_load_frame(selected_frame, false)
	if export_label != null:
		export_label.text = "Removed image and cleared bindings that used it."
	_save_project()

func _clear_bindings_for_texture_path(path: String) -> void:
	if path == "":
		return
	for frame in frames:
		var frame_parts: Array = frame.get("parts", [])
		for part in frame_parts:
			var binding: Dictionary = part.get("binding", {})
			if String(binding.get("path", "")) == path:
				part["binding"] = {}
		frame["parts"] = frame_parts
	for part in parts:
		var binding: Dictionary = part.get("binding", {})
		if String(binding.get("path", "")) == path:
			part["binding"] = {}

func _selected_texture_path() -> String:
	if texture_picker == null or texture_options.is_empty():
		return ""
	var index := texture_picker.selected
	if index < 0 or index >= texture_options.size():
		return ""
	return String(texture_options[index].get("path", ""))

func _map_first_frame_bindings_to_later_frames() -> void:
	_save_current_frame()
	if frames.size() <= 1:
		if export_label != null:
			export_label.text = "Only one frame exists; there are no later frames to map."
		return
	var template_parts: Array = frames[0].get("parts", [])
	var mapped_count := 0
	for frame_index in range(1, frames.size()):
		var frame_parts: Array = frames[frame_index].get("parts", [])
		for part_index in range(mini(template_parts.size(), frame_parts.size())):
			var template_binding: Dictionary = template_parts[part_index].get("binding", {})
			frame_parts[part_index]["binding"] = _copy_binding(template_binding)
			if not template_binding.is_empty():
				mapped_count += 1
		_normalize_parts_to_first_lengths(frame_parts)
		frames[frame_index]["parts"] = frame_parts
	_load_frame(selected_frame, false)
	if export_label != null:
		export_label.text = "Mapped first-frame texture bindings to %d later frames (%d bindings)." % [frames.size() - 1, mapped_count]
	_save_project()

func _copy_first_frame_mapping_from_source_group() -> void:
	if source_group_picker == null or action_groups.is_empty():
		return
	var source_index := source_group_picker.selected
	if source_index < 0 or source_index >= action_groups.size():
		return
	_save_current_frame()
	var source_frames: Array = action_groups[source_index].get("frames", [])
	if source_frames.is_empty() or frames.is_empty():
		return
	var source_parts: Array = source_frames[0].get("parts", [])
	var target_parts: Array = frames[0].get("parts", [])
	var copied_count := 0
	for part_index in range(mini(source_parts.size(), target_parts.size())):
		var source_binding: Dictionary = source_parts[part_index].get("binding", {})
		target_parts[part_index]["binding"] = _copy_binding(source_binding)
		if not source_binding.is_empty():
			copied_count += 1
	frames[0]["parts"] = target_parts
	for frame_index in range(1, frames.size()):
		var frame_parts: Array = frames[frame_index].get("parts", [])
		for part_index in range(mini(source_parts.size(), frame_parts.size())):
			frame_parts[part_index]["binding"] = _copy_binding(source_parts[part_index].get("binding", {}))
		frames[frame_index]["parts"] = frame_parts
	_load_frame(selected_frame, false)
	if export_label != null:
		export_label.text = "Copied %d texture bindings from %s." % [copied_count, String(action_groups[source_index].get("name", ""))]
	_save_project()

func _set_binding_offset_along(value: float) -> void:
	_set_binding_offset(Vector2(value, _current_binding_offset().y))

func _set_binding_offset_perp(value: float) -> void:
	_set_binding_offset(Vector2(_current_binding_offset().x, value))

func _set_binding_offset(offset: Vector2) -> void:
	if updating_binding_controls or selected_part < 0 or selected_part >= parts.size():
		return
	var binding: Dictionary = parts[selected_part].get("binding", {})
	if binding.is_empty():
		return
	binding["offset"] = offset
	parts[selected_part]["binding"] = binding
	_save_current_frame()
	queue_redraw()
	_save_project()

func _current_binding_offset() -> Vector2:
	if selected_part < 0 or selected_part >= parts.size():
		return Vector2.ZERO
	var binding: Dictionary = parts[selected_part].get("binding", {})
	return binding.get("offset", Vector2.ZERO)

func _set_binding_layer(value: float) -> void:
	if updating_binding_controls or selected_part < 0 or selected_part >= parts.size():
		return
	var binding: Dictionary = parts[selected_part].get("binding", {})
	if binding.is_empty():
		return
	binding["layer"] = int(round(value))
	parts[selected_part]["binding"] = binding
	_save_current_frame()
	queue_redraw()
	_save_project()

func _set_binding_opacity(value: float) -> void:
	if updating_binding_controls or selected_part < 0 or selected_part >= parts.size():
		return
	var binding: Dictionary = parts[selected_part].get("binding", {})
	if binding.is_empty():
		return
	binding["opacity"] = clampf(value, 0.15, 1.0)
	parts[selected_part]["binding"] = binding
	_save_current_frame()
	queue_redraw()
	_save_project()

func _set_binding_scale(value: float) -> void:
	if updating_binding_controls or selected_part < 0 or selected_part >= parts.size():
		return
	var binding: Dictionary = parts[selected_part].get("binding", {})
	if binding.is_empty():
		return
	binding["scale"] = clampf(value, 0.1, 4.0)
	parts[selected_part]["binding"] = binding
	_save_current_frame()
	queue_redraw()
	_save_project()

func _set_binding_rotation(value: float) -> void:
	if updating_binding_controls or selected_part < 0 or selected_part >= parts.size():
		return
	var binding: Dictionary = parts[selected_part].get("binding", {})
	if binding.is_empty():
		return
	binding["rotation"] = clampf(value, -180.0, 180.0)
	parts[selected_part]["binding"] = binding
	_save_current_frame()
	queue_redraw()
	_save_project()

func _set_binding_mirror(value: bool) -> void:
	if updating_binding_controls or selected_part < 0 or selected_part >= parts.size():
		return
	var binding: Dictionary = parts[selected_part].get("binding", {})
	if binding.is_empty():
		return
	binding["mirror"] = value
	parts[selected_part]["binding"] = binding
	_save_current_frame()
	queue_redraw()
	_save_project()

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


extends Control

const REF_SHEET_PATH := "res://assets/animation/male_tinpet_walk_10f_v1.png"
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"
const USER_POSES_PATH := "user://walk_ref_part_poses.json"
const PART_DIR := "res://assets/parts/male_tinpet/"
const DISPLAY_Z_BASE := 200

const PARTS := [
	{"name": "far_thigh_mesh", "file": "thigh_tube.png", "from": "hip", "to": "far_knee", "z": -80},
	{"name": "far_shin_mesh", "file": "shin_tube.png", "from": "far_knee", "to": "far_ankle", "z": -79},
	{"name": "far_knee_mesh", "file": "knee_joint.png", "point": "far_knee", "z": -78},
	{"name": "far_ankle_mesh", "file": "ankle_joint.png", "point": "far_ankle", "z": -77},
	{"name": "far_foot_mesh", "file": "foot_side.png", "from": "far_ankle", "to": "far_toe", "z": -76},
	{"name": "far_upper_arm_mesh", "file": "upper_arm_tube.png", "from": "shoulder", "to": "elbow", "z": -60},
	{"name": "far_forearm_mesh", "file": "forearm_tube.png", "from": "elbow", "to": "wrist", "z": -59},
	{"name": "far_shoulder_mesh", "file": "shoulder_joint.png", "point": "shoulder", "z": -58},
	{"name": "far_hand_mesh", "file": "hand_side.png", "from": "wrist", "to": "hand", "z": -57},
	{"name": "torso_mesh", "file": "torso_side.png", "from": "hip", "to": "neck", "z": 0},
	{"name": "head_mesh", "file": "head_side.png", "from": "neck", "to": "head", "z": 30},
	{"name": "near_thigh_mesh", "file": "thigh_tube.png", "from": "hip", "to": "near_knee", "z": 40},
	{"name": "near_shin_mesh", "file": "shin_tube.png", "from": "near_knee", "to": "near_ankle", "z": 41},
	{"name": "near_knee_mesh", "file": "knee_joint.png", "point": "near_knee", "z": 42},
	{"name": "near_ankle_mesh", "file": "ankle_joint.png", "point": "near_ankle", "z": 43},
	{"name": "near_foot_mesh", "file": "foot_side.png", "from": "near_ankle", "to": "near_toe", "z": 44},
	{"name": "near_upper_arm_mesh", "file": "upper_arm_tube.png", "from": "shoulder", "to": "elbow", "z": 60},
	{"name": "near_forearm_mesh", "file": "forearm_tube.png", "from": "elbow", "to": "wrist", "z": 61},
	{"name": "near_shoulder_mesh", "file": "shoulder_joint.png", "point": "shoulder", "z": 62},
	{"name": "near_hand_mesh", "file": "hand_side.png", "from": "wrist", "to": "hand", "z": 63},
]

var ref_sheet: Image
var ref_texture: ImageTexture
var frame_rect := TextureRect.new()
var toolbar := HBoxContainer.new()
var frame_label := Label.new()
var part_select := OptionButton.new()
var status_label := Label.new()
var sprites := {}
var pose_data := {"version": 1, "source": REF_SHEET_PATH, "frames": []}
var ref_points: Array = []
var frame_index := 0
var selected_part := "torso_mesh"
var dragging := false
var last_mouse := Vector2.ZERO
var ref_origin := Vector2(24, 74)
var ref_scale := 1.0
var cell_size := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_reference_assets()
	_build_ui()
	_load_pose_data()
	_create_part_sprites()
	_show_frame(0)
	resized.connect(_layout)
	_layout()

func _build_ui() -> void:
	toolbar.position = Vector2(18, 16)
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	var prev_button := Button.new()
	prev_button.text = "<"
	prev_button.custom_minimum_size = Vector2(38, 34)
	prev_button.pressed.connect(func(): _show_frame(frame_index - 1))
	toolbar.add_child(prev_button)

	var next_button := Button.new()
	next_button.text = ">"
	next_button.custom_minimum_size = Vector2(38, 34)
	next_button.pressed.connect(func(): _show_frame(frame_index + 1))
	toolbar.add_child(next_button)

	frame_label.custom_minimum_size = Vector2(84, 34)
	toolbar.add_child(frame_label)

	for part in PARTS:
		part_select.add_item(part["name"])
	part_select.selected = _part_index(selected_part)
	part_select.item_selected.connect(func(index: int): _select_part(part_select.get_item_text(index)))
	part_select.custom_minimum_size = Vector2(210, 34)
	toolbar.add_child(part_select)

	var reset_button := Button.new()
	reset_button.text = "重置本帧"
	reset_button.custom_minimum_size = Vector2(92, 34)
	reset_button.pressed.connect(_reset_current_frame)
	toolbar.add_child(reset_button)

	var save_button := Button.new()
	save_button.text = "保存校准"
	save_button.custom_minimum_size = Vector2(92, 34)
	save_button.pressed.connect(_save_pose_data)
	toolbar.add_child(save_button)

	status_label.position = Vector2(18, 54)
	status_label.custom_minimum_size = Vector2(760, 24)
	add_child(status_label)

	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_rect)

func _load_reference_assets() -> void:
	ref_sheet = Image.new()
	if ref_sheet.load(REF_SHEET_PATH) != OK:
		push_error("Could not load reference sheet.")
		ref_sheet = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	cell_size = Vector2(ref_sheet.get_width() / 10, ref_sheet.get_height())
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REF_POINTS_PATH))
	if parsed is Dictionary and parsed.has("frames") and parsed["frames"] is Array:
		ref_points = parsed["frames"]

func _load_pose_data() -> void:
	if FileAccess.file_exists(USER_POSES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(USER_POSES_PATH))
		if parsed is Dictionary and parsed.has("frames"):
			pose_data = parsed
	_ensure_pose_frames()

func _ensure_pose_frames() -> void:
	if not pose_data.has("frames") or not (pose_data["frames"] is Array):
		pose_data["frames"] = []
	var frames: Array = pose_data["frames"]
	while frames.size() < 10:
		frames.append({"parts": {}})
	for i in range(10):
		if not (frames[i] is Dictionary):
			frames[i] = {"parts": {}}
		if not frames[i].has("parts"):
			frames[i]["parts"] = {}

func _create_part_sprites() -> void:
	for part in PARTS:
		var sprite := Sprite2D.new()
		sprite.texture = _load_texture(PART_DIR + part["file"])
		sprite.centered = true
		sprite.z_as_relative = false
		sprite.z_index = DISPLAY_Z_BASE + int(part["z"])
		if String(part["name"]).begins_with("far"):
			sprite.modulate.a = 0.58
		add_child(sprite)
		sprites[part["name"]] = sprite

func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_error("Could not load part texture: %s" % path)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)

func _layout() -> void:
	var available := Vector2(max(1.0, size.x - 48.0), max(1.0, size.y - 98.0))
	ref_scale = min(available.x / max(1.0, cell_size.x), available.y / max(1.0, cell_size.y))
	ref_scale = clamp(ref_scale, 0.8, 2.4)
	ref_origin = Vector2(24.0, 86.0)
	frame_rect.position = ref_origin
	frame_rect.size = cell_size * ref_scale
	_apply_frame_poses()

func _show_frame(next_index: int) -> void:
	_capture_current_frame()
	frame_index = wrapi(next_index, 0, 10)
	var cell_w := int(ref_sheet.get_width() / 10)
	var img := ref_sheet.get_region(Rect2i(frame_index * cell_w, 0, cell_w, ref_sheet.get_height()))
	img.convert(Image.FORMAT_RGBA8)
	ref_texture = ImageTexture.create_from_image(img)
	frame_rect.texture = ref_texture
	frame_label.text = "帧 %02d" % [frame_index + 1]
	_apply_frame_poses()

func _apply_frame_poses() -> void:
	if sprites.size() == 0:
		return
	var frame: Dictionary = pose_data["frames"][frame_index]
	var parts: Dictionary = frame["parts"]
	for part in PARTS:
		var name: String = part["name"]
		var pose: Dictionary = parts.get(name, _default_pose(name))
		_apply_pose_to_sprite(name, pose)
	_update_status()
	queue_redraw()

func _default_pose(part_name: String) -> Dictionary:
	var part := _part_def(part_name)
	var points := _current_ref_points()
	var pos: Vector2 = cell_size * 0.5
	var rotation: float = 0.0
	var scale: Vector2 = Vector2(0.38, 0.38)
	if part.has("from") and part.has("to") and points.has(part["from"]) and points.has(part["to"]):
		var a: Vector2 = _point(points[part["from"]])
		var b: Vector2 = _point(points[part["to"]])
		pos = a.lerp(b, 0.5)
		rotation = rad_to_deg((b - a).angle())
		var sprite: Sprite2D = sprites.get(part_name)
		if sprite != null and sprite.texture != null:
			var length: float = a.distance_to(b)
			var tex_len: float = max(1.0, sprite.texture.get_width())
			scale = Vector2.ONE * clamp(length / tex_len, 0.18, 1.2)
	elif part.has("point") and points.has(part["point"]):
		pos = _point(points[part["point"]])
		scale = Vector2(0.34, 0.34)
	if part_name.contains("thigh") or part_name.contains("shin"):
		rotation += 90.0
	if part_name.contains("torso"):
		scale = Vector2(0.44, 0.44)
	if part_name.contains("head"):
		scale = Vector2(0.34, 0.34)
	return {"position": [pos.x, pos.y], "rotation": rotation, "scale": [scale.x, scale.y], "z": int(part.get("z", 0))}

func _apply_pose_to_sprite(part_name: String, pose: Dictionary) -> void:
	var sprite: Sprite2D = sprites.get(part_name)
	if sprite == null:
		return
	var pos: Vector2 = _array_to_vec2(pose.get("position", [cell_size.x * 0.5, cell_size.y * 0.5]))
	var pose_scale: Vector2 = _array_to_vec2(pose.get("scale", [0.4, 0.4]))
	sprite.position = ref_origin + pos * ref_scale
	sprite.rotation = deg_to_rad(float(pose.get("rotation", 0.0)))
	sprite.scale = pose_scale * ref_scale
	sprite.z_index = DISPLAY_Z_BASE + int(pose.get("z", sprite.z_index - DISPLAY_Z_BASE))

func _capture_current_frame() -> void:
	if not pose_data.has("frames"):
		return
	var frame: Dictionary = pose_data["frames"][frame_index]
	var parts: Dictionary = frame["parts"]
	for part_name in sprites.keys():
		var sprite: Sprite2D = sprites[part_name]
		var pos: Vector2 = (sprite.position - ref_origin) / max(0.001, ref_scale)
		var pose_scale: Vector2 = sprite.scale / max(0.001, ref_scale)
		parts[String(part_name)] = {
			"position": [pos.x, pos.y],
			"rotation": rad_to_deg(sprite.rotation),
			"scale": [pose_scale.x, pose_scale.y],
			"z": sprite.z_index - DISPLAY_Z_BASE
		}

func _save_pose_data() -> void:
	_capture_current_frame()
	pose_data["version"] = 1
	pose_data["source"] = REF_SHEET_PATH
	var file := FileAccess.open(USER_POSES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(pose_data, "\t"))
	status_label.text = "已保存到 %s" % USER_POSES_PATH

func _reset_current_frame() -> void:
	var frame: Dictionary = pose_data["frames"][frame_index]
	frame["parts"] = {}
	_apply_frame_poses()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			last_mouse = event.position
			_select_at(event.position)
			dragging = selected_part != ""
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging and selected_part != "":
		var delta: Vector2 = event.position - last_mouse
		last_mouse = event.position
		var sprite: Sprite2D = sprites[selected_part]
		sprite.position += delta
		_update_status()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if selected_part == "" or not sprites.has(selected_part):
		return
	var sprite: Sprite2D = sprites[selected_part]
	match event.keycode:
		KEY_Q:
			sprite.rotation_degrees -= 2.0
		KEY_E:
			sprite.rotation_degrees += 2.0
		KEY_Z:
			sprite.scale *= 0.96
		KEY_X:
			sprite.scale *= 1.04
		KEY_BRACKETLEFT:
			sprite.z_index -= 1
		KEY_BRACKETRIGHT:
			sprite.z_index += 1
		KEY_S:
			if event.ctrl_pressed:
				_save_pose_data()
	_update_status()

func _select_at(pos: Vector2) -> void:
	var best := selected_part
	var best_dist := 999999.0
	for name in sprites.keys():
		var sprite: Sprite2D = sprites[name]
		var dist := sprite.position.distance_to(pos)
		if dist < best_dist and dist < 48.0:
			best = String(name)
			best_dist = dist
	_select_part(best)

func _select_part(part_name: String) -> void:
	selected_part = part_name
	part_select.selected = _part_index(part_name)
	_update_status()
	queue_redraw()

func _draw() -> void:
	if selected_part == "" or not sprites.has(selected_part):
		return
	var sprite: Sprite2D = sprites[selected_part]
	draw_arc(sprite.position, 24.0, 0.0, TAU, 32, Color.WHITE, 2.0)
	draw_circle(sprite.position, 4.0, Color("#d24dff"))

func _update_status() -> void:
	if selected_part == "" or not sprites.has(selected_part):
		status_label.text = ""
		return
	var sprite: Sprite2D = sprites[selected_part]
	var pos: Vector2 = (sprite.position - ref_origin) / max(0.001, ref_scale)
	status_label.text = "%s  x=%.1f y=%.1f rot=%.1f scale=%.2f z=%d" % [
		selected_part, pos.x, pos.y, sprite.rotation_degrees, sprite.scale.x / max(0.001, ref_scale), sprite.z_index - DISPLAY_Z_BASE
	]

func _current_ref_points() -> Dictionary:
	if frame_index >= 0 and frame_index < ref_points.size() and ref_points[frame_index] is Dictionary:
		return ref_points[frame_index]
	return {}

func _point(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _array_to_vec2(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ONE

func _part_def(part_name: String) -> Dictionary:
	for part in PARTS:
		if part["name"] == part_name:
			return part
	return {}

func _part_index(part_name: String) -> int:
	for i in range(PARTS.size()):
		if PARTS[i]["name"] == part_name:
			return i
	return 0

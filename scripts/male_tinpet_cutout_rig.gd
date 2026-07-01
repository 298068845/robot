extends Node2D

const PART_DIR := "res://assets/parts/male_tinpet/"
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"
const PART_LANDMARKS_PATH := "res://assets/parts/male_tinpet/part_landmarks.json"
const BIND_POSE_PATH := "res://assets/parts/male_tinpet/bind_pose.json"
const USER_BIND_POSE_PATH := "user://male_tinpet_cutout_bind_pose.json"
const REF_DISPLAY_SCALE := 0.95
const WALK_DURATION := 1.2

const DRAW_ORDER := {
	"far_thigh_mesh": -80,
	"far_shin_mesh": -79,
	"far_knee_mesh": -78,
	"far_ankle_mesh": -77,
	"far_foot_mesh": -76,
	"far_upper_arm_mesh": -30,
	"far_forearm_mesh": -29,
	"far_shoulder_mesh": -28,
	"far_hand_mesh": -27,
	"torso_mesh": 0,
	"neck_mesh": 20,
	"head_mesh": 30,
	"near_thigh_mesh": 40,
	"near_shin_mesh": 41,
	"near_knee_mesh": 42,
	"near_ankle_mesh": 43,
	"near_foot_mesh": 44,
	"near_upper_arm_mesh": 60,
	"near_forearm_mesh": 61,
	"near_shoulder_mesh": 62,
	"near_hand_mesh": 63,
}

var action := "stand"
var t := 0.0
var root := Node2D.new()
var bones: Dictionary = {}
var sprites: Dictionary = {}
var sprite_textures: Dictionary = {}
var part_landmarks: Dictionary = {}
var bind_pose: Dictionary = {}
var bind_points: Dictionary = {}
var part_defs: Dictionary = {}
var shape_constraints: Dictionary = {}
var skeleton_bones: Dictionary = {}
var walk_frames: Array = []
var current_points: Dictionary = {}
var alpha_bbox_cache: Dictionary = {}
var edit_mode := false

func _ready() -> void:
	add_child(root)
	_load_part_landmarks()
	_load_bind_pose()
	_load_walk_points()
	_build_bones()
	play_action("stand")

func play_action(next_action: String) -> void:
	action = next_action if next_action == "walk" else "stand"
	t = 0.0
	_pose()

func _process(delta: float) -> void:
	if edit_mode:
		return
	t += delta
	_pose()

func _build_bones() -> void:
	_build_skeleton_nodes()
	for name in part_defs.keys():
		var bone := Node2D.new()
		bone.name = String(name).replace("_mesh", "_part")
		root.add_child(bone)
		bones[name] = bone

	for name in part_defs.keys():
		var data: Dictionary = part_defs[name]
		_add_sprite(String(name), String(data["file"]), float(data.get("alpha", 1.0)))

func _build_skeleton_nodes() -> void:
	var hierarchy: Dictionary = bind_pose.get("hierarchy", {})
	for name in _all_skeleton_names(hierarchy):
		var node := Node2D.new()
		node.name = String(name)
		skeleton_bones[String(name)] = node
	var root_name := String(bind_pose.get("root", "hip"))
	root.add_child(skeleton_bones[root_name])
	for parent_name in hierarchy.keys():
		var parent: Node2D = skeleton_bones[String(parent_name)]
		for raw_child in hierarchy[parent_name]:
			var child_name := String(raw_child)
			if skeleton_bones.has(child_name) and skeleton_bones[child_name].get_parent() == null:
				parent.add_child(skeleton_bones[child_name])

func _all_skeleton_names(hierarchy: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for parent_name in hierarchy.keys():
		var p := String(parent_name)
		if not names.has(p):
			names.append(p)
		for raw_child in hierarchy[parent_name]:
			var c := String(raw_child)
			if not names.has(c):
				names.append(c)
	if names.is_empty():
		names.append("hip")
	return names

func _add_sprite(part_name: String, file_name: String, alpha: float) -> void:
	var bone: Node2D = bones[part_name]
	var sprite := Sprite2D.new()
	sprite.texture = _load_texture(PART_DIR + file_name)
	sprite.centered = false
	sprite.modulate.a = alpha
	sprite.z_as_relative = false
	sprite.z_index = int(DRAW_ORDER.get(part_name, 0))
	bone.add_child(sprite)
	sprites[part_name] = sprite
	sprite_textures[part_name] = PART_DIR + file_name

func _pose() -> void:
	var points := _stand_points()
	if action == "walk" and walk_frames.size() >= 2:
		points = _sample_walk_points(_walk_cursor())
	current_points = {}
	for key in points.keys():
		current_points[key] = to_global(points[key])
	_apply_cutout_pose(points)

func _stand_points() -> Dictionary:
	return bind_points.duplicate()

func _apply_cutout_pose(p: Dictionary) -> void:
	_apply_skeleton_pose(p)
	_place_fit("torso_mesh", "torso_mesh", {"neck": p["neck"], "shoulder": p["shoulder"], "torso": p["torso"], "hip": p["hip"]})
	_place_between("neck_mesh", "neck_mesh", {"neck": p["neck"], "torso": p["torso"]}, 1.0 / max(0.001, _scale_multiplier("neck_mesh")))
	_place_between("head_mesh", "head_mesh", {"neck": p["neck"], "head": p["head"]}, 1.0)

	var near_arm := {"shoulder": p["shoulder"], "elbow": p["elbow"], "wrist": p["wrist"], "hand": p["hand"]}
	var far_arm := {"shoulder": p["far_shoulder"], "elbow": p["far_elbow"], "wrist": p["far_wrist"], "hand": p["far_hand"]}
	_place_point("near_shoulder_mesh", "shoulder_joint", p["shoulder"], 0.44)
	_place_between("near_upper_arm_mesh", "upper_arm_tube", near_arm, 1.0)
	_place_between("near_forearm_mesh", "forearm_tube", near_arm, 1.0)
	_place_between("near_hand_mesh", "hand_mesh", near_arm, 1.0)
	_place_point("far_shoulder_mesh", "shoulder_joint", p["far_shoulder"], 0.34)
	_place_between("far_upper_arm_mesh", "upper_arm_tube", far_arm, 1.0)
	_place_between("far_forearm_mesh", "forearm_tube", far_arm, 1.0)
	_place_between("far_hand_mesh", "hand_mesh", far_arm, 1.0)

	_place_leg("near", p["hip"], p["near_knee"], p["near_ankle"], p["near_toe"], 1.0)
	_place_leg("far", p["hip"] + Vector2(-8, 4), p["far_knee"], p["far_ankle"], p["far_toe"], 1.0)
	_apply_dynamic_leg_depth(p)
	_apply_shape_constraints(p)

func _apply_skeleton_pose(p: Dictionary) -> void:
	_set_skeleton_global("hip", p["hip"])
	_set_skeleton_global("torso", p["torso"])
	_set_skeleton_global("neck", p["neck"])
	_set_skeleton_global("head", p["head"])
	_set_skeleton_global("near_upper_arm", p["shoulder"])
	_set_skeleton_global("near_forearm", p["elbow"])
	_set_skeleton_global("near_hand", p["wrist"])
	_set_skeleton_global("far_upper_arm", p["far_shoulder"])
	_set_skeleton_global("far_forearm", p["far_elbow"])
	_set_skeleton_global("far_hand", p["far_wrist"])
	_set_skeleton_global("near_thigh", p["hip"])
	_set_skeleton_global("near_shin", p["near_knee"])
	_set_skeleton_global("near_foot", p["near_ankle"])
	_set_skeleton_global("far_thigh", p["hip"] + Vector2(-8, 4))
	_set_skeleton_global("far_shin", p["far_knee"])
	_set_skeleton_global("far_foot", p["far_ankle"])

func _set_skeleton_global(name: String, local_pos: Vector2) -> void:
	if not skeleton_bones.has(name):
		return
	var node: Node2D = skeleton_bones[name]
	node.global_position = to_global(local_pos)

func _place_leg(prefix: String, hip: Vector2, knee: Vector2, ankle: Vector2, toe: Vector2, depth: float) -> void:
	var leg := {"hip": hip, "knee": knee, "ankle": ankle, "toe": toe}
	_place_between(prefix + "_thigh_mesh", "thigh_tube", leg, depth)
	_place_point(prefix + "_knee_mesh", "knee_joint", knee, 0.44 * depth)
	_place_between(prefix + "_shin_mesh", "shin_tube", leg, depth)
	_place_point(prefix + "_ankle_mesh", "ankle_joint", ankle, 0.38 * depth)
	_place_foot(prefix + "_foot_mesh", ankle, toe, depth)

func _apply_dynamic_leg_depth(p: Dictionary) -> void:
	if not p.has("near_toe") or not p.has("far_toe"):
		return
	var near_toe: Vector2 = p["near_toe"]
	var far_toe: Vector2 = p["far_toe"]
	var near_is_front: bool = near_toe.x >= far_toe.x
	_set_leg_depth("near", near_is_front)
	_set_leg_depth("far", not near_is_front)

func _set_leg_depth(prefix: String, is_front: bool) -> void:
	var names := [
		prefix + "_thigh_mesh",
		prefix + "_knee_mesh",
		prefix + "_shin_mesh",
		prefix + "_ankle_mesh",
		prefix + "_foot_mesh"
	]
	var front_z := {
		"_thigh_mesh": 40,
		"_shin_mesh": 41,
		"_knee_mesh": 42,
		"_ankle_mesh": 43,
		"_foot_mesh": 44
	}
	var back_z := {
		"_thigh_mesh": -80,
		"_shin_mesh": -79,
		"_knee_mesh": -78,
		"_ankle_mesh": -77,
		"_foot_mesh": -76
	}
	for part_name in names:
		if not sprites.has(part_name):
			continue
		var sprite: Sprite2D = sprites[part_name]
		sprite.modulate.a = 1.0 if is_front else 0.5
		for suffix in front_z.keys():
			if part_name.ends_with(suffix):
				sprite.z_index = int(front_z[suffix] if is_front else back_z[suffix])
				break

func _place_between(part_name: String, landmark_name: String, targets: Dictionary, depth: float) -> void:
	var meta := _landmark_meta(landmark_name)
	var axis: Array = meta.get("axis", [])
	if axis.size() < 2:
		return
	var from_key := String(axis[0])
	var to_key := String(axis[1])
	if not targets.has(from_key) or not targets.has(to_key):
		return
	var local_from := _landmark_point(landmark_name, from_key, false)
	var local_to := _landmark_point(landmark_name, to_key, false)
	var target_from: Vector2 = targets[from_key]
	var target_to: Vector2 = targets[to_key]
	_apply_segment(part_name, local_from, local_to, target_from, target_to, depth)

func _place_foot(part_name: String, ankle: Vector2, toe: Vector2, depth: float) -> void:
	var flip_h := toe.x > ankle.x
	var sprite: Sprite2D = sprites[part_name]
	sprite.flip_h = flip_h
	var local_ankle := _landmark_point("foot_mesh", "ankle", flip_h)
	var local_toe := _landmark_point("foot_mesh", "toe", flip_h)
	_apply_segment(part_name, local_ankle, local_toe, ankle, toe, depth)

func _apply_segment(part_name: String, local_from: Vector2, local_to: Vector2, target_from: Vector2, target_to: Vector2, depth: float) -> void:
	var bone: Node2D = bones[part_name]
	var local_vec := local_to - local_from
	var target_vec := target_to - target_from
	if local_vec.length() <= 0.01 or target_vec.length() <= 0.01:
		return
	var scale_axis: float = target_vec.length() / local_vec.length() * depth * _scale_multiplier(_landmark_key(part_name))
	var scale_cross: float = scale_axis * _thickness_multiplier(_landmark_key(part_name))
	var scale_value := Vector2(scale_cross, scale_axis)
	if abs(local_vec.x) >= abs(local_vec.y):
		scale_value = Vector2(scale_axis, scale_cross)
	var rotation := target_vec.angle() - local_vec.angle()
	bone.position = target_from
	bone.rotation = rotation
	bone.scale = scale_value
	var sprite: Sprite2D = sprites[part_name]
	sprite.position = -local_from

func _place_point(part_name: String, landmark_name: String, point: Vector2, scale_value: float) -> void:
	var bone: Node2D = bones[part_name]
	var center := _landmark_point(landmark_name, "center", false)
	bone.position = point
	bone.rotation = 0.0
	bone.scale = Vector2(scale_value, scale_value)
	var sprite: Sprite2D = sprites[part_name]
	sprite.position = -center

func _place_fit(part_name: String, landmark_name: String, targets: Dictionary) -> void:
	var meta := _landmark_meta(landmark_name)
	var keys: Array = meta.get("fit", [])
	var local_points: Array[Vector2] = []
	var target_points: Array[Vector2] = []
	for raw_key in keys:
		var key := String(raw_key)
		if targets.has(key):
			local_points.append(_landmark_point(landmark_name, key, false))
			target_points.append(targets[key])
	if local_points.size() < 2:
		return
	var lc := Vector2.ZERO
	var tc := Vector2.ZERO
	for i in local_points.size():
		lc += local_points[i]
		tc += target_points[i]
	lc /= float(local_points.size())
	tc /= float(target_points.size())
	var dot_sum := 0.0
	var cross_sum := 0.0
	var len_sum := 0.0
	var target_len_sum := 0.0
	for i in local_points.size():
		var lp := local_points[i] - lc
		var tp := target_points[i] - tc
		dot_sum += lp.dot(tp)
		cross_sum += lp.x * tp.y - lp.y * tp.x
		len_sum += lp.length_squared()
		target_len_sum += tp.length_squared()
	var rotation := atan2(cross_sum, dot_sum)
	var scale_value := sqrt(target_len_sum / max(0.01, len_sum)) * _scale_multiplier(landmark_name)
	var bone: Node2D = bones[part_name]
	bone.position = tc
	bone.rotation = rotation
	bone.scale = Vector2(scale_value, scale_value)
	sprites[part_name].position = -lc

func _apply_shape_constraints(p: Dictionary) -> void:
	for part_name in shape_constraints.keys():
		var name := String(part_name)
		if not bones.has(name) or not sprites.has(name):
			continue
		_apply_shape_constraint(name, shape_constraints[name], p)

func _apply_shape_constraint(part_name: String, constraint: Dictionary, points: Dictionary) -> void:
	if not bool(constraint.get("drive_shape", false)):
		return
	var axis: Array = constraint.get("height_axis", [])
	if axis.size() < 2:
		return
	var from_key := String(axis[0])
	var to_key := String(axis[1])
	if not points.has(from_key) or not points.has(to_key):
		return
	var source_box := _alpha_bbox_for_part(part_name)
	if source_box.size.x <= 0.0 or source_box.size.y <= 0.0:
		return
	var target_axis_len: float = points[from_key].distance_to(points[to_key])
	if target_axis_len <= 0.01:
		return
	var desired_size := Vector2(
		target_axis_len * float(constraint.get("width_ratio", 1.0)),
		target_axis_len * float(constraint.get("height_ratio", 1.0))
	)
	var bone: Node2D = bones[part_name]
	var current_box := _part_bbox_in_root(part_name)
	if current_box.size.x <= 0.1 or current_box.size.y <= 0.1:
		return
	var preserve_local := _preserve_landmark_for_shape(part_name)
	var sprite: Sprite2D = sprites[part_name]
	var before: Vector2 = sprite.global_transform * preserve_local
	var x_factor: float = desired_size.x / current_box.size.x
	var y_factor: float = desired_size.y / current_box.size.y
	bone.scale = Vector2(bone.scale.x * x_factor, bone.scale.y * y_factor)
	var after: Vector2 = sprite.global_transform * preserve_local
	bone.global_position += before - after

func _preserve_landmark_for_shape(part_name: String) -> Vector2:
	var landmark_name := _landmark_key(part_name)
	if part_name == "torso_mesh":
		return _landmark_point(landmark_name, "neck", false)
	if part_name == "head_mesh":
		return _landmark_point(landmark_name, "neck", false)
	if part_name.ends_with("_foot_mesh"):
		var sprite: Sprite2D = sprites[part_name]
		return _landmark_point(landmark_name, "ankle", sprite.flip_h)
	return _landmark_point(landmark_name, "center", false)

func _part_bbox_in_root(part_name: String) -> Rect2:
	var source_box := _alpha_bbox_for_part(part_name)
	if source_box.size.x <= 0.0 or source_box.size.y <= 0.0:
		return Rect2()
	var sprite: Sprite2D = sprites[part_name]
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
		var local: Vector2 = point
		if sprite.flip_h:
			local.x = sprite.texture.get_width() - local.x
		var p := root.to_local(sprite.global_transform * local)
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _alpha_bbox_for_part(part_name: String) -> Rect2:
	var path := String(sprite_textures.get(part_name, ""))
	if path == "":
		return Rect2()
	if alpha_bbox_cache.has(path):
		return alpha_bbox_cache[path]
	var img := Image.new()
	if img.load(path) != OK:
		return Rect2()
	img.convert(Image.FORMAT_RGBA8)
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := 0
	var max_y := 0
	var found := false
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.18:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
			found = true
	var box := Rect2()
	if found:
		box = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))
	alpha_bbox_cache[path] = box
	return box

func _sample_walk_points(cursor: float) -> Dictionary:
	var last: int = walk_frames.size() - 1
	var frame_pos: float = clamp(cursor, 0.0, 1.0) * float(last)
	var a_i: int = int(floor(frame_pos))
	var b_i: int = min(a_i + 1, last)
	var local: float = frame_pos - float(a_i)
	local = local * local * (3.0 - 2.0 * local)
	var raw := {}
	for key in walk_frames[a_i].keys():
		if walk_frames[b_i].has(key):
			raw[key] = walk_frames[a_i][key].lerp(walk_frames[b_i][key], local)
	var origin: Vector2 = raw["hip"]
	var ground: float = max(raw["near_toe"].y, raw["far_toe"].y)
	var out := {}
	for key in raw.keys():
		out[key] = Vector2((raw[key].x - origin.x) * REF_DISPLAY_SCALE, (raw[key].y - ground) * REF_DISPLAY_SCALE)
	return out

func _load_walk_points() -> void:
	walk_frames.clear()
	if not FileAccess.file_exists(REF_POINTS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REF_POINTS_PATH))
	if not (parsed is Dictionary) or not parsed.has("frames"):
		return
	for frame in parsed["frames"]:
		var out := {}
		for key in frame.keys():
			var v = frame[key]
			if v is Array and v.size() >= 2:
				out[String(key)] = Vector2(float(v[0]), float(v[1]))
		walk_frames.append(out)

func _load_part_landmarks() -> void:
	part_landmarks.clear()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PART_LANDMARKS_PATH))
	if parsed is Dictionary and parsed.has("parts"):
		part_landmarks = parsed["parts"]

func _load_bind_pose() -> void:
	bind_pose.clear()
	bind_points.clear()
	part_defs.clear()
	shape_constraints.clear()
	var path := USER_BIND_POSE_PATH if FileAccess.file_exists(USER_BIND_POSE_PATH) else BIND_POSE_PATH
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	bind_pose = parsed
	var raw_points: Dictionary = bind_pose.get("points", {})
	for key in raw_points.keys():
		var value = raw_points[key]
		if value is Array and value.size() >= 2:
			bind_points[String(key)] = Vector2(float(value[0]), float(value[1]))
	part_defs = bind_pose.get("parts", {})
	shape_constraints = bind_pose.get("shape_constraints", {})

func _landmark_meta(name: String) -> Dictionary:
	var value = part_landmarks.get(name, {})
	return value if value is Dictionary else {}

func _landmark_point(name: String, point_name: String, flip_h: bool) -> Vector2:
	var meta := _landmark_meta(name)
	var landmarks: Dictionary = meta.get("landmarks", {})
	var v = landmarks.get(point_name, [0, 0])
	var p := Vector2(float(v[0]), float(v[1]))
	if flip_h:
		p.x = _texture_width_for_landmark(name) - p.x
	return p

func _texture_width_for_landmark(name: String) -> float:
	for part_name in sprites.keys():
		if _landmark_key(String(part_name)) == name:
			var sprite: Sprite2D = sprites[part_name]
			return float(sprite.texture.get_width())
	return 0.0

func _landmark_key(part_name: String) -> String:
	if part_name.ends_with("_shoulder_mesh"):
		return "shoulder_joint"
	if part_name.ends_with("_upper_arm_mesh"):
		return "upper_arm_tube"
	if part_name.ends_with("_forearm_mesh"):
		return "forearm_tube"
	if part_name.ends_with("_hand_mesh"):
		return "hand_mesh"
	if part_name.ends_with("_thigh_mesh"):
		return "thigh_tube"
	if part_name.ends_with("_knee_mesh"):
		return "knee_joint"
	if part_name.ends_with("_shin_mesh"):
		return "shin_tube"
	if part_name.ends_with("_ankle_mesh"):
		return "ankle_joint"
	if part_name.ends_with("_foot_mesh"):
		return "foot_mesh"
	return part_name

func _scale_multiplier(name: String) -> float:
	return float(_landmark_meta(name).get("scale_multiplier", 1.0))

func _thickness_multiplier(name: String) -> float:
	return float(_landmark_meta(name).get("thickness_multiplier", 1.0))

func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		push_error("Could not load part texture: %s" % path)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)

func get_compare_points() -> Dictionary:
	return current_points.duplicate()

func get_bind_pose_points() -> Dictionary:
	var out := {}
	for key in bind_points.keys():
		out[String(key)] = to_global(bind_points[key])
	return out

func get_skeleton_hierarchy() -> Dictionary:
	return bind_pose.get("hierarchy", {}).duplicate(true)

func get_skeleton_bone_positions() -> Dictionary:
	var out := {}
	for key in skeleton_bones.keys():
		var node: Node2D = skeleton_bones[key]
		out[String(key)] = node.global_position
	return out

func get_part_pose_snapshot() -> Dictionary:
	var out := {}
	for part_name in sprites.keys():
		var sprite: Sprite2D = sprites[part_name]
		out[String(part_name)] = {
			"position": sprite.global_position,
			"rotation": rad_to_deg(sprite.global_rotation),
			"scale": sprite.global_scale,
			"z": sprite.z_index
		}
	return out

func get_part_render_snapshot() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for part_name in sprites.keys():
		var sprite: Sprite2D = sprites[part_name]
		parts.append({
			"name": String(part_name),
			"path": String(sprite_textures[part_name]),
			"position": sprite.global_position,
			"rotation": sprite.global_rotation,
			"scale": sprite.global_scale,
			"flip_h": sprite.flip_h,
			"alpha": sprite.modulate.a,
			"z": sprite.z_index
		})
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["z"]) < int(b["z"]))
	return parts

func get_part_landmark_positions() -> Dictionary:
	var out := {}
	for part_name in sprites.keys():
		var sprite: Sprite2D = sprites[part_name]
		var landmark_name := _landmark_key(String(part_name))
		var meta := _landmark_meta(landmark_name)
		var landmarks: Dictionary = meta.get("landmarks", {})
		var part_out := {}
		for landmark_key in landmarks.keys():
			var local := _landmark_point(landmark_name, String(landmark_key), sprite.flip_h)
			part_out[String(landmark_key)] = sprite.global_transform * local
		out[String(part_name)] = part_out
	return out

func _walk_cursor() -> float:
	if t > 0.0 and is_equal_approx(t, WALK_DURATION):
		return 1.0
	return fmod(t, WALK_DURATION) / WALK_DURATION

func set_edit_mode(enabled: bool) -> void:
	edit_mode = enabled
	if edit_mode:
		action = "stand"
		t = 0.0
		_pose()

func get_bind_point_names() -> Array:
	var names := bind_points.keys()
	names.sort()
	return names

func get_bind_point_position(point_name: String) -> Vector2:
	if not bind_points.has(point_name):
		return global_position
	return to_global(bind_points[point_name])

func move_bind_point_global(point_name: String, global_point: Vector2) -> void:
	if not bind_points.has(point_name):
		return
	bind_points[point_name] = to_local(global_point)
	if bind_pose.has("points"):
		bind_pose["points"][point_name] = [bind_points[point_name].x, bind_points[point_name].y]
	_pose()

func get_mesh_names() -> Array:
	var names := bones.keys()
	names.sort()
	return names

func get_mesh_position(part_name: String) -> Vector2:
	if not bones.has(part_name):
		return global_position
	var bone: Node2D = bones[part_name]
	return bone.global_position

func move_mesh_global(part_name: String, delta: Vector2) -> void:
	if not bones.has(part_name):
		return
	var bone: Node2D = bones[part_name]
	bone.global_position += delta

func save_binding() -> void:
	if not bind_pose.has("points"):
		bind_pose["points"] = {}
	for point_name in bind_points.keys():
		var p: Vector2 = bind_points[point_name]
		bind_pose["points"][String(point_name)] = [p.x, p.y]
	var file := FileAccess.open(USER_BIND_POSE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save cutout bind pose: %s" % USER_BIND_POSE_PATH)
		return
	file.store_string(JSON.stringify(bind_pose, "\t"))

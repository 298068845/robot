extends Node2D

const PART_DIR := "res://assets/parts/male_tinpet/"
const BINDING_PATH := "user://male_tinpet_binding.json"
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"
const PART_LANDMARKS_PATH := "res://assets/parts/male_tinpet/part_landmarks.json"
const REF_DISPLAY_SCALE := 0.95
const FOOT_TOE_LOCAL := Vector2(185, 88)
const PART_DRAW_ORDER := {
	"far_thigh_mesh": -80,
	"far_shin_mesh": -79,
	"far_knee_mesh": -78,
	"far_ankle_mesh": -77,
	"far_foot_mesh": -76,
	"far_upper_arm_mesh": -8,
	"far_forearm_mesh": -7,
	"far_shoulder_mesh": -6,
	"far_hand_mesh": -5,
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

var action := "walk"
var t := 0.0

var body := Node2D.new()
var torso := Node2D.new()
var neck := Node2D.new()
var head := Node2D.new()
var near_arm := Node2D.new()
var near_forearm := Node2D.new()
var near_hand := Node2D.new()
var far_arm := Node2D.new()
var far_forearm := Node2D.new()
var far_hand := Node2D.new()
var near_thigh := Node2D.new()
var near_knee := Node2D.new()
var near_shin := Node2D.new()
var near_ankle := Node2D.new()
var near_foot := Node2D.new()
var far_thigh := Node2D.new()
var far_knee := Node2D.new()
var far_shin := Node2D.new()
var far_ankle := Node2D.new()
var far_foot := Node2D.new()
var edit_mode := false
var bind_offsets: Dictionary = {}
var part_sprites: Dictionary = {}
var part_texture_paths: Dictionary = {}
var part_landmarks: Dictionary = {}
var reference_walk_frames: Array = []
var current_compare_points: Dictionary = {}

func _ready() -> void:
	add_child(body)
	body.scale = Vector2(0.42, 0.42)
	load_binding()
	_load_part_landmarks()
	_load_reference_walk()
	_build_body()
	play_action("walk")

func set_part(_slot: String, _index: int) -> void:
	pass

func play_action(next_action: String) -> void:
	action = "walk"
	t = 0.0

func _process(delta: float) -> void:
	if edit_mode:
		return
	t += delta
	_pose()

func _build_body() -> void:
	body.add_child(far_thigh)
	far_thigh.add_child(far_knee)
	far_knee.add_child(far_shin)
	far_shin.add_child(far_ankle)
	far_ankle.add_child(far_foot)
	body.add_child(near_thigh)
	near_thigh.add_child(near_knee)
	near_knee.add_child(near_shin)
	near_shin.add_child(near_ankle)
	near_ankle.add_child(near_foot)
	body.add_child(torso)
	body.add_child(neck)
	torso.add_child(head)
	torso.add_child(far_arm)
	far_arm.add_child(far_forearm)
	far_forearm.add_child(far_hand)
	torso.add_child(near_arm)
	near_arm.add_child(near_forearm)
	near_forearm.add_child(near_hand)

	part_sprites["torso_mesh"] = _add_part(torso, "torso_side.png", Vector2(82, 218), 1.0, false, 0.0, "torso_mesh")
	part_sprites["neck_mesh"] = _add_part(neck, "neck_connector.png", Vector2(42, 20), 1.0, false, 0.0, "neck_mesh")
	part_sprites["head_mesh"] = _add_part(head, "head_side.png", Vector2(142, 152), 1.0, true, 266, "head_mesh")
	_add_arm_parts(far_arm, far_forearm, far_hand, 0.52)
	_add_arm_parts(near_arm, near_forearm, near_hand, 1.0)
	_add_leg_parts(far_thigh, far_knee, far_shin, far_ankle, far_foot, 0.46)
	_add_leg_parts(near_thigh, near_knee, near_shin, near_ankle, near_foot, 1.0)

func _add_arm_parts(upper: Node2D, forearm: Node2D, hand_node: Node2D, alpha: float) -> void:
	var prefix := "near" if alpha > 0.9 else "far"
	part_sprites[prefix + "_shoulder_mesh"] = _add_part(upper, "shoulder_joint.png", Vector2(96, 82), alpha, false, 0.0, prefix + "_shoulder_mesh")
	part_sprites[prefix + "_upper_arm_mesh"] = _add_part(upper, "upper_arm_tube.png", Vector2(18, 39), alpha, false, 0.0, prefix + "_upper_arm_mesh")
	part_sprites[prefix + "_forearm_mesh"] = _add_part(forearm, "forearm_tube.png", Vector2(18, 41), alpha, false, 0.0, prefix + "_forearm_mesh")
	part_sprites[prefix + "_hand_mesh"] = _add_part(hand_node, "hand_side.png", Vector2(33, 84), alpha, false, 0.0, prefix + "_hand_mesh")

func _add_leg_parts(thigh: Node2D, knee: Node2D, shin: Node2D, ankle: Node2D, foot: Node2D, alpha: float) -> void:
	var prefix := "near" if alpha > 0.9 else "far"
	part_sprites[prefix + "_thigh_mesh"] = _add_part(thigh, "thigh_tube.png", Vector2(40, 28), alpha, false, 0.0, prefix + "_thigh_mesh")
	part_sprites[prefix + "_knee_mesh"] = _add_part(knee, "knee_joint.png", Vector2(66, 98), alpha, false, 0.0, prefix + "_knee_mesh")
	part_sprites[prefix + "_shin_mesh"] = _add_part(shin, "shin_tube.png", Vector2(38, 28), alpha, false, 0.0, prefix + "_shin_mesh")
	part_sprites[prefix + "_ankle_mesh"] = _add_part(ankle, "ankle_joint.png", Vector2(56, 88), alpha, false, 0.0, prefix + "_ankle_mesh")
	part_sprites[prefix + "_foot_mesh"] = _add_part(foot, "foot_side.png", Vector2(72, 48), alpha, false, 290, prefix + "_foot_mesh")

func _add_part(parent: Node2D, file_name: String, anchor: Vector2, alpha := 1.0, flip_h := false, width := 0.0, part_name := "") -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _load_texture(PART_DIR + file_name)
	sprite.centered = false
	sprite.flip_h = flip_h
	sprite.position = -anchor
	if flip_h:
		sprite.position.x = -(width - anchor.x)
	if part_name != "":
		sprite.position += _offset(part_name)
		part_texture_paths[part_name] = PART_DIR + file_name
	sprite.z_as_relative = false
	sprite.z_index = _part_layer(part_name)
	sprite.modulate.a = alpha
	parent.add_child(sprite)
	return sprite

func _part_layer(part_name: String) -> int:
	return int(PART_DRAW_ORDER.get(part_name, 0))

func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_error("Could not load part texture: %s" % path)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)

func _load_part_landmarks() -> void:
	part_landmarks.clear()
	if not FileAccess.file_exists(PART_LANDMARKS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PART_LANDMARKS_PATH))
	if parsed is Dictionary and parsed.has("parts") and parsed["parts"] is Dictionary:
		part_landmarks = parsed["parts"]

func _reset_pose() -> void:
	current_compare_points.clear()
	body.position = Vector2(0, -132)
	body.rotation = 0
	torso.position = Vector2(0, -380) + _offset("torso")
	torso.rotation = deg_to_rad(-5)
	head.position = Vector2(50, -190) + _offset("head")
	head.rotation = deg_to_rad(1)
	_set_arm_pose(near_arm, near_forearm, near_hand, Vector2(62, -106), 14, 12, 0)
	_set_arm_pose(far_arm, far_forearm, far_hand, Vector2(42, -108), -20, 14, 0)
	_set_leg_pose(near_thigh, near_knee, near_shin, near_ankle, near_foot, Vector2(2, -232), -22, 18, -4, 0)
	_set_leg_pose(far_thigh, far_knee, far_shin, far_ankle, far_foot, Vector2(-20, -232), 28, 34, -8, 0)

func _set_arm_pose(upper: Node2D, forearm: Node2D, hand_node: Node2D, shoulder: Vector2, upper_deg: float, forearm_deg: float, hand_deg: float) -> void:
	var prefix := "near" if upper == near_arm else "far"
	upper.position = shoulder + _offset(prefix + "_shoulder")
	upper.rotation = deg_to_rad(upper_deg)
	forearm.position = Vector2(235, 0) + _offset(prefix + "_elbow")
	forearm.rotation = deg_to_rad(forearm_deg)
	hand_node.position = Vector2(272, 0) + _offset(prefix + "_wrist")
	hand_node.rotation = deg_to_rad(hand_deg)

func _set_leg_pose(thigh: Node2D, knee: Node2D, shin: Node2D, ankle: Node2D, foot: Node2D, hip: Vector2, thigh_deg: float, shin_deg: float, ankle_deg: float, foot_deg: float) -> void:
	var prefix := "near" if thigh == near_thigh else "far"
	thigh.position = hip + _offset(prefix + "_hip")
	thigh.rotation = deg_to_rad(thigh_deg)
	knee.position = Vector2(0, 204) + _offset(prefix + "_knee")
	knee.rotation = deg_to_rad(0)
	shin.position = Vector2(0, 92) + _offset(prefix + "_shin")
	shin.rotation = deg_to_rad(shin_deg)
	ankle.position = Vector2(0, 216) + _offset(prefix + "_ankle")
	ankle.rotation = deg_to_rad(ankle_deg)
	foot.position = Vector2(0, 50) + _offset(prefix + "_foot")
	foot.rotation = deg_to_rad(foot_deg)

func _pose() -> void:
	_reset_pose()
	if action == "walk" and reference_walk_frames.size() >= 2:
		var cursor := fmod(t, 1.2) / 1.2
		var ref_pose := _sample_reference_points(cursor)
		_apply_reference_pose(ref_pose, cursor)
		return
	var data := _animation_data(action)
	var duration: float = data["duration"]
	var cursor: float = fmod(t, duration) / duration
	var pose: Dictionary = _sample_pose(data["frames"], cursor)
	_apply_pose(pose)

func _load_reference_walk() -> void:
	reference_walk_frames.clear()
	if not FileAccess.file_exists(REF_POINTS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REF_POINTS_PATH))
	if not (parsed is Dictionary) or not parsed.has("frames") or not (parsed["frames"] is Array):
		return
	for raw_frame in parsed["frames"]:
		if not (raw_frame is Dictionary):
			continue
		var frame := {}
		for key in raw_frame.keys():
			var value = raw_frame[key]
			if value is Array and value.size() >= 2:
				frame[String(key)] = Vector2(float(value[0]), float(value[1]))
		reference_walk_frames.append(frame)

func _sample_reference_points(cursor: float) -> Dictionary:
	var last_index: int = reference_walk_frames.size() - 1
	var frame_pos: float = clamp(cursor, 0.0, 1.0) * float(last_index)
	var from_index: int = int(floor(frame_pos))
	var to_index: int = min(from_index + 1, last_index)
	var local: float = frame_pos - float(from_index)
	local = local * local * (3.0 - 2.0 * local)
	var from_frame: Dictionary = reference_walk_frames[from_index]
	var to_frame: Dictionary = reference_walk_frames[to_index]
	var result: Dictionary = {}
	for key in from_frame.keys():
		if not to_frame.has(key):
			continue
		var a: Vector2 = from_frame[key]
		var b: Vector2 = to_frame[key]
		result[key] = a.lerp(b, local)
	return result

func _apply_reference_pose(points: Dictionary, cursor := 0.0) -> void:
	if not _has_reference_points(points):
		return
	current_compare_points.clear()
	body.position = Vector2.ZERO
	body.rotation = 0.0
	body.scale = Vector2(0.42, 0.42)
	torso.rotation = 0.0
	neck.rotation = 0.0
	head.rotation = 0.0
	for node in [near_arm, near_forearm, near_hand, far_arm, far_forearm, far_hand, near_thigh, near_knee, near_shin, near_ankle, near_foot, far_thigh, far_knee, far_shin, far_ankle, far_foot]:
		node.rotation = 0.0
		node.scale = Vector2.ONE
	for key in part_sprites.keys():
		var sprite: Sprite2D = part_sprites[key]
		sprite.top_level = false
		sprite.scale = Vector2.ONE

	var origin: Vector2 = points["hip"]
	var ground_y: float = max(float(points["near_toe"].y), float(points["far_toe"].y))
	_cache_reference_compare_points(points, origin, ground_y)

	_set_global_point(torso, _reference_to_rig(points["torso"], origin, ground_y))
	_apply_neck_reference(points, origin, ground_y)
	_set_global_point(head, _reference_to_rig(points["head"], origin, ground_y))
	head.global_rotation = _angle_between(points["neck"], points["head"])

	_apply_arm_reference(near_arm, near_forearm, near_hand, points, "shoulder", "elbow", "wrist", "hand", origin, ground_y)
	_apply_arm_reference(far_arm, far_forearm, far_hand, points, "shoulder", "elbow", "wrist", "hand", origin, ground_y)
	_apply_leg_reference(near_thigh, near_knee, near_shin, near_ankle, near_foot, points, "hip", "near_knee", "near_ankle", "near_toe", origin, ground_y)
	_apply_leg_reference(far_thigh, far_knee, far_shin, far_ankle, far_foot, points, "hip", "far_knee", "far_ankle", "far_toe", origin, ground_y)
	_apply_semantic_part_layout(points, origin, ground_y, cursor)

func _has_reference_points(points: Dictionary) -> bool:
	for key in ["head", "neck", "torso", "shoulder", "elbow", "wrist", "hand", "hip", "near_knee", "near_ankle", "near_toe", "far_knee", "far_ankle", "far_toe"]:
		if not points.has(key):
			return false
	return true

func _reference_to_rig(point: Vector2, origin: Vector2, ground_y: float) -> Vector2:
	return Vector2((point.x - origin.x) * REF_DISPLAY_SCALE, (point.y - ground_y) * REF_DISPLAY_SCALE)

func _cache_reference_compare_points(points: Dictionary, origin: Vector2, ground_y: float) -> void:
	current_compare_points.clear()
	for key in points.keys():
		if points[key] is Vector2:
			current_compare_points[String(key)] = to_global(_reference_to_rig(points[key], origin, ground_y))

func _set_global_point(node: Node2D, rig_local: Vector2) -> void:
	node.global_position = to_global(rig_local)

func _apply_arm_reference(upper: Node2D, forearm: Node2D, hand_node: Node2D, points: Dictionary, shoulder_key: String, elbow_key: String, wrist_key: String, hand_key: String, origin: Vector2, ground_y: float) -> void:
	var shoulder := _reference_to_rig(points[shoulder_key], origin, ground_y)
	var elbow := _reference_to_rig(points[elbow_key], origin, ground_y)
	var wrist := _reference_to_rig(points[wrist_key], origin, ground_y)
	var hand_tip := _reference_to_rig(points[hand_key], origin, ground_y)
	_set_global_point(upper, shoulder)
	upper.global_rotation = (elbow - shoulder).angle()
	_set_global_point(forearm, elbow)
	forearm.global_rotation = (wrist - elbow).angle()
	_set_global_point(hand_node, wrist)
	hand_node.global_rotation = (hand_tip - wrist).angle()

func _apply_neck_reference(points: Dictionary, origin: Vector2, ground_y: float) -> void:
	var neck_p := _reference_to_rig(points["neck"], origin, ground_y)
	var torso_p := _reference_to_rig(points["torso"], origin, ground_y)
	_set_global_point(neck, neck_p)
	neck.global_rotation = (torso_p - neck_p).angle() - PI * 0.5

func _apply_leg_reference(thigh: Node2D, knee: Node2D, shin: Node2D, ankle: Node2D, foot: Node2D, points: Dictionary, hip_key: String, knee_key: String, ankle_key: String, toe_key: String, origin: Vector2, ground_y: float) -> void:
	var hip := _reference_to_rig(points[hip_key], origin, ground_y)
	var knee_p := _reference_to_rig(points[knee_key], origin, ground_y)
	var ankle_p := _reference_to_rig(points[ankle_key], origin, ground_y)
	var toe_p := _reference_to_rig(points[toe_key], origin, ground_y)
	_set_global_point(thigh, hip)
	thigh.global_rotation = (knee_p - hip).angle() - PI * 0.5
	_set_global_point(knee, knee_p)
	knee.global_rotation = 0.0
	_set_global_point(shin, knee_p)
	shin.global_rotation = (ankle_p - knee_p).angle() - PI * 0.5
	_set_global_point(ankle, ankle_p)
	ankle.global_rotation = 0.0
	_set_global_point(foot, ankle_p)
	var toe_vector := toe_p - ankle_p
	if toe_vector.length() > 1.0:
		foot.global_rotation = toe_vector.angle() - FOOT_TOE_LOCAL.angle()

func _apply_semantic_part_layout(points: Dictionary, origin: Vector2, ground_y: float, cursor: float) -> void:
	var target := {}
	for key in points.keys():
		if points[key] is Vector2:
			target[String(key)] = _reference_to_rig(points[key], origin, ground_y)
	var near_arm := {"shoulder": target["shoulder"], "elbow": target["elbow"], "wrist": target["wrist"], "hand": target["hand"]}
	var far_arm := _far_arm_targets(points, origin, ground_y, cursor, near_arm)

	_place_part_between("head_mesh", "head_mesh", {"neck": target["neck"], "head": target["head"]}, 1.0)
	_place_point_part("neck_mesh", "neck_mesh", target["neck"].lerp(target["torso"], 0.5), _scale_multiplier("neck_mesh"))
	_place_part_fit("torso_mesh", "torso_mesh", {"neck": target["neck"], "hip": target["hip"], "torso": target["torso"], "shoulder": target["shoulder"]})

	_place_point_part("near_shoulder_mesh", "shoulder_joint", target["shoulder"], _scale_multiplier("shoulder_joint"))
	_place_part_between("near_upper_arm_mesh", "upper_arm_tube", near_arm, 1.0)
	_place_part_between("near_forearm_mesh", "forearm_tube", near_arm, 1.0)
	_place_part_between("near_hand_mesh", "hand_mesh", near_arm, 1.0)

	_place_point_part("far_shoulder_mesh", "shoulder_joint", far_arm["shoulder"], _scale_multiplier("shoulder_joint") * 0.82)
	_place_part_between("far_upper_arm_mesh", "upper_arm_tube", far_arm, 0.88)
	_place_part_between("far_forearm_mesh", "forearm_tube", far_arm, 0.88)
	_place_part_between("far_hand_mesh", "hand_mesh", far_arm, 0.88)

	_place_leg_parts("near", target["hip"], target["near_knee"], target["near_ankle"], target["near_toe"], 1.0)
	_place_leg_parts("far", target["hip"] + Vector2(-8.0, 5.0), target["far_knee"], target["far_ankle"], target["far_toe"], 0.88)

func _place_leg_parts(prefix: String, hip: Vector2, knee_p: Vector2, ankle_p: Vector2, toe_p: Vector2, depth_scale: float) -> void:
	var leg := {"hip": hip, "knee": knee_p, "ankle": ankle_p, "toe": toe_p}
	_place_part_between(prefix + "_thigh_mesh", "thigh_tube", leg, depth_scale)
	_place_point_part(prefix + "_knee_mesh", "knee_joint", knee_p, _scale_multiplier("knee_joint") * depth_scale)
	_place_part_between(prefix + "_shin_mesh", "shin_tube", leg, depth_scale)
	_place_point_part(prefix + "_ankle_mesh", "ankle_joint", ankle_p, _scale_multiplier("ankle_joint") * depth_scale)
	_place_foot_part(prefix + "_foot_mesh", leg, depth_scale)

func _place_foot_part(sprite_name: String, target_points: Dictionary, depth_scale: float) -> void:
	var sprite: Sprite2D = part_sprites.get(sprite_name)
	if sprite == null:
		return
	if not target_points.has("ankle") or not target_points.has("toe"):
		return
	var landmark_name := "foot_mesh"
	var target_from: Vector2 = target_points["ankle"]
	var target_to: Vector2 = target_points["toe"]
	var flip_h := target_to.x > target_from.x
	sprite.flip_h = flip_h
	var local_from := _landmark_point_with_flip(landmark_name, "ankle", flip_h)
	var local_to := _landmark_point_with_flip(landmark_name, "toe", flip_h)
	var local_vec := local_to - local_from
	var target_vec := target_to - target_from
	if local_vec.length() <= 0.01 or target_vec.length() <= 0.01:
		return
	var axis_scale: float = target_vec.length() / local_vec.length() * depth_scale * _scale_multiplier(landmark_name)
	var thickness_scale: float = axis_scale * _thickness_multiplier(landmark_name)
	var scale_value := Vector2(axis_scale, thickness_scale)
	var rotation_value: float = target_vec.angle() - local_vec.angle()
	_apply_sprite_transform(sprite, local_from, target_from, rotation_value, scale_value)

func _far_arm_targets(points: Dictionary, origin: Vector2, ground_y: float, _cursor: float, near_arm: Dictionary) -> Dictionary:
	if points.has("far_shoulder") and points.has("far_elbow") and points.has("far_wrist") and points.has("far_hand"):
		return {
			"shoulder": _reference_to_rig(points["far_shoulder"], origin, ground_y),
			"elbow": _reference_to_rig(points["far_elbow"], origin, ground_y),
			"wrist": _reference_to_rig(points["far_wrist"], origin, ground_y),
			"hand": _reference_to_rig(points["far_hand"], origin, ground_y)
		}
	var shoulder: Vector2 = near_arm["shoulder"] + Vector2(-8.0, 6.0)
	var near_shoulder: Vector2 = near_arm["shoulder"]
	var near_elbow: Vector2 = near_arm["elbow"]
	var near_wrist: Vector2 = near_arm["wrist"]
	var near_hand_tip: Vector2 = near_arm["hand"]
	var depth_scale := 1.0
	return {
		"shoulder": shoulder,
		"elbow": shoulder + _side_view_far_arm_vector(near_elbow - near_shoulder) * depth_scale,
		"wrist": shoulder + _side_view_far_arm_vector(near_wrist - near_shoulder) * depth_scale,
		"hand": shoulder + _side_view_far_arm_vector(near_hand_tip - near_shoulder) * depth_scale
	}

func _side_view_far_arm_vector(vector: Vector2) -> Vector2:
	return Vector2(-vector.x * 2.0, vector.y * 0.82)

func _place_part_between(sprite_name: String, landmark_name: String, target_points: Dictionary, depth_scale: float) -> void:
	var sprite: Sprite2D = part_sprites.get(sprite_name)
	if sprite == null:
		return
	var meta := _landmark_meta(landmark_name)
	if meta.is_empty() or not meta.has("axis"):
		return
	var axis: Array = meta["axis"]
	var from_key: String = String(axis[0])
	var to_key: String = String(axis[1])
	if not target_points.has(from_key) or not target_points.has(to_key):
		return
	var local_from := _landmark_point(landmark_name, from_key)
	var local_to := _landmark_point(landmark_name, to_key)
	var rotation_axis := _landmark_axis(meta, "rotation_axis", axis)
	var scale_axis := _landmark_axis(meta, "scale_axis", axis)
	var local_rot_from := _landmark_point(landmark_name, String(rotation_axis[0]))
	var local_rot_to := _landmark_point(landmark_name, String(rotation_axis[1]))
	var local_scale_from := _landmark_point(landmark_name, String(scale_axis[0]))
	var local_scale_to := _landmark_point(landmark_name, String(scale_axis[1]))
	var target_from: Vector2 = target_points[from_key]
	var target_to: Vector2 = target_points[to_key]
	var local_vec := local_rot_to - local_rot_from
	var local_scale_vec := local_scale_to - local_scale_from
	var target_vec := target_to - target_from
	if local_vec.length() <= 0.01 or local_scale_vec.length() <= 0.01 or target_vec.length() <= 0.01:
		return
	var axis_scale: float = target_vec.length() / local_scale_vec.length() * depth_scale * _scale_multiplier(landmark_name)
	var thickness_scale: float = axis_scale * _thickness_multiplier(landmark_name)
	var scale_value := Vector2(thickness_scale, axis_scale)
	if abs(local_vec.x) >= abs(local_vec.y):
		scale_value = Vector2(axis_scale, thickness_scale)
	var rotation_value: float = target_vec.angle() - local_vec.angle()
	_apply_sprite_transform(sprite, local_from, target_from, rotation_value, scale_value)

func _landmark_axis(meta: Dictionary, key: String, fallback: Array) -> Array:
	if meta.has(key) and meta[key] is Array and meta[key].size() >= 2:
		return meta[key]
	return fallback

func _place_part_fit(sprite_name: String, landmark_name: String, target_points: Dictionary) -> void:
	var sprite: Sprite2D = part_sprites.get(sprite_name)
	if sprite == null:
		return
	var meta := _landmark_meta(landmark_name)
	if meta.is_empty() or not meta.has("fit") or not (meta["fit"] is Array):
		_place_part_between(sprite_name, landmark_name, target_points, 1.0)
		return
	var keys: Array = meta["fit"]
	var local_points: Array[Vector2] = []
	var target_values: Array[Vector2] = []
	var weights: Array[float] = []
	for raw_key in keys:
		var key := String(raw_key)
		if not target_points.has(key):
			continue
		local_points.append(_landmark_point(landmark_name, key))
		target_values.append(target_points[key])
		weights.append(_fit_weight(meta, key))
	if local_points.size() < 2:
		return
	var local_center := Vector2.ZERO
	var target_center := Vector2.ZERO
	var weight_total := 0.0
	for i in range(local_points.size()):
		local_center += local_points[i] * weights[i]
		target_center += target_values[i] * weights[i]
		weight_total += weights[i]
	if weight_total <= 0.001:
		return
	local_center /= weight_total
	target_center /= weight_total

	var dot_sum := 0.0
	var cross_sum := 0.0
	var local_len_sq := 0.0
	for i in range(local_points.size()):
		var lp := local_points[i] - local_center
		var tp := target_values[i] - target_center
		dot_sum += lp.dot(tp) * weights[i]
		cross_sum += (lp.x * tp.y - lp.y * tp.x) * weights[i]
		local_len_sq += lp.length_squared() * weights[i]
	if local_len_sq <= 0.01:
		return
	var rotation_value := atan2(cross_sum, dot_sum)
	var scale_value := _fit_scale_vector(meta, local_points, target_values, weights, local_center, target_center, rotation_value, landmark_name)
	_apply_sprite_transform(sprite, local_center, target_center, rotation_value, scale_value)

func _fit_scale_vector(meta: Dictionary, local_points: Array[Vector2], target_values: Array[Vector2], weights: Array[float], local_center: Vector2, target_center: Vector2, rotation_value: float, landmark_name: String) -> Vector2:
	if not bool(meta.get("fit_nonuniform", false)):
		var local_len_sq := 0.0
		var target_len_sq := 0.0
		for i in range(local_points.size()):
			local_len_sq += (local_points[i] - local_center).length_squared() * weights[i]
			target_len_sq += (target_values[i] - target_center).length_squared() * weights[i]
		var uniform_scale := sqrt(target_len_sq / max(0.01, local_len_sq)) * _scale_multiplier(landmark_name)
		return Vector2(uniform_scale, uniform_scale)

	var x_num := 0.0
	var x_den := 0.0
	var y_num := 0.0
	var y_den := 0.0
	for i in range(local_points.size()):
		var lp := local_points[i] - local_center
		var tp := (target_values[i] - target_center).rotated(-rotation_value)
		x_num += lp.x * tp.x * weights[i]
		x_den += lp.x * lp.x * weights[i]
		y_num += lp.y * tp.y * weights[i]
		y_den += lp.y * lp.y * weights[i]
	var scale_multiplier := _scale_multiplier(landmark_name)
	var sx: float = clamp(x_num / max(0.01, x_den), 0.05, 4.0) * scale_multiplier
	var sy: float = clamp(y_num / max(0.01, y_den), 0.05, 4.0) * scale_multiplier
	return Vector2(abs(sx), abs(sy))

func _fit_weight(meta: Dictionary, key: String) -> float:
	if meta.has("fit_weights") and meta["fit_weights"] is Dictionary:
		var fit_weights: Dictionary = meta["fit_weights"]
		if fit_weights.has(key):
			return float(fit_weights[key])
	return 1.0

func _place_point_part(sprite_name: String, landmark_name: String, target_point: Vector2, scale_value: float) -> void:
	var sprite: Sprite2D = part_sprites.get(sprite_name)
	if sprite == null:
		return
	var local_center := _landmark_point(landmark_name, "center")
	_apply_sprite_transform(sprite, local_center, target_point, 0.0, Vector2(scale_value, scale_value))

func _apply_sprite_transform(sprite: Sprite2D, local_anchor: Vector2, target_point: Vector2, rotation_value: float, scale_value: Vector2) -> void:
	sprite.top_level = true
	sprite.global_rotation = rotation_value
	sprite.global_scale = scale_value
	var anchor_vec := Vector2(local_anchor.x * scale_value.x, local_anchor.y * scale_value.y)
	sprite.global_position = to_global(target_point) - anchor_vec.rotated(rotation_value)

func _landmark_meta(name: String) -> Dictionary:
	var value = part_landmarks.get(name, {})
	if value is Dictionary:
		return value
	return {}

func _scale_multiplier(name: String) -> float:
	var meta := _landmark_meta(name)
	if meta.has("scale_multiplier"):
		return float(meta["scale_multiplier"])
	return 1.0

func _thickness_multiplier(name: String) -> float:
	var meta := _landmark_meta(name)
	if meta.has("thickness_multiplier"):
		return float(meta["thickness_multiplier"])
	return 1.0

func _landmark_point(name: String, point_name: String) -> Vector2:
	return _landmark_point_with_flip(name, point_name, bool(_landmark_meta(name).get("flip_h", false)))

func _landmark_point_with_flip(name: String, point_name: String, flip_h: bool) -> Vector2:
	var meta := _landmark_meta(name)
	if not meta.has("landmarks") or not (meta["landmarks"] is Dictionary):
		return Vector2.ZERO
	var landmarks: Dictionary = meta["landmarks"]
	if not landmarks.has(point_name):
		return Vector2.ZERO
	var value = landmarks[point_name]
	if not (value is Array) or value.size() < 2:
		return Vector2.ZERO
	var p := Vector2(float(value[0]), float(value[1]))
	if flip_h:
		var width := _texture_width_for_landmark(name)
		p.x = width - p.x
	return p

func _texture_width_for_landmark(name: String) -> float:
	for key in part_sprites.keys():
		if _landmark_key_for_part(String(key)) == name:
			var sprite: Sprite2D = part_sprites[key]
			if sprite.texture != null:
				return float(sprite.texture.get_width())
	return 0.0

func _landmark_key_for_part(part_name: String) -> String:
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

func _offset_target_points(points: Dictionary, delta: Vector2) -> Dictionary:
	var shifted := {}
	for key in points.keys():
		if points[key] is Vector2:
			shifted[key] = points[key] + delta
	return shifted

func _angle_between(from_point: Vector2, to_point: Vector2) -> float:
	return (to_point - from_point).angle()

func _animation_data(name: String) -> Dictionary:
	return {"duration": 1.2, "frames": _walk_frames()}

func _walk_frames() -> Array:
	var lift := 5.0
	var lean := -5.0
	return [
		{"time": 0.00, "root": Vector2(0, -132 - lift), "torso": lean, "head": 2, "nua": 18, "nfa": 12, "nhand": 0, "fua": -24, "ffa": 14, "fhand": 0, "nth": -30, "nsh": 20, "na": -5, "nf": 0, "fth": 30, "fsh": 34, "fa": -8, "ff": 0},
		{"time": 0.10, "root": Vector2(0, -126), "torso": lean + 1, "head": 1, "nua": 12, "nfa": 14, "nhand": 0, "fua": -18, "ffa": 14, "fhand": 0, "nth": -20, "nsh": 30, "na": -2, "nf": 0, "fth": 20, "fsh": 46, "fa": -10, "ff": -4},
		{"time": 0.20, "root": Vector2(0, -122), "torso": lean + 1, "head": 1, "nua": 6, "nfa": 15, "nhand": 0, "fua": -10, "ffa": 15, "fhand": 0, "nth": -8, "nsh": 42, "na": 0, "nf": 0, "fth": 10, "fsh": 58, "fa": -12, "ff": -6},
		{"time": 0.30, "root": Vector2(0, -130), "torso": lean, "head": 1, "nua": -4, "nfa": 15, "nhand": 0, "fua": 2, "ffa": 14, "fhand": 0, "nth": 8, "nsh": 40, "na": -6, "nf": -4, "fth": -4, "fsh": 38, "fa": -4, "ff": 0},
		{"time": 0.40, "root": Vector2(0, -138 - lift), "torso": lean - 1, "head": 2, "nua": -16, "nfa": 14, "nhand": 0, "fua": 14, "ffa": 12, "fhand": 0, "nth": 22, "nsh": 34, "na": -10, "nf": -8, "fth": -18, "fsh": 22, "fa": 0, "ff": 0},
		{"time": 0.50, "root": Vector2(0, -132 - lift), "torso": lean, "head": -1, "nua": -22, "nfa": 12, "nhand": 0, "fua": 20, "ffa": 12, "fhand": 0, "nth": 30, "nsh": 34, "na": -8, "nf": 0, "fth": -30, "fsh": 20, "fa": -4, "ff": 0},
		{"time": 0.60, "root": Vector2(0, -126), "torso": lean + 1, "head": 0, "nua": -16, "nfa": 14, "nhand": 0, "fua": 14, "ffa": 14, "fhand": 0, "nth": 20, "nsh": 46, "na": -12, "nf": -4, "fth": -20, "fsh": 30, "fa": -2, "ff": 0},
		{"time": 0.70, "root": Vector2(0, -122), "torso": lean + 1, "head": 0, "nua": -8, "nfa": 15, "nhand": 0, "fua": 6, "ffa": 15, "fhand": 0, "nth": 8, "nsh": 58, "na": -12, "nf": -6, "fth": -8, "fsh": 42, "fa": 0, "ff": 0},
		{"time": 0.80, "root": Vector2(0, -130), "torso": lean, "head": -1, "nua": 4, "nfa": 15, "nhand": 0, "fua": -6, "ffa": 14, "fhand": 0, "nth": -4, "nsh": 38, "na": -4, "nf": 0, "fth": 8, "fsh": 40, "fa": -6, "ff": -4},
		{"time": 0.90, "root": Vector2(0, -138 - lift), "torso": lean - 1, "head": -2, "nua": 16, "nfa": 14, "nhand": 0, "fua": -18, "ffa": 12, "fhand": 0, "nth": -18, "nsh": 24, "na": 0, "nf": 0, "fth": 22, "fsh": 34, "fa": -10, "ff": -8},
		{"time": 1.00, "root": Vector2(0, -132 - lift), "torso": lean, "head": 2, "nua": 18, "nfa": 12, "nhand": 0, "fua": -24, "ffa": 14, "fhand": 0, "nth": -30, "nsh": 20, "na": -5, "nf": 0, "fth": 30, "fsh": 34, "fa": -8, "ff": 0},
	]

func _sample_pose(frames: Array, cursor: float) -> Dictionary:
	var from_frame: Dictionary = frames[0]
	var to_frame: Dictionary = frames[frames.size() - 1]
	for i in range(frames.size() - 1):
		var a: Dictionary = frames[i]
		var b: Dictionary = frames[i + 1]
		if cursor >= a["time"] and cursor <= b["time"]:
			from_frame = a
			to_frame = b
			break
	var span: float = max(0.001, to_frame["time"] - from_frame["time"])
	var local: float = clamp((cursor - from_frame["time"]) / span, 0.0, 1.0)
	local = local * local * (3.0 - 2.0 * local)
	var pose := {}
	for key in from_frame.keys():
		if key == "time":
			continue
		var av = from_frame[key]
		var bv = to_frame[key]
		if av is Vector2:
			pose[key] = av.lerp(bv, local)
		else:
			pose[key] = lerp(float(av), float(bv), local)
	return pose

func _apply_pose(pose: Dictionary) -> void:
	body.position = pose["root"]
	torso.rotation = deg_to_rad(pose["torso"])
	head.rotation = deg_to_rad(pose["head"])
	_set_arm_pose(near_arm, near_forearm, near_hand, Vector2(62, -106), pose["nua"], pose["nfa"], pose["nhand"])
	_set_arm_pose(far_arm, far_forearm, far_hand, Vector2(42, -108), pose["fua"], pose["ffa"], pose["fhand"])
	_set_leg_pose(near_thigh, near_knee, near_shin, near_ankle, near_foot, Vector2(2, -232), pose["nth"], pose["nsh"], pose["na"], pose["nf"])
	_set_leg_pose(far_thigh, far_knee, far_shin, far_ankle, far_foot, Vector2(-20, -232), pose["fth"], pose["fsh"], pose["fa"], pose["ff"])
	_lock_lowest_foot_to_ground()

func _lock_lowest_foot_to_ground() -> void:
	if not is_inside_tree():
		return
	force_update_transform()
	var near_sole_y: float = to_local(near_foot.global_transform * Vector2(80, 173)).y
	var far_sole_y: float = to_local(far_foot.global_transform * Vector2(80, 173)).y
	body.position.y -= max(near_sole_y, far_sole_y)

func _offset(name: String) -> Vector2:
	var value = bind_offsets.get(name, Vector2.ZERO)
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func set_edit_mode(enabled: bool) -> void:
	edit_mode = enabled
	if edit_mode:
		t = 0.0
		_pose()

func get_bind_point_names() -> Array[String]:
	return [
		"torso", "head",
		"near_shoulder", "near_elbow", "near_wrist",
		"far_shoulder", "far_elbow", "far_wrist",
		"near_hip", "near_knee", "near_shin", "near_ankle", "near_foot",
		"far_hip", "far_knee", "far_shin", "far_ankle", "far_foot"
	]

func get_bind_point_position(name: String) -> Vector2:
	var node := _node_for_point(name)
	if node == null:
		return global_position
	return node.global_position

func get_compare_points() -> Dictionary:
	if current_compare_points.size() > 0:
		return current_compare_points.duplicate()
	return {
		"head": head.global_position,
		"neck": torso.global_transform * Vector2(36, -126),
		"torso": torso.global_position,
		"shoulder": near_arm.global_position,
		"elbow": near_forearm.global_position,
		"wrist": near_hand.global_position,
		"hand": near_hand.global_transform * Vector2(92, 0),
		"hip": near_thigh.global_position,
		"near_knee": near_knee.global_position,
		"near_ankle": near_ankle.global_position,
		"near_toe": near_foot.global_transform * Vector2(185, 88),
		"far_knee": far_knee.global_position,
		"far_ankle": far_ankle.global_position,
		"far_toe": far_foot.global_transform * Vector2(185, 88)
	}

func move_bind_point_global(name: String, global_pos: Vector2) -> void:
	var node := _node_for_point(name)
	if node == null:
		return
	var current_local: Vector2 = to_local(node.global_position)
	var target_local: Vector2 = to_local(global_pos)
	bind_offsets[name] = _offset(name) + target_local - current_local
	_pose()

func get_mesh_names() -> Array[String]:
	var names: Array[String] = []
	for key in part_sprites.keys():
		names.append(String(key))
	return names

func get_mesh_layers() -> Dictionary:
	var layers := {}
	for key in part_sprites.keys():
		var sprite: Sprite2D = part_sprites[key]
		layers[String(key)] = sprite.z_index
	return layers

func get_part_pose_snapshot() -> Dictionary:
	var poses := {}
	for key in part_sprites.keys():
		var sprite: Sprite2D = part_sprites[key]
		poses[String(key)] = {
			"position": sprite.global_position,
			"rotation": rad_to_deg(sprite.global_rotation),
			"scale": sprite.global_scale,
			"z": sprite.z_index
		}
	return poses

func get_part_render_snapshot() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for key in part_sprites.keys():
		var name := String(key)
		var sprite: Sprite2D = part_sprites[key]
		parts.append({
			"name": name,
			"path": String(part_texture_paths.get(name, "")),
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
	var result := {}
	for part_name in part_sprites.keys():
		var landmark_key := _landmark_key_for_part(String(part_name))
		var meta := _landmark_meta(landmark_key)
		if meta.is_empty() or not meta.has("landmarks") or not (meta["landmarks"] is Dictionary):
			continue
		var sprite: Sprite2D = part_sprites[part_name]
		var landmarks: Dictionary = meta["landmarks"]
		var part_result := {}
		for landmark_name in landmarks.keys():
			var local_point := _landmark_point_with_flip(landmark_key, String(landmark_name), sprite.flip_h)
			part_result[String(landmark_name)] = _sprite_landmark_global(sprite, local_point)
		result[String(part_name)] = part_result
	return result

func _sprite_landmark_global(sprite: Sprite2D, local_point: Vector2) -> Vector2:
	var scale_value := sprite.global_scale
	var scaled := Vector2(local_point.x * scale_value.x, local_point.y * scale_value.y)
	return sprite.global_position + scaled.rotated(sprite.global_rotation)

func get_mesh_position(name: String) -> Vector2:
	var sprite: Sprite2D = part_sprites.get(name)
	if sprite == null:
		return global_position
	return sprite.global_position

func move_mesh_global(name: String, global_delta: Vector2) -> void:
	var sprite: Sprite2D = part_sprites.get(name)
	if sprite == null:
		return
	var local_delta: Vector2 = sprite.get_parent().to_local(sprite.global_position + global_delta) - sprite.get_parent().to_local(sprite.global_position)
	bind_offsets[name] = _offset(name) + local_delta
	sprite.position += local_delta

func _node_for_point(name: String) -> Node2D:
	match name:
		"torso":
			return torso
		"head":
			return head
		"near_shoulder":
			return near_arm
		"near_elbow":
			return near_forearm
		"near_wrist":
			return near_hand
		"far_shoulder":
			return far_arm
		"far_elbow":
			return far_forearm
		"far_wrist":
			return far_hand
		"near_hip":
			return near_thigh
		"near_knee":
			return near_knee
		"near_shin":
			return near_shin
		"near_ankle":
			return near_ankle
		"near_foot":
			return near_foot
		"far_hip":
			return far_thigh
		"far_knee":
			return far_knee
		"far_shin":
			return far_shin
		"far_ankle":
			return far_ankle
		"far_foot":
			return far_foot
	return null

func save_binding() -> void:
	var data := {}
	for key in bind_offsets.keys():
		var v := _offset(String(key))
		data[key] = [v.x, v.y]
	var file := FileAccess.open(BINDING_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func load_binding() -> void:
	if not FileAccess.file_exists(BINDING_PATH):
		return
	var text := FileAccess.get_file_as_string(BINDING_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		bind_offsets = parsed

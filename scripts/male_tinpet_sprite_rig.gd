extends Node2D

const PART_DIR := "res://assets/parts/male_tinpet/"
const BINDING_PATH := "user://male_tinpet_binding.json"
const REF_POINTS_PATH := "res://assets/animation/walk_ref_points.json"
const REF_DISPLAY_SCALE := 0.72
const FOOT_TOE_LOCAL := Vector2(185, 88)
const PART_DRAW_ORDER := {
	"far_thigh_mesh": -80,
	"far_shin_mesh": -79,
	"far_knee_mesh": -78,
	"far_ankle_mesh": -77,
	"far_foot_mesh": -76,
	"far_upper_arm_mesh": -60,
	"far_forearm_mesh": -59,
	"far_shoulder_mesh": -58,
	"far_hand_mesh": -57,
	"torso_mesh": 0,
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
var reference_walk_frames: Array = []
var current_compare_points: Dictionary = {}

func _ready() -> void:
	add_child(body)
	body.scale = Vector2(0.42, 0.42)
	load_binding()
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
	torso.add_child(head)
	torso.add_child(far_arm)
	far_arm.add_child(far_forearm)
	far_forearm.add_child(far_hand)
	torso.add_child(near_arm)
	near_arm.add_child(near_forearm)
	near_forearm.add_child(near_hand)

	part_sprites["torso_mesh"] = _add_part(torso, "torso_side.png", Vector2(82, 218), 1.0, false, 0.0, "torso_mesh")
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
	# The source foot faces left. Flip it so toe direction matches the right-facing walk reference.
	part_sprites[prefix + "_foot_mesh"] = _add_part(foot, "foot_side.png", Vector2(72, 48), alpha, true, 290, prefix + "_foot_mesh")

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
		_apply_reference_pose(ref_pose)
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

func _apply_reference_pose(points: Dictionary) -> void:
	if not _has_reference_points(points):
		return
	current_compare_points.clear()
	body.position = Vector2.ZERO
	body.rotation = 0.0
	body.scale = Vector2(0.42, 0.42)
	torso.rotation = 0.0
	head.rotation = 0.0
	for node in [near_arm, near_forearm, near_hand, far_arm, far_forearm, far_hand, near_thigh, near_knee, near_shin, near_ankle, near_foot, far_thigh, far_knee, far_shin, far_ankle, far_foot]:
		node.rotation = 0.0
		node.scale = Vector2.ONE

	var origin: Vector2 = points["hip"]
	var ground_y: float = max(float(points["near_toe"].y), float(points["far_toe"].y))
	_cache_reference_compare_points(points, origin, ground_y)

	_set_global_point(torso, _reference_to_rig(points["torso"], origin, ground_y))
	_set_global_point(head, _reference_to_rig(points["head"], origin, ground_y))
	head.global_rotation = _angle_between(points["neck"], points["head"])

	_apply_arm_reference(near_arm, near_forearm, near_hand, points, "shoulder", "elbow", "wrist", "hand", origin, ground_y)
	_apply_arm_reference(far_arm, far_forearm, far_hand, points, "shoulder", "elbow", "wrist", "hand", origin, ground_y)
	_apply_leg_reference(near_thigh, near_knee, near_shin, near_ankle, near_foot, points, "hip", "near_knee", "near_ankle", "near_toe", origin, ground_y)
	_apply_leg_reference(far_thigh, far_knee, far_shin, far_ankle, far_foot, points, "hip", "far_knee", "far_ankle", "far_toe", origin, ground_y)

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
	var hand_vector := hand_tip - wrist
	if hand_vector.length() > 1.0:
		var global_scale: float = max(0.001, body.global_scale.x)
		var hand_scale: float = hand_vector.length() / (92.0 * global_scale)
		hand_node.scale = Vector2(hand_scale, hand_scale)

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
		var global_scale: float = max(0.001, body.global_scale.x)
		var foot_scale: float = toe_vector.length() / (FOOT_TOE_LOCAL.length() * global_scale)
		foot.scale = Vector2(foot_scale, foot_scale)

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

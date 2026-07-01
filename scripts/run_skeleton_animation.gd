extends Node2D

const SHAPE_PATH := "res://assets/animation/run_skeleton_20f.json"
const KEYFRAME_PATH := "res://assets/animation/run_skeleton_keyframes.json"
const POINT_RADIUS := 2.2
const POINT_OUTLINE_RADIUS := 3.2
const JOINT_RADIUS := 5.5
const JOINT_OUTLINE_RADIUS := 7.0

const ORDER := [
	"head",
	"torso",
	"left_upper_arm",
	"left_forearm",
	"left_hand",
	"right_upper_arm",
	"right_forearm",
	"right_hand",
	"left_thigh",
	"left_shin",
	"left_foot",
	"right_thigh",
	"right_shin",
	"right_foot"
]
const LABELS := {
	"head": "Head",
	"torso": "Torso",
	"left_upper_arm": "Left upper arm",
	"left_forearm": "Left forearm",
	"left_hand": "Left hand",
	"right_upper_arm": "Right upper arm",
	"right_forearm": "Right forearm",
	"right_hand": "Right hand",
	"left_thigh": "Left thigh",
	"left_shin": "Left shin",
	"left_foot": "Left foot",
	"right_thigh": "Right thigh",
	"right_shin": "Right shin",
	"right_foot": "Right foot"
}
const LINKS := [
	["head", "torso"],
	["torso", "left_upper_arm"],
	["left_upper_arm", "left_forearm"],
	["left_forearm", "left_hand"],
	["torso", "right_upper_arm"],
	["right_upper_arm", "right_forearm"],
	["right_forearm", "right_hand"],
	["torso", "left_thigh"],
	["left_thigh", "left_shin"],
	["left_shin", "left_foot"],
	["torso", "right_thigh"],
	["right_thigh", "right_shin"],
	["right_shin", "right_foot"]
]

var groups: Dictionary = {}
var colors: Dictionary = {}
var keyframes: Array[Dictionary] = []
var t := 0.0
var duration := 1.0
var font := ThemeDB.fallback_font

func _ready() -> void:
	_load_data()
	set_process(true)

func _process(delta: float) -> void:
	t = fmod(t + delta, duration)
	queue_redraw()

func _draw() -> void:
	if groups.is_empty() or keyframes.is_empty():
		return
	var pose := _pose_transforms(t / duration)

	for link in LINKS:
		var a: Vector2 = pose[link[0]]["joint"]
		var b: Vector2 = pose[link[1]]["joint"]
		draw_line(a, b, Color(0.82, 0.86, 0.9, 0.58), 2.2)

	for name in ORDER:
		var center: Vector2 = pose[name]["center"]
		var rotation: float = pose[name]["rotation"]
		var scale: Vector2 = pose[name].get("scale", Vector2.ONE)
		var color: Color = colors[name]
		var world_points := _world_points(name, center, rotation, scale)
		draw_colored_polygon(world_points, Color(color.r, color.g, color.b, 0.11))
		for i in range(world_points.size()):
			draw_line(world_points[i], world_points[(i + 1) % world_points.size()], color, 1.6)
		for p in world_points:
			draw_circle(p, POINT_RADIUS, Color(color.r, color.g, color.b, 0.95))
			draw_arc(p, POINT_OUTLINE_RADIUS, 0.0, TAU, 12, Color.WHITE, 0.55)
		draw_circle(center, JOINT_RADIUS, color)
		draw_arc(center, JOINT_OUTLINE_RADIUS, 0.0, TAU, 20, Color.WHITE, 1.2)

	_draw_legend()

func _pose_transforms(cycle_position: float) -> Dictionary:
	var scaled := fposmod(cycle_position, 1.0) * keyframes.size()
	var index_a := int(floor(scaled)) % keyframes.size()
	var index_b := (index_a + 1) % keyframes.size()
	var amount := _smoothstep(scaled - floor(scaled))
	var joints := _interpolate_joints(keyframes[index_a]["joints"], keyframes[index_b]["joints"], amount)
	var pose := _build_pose_from_joints(joints)
	_lock_pose_to_ground(pose)
	return pose

func _interpolate_joints(a: Dictionary, b: Dictionary, amount: float) -> Dictionary:
	var out := {}
	for key in a.keys():
		out[key] = Vector2(a[key]).lerp(Vector2(b[key]), amount)
	return out

func _build_pose_from_joints(joints: Dictionary) -> Dictionary:
	var neck: Vector2 = joints["neck"]
	var head_center: Vector2 = joints["head"]
	var chest: Vector2 = joints["chest"]
	var pelvis: Vector2 = joints["pelvis"]
	var torso_center := (chest + pelvis) * 0.5
	var torso_rotation := (pelvis - chest).angle() - PI * 0.5

	return {
		"head": _part_transform(head_center, neck, (head_center - neck).angle() - PI * 0.5, head_center),
		"torso": _part_transform(torso_center, torso_center, torso_rotation, torso_center),
		"left_upper_arm": _limb_transform("left_upper_arm", joints["left_shoulder"], joints["left_elbow"]),
		"left_forearm": _limb_transform("left_forearm", joints["left_elbow"], joints["left_wrist"]),
		"left_hand": _hand_transform("left_hand", joints["left_wrist"], joints["left_hand"]),
		"right_upper_arm": _limb_transform("right_upper_arm", joints["right_shoulder"], joints["right_elbow"]),
		"right_forearm": _limb_transform("right_forearm", joints["right_elbow"], joints["right_wrist"]),
		"right_hand": _hand_transform("right_hand", joints["right_wrist"], joints["right_hand"]),
		"left_thigh": _limb_transform("left_thigh", joints["left_hip"], joints["left_knee"]),
		"left_shin": _limb_transform("left_shin", joints["left_knee"], joints["left_ankle"]),
		"left_foot": _foot_transform("left_foot", joints["left_ankle"], joints["left_toe"]),
		"right_thigh": _limb_transform("right_thigh", joints["right_hip"], joints["right_knee"]),
		"right_shin": _limb_transform("right_shin", joints["right_knee"], joints["right_ankle"]),
		"right_foot": _foot_transform("right_foot", joints["right_ankle"], joints["right_toe"])
	}

func _lock_pose_to_ground(pose: Dictionary) -> void:
	var lowest := -INF
	for name in ORDER:
		var center: Vector2 = pose[name]["center"]
		var rotation: float = pose[name]["rotation"]
		var scale: Vector2 = pose[name].get("scale", Vector2.ONE)
		for p in _world_points(name, center, rotation, scale):
			lowest = max(lowest, p.y)
	var offset := Vector2(0.0, -lowest)
	for name in ORDER:
		pose[name]["center"] = Vector2(pose[name]["center"]) + offset
		pose[name]["joint"] = Vector2(pose[name]["joint"]) + offset

func _world_points(name: String, center: Vector2, rotation: float, scale: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var world_points: PackedVector2Array = []
	for local_point in groups[name]:
		var local := Vector2(local_point)
		world_points.append(center + Vector2(local.x * scale.x, local.y * scale.y).rotated(rotation))
	return world_points

func _limb_transform(name: String, root_point: Vector2, end_point: Vector2) -> Dictionary:
	var center := (root_point + end_point) * 0.5
	var rotation := (end_point - root_point).angle() - PI * 0.5
	var scale := _segment_scale(name, root_point.distance_to(end_point), true)
	return _part_transform(center, root_point, rotation, center, scale)

func _foot_transform(name: String, ankle: Vector2, toe: Vector2) -> Dictionary:
	var center := (ankle + toe) * 0.5
	var rotation := (toe - ankle).angle()
	var scale := _segment_scale(name, ankle.distance_to(toe), false)
	return _part_transform(center, ankle, rotation, center, scale)

func _hand_transform(name: String, wrist: Vector2, hand_tip: Vector2) -> Dictionary:
	var center := (wrist + hand_tip) * 0.5
	var rotation := (hand_tip - wrist).angle()
	var scale := _segment_scale(name, wrist.distance_to(hand_tip), false)
	return _part_transform(center, wrist, rotation, center, scale)

func _part_transform(center: Vector2, joint: Vector2, rotation: float, draw_center: Vector2, scale: Vector2 = Vector2.ONE) -> Dictionary:
	return {
		"center": draw_center,
		"joint": joint,
		"rotation": rotation,
		"scale": scale
	}

func _segment_scale(name: String, target_length: float, vertical_axis: bool) -> Vector2:
	var bounds := _local_bounds(name)
	var source_length: float
	if vertical_axis:
		source_length = max(1.0, bounds.size.y)
	else:
		source_length = max(1.0, bounds.size.x)
	var major := target_length / source_length
	var minor := clampf(major * 0.92, 0.45, 1.0)
	if vertical_axis:
		return Vector2(minor, major)
	return Vector2(major, clampf(major, 0.42, 1.0))

func _local_bounds(name: String) -> Rect2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for local_point in groups[name]:
		var p := Vector2(local_point)
		min_p.x = min(min_p.x, p.x)
		min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x)
		max_p.y = max(max_p.y, p.y)
	return Rect2(min_p, max_p - min_p)

func _smoothstep(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _draw_legend() -> void:
	var x := -420.0
	var y := -275.0
	draw_string(font, Vector2(x, y - 20), "Reference-frame contour rig: 14 parts, 20 outline points each", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	for name in ORDER:
		var color: Color = colors[name]
		draw_circle(Vector2(x, y), 5.0, color)
		draw_string(font, Vector2(x + 16.0, y + 5.0), "%s  20 points" % LABELS[name], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		y += 19.0

func _load_data() -> void:
	_load_shapes()
	_load_keyframes()

func _load_shapes() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SHAPE_PATH))
	if not (parsed is Dictionary):
		push_error("Invalid run skeleton shape data.")
		return
	var point_count := int(parsed.get("points_per_group", 20))
	var raw_groups: Dictionary = parsed.get("groups", {})
	for name in ORDER:
		if not raw_groups.has(name):
			push_error("Missing run skeleton group: %s" % name)
			continue
		var data: Dictionary = raw_groups[name]
		colors[name] = Color(String(data.get("color", "#ffffff")))
		var out: Array[Vector2] = []
		for value in data.get("points", []):
			if value is Array and value.size() >= 2:
				out.append(Vector2(float(value[0]), float(value[1])))
		if out.size() != point_count:
			push_error("%s must have exactly %d outline points, got %d." % [name, point_count, out.size()])
		groups[name] = out

func _load_keyframes() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(KEYFRAME_PATH))
	if not (parsed is Dictionary):
		push_error("Invalid run skeleton keyframe data.")
		return
	duration = float(parsed.get("duration", duration))
	keyframes.clear()
	for frame in parsed.get("frames", []):
		if not (frame is Dictionary):
			continue
		var joints := {}
		for key in frame.get("joints", {}).keys():
			var value = frame["joints"][key]
			if value is Array and value.size() >= 2:
				joints[key] = Vector2(float(value[0]), float(value[1]))
		keyframes.append({
			"name": String(frame.get("name", "")),
			"joints": joints
		})

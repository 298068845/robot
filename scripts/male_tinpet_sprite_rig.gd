extends Node2D

const PART_DIR := "res://assets/parts/male_tinpet/"
const BINDING_PATH := "user://male_tinpet_binding.json"

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

func _ready() -> void:
	add_child(body)
	body.scale = Vector2(0.42, 0.42)
	load_binding()
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

	part_sprites["torso_mesh"] = _add_part(torso, "torso_side.png", Vector2(82, 218), 2, 1.0, false, 0.0, "torso_mesh")
	part_sprites["head_mesh"] = _add_part(head, "head_side.png", Vector2(142, 152), 8, 1.0, true, 266, "head_mesh")
	_add_arm_parts(far_arm, far_forearm, far_hand, 0.52, -1)
	_add_arm_parts(near_arm, near_forearm, near_hand, 1.0, 6)
	_add_leg_parts(far_thigh, far_knee, far_shin, far_ankle, far_foot, 0.46, -2)
	_add_leg_parts(near_thigh, near_knee, near_shin, near_ankle, near_foot, 1.0, 4)

func _add_arm_parts(upper: Node2D, forearm: Node2D, hand_node: Node2D, alpha: float, z: int) -> void:
	var prefix := "near" if alpha > 0.9 else "far"
	part_sprites[prefix + "_shoulder_mesh"] = _add_part(upper, "shoulder_joint.png", Vector2(96, 82), z + 2, alpha, false, 0.0, prefix + "_shoulder_mesh")
	part_sprites[prefix + "_upper_arm_mesh"] = _add_part(upper, "upper_arm_tube.png", Vector2(18, 39), z + 1, alpha, false, 0.0, prefix + "_upper_arm_mesh")
	part_sprites[prefix + "_forearm_mesh"] = _add_part(forearm, "forearm_tube.png", Vector2(18, 41), z + 1, alpha, false, 0.0, prefix + "_forearm_mesh")
	part_sprites[prefix + "_hand_mesh"] = _add_part(hand_node, "hand_side.png", Vector2(33, 84), z + 3, alpha, false, 0.0, prefix + "_hand_mesh")

func _add_leg_parts(thigh: Node2D, knee: Node2D, shin: Node2D, ankle: Node2D, foot: Node2D, alpha: float, z: int) -> void:
	var prefix := "near" if alpha > 0.9 else "far"
	part_sprites[prefix + "_thigh_mesh"] = _add_part(thigh, "thigh_tube.png", Vector2(40, 28), z, alpha, false, 0.0, prefix + "_thigh_mesh")
	part_sprites[prefix + "_knee_mesh"] = _add_part(knee, "knee_joint.png", Vector2(66, 98), z + 2, alpha, false, 0.0, prefix + "_knee_mesh")
	part_sprites[prefix + "_shin_mesh"] = _add_part(shin, "shin_tube.png", Vector2(38, 28), z, alpha, false, 0.0, prefix + "_shin_mesh")
	part_sprites[prefix + "_ankle_mesh"] = _add_part(ankle, "ankle_joint.png", Vector2(56, 88), z + 2, alpha, false, 0.0, prefix + "_ankle_mesh")
	# The source foot faces left. Flip it so toe direction matches the right-facing walk reference.
	part_sprites[prefix + "_foot_mesh"] = _add_part(foot, "foot_side.png", Vector2(72, 48), z + 3, alpha, true, 290, prefix + "_foot_mesh")

func _add_part(parent: Node2D, file_name: String, anchor: Vector2, z: int, alpha := 1.0, flip_h := false, width := 0.0, part_name := "") -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _load_texture(PART_DIR + file_name)
	sprite.centered = false
	sprite.flip_h = flip_h
	sprite.position = -anchor
	if flip_h:
		sprite.position.x = -(width - anchor.x)
	if part_name != "":
		sprite.position += _offset(part_name)
	sprite.z_index = z
	sprite.modulate.a = alpha
	parent.add_child(sprite)
	return sprite

func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_error("Could not load part texture: %s" % path)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)

func _reset_pose() -> void:
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
	var data := _animation_data(action)
	var duration: float = data["duration"]
	var cursor: float = fmod(t, duration) / duration
	var pose: Dictionary = _sample_pose(data["frames"], cursor)
	_apply_pose(pose)

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

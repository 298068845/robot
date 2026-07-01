extends Node2D

const TEMPLATE_PATH := "res://assets/animation/runner_skeleton_template.json"
const KEYFRAME_PATH := "res://assets/animation/runner_skeleton_keyframes.json"
const REFERENCE_PATH := "res://assets/animation/runner_reference_sheet_8f.png"
const GROUP_ORDER := ["legs", "torso", "arms", "head"]

var groups: Dictionary = {}
var keyframes: Array = []
var reference_texture: Texture2D
var t := 0.0
var duration := 0.8

func _ready() -> void:
	_load_data()
	set_process(true)

func _process(delta: float) -> void:
	t = fmod(t + delta, duration)
	queue_redraw()

func _draw() -> void:
	if groups.is_empty() or keyframes.is_empty():
		return
	_draw_reference()
	var pose := _pose(t / duration)
	for name in GROUP_ORDER:
		_draw_group(name, pose[name])

func _draw_reference() -> void:
	if reference_texture == null:
		return
	var target_height := 430.0
	var target_width := target_height * float(reference_texture.get_width()) / float(reference_texture.get_height())
	draw_texture_rect(reference_texture, Rect2(Vector2(-target_width * 0.5, -target_height + 20.0), Vector2(target_width, target_height)), false, Color(1, 1, 1, 0.28))

func _draw_group(name: String, transform_data: Dictionary) -> void:
	var group: Dictionary = groups[name]
	var color := Color(String(group["color"]))
	var center: Vector2 = transform_data["position"]
	var rotation: float = transform_data["rotation"]
	var points: Array = group["points"]
	for point in points:
		var local := Vector2(float(point[0]), float(point[1]))
		var p := center + local.rotated(rotation)
		draw_circle(p, 1.4, color)
	for i in range(points.size()):
		var a := center + Vector2(float(points[i][0]), float(points[i][1])).rotated(rotation)
		var b := center + Vector2(float(points[(i + 1) % points.size()][0]), float(points[(i + 1) % points.size()][1])).rotated(rotation)
		if a.distance_to(b) < 16.0:
			draw_line(a, b, color, 1.0)
	draw_circle(center, 3.0, color)

func _pose(cycle: float) -> Dictionary:
	var scaled := fposmod(cycle, 1.0) * keyframes.size()
	var ia := int(floor(scaled)) % keyframes.size()
	var ib := (ia + 1) % keyframes.size()
	var amount := _smoothstep(scaled - floor(scaled))
	var out := {}
	var root_a := _raw_position(keyframes[ia]["transforms"]["torso"])
	var root_b := _raw_position(keyframes[ib]["transforms"]["torso"])
	for name in GROUP_ORDER:
		var a: Dictionary = keyframes[ia]["transforms"]
		var b: Dictionary = keyframes[ib]["transforms"]
		var av: Array = a[name]
		var bv: Array = b[name]
		var pos_a := _normalize_frame_position(_raw_position(av), root_a)
		var pos_b := _normalize_frame_position(_raw_position(bv), root_b)
		var pos := pos_a.lerp(pos_b, amount)
		var rot := lerp_angle(float(av[2]), float(bv[2]), amount)
		out[name] = {
			"position": pos,
			"rotation": rot
		}
	return out

func _raw_position(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))

func _normalize_frame_position(point: Vector2, root: Vector2) -> Vector2:
	var fixed_root := Vector2(0.0, -175.0)
	return fixed_root + (point - root) * 0.95

func _smoothstep(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _load_data() -> void:
	var template = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATE_PATH))
	if template is Dictionary:
		groups = template.get("groups", {})
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(KEYFRAME_PATH))
	if parsed is Dictionary:
		duration = float(parsed.get("duration", duration))
		keyframes = parsed.get("frames", [])
	var image := Image.new()
	if image.load(REFERENCE_PATH) == OK:
		reference_texture = ImageTexture.create_from_image(image)

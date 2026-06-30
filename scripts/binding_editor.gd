extends Control

const MaleTinpetSpriteRig = preload("res://scripts/male_tinpet_sprite_rig.gd")

var rig: Node2D
var ground_line: ColorRect
var save_button: Button
var selected_kind := ""
var selected_name := ""
var last_mouse := Vector2.ZERO

var colors := {
	"torso": Color("#ff4d4d"),
	"head": Color("#ffb84d"),
	"near": Color("#4da3ff"),
	"far": Color("#7f8c99"),
	"leg": Color("#4dff88"),
	"mesh": Color("#d24dff")
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	ground_line = ColorRect.new()
	ground_line.color = Color(0.28, 0.31, 0.34, 1.0)
	ground_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground_line)

	rig = MaleTinpetSpriteRig.new()
	add_child(rig)
	rig.set_edit_mode(true)

	save_button = Button.new()
	save_button.text = "保存"
	save_button.custom_minimum_size = Vector2(96, 36)
	save_button.position = Vector2(18, 18)
	save_button.pressed.connect(_save_binding)
	add_child(save_button)

	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var ground_y: float = max(360.0, size.y - 58.0)
	if rig != null:
		rig.position = Vector2(size.x * 0.5 - 24.0, ground_y)
	if ground_line != null:
		ground_line.position = Vector2(48.0, ground_y + 1.0)
		ground_line.size = Vector2(max(0.0, size.x - 96.0), 2.0)
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			last_mouse = event.position
			_pick(event.position)
		else:
			selected_kind = ""
			selected_name = ""
	elif event is InputEventMouseMotion and selected_name != "":
		var delta: Vector2 = event.position - last_mouse
		last_mouse = event.position
		if selected_kind == "point":
			rig.move_bind_point_global(selected_name, get_global_transform() * event.position)
		elif selected_kind == "mesh":
			rig.move_mesh_global(selected_name, delta)
		queue_redraw()

func _pick(pos: Vector2) -> void:
	var best_name := ""
	var best_kind := ""
	var best_dist := 999999.0
	for name in rig.get_bind_point_names():
		var p: Vector2 = get_global_transform().affine_inverse() * rig.get_bind_point_position(name)
		var dist := p.distance_to(pos)
		if dist < best_dist and dist <= 14.0:
			best_dist = dist
			best_name = name
			best_kind = "point"
	if best_name == "":
		for name in rig.get_mesh_names():
			var p: Vector2 = get_global_transform().affine_inverse() * rig.get_mesh_position(name)
			var dist := p.distance_to(pos)
			if dist < best_dist and dist <= 42.0:
				best_dist = dist
				best_name = name
				best_kind = "mesh"
	selected_name = best_name
	selected_kind = best_kind

func _draw() -> void:
	if rig == null:
		return
	for name in rig.get_mesh_names():
		var p: Vector2 = get_global_transform().affine_inverse() * rig.get_mesh_position(name)
		draw_circle(p, 5.0, colors.mesh)
		draw_arc(p, 11.0, 0.0, TAU, 24, colors.mesh, 1.5)
	for name in rig.get_bind_point_names():
		var p: Vector2 = get_global_transform().affine_inverse() * rig.get_bind_point_position(name)
		var color := _color_for_point(name)
		draw_circle(p, 8.0, color)
		draw_arc(p, 12.0, 0.0, TAU, 24, Color.BLACK, 1.5)
	if selected_name != "":
		var p := Vector2.ZERO
		if selected_kind == "point":
			p = get_global_transform().affine_inverse() * rig.get_bind_point_position(selected_name)
		else:
			p = get_global_transform().affine_inverse() * rig.get_mesh_position(selected_name)
		draw_arc(p, 18.0, 0.0, TAU, 32, Color.WHITE, 2.0)

func _color_for_point(name: String) -> Color:
	if name == "torso":
		return colors.torso
	if name == "head":
		return colors.head
	if name.begins_with("far"):
		return colors.far
	if name.contains("hip") or name.contains("knee") or name.contains("ankle") or name.contains("foot") or name.contains("shin"):
		return colors.leg
	return colors.near

func _save_binding() -> void:
	rig.save_binding()

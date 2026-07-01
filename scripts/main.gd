extends Control

const MaleTinpetSpriteRig = preload("res://scripts/male_tinpet_cutout_rig.gd")
const BindingEditor = preload("res://scripts/binding_editor.gd")
const AutoComparePanel = preload("res://scripts/auto_compare_panel.gd")
const PartCalibrationEditor = preload("res://scripts/part_calibration_editor.gd")

var rig: Node2D
var binding_editor: Control
var part_calibration_editor: Control
var compare_panel: Control
var stage: Control
var ground_line: ColorRect

func _ready() -> void:
	_build_ui()
	_show_binding_editor()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 58)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)

	var bind_button := Button.new()
	bind_button.text = "骨骼绑定"
	bind_button.custom_minimum_size = Vector2(116, 40)
	bind_button.pressed.connect(_show_binding_editor)
	top.add_child(bind_button)

	var stand_button := Button.new()
	stand_button.text = "站立展示"
	stand_button.custom_minimum_size = Vector2(116, 40)
	stand_button.pressed.connect(_show_stand)
	top.add_child(stand_button)

	var animation_button := Button.new()
	animation_button.text = "动画演示"
	animation_button.custom_minimum_size = Vector2(116, 40)
	animation_button.pressed.connect(_show_animation)
	top.add_child(animation_button)

	var calibration_button := Button.new()
	calibration_button.text = "贴图校准"
	calibration_button.custom_minimum_size = Vector2(116, 40)
	calibration_button.pressed.connect(_show_part_calibration)
	top.add_child(calibration_button)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	stage = Control.new()
	stage.clip_contents = true
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(stage)

	ground_line = ColorRect.new()
	ground_line.color = Color(0.28, 0.31, 0.34, 1.0)
	ground_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(ground_line)

	rig = MaleTinpetSpriteRig.new()
	stage.add_child(rig)

	binding_editor = BindingEditor.new()
	binding_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(binding_editor)

	part_calibration_editor = PartCalibrationEditor.new()
	part_calibration_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	part_calibration_editor.visible = false
	stage.add_child(part_calibration_editor)

	compare_panel = AutoComparePanel.new()
	compare_panel.position = Vector2(18, 18)
	compare_panel.visible = false
	stage.add_child(compare_panel)

	stage.resized.connect(_layout_stage)
	_layout_stage()

func _layout_stage() -> void:
	if stage == null:
		return
	var ground_y: float = max(360.0, stage.size.y - 58.0)
	if rig != null:
		rig.position = Vector2(stage.size.x * 0.5 - 24.0, ground_y)
	if ground_line != null:
		ground_line.position = Vector2(48.0, ground_y + 1.0)
		ground_line.size = Vector2(max(0.0, stage.size.x - 96.0), 2.0)

func _show_binding_editor() -> void:
	if rig != null:
		rig.visible = false
	if ground_line != null:
		ground_line.visible = false
	if binding_editor != null:
		binding_editor.visible = true
	if part_calibration_editor != null:
		part_calibration_editor.visible = false
	if compare_panel != null:
		compare_panel.visible = false

func _show_animation() -> void:
	if binding_editor != null:
		binding_editor.visible = false
	if part_calibration_editor != null:
		part_calibration_editor.visible = false
	if rig != null:
		rig.queue_free()
	rig = MaleTinpetSpriteRig.new()
	stage.add_child(rig)
	rig.play_action("walk")
	_layout_stage()
	if ground_line != null:
		ground_line.visible = true
	if compare_panel != null:
		compare_panel.visible = true

func _show_stand() -> void:
	if binding_editor != null:
		binding_editor.visible = false
	if part_calibration_editor != null:
		part_calibration_editor.visible = false
	if rig != null:
		rig.queue_free()
	rig = MaleTinpetSpriteRig.new()
	stage.add_child(rig)
	rig.play_action("stand")
	_layout_stage()
	if ground_line != null:
		ground_line.visible = true
	if compare_panel != null:
		compare_panel.visible = false

func _show_part_calibration() -> void:
	if rig != null:
		rig.visible = false
	if ground_line != null:
		ground_line.visible = false
	if binding_editor != null:
		binding_editor.visible = false
	if compare_panel != null:
		compare_panel.visible = false
	if part_calibration_editor != null:
		part_calibration_editor.visible = true

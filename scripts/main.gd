extends Control

const StickFigureEditor = preload("res://scripts/stick_figure_editor.gd")

var stick_figure_editor: Control

func _ready() -> void:
	stick_figure_editor = StickFigureEditor.new()
	stick_figure_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stick_figure_editor)

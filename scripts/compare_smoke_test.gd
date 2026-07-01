extends SceneTree

const AutoComparePanel = preload("res://scripts/auto_compare_panel.gd")

func _initialize() -> void:
	var panel := AutoComparePanel.new()
	get_root().add_child(panel)
	await process_frame
	await panel._run_compare()
	print(panel.result_label.text)
	if panel.debug_rect.texture == null:
		push_error("Auto compare did not generate a debug texture.")
		quit(1)
		return
	if panel.result_label.text.begins_with("通过") or panel.result_label.text.begins_with("閫氳繃"):
		quit(0)
		return
	if panel.result_label.text.begins_with("失败") or panel.result_label.text.begins_with("澶辫触"):
		quit(1)
		return
	push_error("Auto compare did not produce a valid result label.")
	quit(1)

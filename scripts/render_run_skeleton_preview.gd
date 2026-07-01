extends SceneTree

const RunSkeleton = preload("res://scripts/run_skeleton_animation.gd")

func _initialize() -> void:
	var run := RunSkeleton.new()
	get_root().add_child(run)
	run._load_data()
	print("groups=%d keyframes=%d duration=%.2f" % [run.groups.size(), run.keyframes.size(), run.duration])
	for name in run.ORDER:
		print("%s points=%d" % [name, run.groups[name].size()])

	for i in range(run.keyframes.size()):
		run.t = run.duration * float(i) / float(run.keyframes.size())
		run.queue_redraw()
		var pose: Dictionary = run._pose_transforms(float(i) / float(run.keyframes.size()))
		var left_foot: Vector2 = pose["left_foot"]["center"]
		var right_foot: Vector2 = pose["right_foot"]["center"]
		var lowest := -INF
		var left_lowest := -INF
		var right_lowest := -INF
		for name in run.ORDER:
			var center: Vector2 = pose[name]["center"]
			var rotation: float = pose[name]["rotation"]
			var scale: Vector2 = pose[name].get("scale", Vector2.ONE)
			for p in run._world_points(name, center, rotation, scale):
				lowest = max(lowest, p.y)
				if name == "left_foot":
					left_lowest = max(left_lowest, p.y)
				elif name == "right_foot":
					right_lowest = max(right_lowest, p.y)
		print("frame %d lowest_y=%.2f left_lowest=%.2f right_lowest=%.2f left_foot=(%.1f, %.1f) right_foot=(%.1f, %.1f)" % [i + 1, lowest, left_lowest, right_lowest, left_foot.x, left_foot.y, right_foot.x, right_foot.y])
	print(ProjectSettings.globalize_path("user://"))
	quit(0)

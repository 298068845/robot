extends SceneTree

const Rig := preload("res://scripts/male_tinpet_cutout_rig.gd")

func _initialize() -> void:
	var rig := Rig.new()
	get_root().add_child(rig)
	rig.position = Vector2(0, 0)
	await process_frame
	rig.play_action("walk")
	var lines: Array[String] = []
	for i in 10:
		rig.t = 1.2 * float(i) / 10.0
		rig._pose()
		rig.force_update_transform()
		var landmarks := rig.get_part_landmark_positions()
		var near_y: float = landmarks["near_foot_mesh"]["toe"].y
		var far_y: float = landmarks["far_foot_mesh"]["toe"].y
		lines.append("frame %02d near_sole_y=%.2f far_sole_y=%.2f" % [i + 1, near_y, far_y])
	print("\n".join(lines))
	quit(0)

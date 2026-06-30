extends SceneTree

const Rig := preload("res://scripts/male_tinpet_sprite_rig.gd")

func _initialize() -> void:
	var rig := Rig.new()
	get_root().add_child(rig)
	rig.position = Vector2(0, 0)
	rig.play_action("walk")
	await process_frame
	var lines: Array[String] = []
	for i in 10:
		rig.t = 1.2 * float(i) / 10.0
		rig._pose()
		rig.force_update_transform()
		var near_y: float = (rig.near_foot.global_transform * Vector2(80, 173)).y
		var far_y: float = (rig.far_foot.global_transform * Vector2(80, 173)).y
		lines.append("frame %02d near_sole_y=%.2f far_sole_y=%.2f" % [i + 1, near_y, far_y])
	print("\n".join(lines))
	quit(0)

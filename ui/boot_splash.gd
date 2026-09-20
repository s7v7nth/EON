extends Control
## First paint only. No art banks, no campaign graph, no SFX.
## Class select loads after one drawn frame so an M1 Air sees something immediately.


func _ready() -> void:
	print("BOOT_SPLASH_READY")
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://ui/class_select.tscn")

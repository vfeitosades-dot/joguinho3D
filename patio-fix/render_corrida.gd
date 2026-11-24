extends SceneTree

func _initialize() -> void:
	call_deferred("executar")

func executar() -> void:
	root.size = Vector2i(640,480)
	var cena := (load("res://patio.tscn") as PackedScene).instantiate()
	root.add_child(cena)
	await process_frame
	var ator = cena.get_node("Personagem")
	ator.set_physics_process(false)
	ator.set_process(false)
	ator.modelo.rotation.y = 0.0
	ator.velocidade = 5.24
	ator.velocidade_visual = 5.24
	cena.get_node("Interface").hide()
	var cam := cena.get_node("Camera") as Camera3D
	var centro: Vector3 = ator.global_position+Vector3.UP*1.0
	cam.fov = 42.0
	for vista in range(2):
		var offset := Vector3(0.0,0.12,3.15) if vista == 0 else Vector3(3.15,0.12,0.0)
		cam.position = centro+offset
		cam.look_at(centro)
		for k in range(4):
			ator.fase = float(k)/4.0
			ator.animar(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.save_png("/tmp/pose_%d_%d.png" % [vista,k])
	print("RENDER_OK")
	quit()

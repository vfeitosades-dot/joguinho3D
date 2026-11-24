extends SceneTree

func _initialize() -> void:
	call_deferred("executar")

func executar() -> void:
	var cena := (load("res://patio.tscn") as PackedScene).instantiate()
	root.add_child(cena)
	await process_frame
	var ator = cena.get_node("Personagem")
	ator.set_physics_process(false)
	ator.set_process(false)
	ator.modelo.rotation.y = 0.0
	var s := ator.modelo.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var base := s.global_transform.basis.orthonormalized().inverse()*ator.modelo.global_transform.basis.orthonormalized()
	var direita := (base*Vector3.RIGHT).normalized()
	var min_ang := 180.0
	var max_ang := 0.0
	var min_lateral := 99.0
	var min_alinhamento := 1.0
	ator.velocidade = 5.24
	for i in range(240):
		ator.animar(1.0/60.0)
		s.force_update_all_bone_transforms()
		if i < 45:
			continue
		var peito := s.get_bone_global_pose(s.find_bone("spine_03")).origin
		for lado in ["l","r"]:
			var a := s.get_bone_global_pose(s.find_bone("upperarm_"+lado)).origin
			var b := s.get_bone_global_pose(s.find_bone("lowerarm_"+lado)).origin
			var c := s.get_bone_global_pose(s.find_bone("hand_"+lado)).origin
			var d := s.get_bone_global_pose(s.find_bone("middle_01_"+lado)).origin
			var u := (b-a).normalized()
			var v := (c-b).normalized()
			var w := (d-c).normalized()
			var ang := rad_to_deg(u.angle_to(v))
			min_ang = minf(min_ang,ang)
			max_ang = maxf(max_ang,ang)
			min_lateral = minf(min_lateral,(c-peito).dot(direita)*signf((a-peito).dot(direita)))
			min_alinhamento = minf(min_alinhamento,v.dot(w))
	print("RUNTIME_AUDIT elbow_deg=",min_ang,"..",max_ang," min_wrist_lateral_m=",min_lateral," wrist_alignment=",min_alinhamento)
	if min_ang < 75.0 or max_ang > 115.0 or min_lateral < 0.15 or min_alinhamento < 0.95 or ator.ritmo != "Corrida":
		push_error("A animacao em jogo nao respeita a geometria corrigida")
		quit(1)
		return
	print("RUNTIME_OK")
	quit()

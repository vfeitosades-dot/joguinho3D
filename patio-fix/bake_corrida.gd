extends SceneTree

func _initialize() -> void:
	call_deferred("executar")

func quadro(eixo: Vector3, normal: Vector3) -> Basis:
	var x := eixo.normalized()
	var z := (normal - x * normal.dot(x)).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)

func eixo_entre(s: Skeleton3D, a: int, b: int) -> Vector3:
	return (s.get_bone_global_pose(b).origin - s.get_bone_global_pose(a).origin).normalized()

func orientar(s: Skeleton3D, i: int, ref: Basis, d: Vector3, n: Vector3) -> void:
	var desejada := quadro(d, n) * ref.inverse()
	var p := s.get_bone_parent(i)
	var pai := Basis.IDENTITY if p < 0 else s.get_bone_global_pose(p).basis.orthonormalized()
	s.set_bone_pose_rotation(i, (pai.inverse() * desejada).orthonormalized().get_rotation_quaternion())
	s.force_update_all_bone_transforms()

func executar() -> void:
	var modelo := (load("res://assets/manequim.scn") as PackedScene).instantiate() as Node3D
	root.add_child(modelo)
	var s := modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := modelo.get_node("AnimationPlayer") as AnimationPlayer
	var original := ap.get_animation("Run")
	var corrigida := original.duplicate(true) as Animation
	var base := s.global_transform.basis.orthonormalized().inverse() * modelo.global_transform.basis.orthonormalized()
	var cima := (base * Vector3.UP).normalized()
	var frente := (base * Vector3.BACK).normalized()
	var direita := (base * Vector3.RIGHT).normalized()
	var prefixo := str(ap.get_node(ap.root_node).get_path_to(s)) + ":"
	var dados := []
	var trilhas := {}
	var amostras := {}
	for lado in ["l", "r"]:
		var a := s.find_bone("upperarm_" + lado)
		var b := s.find_bone("lowerarm_" + lado)
		var c := s.find_bone("hand_" + lado)
		var dedo := s.find_bone("middle_01_" + lado)
		var t := s.find_bone("thigh_" + lado)
		var j := s.find_bone("calf_" + lado)
		var ta := s.find_bone("upperarm_twist_01_" + lado)
		var tb := s.find_bone("lowerarm_twist_01_" + lado)
		assert(mini(mini(a,b),mini(c,dedo)) >= 0 and mini(mini(t,j),mini(ta,tb)) >= 0)
		var ra := s.get_bone_global_rest(a)
		var rb := s.get_bone_global_rest(b)
		var rc := s.get_bone_global_rest(c)
		var rd := s.get_bone_global_rest(dedo)
		var u := (rb.origin - ra.origin).normalized()
		var v := (rc.origin - rb.origin).normalized()
		var w := (rd.origin - rc.origin).normalized()
		var normal := u.cross(v).normalized()
		assert(normal.length_squared() > 0.9)
		var sinal := signf((ra.origin - s.get_bone_global_rest(s.find_bone("spine_03")).origin).dot(direita))
		assert(absf(sinal) == 1.0)
		dados.append({"a":a,"b":b,"c":c,"dedo":dedo,"t":t,"j":j,"ta":ta,"tb":tb,"sinal":sinal,
			"ra":quadro(ra.basis.inverse()*u,ra.basis.inverse()*normal),
			"rb":quadro(rb.basis.inverse()*v,rb.basis.inverse()*normal),
			"rc":quadro(rc.basis.inverse()*w,rc.basis.inverse()*normal)})
		for osso in [a,b,c,ta,tb]:
			var caminho := NodePath(prefixo + s.get_bone_name(osso))
			var id := corrigida.find_track(caminho, Animation.TYPE_ROTATION_3D)
			if id < 0:
				id = corrigida.add_track(Animation.TYPE_ROTATION_3D)
				corrigida.track_set_path(id, caminho)
			while corrigida.track_get_key_count(id) > 0:
				corrigida.track_remove_key(id, 0)
			trilhas[osso] = id
			amostras[osso] = []
	var n := maxi(32, ceili(original.length * 90.0))
	var max_original := 0.0
	var min_original := 180.0
	var max_novo := 0.0
	var min_novo := 180.0
	var min_dist := 99.0
	var min_punho := 1.0
	ap.play("Run")
	for k in range(n):
		var tempo := original.length * float(k) / float(n)
		ap.seek(tempo, true)
		s.force_update_all_bone_transforms()
		var l: Dictionary = dados[0]
		var r: Dictionary = dados[1]
		var dif := (eixo_entre(s,r.t,r.j).dot(frente) - eixo_entre(s,l.t,l.j).dot(frente))
		var oscilacao := tanh(dif * 1.45)
		for i in range(2):
			var d: Dictionary = dados[i]
			var a: int = d.a
			var b: int = d.b
			var c: int = d.c
			var sinal: float = d.sinal
			var angulo := rad_to_deg(eixo_entre(s,a,b).angle_to(eixo_entre(s,b,c)))
			max_original = maxf(max_original, angulo)
			min_original = minf(min_original, angulo)
			var swing := oscilacao if i == 0 else -oscilacao
			var u := (-cima * 0.94 + frente * (0.49*swing - 0.10) + direita * (sinal*0.24)).normalized()
			var flex := (frente - u * frente.dot(u)).normalized()
			var ang := deg_to_rad(93.0 + 9.0 * swing)
			var v := (u*cos(ang) + flex*sin(ang)).normalized()
			var normal := u.cross(v).normalized()
			orientar(s,a,d.ra,u,normal)
			orientar(s,b,d.rb,v,normal)
			# Dedos apontam no sentido do antebraco, com palma sem torcao abrupta.
			var w := (v + u * 0.075).normalized()
			orientar(s,c,d.rc,w,normal)
			for osso in [d.ta,d.tb]:
				s.set_bone_pose_rotation(osso,s.get_bone_rest(osso).basis.get_rotation_quaternion())
			s.force_update_all_bone_transforms()
			var novo := rad_to_deg(eixo_entre(s,a,b).angle_to(eixo_entre(s,b,c)))
			max_novo = maxf(max_novo,novo)
			min_novo = minf(min_novo,novo)
			var peito := s.get_bone_global_pose(s.find_bone("spine_03")).origin
			var dist := (s.get_bone_global_pose(c).origin - peito).dot(direita)*sinal
			min_dist = minf(min_dist,dist)
			min_punho = minf(min_punho,eixo_entre(s,b,c).dot(eixo_entre(s,c,d.dedo)))
			for osso in [a,b,c,d.ta,d.tb]:
				var rot := s.get_bone_pose_rotation(osso).normalized()
				if k > 0 and rot.dot(amostras[osso][-1]) < 0.0:
					rot = -rot
				amostras[osso].append(rot)
				corrigida.rotation_track_insert_key(trilhas[osso],tempo,rot)
	for osso in trilhas:
		var rot: Quaternion = amostras[osso][0]
		if rot.dot(amostras[osso][-1]) < 0.0:
			rot = -rot
		corrigida.rotation_track_insert_key(trilhas[osso],original.length,rot)
	corrigida.loop_mode = Animation.LOOP_LINEAR
	corrigida.resource_name = "Corrida corrigida"
	print("AUDIT original_elbow_deg=", min_original, "..", max_original, " corrected_elbow_deg=",min_novo,"..",max_novo, " min_wrist_lateral_m=",min_dist," wrist_alignment=",min_punho," samples=",n)
	if min_novo < 75.0 or max_novo > 115.0 or min_dist < 0.15 or min_punho < 0.95:
		push_error("Geometria dos bracos fora dos limites")
		quit(1)
		return
	var erro := ResourceSaver.save(corrigida,"res://assets/corrida_corrigida.res")
	if erro != OK:
		push_error("Falha ao salvar corrida")
		quit(1)
		return
	print("BAKE_OK")
	quit()

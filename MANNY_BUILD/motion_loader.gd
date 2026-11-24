extends RefCounted

static func import_pack(path: String) -> bool:
	var raw: PackedByteArray
	if path.get_extension().to_lower() == "zip":
		var zip := ZIPReader.new()
		if zip.open(path) != OK:
			return false
		for filename in zip.get_files():
			if filename.get_file() == "MotionSmith_manny.json":
				raw = zip.read_file(filename)
				break
		zip.close()
	else:
		raw = FileAccess.get_file_as_bytes(path)
	if raw.is_empty() or raw.size() > 5000000:
		return false
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary or int(parsed.get("format",0)) != 1 or not parsed.get("clips") is Dictionary:
		return false
	for name in ["walk","jog","sprint","start_walk","jump_up","jump_forward"]:
		var clip: Variant = parsed["clips"].get(name)
		if not clip is Dictionary or not clip.get("times") is Array or not clip.get("rotations") is Dictionary:
			return false
		if clip["times"].size() < 2 or clip["rotations"].size() < 20:
			return false
	var target := FileAccess.open("user://MotionSmith_manny.json",FileAccess.WRITE)
	if target == null:
		return false
	target.store_buffer(raw)
	target.close()
	return true

static func load_pack(anim: AnimationPlayer, skeleton: Skeleton3D, clips: Dictionary) -> Dictionary:
	var path := "user://MotionSmith_manny.json"
	if not FileAccess.file_exists(path):
		path = OS.get_executable_path().get_base_dir().path_join("MotionSmith_manny.json")
	if not FileAccess.file_exists(path):
		path = "res://assets/manny/MotionSmith_manny.json"
	if not FileAccess.file_exists(path):
		print("MOTIONSMITH_OPTIONAL: place MotionSmith_manny.json beside the EXE")
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		push_warning("MotionSmith: invalid JSON")
		return {}
	var data: Dictionary = value
	if int(data.get("format", 0)) != 1 or not data.get("clips") is Dictionary:
		return {}
	var root_node := anim.get_node_or_null(anim.root_node)
	if root_node == null:
		return {}
	var skeleton_path := String(root_node.get_path_to(skeleton))
	var names: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("_\\d+$")
	for i in range(skeleton.get_bone_count()):
		var bone: String = String(skeleton.get_bone_name(i))
		names[regex.sub(bone.to_lower(), "")] = bone
	var lib := AnimationLibrary.new()
	var speeds: Dictionary = {}
	var imported: Dictionary = {}
	for key in ["walk", "jog", "sprint", "start_walk", "jump_up", "jump_forward"]:
		var entry: Variant = data["clips"].get(key)
		if not entry is Dictionary:
			continue
		var times: Array = entry.get("times", [])
		if times.size() < 2 or times.size() > 1000:
			continue
		var motion := Animation.new()
		motion.length = clampf(float(entry.get("duration", 1.0)), 0.1, 12.0)
		motion.loop_mode = Animation.LOOP_LINEAR if bool(entry.get("loop", false)) else Animation.LOOP_NONE
		var rotations: Dictionary = entry.get("rotations", {})
		for name in rotations:
			var normalized: String = regex.sub(String(name).to_lower(), "")
			if not names.has(normalized):
				continue
			var frames: Array = rotations[name]
			if frames.size() != times.size():
				continue
			var track := motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, NodePath(skeleton_path + ":" + String(names[normalized])))
			for i in range(frames.size()):
				var q: Array = frames[i]
				if q.size() == 4:
					motion.rotation_track_insert_key(track, float(times[i]), Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized())
		var pelvis: String = regex.sub(String(entry.get("pelvis", "pelvis")).to_lower(), "")
		var positions: Array = entry.get("positions", [])
		if names.has(pelvis) and positions.size() == times.size():
			var track := motion.add_track(Animation.TYPE_POSITION_3D)
			motion.track_set_path(track, NodePath(skeleton_path + ":" + String(names[pelvis])))
			for i in range(positions.size()):
				var v: Array = positions[i]
				if v.size() == 3:
					motion.position_track_insert_key(track, float(times[i]), Vector3(float(v[0]), float(v[1]), float(v[2])))
		if motion.get_track_count() < 20:
			continue
		lib.add_animation(key, motion)
		imported[key] = "motionsmith/" + key
		speeds[key] = float(entry.get("source_speed", 1.0))
	if imported.size() != 6:
		push_warning("MotionSmith pack incomplete; retaining original animations")
		return {}
	anim.add_animation_library("motionsmith", lib)
	for key in imported:
		clips[key] = StringName(imported[key])
	print("MOTIONSMITH_READY: ", imported.size(), " clips")
	return speeds

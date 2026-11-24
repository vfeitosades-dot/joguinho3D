extends Node
var actor: CharacterBody3D
var body: Node3D
var skeleton: Skeleton3D
var ik: SkeletonIK3D
var solvers: Array[SkeletonIK3D] = []
var markers: Array[Node3D] = []
var shoulders: Array[int] = []
var hands: Array[int] = []
var reaches: Array[float] = []
var blend: float = 0.0
var active_contact: bool = false
var grace: float = 0.0
var normal: Vector3 = Vector3.ZERO
var point: Vector3
var heading: Vector3 = Vector3.FORWARD

func setup(character: CharacterBody3D, visual: Node3D, model: Node) -> void:
	actor = character
	body = visual
	skeleton = _find_skeleton(model)
	if skeleton == null:
		return
	for side in ["r", "l"]:
		var upper: int = _bone("upperarm_" + side)
		var lower: int = _bone("lowerarm_" + side)
		var hand: int = _bone("hand_" + side)
		if mini(upper, mini(lower, hand)) < 0:
			push_error("Missing arm " + side)
			return
		var target := Node3D.new()
		target.name = "WallContact_" + side
		actor.add_child(target)
		target.top_level = true
		target.global_position = _world(hand)
		var solver := SkeletonIK3D.new()
		solver.name = "ContactIK_" + side
		solver.root_bone = skeleton.get_bone_name(upper)
		solver.tip_bone = skeleton.get_bone_name(hand)
		skeleton.add_child(solver)
		solver.target_node = solver.get_path_to(target)
		solver.override_tip_basis = false
		solver.max_iterations = 12
		solver.min_distance = 0.008
		solver.influence = 0.0
		solvers.append(solver)
		markers.append(target)
		shoulders.append(upper)
		hands.append(hand)
		reaches.append(_world(upper).distance_to(_world(lower)) + _world(lower).distance_to(_world(hand)))
	ik = solvers[0]
	print("WALL_TOUCH_READY: 2 hands")

func _bone(prefix: String) -> int:
	for i in range(skeleton.get_bone_count()):
		var n: String = String(skeleton.get_bone_name(i)).to_lower()
		if n == prefix or n.begins_with(prefix + "_"):
			return i
	return -1

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _world(index: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)

func release_now() -> void:
	active_contact = false
	blend = 0.0
	grace = 0.0
	for solver in solvers:
		solver.influence = 0.0
		if solver.is_running():
			solver.stop()

func update_contact(delta: float, direction: Vector3) -> void:
	if solvers.size() != 2:
		return
	if direction.length_squared() > 0.04:
		heading = direction.normalized()
	elif blend < 0.01:
		heading = -body.global_transform.basis.z.normalized()
	var lateral: Vector3 = heading.cross(Vector3.UP).normalized()
	var valid: bool = false
	if actor.is_on_floor() and actor.velocity.y < 0.5 and not Input.is_action_pressed("sprint"):
		var origin := actor.global_position + Vector3.UP * 1.12
		for sign_value in [-1.0, 1.0]:
			var ray := PhysicsRayQueryParameters3D.create(origin, origin + lateral * float(sign_value) * 0.73)
			ray.exclude = [actor.get_rid()]
			var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				continue
			var surface := hit["collider"] as Node3D
			var n: Vector3 = hit["normal"]
			if surface != null and surface.is_in_group("touch_wall") and absf(n.y) < 0.15 and absf(n.dot(heading)) < 0.45:
				normal = n
				point = hit["position"]
				valid = true
				break
	if valid:
		grace = 0.14
	else:
		grace = maxf(0.0, grace - delta)
		valid = grace > 0.0 and actor.is_on_floor() and not Input.is_action_pressed("sprint")
	if valid:
		# Keep the walking direction parallel to the wall; rotate upper body partly toward it.
		var facing := (heading * 0.66 - normal * 0.75).normalized()
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-9.0 * delta))
		for i in range(2):
			var shoulder := _world(shoulders[i])
			var target: Vector3 = shoulder - normal * ((shoulder - point).dot(normal) - 0.075)
			target.y = actor.global_position.y + 1.15 + float(i) * 0.07
			target += heading * (0.18 if i == 0 else -0.18)
			var offset := target - shoulder
			if offset.length() > reaches[i] * 0.98:
				target = shoulder + offset.normalized() * reaches[i] * 0.98
			if not solvers[i].is_running():
				markers[i].global_position = _world(hands[i])
				solvers[i].start()
			markers[i].global_position = markers[i].global_position.lerp(target, 1.0 - exp(-12.0 * delta))
		blend = move_toward(blend, 1.0, delta / 0.30)
	else:
		blend = move_toward(blend, 0.0, delta / 0.25)
		if blend <= 0.0:
			release_now()
			return
	active_contact = valid
	for solver in solvers:
		solver.influence = blend * blend * (3.0 - 2.0 * blend)

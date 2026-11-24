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
var hand_blends: Array[float] = [0.0, 0.0]
var hand_grace: Array[float] = [0.0, 0.0]
var targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var pelvis: int = -1
var leg_solvers: Array[SkeletonIK3D] = []
var leg_markers: Array[Node3D] = []
var feet: Array[int] = []

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
	pelvis = _bone("pelvis")
	for side in ["r", "l"]:
		var thigh: int = _bone("thigh_" + side)
		var foot: int = _bone("foot_" + side)
		if thigh < 0 or foot < 0:
			continue
		var target := Node3D.new()
		target.name = "FootTarget_" + side
		actor.add_child(target)
		target.top_level = true
		target.global_position = _world(foot)
		var solver := SkeletonIK3D.new()
		solver.name = "PedalIK_" + side
		solver.root_bone = skeleton.get_bone_name(thigh)
		solver.tip_bone = skeleton.get_bone_name(foot)
		skeleton.add_child(solver)
		solver.target_node = solver.get_path_to(target)
		solver.override_tip_basis = false
		solver.max_iterations = 10
		solver.min_distance = 0.012
		solver.influence = 0.0
		leg_solvers.append(solver)
		leg_markers.append(target)
		feet.append(foot)
	print("WALL_TOUCH_READY: independent arms, seated IK")

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
	hand_blends = [0.0, 0.0]
	hand_grace = [0.0, 0.0]
	for solver in solvers:
		solver.influence = 0.0
		if solver.is_running():
			solver.stop()
	for solver in leg_solvers:
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
	var right_axis: Vector3 = heading.cross(Vector3.UP).normalized()
	var grounded: bool = actor.is_on_floor() and actor.velocity.y < 0.5 and not Input.is_action_pressed("sprint")
	active_contact = false
	for i in range(2):
		var side: Vector3 = right_axis if i == 0 else -right_axis
		var valid: bool = false
		var shoulder_pos := _world(shoulders[i])
		if grounded:
			var origin := actor.global_position + Vector3.UP * 1.12
			var ray := PhysicsRayQueryParameters3D.create(origin, origin + side * 0.76)
			ray.exclude = [actor.get_rid()]
			var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():
				var surface := hit["collider"] as Node3D
				var n: Vector3 = hit["normal"]
				if surface != null and surface.is_in_group("touch_wall") and absf(n.y) < 0.15 and n.dot(side) < -0.70:
					var point_on_wall: Vector3 = hit["position"]
					var target: Vector3 = shoulder_pos - n * ((shoulder_pos - point_on_wall).dot(n) - 0.065)
					target.y = actor.global_position.y + 1.10
					target += heading * 0.13
					var offset := target - shoulder_pos
					if offset.length() <= reaches[i] * 1.10:
						targets[i] = shoulder_pos + offset.limit_length(reaches[i] * 0.98)
						valid = true
		if valid:
			hand_grace[i] = 0.12
		else:
			hand_grace[i] = maxf(0.0, hand_grace[i] - delta)
			valid = grounded and hand_grace[i] > 0.0 and shoulder_pos.distance_to(targets[i]) < reaches[i] * 1.12
		if valid:
			active_contact = true
			hand_blends[i] = move_toward(hand_blends[i], 1.0, delta / 0.26)
			_set_arm(i, targets[i], hand_blends[i], delta)
		else:
			hand_blends[i] = move_toward(hand_blends[i], 0.0, delta / 0.23)
			if hand_blends[i] <= 0.0:
				solvers[i].influence = 0.0
				if solvers[i].is_running():
					solvers[i].stop()
			else:
				solvers[i].influence = _ease(hand_blends[i])
	blend = maxf(hand_blends[0], hand_blends[1])

func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func _set_arm(index: int, target: Vector3, amount: float, delta: float) -> void:
	if not solvers[index].is_running():
		markers[index].global_position = _world(hands[index])
		solvers[index].start()
	markers[index].global_position = markers[index].global_position.lerp(target, 1.0 - exp(-18.0 * delta))
	solvers[index].influence = _ease(amount)

func align_hips(target: Vector3, amount: float) -> void:
	if pelvis < 0:
		return
	actor.global_position += (target - _world(pelvis)) * amount

func hips_world() -> Vector3:
	return _world(pelvis) if pelvis >= 0 else actor.global_position

func drive_pose(car: Node3D, delta: float, amount: float = 1.0) -> void:
	if solvers.size() != 2:
		return
	var left := car.get("grip_left") as Node3D
	var right := car.get("grip_right") as Node3D
	if left == null or right == null:
		return
	var wheel := car.get("steering_wheel") as Node3D
	if wheel != null:
		var center: Vector3 = wheel.get_global_transform_interpolated().origin
		var normal: Vector3 = wheel.get_global_transform_interpolated().basis.z.normalized()
		for i in range(2):
			var grip := right if i == 0 else left
			var contact: Vector3 = grip.get_global_transform_interpolated().origin
			var outward: Vector3 = (contact - center).slide(normal).normalized()
			var wrist: Vector3 = contact + outward * 0.065 - normal * 0.025
			var shoulder: Vector3 = _world(shoulders[i])
			_set_arm(i, shoulder + (wrist - shoulder).limit_length(reaches[i] * 0.99), amount, delta)
	for i in range(leg_solvers.size()):
		if not leg_solvers[i].is_running():
			leg_markers[i].global_position = _world(feet[i])
			leg_solvers[i].start()
		var target: Vector3 = car.call("pedal_world", i == 0)
		leg_markers[i].global_position = leg_markers[i].global_position.lerp(target, 1.0 - exp(-15.0 * delta))
		leg_solvers[i].influence = _ease(amount) * 0.85

func door_pose(car: Node3D, inside: bool, amount: float, delta: float) -> void:
	if solvers.size() != 2:
		return
	var arm: int = 1 if inside else 0
	var target: Vector3 = car.call("handle_world", inside)
	var shoulder: Vector3 = _world(shoulders[arm])
	target = shoulder + (target - shoulder).limit_length(reaches[arm] * 0.98)
	_set_arm(arm, target, clampf(amount, 0.0, 1.0), delta)

func fade_door(amount: float) -> void:
	if solvers.size() != 2:
		return
	solvers[0].influence = _ease(clampf(amount, 0.0, 1.0))
	if amount <= 0.001 and solvers[0].is_running():
		solvers[0].stop()

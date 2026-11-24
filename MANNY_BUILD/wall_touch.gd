extends Node

var actor: CharacterBody3D
var body: Node3D
var skeleton: Skeleton3D
var ik: SkeletonIK3D
var marker: Node3D
var shoulder: int = -1
var hand: int = -1
var elbow: int = -1
var blend: float = 0.0
var active_contact: bool = false
var contact_point: Vector3
var contact_wall: Node3D
var contact_local: Vector3
var has_target: bool = false

func setup(character: CharacterBody3D, visual: Node3D, model: Node) -> void:
	actor = character
	body = visual
	skeleton = _find_skeleton(model)
	if skeleton == null:
		push_warning("WALL_TOUCH: skeleton not found")
		return
	for i in range(skeleton.get_bone_count()):
		var name_text: String = String(skeleton.get_bone_name(i)).to_lower()
		if name_text.begins_with("upperarm_r_") or name_text == "upperarm_r":
			shoulder = i
		if name_text.begins_with("lowerarm_r_") or name_text == "lowerarm_r":
			elbow = i
		if name_text.begins_with("hand_r_") or name_text == "hand_r":
			hand = i
	if shoulder < 0 or elbow < 0 or hand < 0:
		push_error("WALL_TOUCH: incomplete arm")
		return
	marker = Node3D.new()
	marker.name = "WallContactTarget"
	actor.add_child(marker)
	marker.top_level = true
	marker.global_position = _bone_world(hand)
	ik = SkeletonIK3D.new()
	ik.name = "WallArmIK"
	skeleton.add_child(ik)
	ik.root_bone = skeleton.get_bone_name(shoulder)
	ik.tip_bone = skeleton.get_bone_name(hand)
	ik.target_node = ik.get_path_to(marker)
	ik.override_tip_basis = false
	ik.max_iterations = 10
	ik.min_distance = 0.008
	ik.influence = 0.0
	print("WALL_TOUCH_READY")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null

func _bone_world(index: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)

func release_now() -> void:
	active_contact = false
	has_target = false
	blend = 0.0
	contact_wall = null
	if ik != null:
		ik.influence = 0.0
		if ik.is_running():
			ik.stop()

func update_contact(delta: float, move_direction: Vector3) -> void:
	if ik == null:
		return
	var forward: Vector3 = -body.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var shoulder_pos := _bone_world(shoulder)
	var arm_length: float = shoulder_pos.distance_to(_bone_world(elbow)) + _bone_world(elbow).distance_to(_bone_world(hand))
	var origin := Vector3(shoulder_pos.x, shoulder_pos.y - 0.12, shoulder_pos.z)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + forward * maxf(0.45, arm_length + 0.16))
	ray.exclude = [actor.get_rid()]
	ray.collide_with_areas = false
	var result: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
	var valid: bool = false
	if not result.is_empty() and actor.is_on_floor() and actor.velocity.y < 0.5 and not Input.is_action_pressed("sprint"):
		var surface := result.get("collider") as Node3D
		var normal: Vector3 = result["normal"]
		var point: Vector3 = result["position"]
		var wrist := point + normal * 0.075
		if surface != null and surface.is_in_group("touch_wall") and absf(normal.y) < 0.15 and normal.dot(forward) < -0.65 and shoulder_pos.distance_to(wrist) < arm_length * 0.98 and (move_direction.length_squared() < 0.01 or move_direction.dot(forward) > 0.65):
			valid = true
			if not has_target or surface != contact_wall:
				contact_wall = surface
				contact_local = surface.to_local(wrist)
				has_target = true
				marker.global_position = _bone_world(hand)
			var old_point: Vector3 = surface.to_global(contact_local)
			if shoulder_pos.distance_to(old_point) > arm_length * 0.96:
				contact_local = surface.to_local(wrist)
			contact_point = surface.to_global(contact_local)
	if valid:
		marker.global_position = marker.global_position.lerp(contact_point, 1.0 - exp(-13.0 * delta))
		if not ik.is_running():
			ik.start()
		blend = move_toward(blend, 1.0, delta / 0.28)
	else:
		blend = move_toward(blend, 0.0, delta / 0.23)
		if blend <= 0.0:
			release_now()
			return
	active_contact = valid
	ik.influence = blend * blend * (3.0 - 2.0 * blend)

extends CharacterBody3D

var title: String = ""
var engine_on: bool = false
var occupied: bool = false
var speed: float = 0.0
var steer: float = 0.0
var roll: float = 0.0
var max_speed: float = 25.0
var acceleration: float = 5.0
var radius: float = 0.35
var width: float = 2.1
var length: float = 4.8
var seat: Vector3 = Vector3(0.37, 0.08, -0.28)
var visual: Node3D
var wheels: Array[Node3D] = []
var wheel_bases: Array[Basis] = []
var steering_wheel: Node3D
var steering_basis: Basis
var motor: AudioStreamPlayer3D
var shadow_mesh: MeshInstance3D
var door: Node3D
var door_angle: float = 0.0
var door_goal: float = 0.0
var road_velocity: Vector3 = Vector3.ZERO
var wheelbase: float = 2.8
var front_track: float = 1.6
var yaw_rate: float = 0.0
var throttle: float = 0.0
var brake_pressure: float = 0.0
var pitch_velocity: float = 0.0
var roll_velocity: float = 0.0
var heave_velocity: float = 0.0
var wheel_positions: Array[Vector3] = []
var wheel_roll: Array[float] = [0.0, 0.0, 0.0, 0.0]
var wheel_radius: float = 0.18
var pedal_left: Vector3
var pedal_right: Vector3
var hip_anchor: Vector3
var grip_left: Node3D
var grip_right: Node3D
var impact_strength: float = 0.0
var impact_cooldown: float = 0.0
var impact_player: AudioStreamPlayer3D
var impact_count: int = 0
var impact_direction: Vector3 = Vector3.ZERO
var filtered_accel: float = 0.0
var vehicle_mass: float = 1450.0
var crash_yaw: float = 0.0
var body_mesh: MeshInstance3D
var front_dent: float = 0.0
var rear_dent: float = 0.0
var door_handle: Node3D
var cabin_handle: Node3D
var transition_locked: bool = false
var damage_goal: Vector2 = Vector2.ZERO
var reflective_glass_count: int = 0
var reflective_paint_count: int = 0
var tuned_materials: Dictionary = {}
var glass_materials: Array[BaseMaterial3D] = []
var glass_plane: Array = []
var wheel_root: Node3D
var wheel_radii: Array[float] = []
var wheel_steer_limits: Array[float] = []

func setup(path: String, data: Dictionary) -> bool:
	title = data["title"]
	width = data["width"]
	vehicle_mass = float(data.get("mass", 1450.0))
	length = data["length"]
	radius = data["radius"]
	max_speed = data["top"]
	acceleration = data["accel"]
	seat = Vector3(data["seat_x"], data["seat_y"], data["seat_z"])
	hip_anchor = Vector3(data["seat_x"], data["hip_y"], data["hip_z"])
	pedal_left = Vector3(data["seat_x"] + 0.13, data["pedal_y"], data["pedal_z"])
	pedal_right = Vector3(data["seat_x"] - 0.075, data["pedal_y"], data["pedal_z"])
	wheel_radius = data["grip_radius"]
	glass_plane = data.get("glass_plane",[])
	var doc := GLTFDocument.new()
	var gltf := GLTFState.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	if doc.append_from_buffer(bytes, "", gltf) != OK:
		push_error("CAR_LOAD_FAILED " + path)
		return false
	visual = Node3D.new()
	add_child(visual)
	var model := doc.generate_scene(gltf) as Node3D
	if model == null:
		push_error("CAR_SCENE_FAILED " + path)
		return false
	visual.add_child(model)
	_polish_surfaces(model)
	print("REFLECTIVE_MATERIALS: ", title, " glass=", reflective_glass_count, " paint=", reflective_paint_count)
	body_mesh = _part(model, "Body") as MeshInstance3D
	if body_mesh == null or body_mesh.get_blend_shape_count() < 2:
		body_mesh = _find_damage_mesh(model)
	wheel_root = Node3D.new()
	wheel_root.name = "IndependentWheelAxles"
	add_child(wheel_root)
	for name_part in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var wheel := _part(model, name_part)
		if wheel == null:
			push_error("Missing wheel " + name_part)
			return false
		wheel.reparent(wheel_root,true)
		wheels.append(wheel)
		wheel_bases.append(wheel.basis)
		wheel_positions.append(wheel.position)
		var tyre_radius: float = radius
		var tyre_half_width: float = 0.14
		if wheel is MeshInstance3D:
			var bounds: AABB = (wheel as MeshInstance3D).get_aabb()
			tyre_radius = maxf(bounds.size.y,bounds.size.z)*0.5
			tyre_half_width = bounds.size.x*0.5
		wheel_radii.append(maxf(tyre_radius,0.1))
		var clearance: float = maxf(0.045,width*0.5-absf(wheel.position.x)-tyre_half_width)
		wheel_steer_limits.append(clampf(asin(clampf(clearance/maxf(tyre_radius,0.1),0.0,0.9)),0.18,0.40))
	door = _part(model, "DriverDoorPivot")
	if door == null:
		push_error("Missing driver door " + title)
		return false
	# Attach targets to the moving door, so the hand follows its opening arc.
	door_handle = Node3D.new()
	door.add_child(door_handle)
	door_handle.position = door.to_local(visual.to_global(Vector3(width * 0.435, float(data["handle_y"]), float(data["handle_z"]))))
	cabin_handle = Node3D.new()
	door.add_child(cabin_handle)
	cabin_handle.position = door_handle.position + Vector3(-0.095, -0.055, 0.06)
	steering_wheel = _part(model, "Steering_Wheel")
	if steering_wheel != null:
		steering_basis = steering_wheel.basis
		grip_left = _make_grip(Vector3(wheel_radius * 0.90, wheel_radius * 0.40, -0.024), "GripLeft")
		grip_right = _make_grip(Vector3(-wheel_radius * 0.90, wheel_radius * 0.40, -0.024), "GripRight")
	else:
		push_warning("No steering node for " + title)
	print("CAR_PARTS: ", title, " wheels=", wheels.size(), " steering=", steering_wheel != null)
	wheelbase = maxf(1.8, absf((wheel_positions[0].z + wheel_positions[1].z - wheel_positions[2].z - wheel_positions[3].z) * 0.5))
	front_track = absf(wheel_positions[0].x - wheel_positions[1].x)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width * 0.95, float(data["height"]) * 0.85, length * 0.95)
	collider.shape = shape
	collider.position.y = float(data["height"]) * 0.45
	add_child(collider)
	floor_snap_length = 0.3
	_create_shadow()
	motor = AudioStreamPlayer3D.new()
	var loop := load("res://assets/garage/engine.wav") as AudioStreamWAV
	if loop != null:
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = 44100
		motor.stream = loop
	motor.unit_size = 5.0
	motor.max_distance = 27.0
	motor.volume_db = -18.0
	add_child(motor)
	impact_player = AudioStreamPlayer3D.new()
	impact_player.stream = load("res://assets/garage/impact.wav") as AudioStream
	impact_player.unit_size = 5.0
	impact_player.max_distance = 25.0
	add_child(impact_player)
	reset_physics_interpolation()
	return true

func _polish_surfaces(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for i in range(instance.mesh.get_surface_count()):
				var original := instance.get_active_material(i) as BaseMaterial3D
				if original == null:
					continue
				var label: String = original.resource_name.to_lower()
				var glass: bool = label.begins_with("glass")
				var paint: bool = label.begins_with("paint")
				if not glass and not paint:
					continue
				var material: BaseMaterial3D
				if tuned_materials.has(original):
					material = tuned_materials[original]
				else:
					material = original.duplicate() as BaseMaterial3D
					material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
					material.metallic_texture = null
					material.roughness_texture = null
					if glass:
						material.metallic = 0.0
						material.metallic_specular = 0.68
						material.roughness = 0.085
						material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						material.cull_mode = BaseMaterial3D.CULL_BACK
						var tint: Color = material.albedo_color
						tint.a = clampf(tint.a,0.32,0.53)
						material.albedo_color = tint
					else:
						material.metallic = 0.38
						material.metallic_specular = 0.58
						material.roughness = 0.21
					tuned_materials[original] = material
				instance.set_surface_override_material(i,material)
				if glass:
					if not glass_materials.has(material):
						glass_materials.append(material)
					reflective_glass_count += 1
				else:
					reflective_paint_count += 1
	for child in node.get_children():
		_polish_surfaces(child)

func set_glass_overlay(material: Material) -> void:
	for glass in glass_materials:
		glass.next_pass = material

func set_render_visible(show: bool) -> void:
	visual.visible = show
	wheel_root.visible = show

func wheel_geometry_ok() -> bool:
	if wheels.size() != 4 or wheel_radii.size() != 4:
		return false
	for i in range(4):
		if wheels[i].get_parent() != wheel_root or wheels[i].position.distance_to(wheel_positions[i]) > 0.002:
			return false
		if absf(wheel_positions[i].y-wheel_radii[i]) > 0.035:
			return false
	return true

func _find_damage_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.get_blend_shape_count() >= 2:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_damage_mesh(child)
		if found != null:
			return found
	return null

func handle_world(inside: bool) -> Vector3:
	var marker := cabin_handle if inside else door_handle
	return marker.get_global_transform_interpolated().origin if marker != null else global_position

func _make_grip(local_pos: Vector3, label: String) -> Node3D:
	var grip := Node3D.new()
	grip.name = label
	steering_wheel.add_child(grip)
	grip.position = local_pos
	return grip

func seat_world() -> Vector3:
	return visual.to_global(hip_anchor)

func rendered_seat_world() -> Vector3:
	return visual.get_global_transform_interpolated() * hip_anchor

func pedal_world(right: bool) -> Vector3:
	var local_pos := pedal_right if right else pedal_left
	if right:
		local_pos.z += throttle * 0.035
		local_pos.y -= brake_pressure * 0.018
	return visual.get_global_transform_interpolated() * local_pos

func _part(node: Node, wanted: String) -> Node3D:
	var key: String = String(node.name).to_lower().replace("_", "").replace(" ", "").replace("-", "")
	var target: String = wanted.to_lower().replace("_", "").replace(" ", "").replace("-", "")
	if node is Node3D and (key == target or key.begins_with(target)):
		return node as Node3D
	for child in node.get_children():
		var part := _part(child, wanted)
		if part != null:
			return part
	return null

func set_door(opened: bool) -> void:
	door_goal = -1.05 if opened else 0.0

func _create_shadow() -> void:
	shadow_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width * 1.6, length * 1.24)
	shadow_mesh.mesh = plane
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02, 0.03, 0.04, 0.58), Color(0.02, 0.03, 0.04, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = texture
	shadow_mesh.material_override = mat
	shadow_mesh.position.y = 0.018
	shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow_mesh)

func start_engine() -> void:
	engine_on = true
	if motor != null and not motor.playing:
		motor.play()

func stop_engine() -> void:
	engine_on = false
	if motor != null:
		motor.stop()

func _physics_process(delta: float) -> void:
	if visual == null:
		return
	if door != null:
		door_angle = lerpf(door_angle, door_goal, 1.0 - exp(-7.0 * delta))
		door.rotation.y = door_angle
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	impact_strength = move_toward(impact_strength, 0.0, delta * 2.6)
	_update_damage(delta)
	crash_yaw = move_toward(crash_yaw, 0.0, delta * 2.8)
	if transition_locked:
		return
	# Parked vehicles are static after settling; avoid seven floor collision solves every tick.
	if not occupied and road_velocity.length_squared() < 0.0001 and absf(visual.rotation.x) < 0.001 and absf(visual.rotation.z) < 0.001 and absf(visual.position.y) < 0.001 and is_on_floor():
		return
	var gas: float = 0.0
	var turn: float = 0.0
	var braking: bool = false
	var enabled: bool = occupied and engine_on and not bool(get_parent().get("menu_open")) and not bool(get_parent().get("puzzle"))
	if enabled:
		gas = Input.get_axis("move_backward", "move_forward")
		turn = Input.get_axis("move_right", "move_left")
		braking = Input.is_action_pressed("jump")
	var previous: float = speed
	var forward := global_transform.basis.z
	var right_axis := global_transform.basis.x
	speed = road_velocity.dot(forward)
	var reverse_brake: bool = gas * speed < -0.4
	throttle = move_toward(throttle, absf(gas) if not reverse_brake and not braking else 0.0, delta * 3.8)
	brake_pressure = move_toward(brake_pressure, 1.0 if braking or reverse_brake or (occupied and not enabled) else (0.28 if not occupied else 0.0), delta * 5.0)
	var target_speed: float = gas * (max_speed if gas >= 0 else 6.0)
	var drag: float = 0.38 + absf(speed) * 0.037 + speed * speed * 0.003
	var traction: float = acceleration * (1.0 - 0.70 * clampf(absf(speed) / max_speed, 0.0, 1.0))
	if brake_pressure > 0.02:
		speed = move_toward(speed, 0.0, (10.5 * brake_pressure + drag) * delta)
	elif absf(gas) > 0.01:
		speed = move_toward(speed, target_speed, traction * throttle * delta)
	else:
		speed = move_toward(speed, 0.0, drag * delta)
	var angle: float = turn * lerpf(minf(wheel_steer_limits[0],wheel_steer_limits[1])*0.85, 0.11, clampf(absf(speed) / max_speed, 0.0, 1.0))
	steer = move_toward(steer, angle, delta * (2.1 if absf(turn) > 0.01 else 3.4))
	var desired_yaw: float = tan(steer) * speed / wheelbase
	# Cap lateral acceleration to a dry-road grip envelope; smooth inertia at turn-in.
	var grip: float = 7.6 if not braking else 5.8
	var limit: float = grip / maxf(absf(speed), 1.0)
	desired_yaw = clampf(desired_yaw, -limit, limit) if absf(speed) > 0.15 else 0.0
	yaw_rate = lerpf(yaw_rate, desired_yaw, 1.0 - exp(-7.0 * delta))
	if absf(speed) < 0.12:
		yaw_rate = 0.0
	rotate_y((yaw_rate + crash_yaw) * delta)
	forward = global_transform.basis.z
	right_axis = global_transform.basis.x
	# Preserve momentum sideways, then recover grip progressively instead of snapping heading.
	var side_speed: float = road_velocity.dot(right_axis)
	side_speed = move_toward(side_speed, 0.0, grip * delta)
	road_velocity = forward * speed + right_axis * side_speed
	if not enabled and road_velocity.length() < 0.10:
		road_velocity = Vector3.ZERO
	velocity = road_velocity
	velocity.y = -0.35
	move_and_slide()
	for k in range(get_slide_collision_count()):
		var collision := get_slide_collision(k)
		var n := collision.get_normal()
		if absf(n.y) < 0.35:
			_resolve_contact(n, collision.get_position(), collision.get_collider())
	if absf(global_position.x) > 46.0 or absf(global_position.z) > 46.0:
		var boundary_normal := Vector3.ZERO
		if absf(global_position.x) > 46.0:
			boundary_normal.x = -signf(global_position.x)
		if absf(global_position.z) > 46.0:
			boundary_normal.z = -signf(global_position.z)
		boundary_normal = boundary_normal.normalized()
		if impact_cooldown <= 0.0 and road_velocity.length() > 1.4:
			_register_impact(road_velocity.length(), boundary_normal)
		global_position.x = clampf(global_position.x, -46.0, 46.0)
		global_position.z = clampf(global_position.z, -46.0, 46.0)
		road_velocity = road_velocity.slide(boundary_normal) * 0.35
		reset_physics_interpolation()
	speed = road_velocity.dot(forward)
	var longitudinal_accel: float = clampf((speed - previous) / maxf(delta, 0.001), -14.0, 9.0)
	filtered_accel = lerpf(filtered_accel, longitudinal_accel, 1.0 - exp(-10.0 * delta))
	var lateral_accel: float = yaw_rate * speed
	var pitch_goal: float = clampf(filtered_accel * 0.0045, -0.042, 0.038)
	var roll_goal: float = clampf(-lateral_accel * 0.006, -0.042, 0.042)
	pitch_goal = clampf(pitch_goal + impact_direction.z * impact_strength * 0.035,-0.055,0.055)
	roll_goal = clampf(roll_goal + impact_direction.x * impact_strength * 0.03,-0.055,0.055)
	# Damped spring chassis animation; wheel centers remain at road height.
	pitch_velocity += ((pitch_goal - visual.rotation.x) * 64.0 - pitch_velocity * 13.0) * delta
	roll_velocity += ((roll_goal - visual.rotation.z) * 60.0 - roll_velocity * 12.0) * delta
	visual.rotation.x = clampf(visual.rotation.x + pitch_velocity * delta,-0.065,0.065)
	visual.rotation.z = clampf(visual.rotation.z + roll_velocity * delta,-0.055,0.055)
	var heave_goal: float = -0.004 * absf(filtered_accel) - 0.002 * absf(lateral_accel)
	heave_velocity += ((heave_goal - visual.position.y) * 95.0 - heave_velocity * 17.0) * delta
	visual.position.y = clampf(visual.position.y + heave_velocity * delta,-0.023,0.016)
	for i in range(wheels.size()):
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var yaw_amount: float = 0.0
		if i < 2 and absf(steer) > 0.001:
			var center_radius: float = wheelbase / tan(absf(steer))
			var inner: bool = signf(steer) == side
			yaw_amount = signf(steer) * atan(wheelbase / maxf(0.6, center_radius + (-0.5 if inner else 0.5) * front_track))
		var linear: float = speed - yaw_rate * wheel_positions[i].x
		yaw_amount = clampf(yaw_amount,-wheel_steer_limits[i],wheel_steer_limits[i])
		wheel_roll[i] = fposmod(wheel_roll[i] + linear * delta / wheel_radii[i], TAU)
		wheels[i].position = wheel_positions[i]
		wheels[i].basis = Basis(Vector3.UP, yaw_amount) * wheel_bases[i] * Basis(Vector3.RIGHT, wheel_roll[i] * side)
	if steering_wheel != null:
		steering_wheel.basis = steering_basis * Basis(Vector3.FORWARD, -steer * 3.0)
	if motor != null and engine_on:
		motor.pitch_scale = 0.70 + absf(speed) / max_speed * 0.95 + throttle * 0.20
		motor.volume_db = -23.0 + throttle * 10.0

func _resolve_contact(surface_normal: Vector3, point: Vector3, other: Object) -> void:
	var n := Vector3(surface_normal.x, 0.0, surface_normal.z).normalized()
	if n.length_squared() < 0.1:
		return
	var moving_other: Vector3 = Vector3.ZERO
	var other_mass: float = 0.0
	var other_car := other as Node3D
	if other_car != null and other_car.has_method("receive_car_impulse") and not bool(other_car.get("transition_locked")):
		moving_other = other_car.get("road_velocity")
		other_mass = float(other_car.get("vehicle_mass"))
	var closing: float = maxf(0.0, -(road_velocity - moving_other).dot(n))
	if closing <= 0.02:
		return
	var inv_mass: float = 1.0 / vehicle_mass
	var inv_other: float = 1.0 / other_mass if other_mass > 0.0 else 0.0
	var restitution: float = 0.14 if other_mass > 0.0 else 0.10
	var impulse: float = (1.0 + restitution) * closing / (inv_mass + inv_other)
	var impulse_vec := n * impulse
	road_velocity += impulse_vec * inv_mass
	var tangent := road_velocity.slide(n)
	road_velocity -= tangent * clampf(closing * 0.015, 0.0, 0.24)
	road_velocity = road_velocity.limit_length(max_speed)
	_apply_crash_rotation(impulse_vec, point)
	if other_mass > 0.0:
		other_car.call("receive_car_impulse", -impulse_vec, point, closing)
	if closing > 1.4 and impact_cooldown <= 0.0:
		_register_impact(closing, n)

func receive_car_impulse(impulse: Vector3, point: Vector3, closing: float) -> void:
	road_velocity += impulse / vehicle_mass
	road_velocity = road_velocity.limit_length(max_speed)
	_apply_crash_rotation(impulse, point)
	if closing > 1.4 and impact_cooldown <= 0.0:
		_register_impact(closing, impulse.normalized())

func _apply_crash_rotation(impulse: Vector3, point: Vector3) -> void:
	var lever: Vector3 = point - global_position
	var inertia: float = vehicle_mass * (width * width + length * length) / 12.0
	crash_yaw = clampf(crash_yaw + lever.cross(impulse).y / maxf(inertia, 1.0) * 0.52, -1.25, 1.25)

func _update_damage(delta: float) -> void:
	if body_mesh == null:
		return
	if absf(front_dent - damage_goal.x) > 0.001:
		front_dent = lerpf(front_dent, damage_goal.x, 1.0 - exp(-30.0 * delta))
		body_mesh.set_blend_shape_value(0, front_dent)
	if absf(rear_dent - damage_goal.y) > 0.001:
		rear_dent = lerpf(rear_dent, damage_goal.y, 1.0 - exp(-30.0 * delta))
		body_mesh.set_blend_shape_value(1, rear_dent)

func _register_impact(closing: float, surface_normal: Vector3) -> void:
	impact_count += 1
	impact_cooldown = 0.25
	impact_strength = clampf(closing / 10.0, 0.12, 1.0)
	impact_direction = global_basis.inverse() * surface_normal
	var amount: float = clampf((closing - 2.2) / 15.0, 0.0, 0.55)
	if impact_direction.z < -0.50:
		damage_goal.x = clampf(damage_goal.x + amount, 0.0, 1.0)
	elif impact_direction.z > 0.50:
		damage_goal.y = clampf(damage_goal.y + amount, 0.0, 1.0)
	pitch_velocity += impact_direction.z * impact_strength * 0.9
	roll_velocity += impact_direction.x * impact_strength * 0.8
	heave_velocity -= impact_strength * 0.12
	if impact_player != null and impact_player.stream != null:
		impact_player.volume_db = lerpf(-23.0, -10.0, impact_strength)
		impact_player.pitch_scale = lerpf(1.12, 0.82, impact_strength)
		impact_player.play()

func reset_motion() -> void:
	crash_yaw = 0.0
	speed = 0.0
	road_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	yaw_rate = 0.0

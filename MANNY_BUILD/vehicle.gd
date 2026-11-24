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

func setup(path: String, data: Dictionary) -> bool:
	title = data["title"]
	width = data["width"]
	length = data["length"]
	radius = data["radius"]
	max_speed = data["top"]
	acceleration = data["accel"]
	seat = Vector3(data["seat_x"], data["seat_y"], data["seat_z"])
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
	for name_part in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var wheel := _part(model, name_part)
		if wheel == null:
			push_error("Missing wheel " + name_part)
			return false
		wheels.append(wheel)
		wheel_bases.append(wheel.basis)
	steering_wheel = _part(model, "Steering_Wheel")
	if steering_wheel != null:
		steering_basis = steering_wheel.basis
	else:
		push_warning("No steering node for " + title)
	print("CAR_PARTS: ", title, " wheels=", wheels.size(), " steering=", steering_wheel != null)
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
	return true

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
	var gas: float = 0.0
	var turn: float = 0.0
	var braking: bool = false
	if occupied and engine_on:
		gas = Input.get_axis("move_backward", "move_forward")
		turn = Input.get_axis("move_right", "move_left")
		braking = Input.is_action_pressed("jump")
	var previous: float = speed
	var goal: float = gas * (max_speed if gas >= 0.0 else 7.0)
	var rate: float = acceleration if absf(gas) > 0.01 else 2.4
	if speed * goal < 0.0:
		rate = 9.5
	if braking or not occupied:
		goal = 0.0
		rate = 13.0
	speed = move_toward(speed, goal, rate * delta)
	var angle: float = turn * lerpf(0.49, 0.14, clampf(absf(speed) / max_speed, 0.0, 1.0))
	steer = move_toward(steer, angle, 3.0 * delta)
	if absf(speed) > 0.10:
		rotate_y(tan(steer) * speed / (length * 0.59) * delta)
	var forward := global_transform.basis.z
	velocity = forward * speed
	velocity.y = -1.5
	move_and_slide()
	for k in range(get_slide_collision_count()):
		var collision := get_slide_collision(k)
		if absf(collision.get_normal().y) < 0.35:
			speed *= 0.23
	if absf(global_position.x) > 46.0 or absf(global_position.z) > 46.0:
		global_position.x = clampf(global_position.x, -46.0, 46.0)
		global_position.z = clampf(global_position.z, -46.0, 46.0)
		speed = 0.0
	roll = fposmod(roll + speed * delta / radius, TAU)
	for i in range(wheels.size()):
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var yaw_amount: float = steer if i < 2 else 0.0
		wheels[i].basis = Basis(Vector3.UP, yaw_amount) * wheel_bases[i] * Basis(Vector3.RIGHT, roll * side)
	if steering_wheel != null:
		steering_wheel.basis = steering_basis * Basis(Vector3.FORWARD, -steer * 3.6)
	visual.rotation.z = lerpf(visual.rotation.z, -steer * absf(speed) * 0.007, minf(1.0, delta * 5.0))
	visual.rotation.x = lerpf(visual.rotation.x, (speed - previous) * 0.06, minf(1.0, delta * 6.0))
	if motor != null and engine_on:
		motor.pitch_scale = 0.7 + absf(speed) / max_speed * 1.0 + absf(gas) * 0.14
		motor.volume_db = -22.0 + absf(gas) * 9.0

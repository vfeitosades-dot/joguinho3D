extends CharacterBody3D
## Personagem procedural em formato humanoide, sem assets externos.

const WALK_SPEED: float = 4.8
const RUN_SPEED: float = 7.5
const JUMP_VELOCITY: float = 7.4
const GRAVITY: float = 22.0

var _body_visual: Node3D
var _left_arm: MeshInstance3D
var _right_arm: MeshInstance3D
var _left_leg: MeshInstance3D
var _right_leg: MeshInstance3D
var _walk_phase: float = 0.0

func _ready() -> void:
	_setup_controls()
	floor_snap_length = 0.32
	_create_collision()
	_create_humanoid()

func _setup_controls() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_backward", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("restart", KEY_R)

func _bind_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _create_collision() -> void:
	var collider := CollisionShape3D.new()
	collider.name = "Colisao_Humanoide"
	collider.position.y = 0.97
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.9
	collider.shape = capsule
	add_child(collider)

func _create_humanoid() -> void:
	_body_visual = Node3D.new()
	_body_visual.name = "Modelo_Humanoide"
	add_child(_body_visual)

	var skin := _material(Color(0.95, 0.73, 0.54))
	var shirt := _material(Color(0.10, 0.39, 0.79))
	var pants := _material(Color(0.15, 0.19, 0.28))
	var hair := _material(Color(0.13, 0.12, 0.14))
	var eyes := _material(Color(0.04, 0.06, 0.09))

	_box("Tronco", Vector3(0.0, 1.32, 0.0), Vector3(0.60, 0.71, 0.33), shirt)
	_sphere("Cabeca", Vector3(0.0, 1.88, 0.0), Vector3(0.24, 0.27, 0.24), skin)
	_box("Cabelo", Vector3(0.0, 2.105, 0.0), Vector3(0.49, 0.13, 0.47), hair)
	_sphere("Olho_E", Vector3(-0.105, 1.91, -0.22), Vector3(0.028, 0.036, 0.025), eyes)
	_sphere("Olho_D", Vector3(0.105, 1.91, -0.22), Vector3(0.028, 0.036, 0.025), eyes)

	_left_arm = _box("Braco_E", Vector3(-0.43, 1.31, 0.0), Vector3(0.22, 0.64, 0.27), shirt)
	_right_arm = _box("Braco_D", Vector3(0.43, 1.31, 0.0), Vector3(0.22, 0.64, 0.27), shirt)
	_left_leg = _box("Perna_E", Vector3(-0.16, 0.55, 0.0), Vector3(0.25, 0.90, 0.29), pants)
	_right_leg = _box("Perna_D", Vector3(0.16, 0.55, 0.0), Vector3(0.25, 0.90, 0.29), pants)

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.78
	return m

func _box(label: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = material
	mesh.position = pos
	_body_visual.add_child(mesh)
	return mesh

func _sphere(label: String, pos: Vector3, scale3d: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.position = pos
	mesh.scale = scale3d
	_body_visual.add_child(mesh)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart") or global_position.y < -15.0:
		global_position = Vector3(0.0, 0.04, 0.0)
		velocity = Vector3.ZERO

	var axis: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera: Camera3D = get_viewport().get_camera_3d()
	var move_direction := Vector3.ZERO
	if camera != null:
		var forward: Vector3 = -camera.global_transform.basis.z
		var right: Vector3 = camera.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		move_direction = (right.normalized() * axis.x + forward.normalized() * -axis.y).normalized()
	else:
		move_direction = Vector3(axis.x, 0.0, axis.y).normalized()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		elif velocity.y < 0.0:
			velocity.y = -0.1

	var speed: float = RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = move_direction.x * speed
	velocity.z = move_direction.z * speed
	move_and_slide()

	if move_direction.length_squared() > 0.001:
		_body_visual.rotation.y = lerp_angle(_body_visual.rotation.y,
			atan2(-move_direction.x, -move_direction.z), minf(delta * 11.0, 1.0))

	var moving: bool = move_direction.length_squared() > 0.01 and is_on_floor()
	if moving:
		_walk_phase += delta * (12.0 if speed == RUN_SPEED else 8.5)
	var sway: float = sin(_walk_phase) * 0.35 if moving else 0.0
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, sway, delta * 13.0)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -sway, delta * 13.0)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -sway * 0.75, delta * 13.0)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, sway * 0.75, delta * 13.0)

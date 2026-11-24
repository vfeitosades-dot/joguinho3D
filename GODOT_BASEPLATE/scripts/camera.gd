extends Camera3D
@export var target: Node3D
var yaw: float = 0.0
var pitch: float = 0.36
var distance: float = 4.0
var focus: Vector3
var previous_target: Node3D
var shake: float = 0.0
var phase: float = 0.0
var collision_distance: float = 4.0

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	fov = 68.0
	near = 0.1
	far = 180.0
	if target != null:
		focus = target.global_position + Vector3.UP * 1.18
		target.get_global_transform_interpolated()
		previous_target = target
		global_position = focus + _offset(distance)
		look_at(focus, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -0.14, 1.1)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var driving: bool = target.has_method("seat_world")
	var aim: Vector3 = target.get_global_transform_interpolated().origin + Vector3.UP * (1.15 if driving else 1.18)
	if previous_target != target:
		previous_target = target
		collision_distance = distance
		focus = aim
	focus = focus.lerp(aim, 1.0 - exp(-18.0 * delta))
	var wanted_fov: float = 68.0
	if driving:
		wanted_fov += clampf(absf(float(target.get("speed"))) / 26.0, 0.0, 1.0) * 7.0
		shake = maxf(shake, float(target.get("impact_strength")) * 0.045)
	shake = move_toward(shake, 0.0, delta * 0.20)
	fov = lerpf(fov, wanted_fov, 1.0 - exp(-4.0 * delta))
	var wanted := focus + _offset(distance)
	var ray := PhysicsRayQueryParameters3D.create(focus, wanted)
	ray.collide_with_areas = false
	if target is CollisionObject3D:
		ray.exclude = [(target as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var available: float = distance
	if not hit.is_empty():
		available = maxf(0.48, focus.distance_to(hit.position) - 0.24)
	collision_distance = minf(available, lerpf(collision_distance, available, 1.0 - exp(-9.0 * delta)))
	phase += delta * 31.0
	var offset := _offset(collision_distance)
	var shake_offset := Vector3(sin(phase * 1.2), cos(phase), 0.0) * shake
	var desired := focus + offset + shake_offset
	global_position = global_position.lerp(desired, 1.0 - exp(-16.0 * delta))
	if global_position.distance_to(focus) > 0.05:
		look_at(focus, Vector3.UP)

func _offset(dist: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw)) * dist * cos(pitch) + Vector3.UP * dist * sin(pitch)

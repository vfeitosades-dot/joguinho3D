extends Camera3D
## Câmera orbital suave em terceira pessoa.

@export var target: Node3D

var yaw: float = 0.0
var pitch: float = 0.36
var distance: float = 6.1

func _ready() -> void:
	current = true
	fov = 70.0
	near = 0.1
	far = 180.0
	if target != null:
		global_position = _desired_position()
		look_at(target.global_position + Vector3.UP * 1.25, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw += event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -0.14, 1.1)

func _process(delta: float) -> void:
	if target == null:
		return
	var aim := target.global_position + Vector3.UP * 1.25
	var wanted := _desired_position()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(aim, wanted)
	query.collide_with_areas = false
	if target is CollisionObject3D:
		query.exclude = [(target as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		wanted = aim + (wanted - aim).normalized() * maxf(0.45, aim.distance_to(hit.position) - 0.3)
	global_position = global_position.lerp(wanted, 1.0 - exp(-11.0 * delta))
	look_at(aim, Vector3.UP)

func _desired_position() -> Vector3:
	var aim := target.global_position + Vector3.UP * 1.25
	var horizontal := Vector3(sin(yaw), 0.0, cos(yaw))
	return aim + horizontal * (distance * cos(pitch)) + Vector3.UP * (distance * sin(pitch))

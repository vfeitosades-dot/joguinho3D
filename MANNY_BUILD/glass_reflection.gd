extends Node3D
# One low-resolution planar capture of the actual animated player.
var actor: Node3D
var main_camera: Camera3D
var cars: Array = []
var capture: SubViewport
var mirror_camera: Camera3D
var overlay: ShaderMaterial
var selected: Node3D
var elapsed: float = 0.0
var quality: int = 0
var capture_count: int = 0
var current_plane: Vector3 = Vector3.ZERO
var current_normal: Vector3 = Vector3.RIGHT

func setup(player: Node3D, camera: Camera3D) -> void:
	actor = player
	main_camera = camera
	_mark_actor(player)
	capture = SubViewport.new()
	capture.size = Vector2i(256,144)
	capture.transparent_bg = true
	capture.world_3d = get_viewport().world_3d
	capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(capture)
	mirror_camera = Camera3D.new()
	mirror_camera.cull_mask = 2
	mirror_camera.current = true
	mirror_camera.near = 0.05
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9,0.94,1.0)
	env.ambient_light_energy = 0.85
	mirror_camera.environment = env
	capture.add_child(mirror_camera)
	overlay = ShaderMaterial.new()
	overlay.shader = preload("res://scripts/player_glass.gdshader")
	overlay.render_priority = 4
	overlay.set_shader_parameter("mirror_tex",capture.get_texture())

func _mark_actor(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).layers = 2
	for child in node.get_children():
		_mark_actor(child)

func set_quality(mode: int) -> void:
	quality = mode
	if capture != null:
		capture.size = Vector2i(192,108) if mode == 0 else (Vector2i(320,180) if mode == 1 else Vector2i(480,270))

func _clear() -> void:
	if is_instance_valid(selected):
		selected.call("set_glass_overlay",null)
	selected = null

func update_reflection(delta: float, blocked: bool) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(main_camera) or capture == null:
		return
	if blocked:
		_clear()
		return
	elapsed += delta
	if elapsed < (0.066 if quality == 0 else 0.042):
		return
	elapsed = 0.0
	var cam_pos: Vector3 = main_camera.global_position
	var chosen: Node3D = null
	var plane_pos: Vector3 = Vector3.ZERO
	var plane_n: Vector3 = Vector3.RIGHT
	var score: float = INF
	for car in cars:
		if not is_instance_valid(car) or not car.get("visual").visible:
			continue
		if actor.global_position.distance_to(car.global_position) > 5.2:
			continue
		var car_visual: Node3D = car.get("visual")
		var local_cam: Vector3 = car_visual.to_local(cam_pos)
		var side: float = 1.0 if local_cam.x >= 0.0 else -1.0
		var fit: Array = car.get("glass_plane")
		if fit.size() != 6:
			continue
		var pp: Vector3 = car_visual.to_global(Vector3(float(fit[0])*side,float(fit[1]),float(fit[2])))
		var nn: Vector3 = (car_visual.global_basis * Vector3(float(fit[3])*side,float(fit[4]),float(fit[5]))).normalized()
		var camera_side: float = (cam_pos-pp).dot(nn)
		var player_side: float = (actor.global_position+Vector3.UP*0.85-pp).dot(nn)
		if camera_side < 0.25 or player_side < 0.05 or absf(float(car.get("door_angle"))) > 0.12:
			continue
		var d: float = actor.global_position.distance_to(pp)
		if d < score:
			score = d
			chosen = car
			plane_pos = pp
			plane_n = nn
	if chosen == null:
		_clear()
		return
	if selected != chosen:
		_clear()
		selected = chosen
		selected.call("set_glass_overlay",overlay)
	current_plane = plane_pos
	current_normal = plane_n
	var mirrored: Vector3 = cam_pos - 2.0 * (cam_pos-plane_pos).dot(plane_n)*plane_n
	var forward: Vector3 = -main_camera.global_basis.z
	var up: Vector3 = main_camera.global_basis.y
	forward = forward - 2.0*forward.dot(plane_n)*plane_n
	up = up - 2.0*up.dot(plane_n)*plane_n
	mirror_camera.global_position = mirrored
	mirror_camera.look_at(mirrored+forward,up)
	mirror_camera.fov = main_camera.fov
	mirror_camera.far = main_camera.far
	overlay.set_shader_parameter("plane_point",plane_pos)
	overlay.set_shader_parameter("plane_normal",plane_n)
	overlay.set_shader_parameter("strength",clampf(1.0-(score-0.7)/5.0,0.12,0.88))
	capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	capture_count += 1

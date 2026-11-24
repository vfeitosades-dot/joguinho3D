extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const CAMERA_SCRIPT = preload("res://scripts/camera.gd")
const CAR_SCRIPT = preload("res://scripts/vehicle.gd")
const DATA_PATH = "res://assets/garage/catalog.json"
var player: CharacterBody3D
var camera: Camera3D
var cars: Array[CharacterBody3D] = []
var active: CharacterBody3D
var nearest: CharacterBody3D
var locked: bool = false
var puzzle: bool = false
var stage: int = 0
var pulse: float = 0.0
var targets: Array[float] = [0.32, 0.70, 0.48]
var ui: CanvasLayer
var hint: Label
var speed_label: Label
var fps_label: Label
var status_label: Label
var title_label: Label
var puzzle_panel: PanelContainer
var pulse_bar: ProgressBar
var puzzle_title: Label
var puzzle_hint: Label
var target_label: Label
var quality: int = 0
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var perf_timer: float = 0.0
var loading: bool = true
var sky_quality: Sky


func _ready() -> void:
	_create_world()
	_create_ground()
	_create_wall()
	player = CharacterBody3D.new()
	player.name = "Humanoide"
	player.position = Vector3(0.0, 0.04, -6.0)
	player.set_script(PLAYER_SCRIPT)
	add_child(player)
	camera = Camera3D.new()
	camera.set_script(CAMERA_SCRIPT)
	camera.set("target", player)
	camera.current = true
	add_child(camera)
	_create_ui()
	_apply_quality(0)
	player.set_physics_process(false)
	_load_cars.call_deferred()

func _load_cars() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not raw is Array:
		loading = false
		player.set_physics_process(true)
		push_error("GARAGE_CATALOG_MISSING")
		return
	var catalog: Array = raw
	for i in range(catalog.size()):
		hint.text = "Carregando veículos %d / %d" % [i + 1, catalog.size()]
		for frame in range(3):
			await get_tree().process_frame
		print("CAR_LOADING: ", catalog[i]["file"])
		var data: Dictionary = catalog[i]
		var car := CharacterBody3D.new()
		car.set_script(CAR_SCRIPT)
		car.position = Vector3(-18.0 + float(i % 4) * 12.0, 0.03, 4.0 + float(floori(float(i) / 4.0)) * 12.0)
		car.rotation.y = PI if i >= 4 else 0.0
		add_child(car)
		if car.call("setup", "res://assets/garage/" + str(data["file"]) + ".glbdata", data):
			cars.append(car)
		else:
			car.queue_free()
	loading = false
	player.set_physics_process(true)
	if cars.size() == 7:
		print("GARAGE_READY: 7 cars")
	else:
		push_error("Garage failed: " + str(cars.size()))
	if "--garage-test" in OS.get_cmdline_user_args():
		_test.call_deferred()

func _test() -> void:
	if cars.size() != 7:
		get_tree().quit(1)
		return
	player.global_position = cars[0].to_global(Vector3(1.7, 0.04, 0))
	_enter(cars[0], true)
	for i in range(3):
		pulse = targets[stage]
		_press_puzzle()
	if active == null or not bool(active.get("engine_on")):
		push_error("Garage ignition state failed")
		get_tree().quit(2)
		return
	Input.action_press("move_forward")
	for i in range(18):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	if float(active.get("speed")) <= 0.1:
		get_tree().quit(3)
		return
	active.set("speed", 0.0)
	_exit(true)
	if active != null or not player.is_physics_processing():
		get_tree().quit(4)
		return
	print("GARAGE_TEST_OK")
	var gesture := player.get("wall_touch") as Node
	if gesture == null or gesture.get("ik") == null:
		push_error("Wall gesture not initialized")
		get_tree().quit(5)
		return
	player.global_position = Vector3(0, 0.04, -12.38)
	var body := player.get("_body_visual") as Node3D
	body.rotation.y = 0.0
	for i in range(36):
		await get_tree().physics_frame
	if not bool(gesture.get("active_contact")) or float(gesture.get("blend")) < 0.75:
		push_error("Wall contact not detected: " + str(gesture.get("blend")))
		get_tree().quit(6)
		return
	player.global_position = Vector3(0, 0.04, -10.0)
	for i in range(30):
		await get_tree().physics_frame
	if float(gesture.get("blend")) > 0.01:
		get_tree().quit(7)
		return
	print("WALL_TOUCH_TEST_OK")
	get_tree().quit()

func _create_wall() -> void:
	var wall := StaticBody3D.new()
	wall.name = "Parede_de_teste"
	wall.position = Vector3(0.0, 1.45, -13.0)
	wall.add_to_group("touch_wall")
	add_child(wall)
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.0, 2.9, 0.36)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.56, 0.58, 0.60)
	mat.roughness = 0.93
	mesh.material_override = mat
	wall.add_child(mesh)

func _create_world() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.61, 0.75, 0.90)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.89, 0.91, 0.97)
	env.ambient_light_energy = 0.82
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-37, -38, 0)
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.light_energy = 1.18
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 26.0
	add_child(sun)

func _create_ground() -> void:
	var ground := StaticBody3D.new()
	ground.position.y = -0.5
	add_child(ground)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	col.shape = box
	ground.add_child(col)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = box.size
	mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.32, 0.35)
	mat.roughness = 0.92
	var tex := load("res://assets/garage/asphalt.png") as Texture2D
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(48, 48, 48)
	mesh.material_override = mat
	ground.add_child(mesh)
	for i in range(7):
		var x: float = -18.0 + float(i % 4) * 12.0
		var z: float = 4.0 + float(floori(float(i) / 4.0)) * 12.0
		_mark(Vector3(x - 1.8, 0.014, z), Vector3(0.075, 0.012, 6.1))
		_mark(Vector3(x + 1.8, 0.014, z), Vector3(0.075, 0.012, 6.1))
		_mark(Vector3(x, 0.014, z + 3.05), Vector3(3.6, 0.012, 0.075))
	for i in range(15):
		_mark(Vector3(-42.0 + float(i) * 6.0, 0.012, -18.0), Vector3(2.6, 0.01, 0.10))

func _mark(pos: Vector3, size: Vector3) -> void:
	var item := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	item.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.67)
	mat.roughness = 0.98
	item.material_override = mat
	item.position = pos
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 15
	s.content_margin_right = 15
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _label(content: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _create_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var left := PanelContainer.new()
	left.position = Vector2(15, 15)
	left.add_theme_stylebox_override("panel", _style(Color(0.035, 0.055, 0.08, 0.90), Color(0.27, 0.37, 0.47, 0.8)))
	root.add_child(left)
	var stack := VBoxContainer.new()
	left.add_child(stack)
	title_label = _label("MANNY   /   MOTOR LAB", 19, Color(0.9, 0.95, 1.0))
	stack.add_child(title_label)
	hint = _label("WASD  |  Mouse  |  E: interagir", 13, Color(0.77, 0.85, 0.92))
	stack.add_child(hint)
	fps_label = _label("", 12, Color(0.52, 0.78, 0.92))
	stack.add_child(fps_label)
	var hud := PanelContainer.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hud.offset_left = -228
	hud.offset_top = -110
	hud.offset_right = -15
	hud.offset_bottom = -15
	hud.add_theme_stylebox_override("panel", _style(Color(0.035, 0.055, 0.08, 0.88), Color(0.27, 0.37, 0.47)))
	var bottom := VBoxContainer.new()
	hud.add_child(bottom)
	speed_label = _label("00  km/h", 30, Color.WHITE)
	bottom.add_child(speed_label)
	status_label = _label("A PÉ", 13, Color(0.66, 0.82, 0.93))
	bottom.add_child(status_label)
	puzzle_panel = PanelContainer.new()
	root.add_child(puzzle_panel)
	puzzle_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	puzzle_panel.offset_left = -184
	puzzle_panel.offset_right = 184
	puzzle_panel.offset_top = -112
	puzzle_panel.offset_bottom = 112
	puzzle_panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.055, 0.08, 0.97), Color(0.33, 0.72, 0.88)))
	var panel_stack := VBoxContainer.new()
	panel_stack.add_theme_constant_override("separation", 12)
	puzzle_panel.add_child(panel_stack)
	puzzle_title = _label("ATIVAÇÃO DO VEÍCULO", 21, Color(0.9, 0.97, 1.0))
	panel_stack.add_child(puzzle_title)
	puzzle_hint = _label("Pressione ESPAÇO na zona indicada.", 14, Color(0.75, 0.86, 0.94))
	panel_stack.add_child(puzzle_hint)
	target_label = _label("", 15, Color(0.35, 0.9, 0.73))
	panel_stack.add_child(target_label)
	pulse_bar = ProgressBar.new()
	pulse_bar.max_value = 100.0
	pulse_bar.show_percentage = false
	pulse_bar.custom_minimum_size = Vector2(330, 24)
	pulse_bar.add_theme_stylebox_override("background", _style(Color(0.11, 0.15, 0.19), Color(0.24, 0.35, 0.43)))
	pulse_bar.add_theme_stylebox_override("fill", _style(Color(0.19, 0.64, 0.82), Color(0.30, 0.8, 0.95)))
	panel_stack.add_child(pulse_bar)
	panel_stack.add_child(_label("E  cancelar  •  teste fictício de reflexo", 12, Color(0.58, 0.68, 0.78)))
	puzzle_panel.hide()

func _apply_quality(mode: int) -> void:
	quality = mode
	var window := get_window()
	window.content_scale_size = Vector2i(960, 540) if mode == 1 else Vector2i(640, 360)
	if mode == 1 and sky_quality == null:
		sky_quality = Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.19, 0.40, 0.69)
		sky_mat.sky_horizon_color = Color(0.76, 0.86, 0.96)
		sky_quality.sky_material = sky_mat
		sky_quality.radiance_size = Sky.RADIANCE_SIZE_32
	var env := world_env.environment
	env.sky = sky_quality if mode == 1 else null
	env.background_mode = Environment.BG_SKY if mode == 1 else Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if mode == 1 else Environment.AMBIENT_SOURCE_COLOR
	sun.shadow_enabled = mode == 1
	camera.far = 100.0 if mode == 1 else 78.0

func _process(delta: float) -> void:
	if loading:
		return
	perf_timer += delta
	if perf_timer > 0.3:
		perf_timer = 0.0
		fps_label.text = "%d FPS   |   F1: %s" % [Engine.get_frames_per_second(), "QUALIDADE" if quality == 1 else "DESEMPENHO"]
	if active != null:
		if not locked:
			player.global_position = active.to_global(active.get("seat"))
			player.global_rotation = active.global_rotation
		speed_label.text = "%02d  km/h" % int(absf(float(active.get("speed"))) * 3.6)
		status_label.text = str(active.get("title")) + ("  /  ON" if active.get("engine_on") else "  /  OFF")
		hint.text = "WASD dirigir  |  ESPAÇO freio  |  E sair" if not puzzle else "Ativação do veículo"
		if puzzle:
			pulse += delta * (0.68 + float(stage) * 0.13)
			if pulse > 1.0:
				pulse = fposmod(pulse, 1.0)
			pulse_bar.value = pulse * 100.0
			pulse_bar.modulate = Color(0.60, 1.0, 0.72) if absf(pulse - targets[stage]) <= 0.11 else Color.WHITE
	else:
		speed_label.text = "00  km/h"
		status_label.text = "A PÉ"
		nearest = null
		var best: float = 3.5
		for car in cars:
			var d: float = player.global_position.distance_to(car.global_position)
			if d < best:
				best = d
				nearest = car
		hint.text = "E  entrar  •  " + str(nearest.get("title")) if nearest != null else "WASD andar  |  Mouse câmera  |  SHIFT correr"
	# Keep distant parked meshes out of the low-end GPU draw list.
	for car in cars:
		var visual := car.get("visual") as Node3D
		if visual != null:
			visual.visible = car == active or camera.global_position.distance_to(car.global_position) < (50.0 if quality == 1 else 29.0)

func _input(event: InputEvent) -> void:
	if loading:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F1:
		_apply_quality(1 - quality)
	elif event.physical_keycode == KEY_E and not locked:
		if active != null:
			if absf(float(active.get("speed"))) < 1.2:
				_exit()
		elif nearest != null:
			_enter(nearest)
	elif event.physical_keycode == KEY_SPACE and puzzle and not locked:
		_press_puzzle()
		get_viewport().set_input_as_handled()

func _enter(car: CharacterBody3D, immediate: bool = false) -> void:
	active = car
	locked = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.global_rotation = car.global_rotation
	var body := player.get("_body_visual") as Node3D
	body.rotation.y = PI
	player.call("_play", "enter")
	var destination: Vector3 = car.to_global(car.get("seat"))
	if not immediate:
		var tween := create_tween()
		tween.tween_property(player, "global_position", destination, 0.75).set_trans(Tween.TRANS_SINE)
		await tween.finished
	else:
		player.global_position = destination
	player.call("_play", "drive")
	camera.set("target", car)
	camera.set("distance", 6.1)
	camera.set("yaw", car.rotation.y + PI)
	car.set("occupied", true)
	locked = false
	if not car.get("engine_on"):
		puzzle = true
		stage = 0
		pulse = 0.0
		puzzle_panel.show()
		_update_puzzle()

func _exit(immediate: bool = false) -> void:
	if active == null:
		return
	var car := active
	locked = true
	puzzle = false
	puzzle_panel.hide()
	car.set("occupied", false)
	car.call("stop_engine")
	player.call("_play", "exit")
	var exit_pos: Vector3 = car.to_global(Vector3(float(car.get("width")) * 0.5 + 0.78, 0.04, 0.0))
	if not immediate:
		var tween := create_tween()
		tween.tween_property(player, "global_position", exit_pos, 0.72).set_trans(Tween.TRANS_SINE)
		await tween.finished
	else:
		player.global_position = exit_pos
	active = null
	player.global_rotation = Vector3.ZERO
	player.collision_layer = 1
	player.collision_mask = 1
	player.call("_play", "idle")
	player.set_physics_process(true)
	camera.set("target", player)
	camera.set("distance", 4.0)
	locked = false

func _update_puzzle() -> void:
	puzzle_title.text = "ATIVAÇÃO   %d / 3" % (stage + 1)
	target_label.text = "ZONA VERDE   %d–%d%%" % [int((targets[stage] - 0.11) * 100.0), int((targets[stage] + 0.11) * 100.0)]

func _press_puzzle() -> void:
	if not puzzle or active == null:
		return
	if absf(pulse - targets[stage]) <= 0.11:
		stage += 1
		if stage >= targets.size():
			active.call("start_engine")
			puzzle = false
			puzzle_panel.hide()
			return
		pulse = 0.0
		puzzle_hint.text = "Correto. Acerte a próxima zona."
	else:
		puzzle_hint.text = "Fora da zona. Tente novamente."
		pulse = 0.0
	_update_puzzle()

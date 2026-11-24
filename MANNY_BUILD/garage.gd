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
var menu_open: bool = false
var menu: Control
var play_button: Button
var quality_select: OptionButton
var testing: bool = false
var seating_weight: float = 0.0
var dash: Control
var hud_panel: PanelContainer
var hud_clock: float = 0.0
var seated_scale: float = 0.88


func _ready() -> void:
	_create_world()
	_create_ground()
	_create_wall()
	_create_details()
	var sky_fx := Node3D.new()
	sky_fx.set_script(preload("res://scripts/sky_fx.gd"))
	add_child(sky_fx)
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
	testing = "--garage-test" in OS.get_cmdline_user_args()
	_create_ui()
	_create_menu()
	_apply_quality(1)
	quality_select.select(1)
	if not testing:
		get_window().mode = Window.MODE_FULLSCREEN
		_show_menu(true)

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
	player.set_physics_process(not menu_open)
	play_button.disabled = false
	play_button.text = "JOGAR"
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
	var gesture := player.get("wall_touch") as Node
	if gesture == null or gesture.get("ik") == null:
		get_tree().quit(5)
		return
	# Test seat and wheel anchors on all seven cars.
	for car in cars:
		player.global_position = car.to_global(Vector3(1.7, 0.04, 0))
		_enter(car, true)
		for i in range(22):
			await get_tree().physics_frame
			await get_tree().process_frame
		if car.get("grip_left") == null or car.get("grip_right") == null:
			get_tree().quit(10)
			return
		var hip: Vector3 = gesture.call("hips_world")
		var anchor: Vector3 = car.call("seat_world")
		if hip.distance_to(anchor) > 0.16:
			push_error("Seat alignment failed: " + str(hip.distance_to(anchor)))
			get_tree().quit(11)
			return
		var arms: Array = gesture.get("solvers")
		if arms.size() != 2 or arms[0].influence < 0.1 or arms[1].influence < 0.1:
			get_tree().quit(12)
			return
		_exit(true)
	print("SEATING_TEST_OK")
	player.global_position = cars[0].to_global(Vector3(1.7, 0.04, 0))
	_enter(cars[0], true)
	for i in range(3):
		pulse = targets[stage]
		_press_puzzle()
	if active == null or not bool(active.get("engine_on")):
		get_tree().quit(2)
		return
	Input.action_press("move_forward")
	for i in range(48):
		await get_tree().physics_frame
	if float(active.get("speed")) <= 0.5:
		get_tree().quit(3)
		return
	var before_yaw: float = active.rotation.y
	Input.action_press("move_left")
	for i in range(25):
		await get_tree().physics_frame
	Input.action_release("move_left")
	Input.action_release("move_forward")
	if absf(angle_difference(before_yaw, active.rotation.y)) < 0.02:
		get_tree().quit(13)
		return
	var before_brake: float = absf(float(active.get("speed")))
	Input.action_press("jump")
	for i in range(48):
		await get_tree().physics_frame
	Input.action_release("jump")
	if absf(float(active.get("speed"))) >= before_brake * 0.8:
		get_tree().quit(14)
		return
	active.call("reset_motion")
	_exit(true)
	print("DRIVING_PHYSICS_TEST_OK")
	cars[0].call("_register_impact", 6.0, Vector3.FORWARD)
	if int(cars[0].get("impact_count")) < 1 or float(cars[0].get("impact_strength")) < 0.1:
		get_tree().quit(15)
		return
	print("IMPACT_TEST_OK")
	if active != null or not player.is_physics_processing():
		get_tree().quit(4)
		return
	for car in cars:
		if car.get("door") == null:
			get_tree().quit(8)
			return
		car.call("set_door", true)
		for frame in range(18):
			await get_tree().physics_frame
		if absf(float(car.get("door_angle"))) < 0.3:
			get_tree().quit(9)
			return
		car.call("set_door", false)
	print("DOORS_TEST_OK")
	print("GARAGE_TEST_OK")
	var body := player.get("_body_visual") as Node3D
	# Wall on right when facing -X, and on left when facing +X.
	for side in range(2):
		gesture.call("release_now")
		player.global_position = Vector3(0, 0.04, -12.38)
		body.rotation.y = PI / 2.0 if side == 0 else -PI / 2.0
		gesture.set("heading", Vector3.LEFT if side == 0 else Vector3.RIGHT)
		for i in range(48):
			await get_tree().physics_frame
		var amounts: Array = gesture.get("hand_blends")
		if float(amounts[side]) < 0.70 or float(amounts[1 - side]) > 0.05:
			push_error("Independent hand failed: " + str(amounts))
			get_tree().quit(6)
			return
		player.global_position = Vector3(0, 0.04, -10.0)
		for i in range(36):
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

func _create_details() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.30, 0.34, 0.39)
	concrete.roughness = 0.9
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.82, 0.60, 0.18)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.10, 0.14)
	for i in range(5):
		var x := -44.0 + float(i) * 22.0
		_detail_box(Vector3(x, 2.0, 30.0), Vector3(0.65, 4.0, 0.65), concrete)
		_detail_box(Vector3(x, 0.6, 30.0), Vector3(0.7, 0.16, 0.7), accent)
	_detail_box(Vector3(0, 4.0, 30), Vector3(90, 0.35, 0.7), concrete)
	_detail_box(Vector3(0, 1.2, 33), Vector3(90, 2.4, 0.35), dark)
	for i in range(6):
		_detail_box(Vector3(-40.0 + i * 16.0, 0.11, -25.0), Vector3(0.25, 0.22, 4.0), accent)
	for i in range(4):
		_detail_box(Vector3(-3.2 + i * 2.15, 2.79, -12.79), Vector3(0.08, 0.08, 0.08), accent)

func _detail_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	add_child(instance)

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
	sun.light_color = Color(1.0, 0.94, 0.81)
	sun.light_energy = 1.25
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
	hud_panel = hud
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hud.offset_left = -322
	hud.offset_top = -204
	hud.offset_right = -15
	hud.offset_bottom = -15
	hud.add_theme_stylebox_override("panel", _style(Color(0.035, 0.055, 0.08, 0.88), Color(0.27, 0.37, 0.47)))
	var bottom := VBoxContainer.new()
	hud.add_child(bottom)
	status_label = _label("VEÍCULO", 14, Color(0.72, 0.88, 0.93))
	bottom.add_child(status_label)
	speed_label = _label("", 12, Color.WHITE)
	speed_label.hide()
	bottom.add_child(speed_label)
	dash = Control.new()
	dash.set_script(preload("res://scripts/dashboard.gd"))
	dash.custom_minimum_size = Vector2(290, 155)
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(dash)
	hud.hide()
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

func _create_menu() -> void:
	menu = Control.new()
	ui.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	menu.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.018, 0.026, 0.04, 0.77)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.045, 0.067, 0.095, 0.98), Color(0.22, 0.43, 0.56)))
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	stack.add_child(_label("MOTOR / LAB", 40, Color(0.94, 0.97, 1.0)))
	stack.add_child(_label("DRIVING EXPERIENCE     •     V10", 14, Color(0.35, 0.81, 0.91)))
	stack.add_child(HSeparator.new())
	play_button = _menu_button("CARREGANDO VEÍCULOS…")
	play_button.disabled = true
	play_button.pressed.connect(func(): _show_menu(false))
	stack.add_child(play_button)
	stack.add_child(_label("RESOLUÇÃO DE RENDERIZAÇÃO", 13, Color(0.70, 0.81, 0.88)))
	quality_select = OptionButton.new()
	quality_select.add_item("960 × 540  •  Desempenho")
	quality_select.add_item("1280 × 720  •  HD")
	quality_select.add_item("1920 × 1080  •  Full HD")
	quality_select.custom_minimum_size.y = 40
	quality_select.item_selected.connect(_apply_quality)
	stack.add_child(quality_select)
	var full := _menu_button("TELA CHEIA / JANELA")
	full.pressed.connect(func(): get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN)
	stack.add_child(full)
	var quit := _menu_button("SAIR")
	quit.pressed.connect(func(): get_tree().quit())
	stack.add_child(quit)
	stack.add_child(_label("WASD • E interagir • ESC menu • F11 tela cheia", 12, Color(0.64, 0.73, 0.81)))
	menu.hide()

func _menu_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _style(Color(0.09, 0.16, 0.22), Color(0.21, 0.35, 0.43)))
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.30, 0.38), Color(0.39, 0.79, 0.90)))
	return button

func _show_menu(show: bool) -> void:
	menu_open = show
	menu.visible = show
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED
	player.set_physics_process(not show and not loading and active == null)
	camera.set_process_unhandled_input(not show)
	if not loading:
		play_button.text = "CONTINUAR"

func _apply_quality(mode: int) -> void:
	quality = mode
	var window := get_window()
	window.content_scale_size = Vector2i(1920, 1080) if mode == 2 else (Vector2i(1280, 720) if mode == 1 else Vector2i(960, 540))
	if mode >= 1 and sky_quality == null:
		sky_quality = Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.18, 0.43, 0.76)
		sky_mat.sky_horizon_color = Color(0.78, 0.88, 0.97)
		sky_mat.sun_angle_max = 8.0
		sky_quality.sky_material = sky_mat
		sky_quality.radiance_size = Sky.RADIANCE_SIZE_32
	var env := world_env.environment
	env.sky = sky_quality if mode >= 1 else null
	env.background_mode = Environment.BG_SKY if mode >= 1 else Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if mode >= 1 else Environment.AMBIENT_SOURCE_COLOR
	sun.shadow_enabled = mode == 2
	camera.far = 100.0 if mode >= 1 else 78.0

func _process(delta: float) -> void:
	if loading or menu_open:
		return
	perf_timer += delta
	if perf_timer > 0.3:
		perf_timer = 0.0
		fps_label.text = "%d FPS   |   F1: %s" % [Engine.get_frames_per_second(), ["540p", "720p", "1080p"][quality]]
	if active != null:
		if not locked:
			player.global_rotation = active.get_global_transform_interpolated().basis.get_euler()
			var visual_body := player.get("_body_visual") as Node3D
			var car_visual := active.get("visual") as Node3D
			visual_body.rotation.x = -car_visual.rotation.x
			visual_body.rotation.z = -car_visual.rotation.z
			var rig := player.get("wall_touch") as Node
			seating_weight = move_toward(seating_weight, 1.0, delta * 3.0)
			rig.call("align_hips", active.call("rendered_seat_world"), 1.0)
			rig.call("drive_pose", active, delta, seating_weight)
		hud_panel.show()
		dash.set("speed", absf(float(active.get("speed"))) * 3.6)
		dash.set("max_speed", float(active.get("max_speed")) * 3.6)
		dash.set("throttle", active.get("throttle"))
		dash.set("brake", active.get("brake_pressure"))
		dash.set("impact", active.get("impact_strength"))
		dash.set("engine_on", active.get("engine_on"))
		dash.set("gear", "R" if float(active.get("speed")) < -0.2 else ("D" if active.get("engine_on") else "P"))
		status_label.text = str(active.get("title")).to_upper()
		hint.text = "WASD dirigir  |  ESPAÇO freio  |  E sair" if not puzzle else "Ativação do veículo"
		if puzzle:
			pulse += delta * (0.68 + float(stage) * 0.13)
			if pulse > 1.0:
				pulse = fposmod(pulse, 1.0)
			pulse_bar.value = pulse * 100.0
			pulse_bar.modulate = Color(0.60, 1.0, 0.72) if absf(pulse - targets[stage]) <= 0.11 else Color.WHITE
	else:
		hud_panel.hide()
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
			visual.visible = car == active or camera.global_position.distance_to(car.global_position) < (50.0 if quality >= 1 else 36.0)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F11 and not testing:
		get_window().mode = Window.MODE_WINDOWED if get_window().mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and not locked:
		_show_menu(not menu_open)
		get_viewport().set_input_as_handled()
		return
	if loading or menu_open:
		return
	if event.physical_keycode == KEY_F1:
		_apply_quality((quality + 1) % 3)
		quality_select.select(quality)
	elif event.physical_keycode == KEY_E and not locked:
		if active != null:
			if absf(float(active.get("speed"))) < 1.2:
				_exit()
		elif nearest != null:
			_enter(nearest)
	elif event.physical_keycode == KEY_SPACE and puzzle and not locked:
		_press_puzzle()
		get_viewport().set_input_as_handled()

func _clip_duration(name: String, fallback: float) -> float:
	var anim := player.get("_anim") as AnimationPlayer
	var clips: Dictionary = player.get("_clips")
	if anim == null or not clips.has(name):
		return fallback
	return clampf(anim.get_animation(clips[name]).length, 0.5, 2.5)

func _enter(car: CharacterBody3D, immediate: bool = false) -> void:
	active = car
	locked = true
	seating_weight = 0.0
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var body := player.get("_body_visual") as Node3D
	var rig := player.get("wall_touch") as Node
	rig.call("release_now")
	car.call("reset_motion")
	var anchor: Vector3 = car.get("hip_anchor")
	var approach: Vector3 = car.to_global(Vector3(float(car.get("width")) * 0.5 + 0.43, 0.04, anchor.z + 0.12))
	var sill: Vector3 = car.to_global(Vector3(float(car.get("width")) * 0.35, 0.15, anchor.z))
	var destination: Vector3 = car.call("seat_world")
	if not immediate:
		var heading: Vector3 = (approach - player.global_position).normalized()
		player.call("_play", "walk")
		var target_yaw: float = atan2(-heading.x, -heading.z)
		var walk := create_tween().set_parallel(true)
		walk.tween_property(player, "global_position", approach, clampf(player.global_position.distance_to(approach) / 1.6, 0.22, 1.4)).set_trans(Tween.TRANS_SINE)
		walk.tween_property(body, "rotation:y", body.rotation.y + angle_difference(body.rotation.y, target_yaw), 0.24)
		await walk.finished
		player.call("_play", "idle")
		car.call("set_door", true)
		await get_tree().create_timer(0.30).timeout
		player.global_rotation = car.global_rotation
		body.rotation.y = PI / 2.0
		player.call("_play", "enter")
		var duration: float = _clip_duration("enter", 1.1)
		var start_hips: Vector3 = rig.call("hips_world")
		var bend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bend.tween_property(player, "global_position", sill, duration * 0.40)
		bend.parallel().tween_property(body, "rotation:y", PI, duration * 0.72)
		bend.parallel().tween_property(body, "scale", Vector3.ONE * seated_scale, duration * 0.80)
		await bend.finished
		var settle := create_tween()
		settle.tween_method(func(t: float):
			var hips: Vector3 = rig.call("hips_world")
			var desired: Vector3 = hips.lerp(destination, t)
			rig.call("align_hips", desired, 1.0), 0.0, 1.0, duration * 0.35)
		await settle.finished
	else:
		car.call("set_door", true)
		player.global_rotation = car.global_rotation
		body.rotation.y = PI
		body.scale = Vector3.ONE * seated_scale
		player.global_position = car.to_global(car.get("seat"))
	player.call("_play", "drive")
	var anim := player.get("_anim") as AnimationPlayer
	if anim != null:
		anim.advance(0.0)
	rig.call("align_hips", destination, 1.0)
	if not immediate:
		for i in range(12):
			await get_tree().physics_frame
			rig.call("align_hips", car.call("seat_world"), 1.0)
			rig.call("drive_pose", car, 1.0 / 60.0, float(i + 1) / 12.0)
	car.call("set_door", false)
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
	car.call("reset_motion")
	car.call("stop_engine")
	car.call("set_door", true)
	var body := player.get("_body_visual") as Node3D
	var rig := player.get("wall_touch") as Node
	rig.call("release_now")
	var anchor: Vector3 = car.get("hip_anchor")
	var exit_pos: Vector3 = car.to_global(Vector3(float(car.get("width")) * 0.5 + 0.65, 0.04, anchor.z))
	if not immediate:
		await get_tree().create_timer(0.28).timeout
		player.call("_play", "exit")
		var duration: float = _clip_duration("exit", 1.0)
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		tween.tween_property(player, "global_position", exit_pos, duration)
		tween.tween_property(body, "scale", Vector3.ONE, duration * 0.85)
		tween.tween_property(body, "rotation:y", PI / 2.0, duration * 0.8)
		await tween.finished
	else:
		player.global_position = exit_pos
	body.scale = Vector3.ONE
	body.rotation = Vector3(0.0, car.rotation.y + PI / 2.0, 0.0)
	car.call("set_door", false)
	active = null
	player.global_rotation = Vector3.ZERO
	player.collision_layer = 1
	player.collision_mask = 1
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	player.reset_physics_interpolation()
	player.call("_play", "idle")
	player.set_physics_process(true)
	camera.set("target", player)
	camera.set("distance", 4.0)
	locked = false
	seating_weight = 0.0

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

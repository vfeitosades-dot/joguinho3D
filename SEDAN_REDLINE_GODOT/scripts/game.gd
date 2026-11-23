extends Node3D
## REDLINE. Only a baseplate and an animated, procedural low-poly sedan.
## 4.x / Windows. The fictional hotwire mechanic is timing-based, not a wiring guide.

const FACTORY = preload("res://scripts/car_factory.gd")
const HOTWIRE_UI = preload("res://scripts/hotwire_ui.gd")

var car_root: Node3D
var wheel_nodes: Array
var steering_nodes: Array
var doors: Array
var hood: Node3D
var trunk: Node3D
var steering_wheel: Node3D
var door_state := [false, false, false, false]
var hood_open := false
var trunk_open := false
var is_driving := false
var engine_on := false
var headlights_on := true
var velocity := 0.0
var steering := 0.0
var car_yaw := 0.0
var driving_time := 0.0
var mouse_drag := false
var cam_azimuth := 2.57
var cam_distance := 7.8
var cam_height := 3.35
var camera: Camera3D
var hotwire: Control
var hud_speed: Label
var hud_state: Label
var hud_hint: Label
var hud_title: Label
var intro: PanelContainer
var exhaust: GPUParticles3D
var lights: Array[SpotLight3D] = []
var engine_player: AudioStreamPlayer3D
var start_player: AudioStreamPlayer3D
var tap_player: AudioStreamPlayer
var low_car: Node3D
var full_car: Node3D
var low_wheels: Array = []
var low_steer: Array = []
var full_wheels: Array = []
var full_steer: Array = []
var detailed := false
var player: Node3D
var anim: AnimationPlayer
var current_anim := ""
var jump_v := 0.0
var sitting := false

func _ready() -> void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
    _make_environment()
    _make_baseplate()
    car_root = Node3D.new()
    car_root.name = "CarController"
    add_child(car_root)
    _load_lowpoly_car()
    _load_human()
    _make_lights()
    _make_camera()
    _make_audio()
    _make_ui()

func _make_environment() -> void:
    var world := WorldEnvironment.new()
    world.name = "Sky / PBR reflections"
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var material := ProceduralSkyMaterial.new()
    material.sky_top_color = Color("647c9d")
    material.sky_horizon_color = Color("c2ccd8")
    material.ground_horizon_color = Color("818995")
    material.ground_bottom_color = Color("4e5664")
    material.sun_angle_max = 28.0
    sky.sky_material = material
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.58
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.name = "Sun / soft studio key"
    sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-32), deg_to_rad(0))
    sun.light_color = Color("ffe2c7")
    sun.light_energy = 1.7
    sun.shadow_enabled = false # preset performance
    add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.name = "Fill / cool reflections"
    fill.rotation = Vector3(deg_to_rad(-36), deg_to_rad(147), 0)
    fill.light_color = Color("9ebcd5")
    fill.light_energy = 0.68
    add_child(fill)

func _make_baseplate() -> void:
    var ground := StaticBody3D.new()
    ground.name = "Baseplate sem estruturas"
    add_child(ground)
    var slab := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(80, 0.24, 80)
    slab.mesh = mesh
    slab.position.y = -0.16
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("343b43")
    material.metallic = 0.22
    material.roughness = 0.43
    slab.material_override = material
    ground.add_child(slab)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(80, 0.25, 80)
    collider.shape = shape
    collider.position = Vector3(0, -0.16, 0)
    ground.add_child(collider)
    # Fine grid like a standard modeling baseplate, no other objects.
    var line_mat := StandardMaterial3D.new()
    line_mat.albedo_color = Color("46505c")
    line_mat.roughness = 0.75
    var im := ImmediateMesh.new()
    im.surface_begin(Mesh.PRIMITIVE_LINES, line_mat)
    for i in range(-40, 41, 2):
        im.surface_add_vertex(Vector3(i, -0.037, -40))
        im.surface_add_vertex(Vector3(i, -0.037, 40))
        im.surface_add_vertex(Vector3(-40, -0.037, i))
        im.surface_add_vertex(Vector3(40, -0.037, i))
    im.surface_end()
    var grid := MeshInstance3D.new()
    grid.name = "Grade sutil baseplate"
    grid.mesh = im
    ground.add_child(grid)

func _make_lights() -> void:
    for side in [-1.0, 1.0]:
        var lamp := SpotLight3D.new()
        lamp.name = "Farois foco 3D"
        lamp.position = Vector3(side * 0.68, 1.0, -2.31)
        lamp.rotation = Vector3(deg_to_rad(-7), 0, 0)
        lamp.spot_range = 17
        lamp.spot_angle = 29
        lamp.light_color = Color("d8f0ff")
        lamp.light_energy = 4.0
        lamp.shadow_enabled = false
        car_root.add_child(lamp)
        lights.append(lamp)
    _sync_headlights()

func _sync_headlights() -> void:
    for lamp in lights:
        lamp.visible = headlights_on

func _make_camera() -> void:
    camera = Camera3D.new()
    camera.name = "Cinematic orbit camera"
    camera.fov = 66.0
    camera.current = true
    camera.near = 0.12
    add_child(camera)
    camera.position = Vector3(4.0, 3.0, -6.0)
    camera.look_at(Vector3(0, 1.0, 0))

func _make_audio() -> void:
    engine_player = AudioStreamPlayer3D.new()
    engine_player.name = "Motor idle loop"
    engine_player.stream = _audio_tone("idle")
    engine_player.volume_db = -21.0
    engine_player.max_distance = 38
    car_root.add_child(engine_player)
    start_player = AudioStreamPlayer3D.new()
    start_player.name = "Partida do motor"
    start_player.stream = _audio_tone("start")
    start_player.volume_db = -12.0
    car_root.add_child(start_player)
    tap_player = AudioStreamPlayer.new()
    tap_player.stream = _audio_tone("tap")
    tap_player.volume_db = -8.0
    add_child(tap_player)

func _audio_tone(kind: String) -> AudioStreamWAV:
    # Self-contained synthetic sound: no external audio resources required.
    var sr := 22050
    var length := 0.75 if kind == "idle" else (1.5 if kind == "start" else 0.18)
    var n := int(sr * length)
    var pcm := PackedByteArray()
    pcm.resize(n * 2)
    var phase := 0.0
    for i in range(n):
        var t := float(i) / sr
        var sample := 0.0
        if kind == "idle":
            phase += TAU * (62.0 + sin(t * 11.0) * 4.0) / sr
            sample = (sin(phase) * 0.32 + sin(phase * 2) * 0.18 + sin(phase * 3.0) * 0.08) * 0.50
        elif kind == "start":
            phase += TAU * (59.0 + 65.0 * (1.0 - exp(-t * 2.7))) / sr
            sample = (sin(phase) * 0.38 + sin(phase * 2.0) * 0.12) * minf(t * 9.0, 1.0) * minf((length - t) * 3.0, 1.0)
        else:
            phase += TAU * (830.0 - 460.0 * t) / sr
            sample = sin(phase) * exp(-18.0 * t) * 0.22
        pcm.encode_s16(i * 2, int(clampf(sample, -0.95, 0.95) * 32700.0))
    var audio := AudioStreamWAV.new()
    audio.format = AudioStreamWAV.FORMAT_16_BITS
    audio.mix_rate = sr
    audio.stereo = false
    audio.data = pcm
    if kind == "idle":
        audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
    return audio

func _label(text_: String, size_: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", size_)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _make_ui() -> void:
    var ui := CanvasLayer.new()
    ui.name = "HUD REDLINE"
    add_child(ui)
    var root_ui := Control.new()
    root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(root_ui)
    var top := VBoxContainer.new()
    top.position = Vector2(31, 23)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_ui.add_child(top)
    hud_title = _label("R E D L I N E", 28, Color("f9fbfe"))
    top.add_child(hud_title)
    top.add_child(_label("SEDAN CC0  /  HUMANO ANIMADO  /  PBR", 13, Color("a4b9cf")))
    top.add_child(_label("MODO LEVE  ·  1152 x 648  ·  V: DETALHES", 12, Color("8d9eaf")))
    var right := VBoxContainer.new()
    right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    right.position = Vector2(-308, 30)
    right.custom_minimum_size = Vector2(276, 90)
    right.alignment = BoxContainer.ALIGNMENT_END
    right.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_ui.add_child(right)
    hud_speed = _label("000 KM/H", 33, Color("f4f9ff"))
    hud_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    right.add_child(hud_speed)
    hud_state = _label("MOTOR  ·  DESLIGADO", 14, Color("ffb8b4"))
    hud_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    right.add_child(hud_state)
    hud_hint = _label("E ENTRAR   ·   Q PORTA   ·   H CAPÔ   ·   T PORTA-MALAS   ·   L FARÓIS   ·   R RESET   ·   MOUSE CÂMERA", 14, Color("f7fafc"))
    hud_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    hud_hint.offset_left = 26
    hud_hint.offset_right = -26
    hud_hint.offset_top = -52
    hud_hint.offset_bottom = -20
    hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_ui.add_child(hud_hint)
    hotwire = HOTWIRE_UI.new()
    hotwire.name = "Ligacao direta / puzzle cinematografico"
    root_ui.add_child(hotwire)
    hotwire.completed.connect(_start_engine)
    hotwire.click_result.connect(_hotwire_click)

func _hotwire_click(_success: bool) -> void:
    tap_player.play()

func _start_engine() -> void:
    engine_on = true
    headlights_on = true
    _sync_headlights()
    start_player.play()
    engine_player.play()
    for i in range(door_state.size()):
        door_state[i] = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            mouse_drag = event.pressed
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            cam_distance = maxf(3.0, cam_distance - 0.65)
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            cam_distance = minf(14.0, cam_distance + 0.65)
    if event is InputEventMouseMotion and mouse_drag:
        cam_azimuth += event.relative.x * 0.008
        cam_height = clampf(cam_height + event.relative.y * 0.016, 1.3, 7.0)
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_E:
            if hotwire.active:
                hotwire.cancel_puzzle()
                _exit_car()
            elif is_driving:
                _exit_car()
            elif player.position.distance_to(car_root.position) < 3.6:
                sitting = false
                is_driving = true
                player.visible = false
                cam_azimuth = 0.0
                if not engine_on:
                    hotwire.start_puzzle()
        KEY_SPACE:
            if hotwire.active:
                hotwire.attempt()
            elif not is_driving and player.position.y <= 0.001:
                jump_v = 5.3
                sitting = false
                _play_human("Jump_Start")
        KEY_Q:
            if detailed and not hotwire.active:
                door_state[0] = not door_state[0]
        KEY_H:
            if detailed:
                hood_open = not hood_open
        KEY_T:
            if detailed:
                trunk_open = not trunk_open
        KEY_L:
            headlights_on = not headlights_on
            _sync_headlights()
        KEY_R:
            _reset_car()
        KEY_V:
            _switch_car()
        KEY_F:
            if not is_driving:
                sitting = not sitting
                _play_human("Sit_Chair_Down" if sitting else "Sit_Chair_StandUp")
        KEY_G:
            if not is_driving:
                sitting = false
                _play_human("Waving")

func _reset_car() -> void:
    velocity = 0.0
    car_root.position = Vector3.ZERO
    car_root.rotation = Vector3.ZERO
    car_yaw = 0.0
    for i in range(door_state.size()):
        door_state[i] = false
    hood_open = false
    trunk_open = false

func _process(delta: float) -> void:
    _drive(delta)
    _move_human(delta)
    _animate_car(delta)
    _camera(delta)
    _update_hud()

func _drive(delta: float) -> void:
    var acceleration := 0.0
    if is_driving and engine_on and not hotwire.active:
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            acceleration = 10.8
        elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            acceleration = -9.2
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            steering = move_toward(steering, 1.0, delta * 2.9)
        elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            steering = move_toward(steering, -1.0, delta * 2.9)
        else:
            steering = move_toward(steering, 0.0, delta * 4.0)
    else:
        steering = move_toward(steering, 0.0, delta * 4.0)
    if absf(acceleration) < 0.1:
        velocity = move_toward(velocity, 0.0, delta * (2.5 + absf(velocity) * 0.22))
    else:
        velocity = clampf(velocity + acceleration * delta, -7.4, 24.0)
    if absf(velocity) > 0.25:
        car_yaw += steering * velocity * delta * 0.035
    var forward := Vector3(-sin(car_yaw), 0, -cos(car_yaw))
    var wanted := car_root.position + forward * velocity * delta
    car_root.position.x = clampf(wanted.x, -37, 37)
    car_root.position.z = clampf(wanted.z, -37, 37)
    car_root.rotation.y = car_yaw
    driving_time += delta
    car_root.position.y = sin(driving_time * 36.0) * 0.0018 if engine_on else 0.0
    for node in wheel_nodes:
        node.rotate_x(-velocity * delta / 0.417)
    for node in steering_nodes:
        node.rotation.y = lerpf(node.rotation.y, steering * 0.39, clampf(delta * 7.0, 0.0, 1.0))
    if is_instance_valid(steering_wheel) and detailed:
        steering_wheel.rotation.z = lerpf(steering_wheel.rotation.z, steering * 0.80, clampf(delta * 5.0, 0.0, 1.0))
    engine_player.pitch_scale = clampf(0.85 + absf(velocity) * 0.034, 0.85, 1.7)

func _animate_car(delta: float) -> void:
    for i in range(doors.size()):
        var side := -1.0 if i < 2 else 1.0
        var to_angle := side * deg_to_rad(69) if door_state[i] else 0.0
        doors[i].rotation.y = lerp_angle(doors[i].rotation.y, to_angle, clampf(delta * 4.2, 0.0, 1.0))
    if is_instance_valid(hood) and detailed:
        hood.rotation.x = lerp_angle(hood.rotation.x, deg_to_rad(49) if hood_open else 0.0, clampf(delta * 2.9, 0.0, 1.0))
    if is_instance_valid(trunk) and detailed:
        trunk.rotation.x = lerp_angle(trunk.rotation.x, deg_to_rad(-57) if trunk_open else 0.0, clampf(delta * 3.4, 0.0, 1.0))

func _camera(delta: float) -> void:
    var a := cam_azimuth + car_yaw if is_driving else cam_azimuth
    var target := (car_root.position if is_driving else player.position) + Vector3(0, 1.02, 0)
    var wanted := target + Vector3(sin(a) * cam_distance, cam_height, cos(a) * cam_distance)
    var k := 1.0 - exp(-delta * 5.4)
    camera.global_position = camera.global_position.lerp(wanted, k)
    camera.look_at(target, Vector3.UP)

func _update_hud() -> void:
    hud_speed.text = "%03d KM/H" % int(round(absf(velocity) * 3.6))
    hud_state.text = "MOTOR  ·  LIGADO" if engine_on else "MOTOR  ·  DESLIGADO"
    hud_state.add_theme_color_override("font_color", Color("9af5c7") if engine_on else Color("ffb8b4"))
    if hotwire.active:
        hud_hint.text = "ESPAÇO  ·  ACERTAR O PULSO VERDE      |      E  ·  SAIR"
    elif is_driving:
        hud_hint.text = "WASD DIRIGIR  ·  E SAIR  ·  V CARRO  ·  L FARÓIS  ·  R RESET" + ("  ·  Q PORTA  H CAPÔ  T BAÚ" if detailed else "")
    else:
        hud_hint.text = "WASD ANDAR  ·  SHIFT CORRER  ·  ESPAÇO PULAR  ·  E ENTRAR  ·  F SENTAR  ·  G ACENAR  ·  V CARRO"

func _load_lowpoly_car() -> void:
    var asset := load("res://assets/sedan_kenney_cc0.glb") as PackedScene
    if asset == null:
        _ensure_full_car()
        detailed = true
        full_car.visible = true
        wheel_nodes = full_wheels
        steering_nodes = full_steer
        return
    low_car = asset.instantiate() as Node3D
    low_car.name = "Sedan Kenney CC0 - optimized"
    low_car.rotation.y = PI
    low_car.scale = Vector3(1.30, 1.30, 1.86)
    car_root.add_child(low_car)
    for item in low_car.find_children("*", "MeshInstance3D", true, false):
        var part := item as MeshInstance3D
        if part.name.begins_with("wheel-"):
            var parent := part.get_parent() as Node3D
            var old_pos := part.position
            parent.remove_child(part)
            var steer_node := Node3D.new()
            steer_node.name = "Wheel pivot"
            steer_node.position = old_pos
            parent.add_child(steer_node)
            part.position = Vector3.ZERO
            steer_node.add_child(part)
            low_wheels.append(part)
            if part.name.contains("front"):
                low_steer.append(steer_node)
        elif part.name.to_lower().contains("body"):
            var material := part.get_active_material(0)
            if material is StandardMaterial3D:
                var finish := material.duplicate() as StandardMaterial3D
                finish.albedo_color = Color(0.90, 0.52, 0.52)
                finish.metallic = 0.4
                finish.roughness = 0.26
                finish.clearcoat_enabled = true
                finish.clearcoat = 0.85
                part.set_surface_override_material(0, finish)
    wheel_nodes = low_wheels
    steering_nodes = low_steer

func _ensure_full_car() -> void:
    if is_instance_valid(full_car):
        return
    var factory = FACTORY.new()
    var model: Dictionary = factory.add_car(car_root)
    full_car = model["root"]
    full_car.visible = false
    full_wheels = model["wheels"]
    full_steer = model["steering_nodes"]
    doors = model["doors"]
    hood = model["hood"]
    trunk = model["trunk"]
    steering_wheel = model["steering_wheel"]

func _switch_car() -> void:
    if not is_instance_valid(low_car):
        return
    if not detailed:
        _ensure_full_car()
    detailed = not detailed
    full_car.visible = detailed
    low_car.visible = not detailed
    wheel_nodes = full_wheels if detailed else low_wheels
    steering_nodes = full_steer if detailed else low_steer

func _load_human() -> void:
    player = Node3D.new()
    player.name = "Animated human"
    player.position = Vector3(-2.65, 0, -0.65)
    add_child(player)
    var asset := load("res://assets/humanoid_cc0.glb") as PackedScene
    if asset == null:
        push_warning("Human asset unavailable")
        return
    var human := asset.instantiate() as Node3D
    player.add_child(human)
    var list := human.find_children("*", "AnimationPlayer", true, false)
    if not list.is_empty():
        anim = list[0] as AnimationPlayer
        _play_human("Idle_A")

func _play_human(clip: String) -> void:
    if not is_instance_valid(anim) or current_anim == clip:
        return
    for candidate in anim.get_animation_list():
        var nm := String(candidate)
        if nm == clip or nm.ends_with("/" + clip):
            var clip_resource := anim.get_animation(candidate)
            if clip_resource != null and (clip.begins_with("Idle") or clip.begins_with("Walking") or clip.begins_with("Running") or clip == "Crouching" or clip == "Sit_Chair_Idle"):
                clip_resource.loop_mode = Animation.LOOP_LINEAR
            anim.play(candidate, 0.16)
            current_anim = clip
            return

func _move_human(delta: float) -> void:
    if is_driving or hotwire.active:
        return
    var direction := Vector3.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.z -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.z += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1.0
    var moving := direction.length() > 0.01
    var running := Input.is_key_pressed(KEY_SHIFT)
    if moving:
        sitting = false
        var heading := direction.normalized().rotated(Vector3.UP, cam_azimuth)
        player.position += heading * (4.65 if running else 2.6) * delta
        player.position.x = clampf(player.position.x, -38, 38)
        player.position.z = clampf(player.position.z, -38, 38)
        player.rotation.y = lerp_angle(player.rotation.y, atan2(-heading.x, -heading.z), clampf(delta * 9, 0, 1))
    if player.position.y > 0.001 or jump_v > 0.0:
        player.position.y += jump_v * delta
        jump_v -= 15.5 * delta
        if player.position.y <= 0:
            player.position.y = 0
            jump_v = 0
            _play_human("Jump_Land")
    elif sitting:
        if is_instance_valid(anim) and not anim.is_playing():
            _play_human("Sit_Chair_Idle")
    elif moving:
        _play_human("Running_A" if running else "Walking_A")
    elif is_instance_valid(anim) and not anim.is_playing():
        _play_human("Idle_A")
    elif current_anim != "Idle_A" and current_anim != "Waving" and current_anim != "Sit_Chair_Down" and current_anim != "Sit_Chair_StandUp":
        _play_human("Idle_A")

func _exit_car() -> void:
    is_driving = false
    cam_azimuth = 2.57
    player.position = car_root.position + car_root.basis.x * 2.05
    player.position.y = 0.0
    player.visible = true
    _play_human("Idle_A")

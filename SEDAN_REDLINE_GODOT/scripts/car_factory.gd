extends RefCounted
## REDLINE - sedan modular: exterior, cockpit, body panels, moving hinges & rolling wheels.
## Forward -Z, right +X, world vertical +Y. All lengths in meters.

var paint: StandardMaterial3D
var paint_gloss: StandardMaterial3D
var paint_dark: StandardMaterial3D
var carbon: StandardMaterial3D
var rubber: StandardMaterial3D
var metal: StandardMaterial3D
var wheel_metal: StandardMaterial3D
var glass: StandardMaterial3D
var tail_glass: StandardMaterial3D
var light_white: StandardMaterial3D
var rear_light: StandardMaterial3D
var leather: StandardMaterial3D
var leather_soft: StandardMaterial3D
var screen: StandardMaterial3D
var chrome: StandardMaterial3D
var black_glass: StandardMaterial3D
var car: Node3D
var wheels: Array[Node3D] = []
var steering_nodes: Array[Node3D] = []
var doors: Array[Node3D] = []
var hood: Node3D
var trunk: Node3D
var steering_wheel: Node3D
var lamps: Array[MeshInstance3D] = []

func make_material(color: Color, metallic: float = 0.0, roughness: float = 0.5, glow: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    if transparent:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    if glow > 0:
        m.emission_enabled = true
        m.emission = Color(color.r, color.g, color.b)
        m.emission_energy_multiplier = glow
    return m

func init_materials() -> void:
    paint = make_material(Color("8c1922"), 0.78, 0.17)
    paint.clearcoat_enabled = true
    paint.clearcoat = 0.96
    paint.clearcoat_roughness = 0.085
    paint_gloss = make_material(Color("b02b31"), 0.84, 0.14)
    paint_gloss.clearcoat_enabled = true
    paint_gloss.clearcoat = 1.0
    paint_gloss.clearcoat_roughness = 0.07
    paint_dark = make_material(Color("5c111a"), 0.78, 0.18)
    carbon = make_material(Color("11191e"), 0.21, 0.32)
    rubber = make_material(Color("0b0d0f"), 0.03, 0.88)
    metal = make_material(Color("505a66"), 0.88, 0.26)
    wheel_metal = make_material(Color("a5aeb8"), 0.92, 0.21)
    chrome = make_material(Color("c2ceda"), 0.95, 0.13)
    glass = make_material(Color(0.29, 0.44, 0.55, 0.29), 0.18, 0.045, 0.0, true)
    tail_glass = make_material(Color(0.7, 0.05, 0.08, 0.55), 0.08, 0.09, 0.0, true)
    black_glass = make_material(Color(0.035, 0.055, 0.085, 0.68), 0.16, 0.09, 0.0, true)
    light_white = make_material(Color("bdeeff"), 0.03, 0.14, 4.2)
    rear_light = make_material(Color("ff2433"), 0.05, 0.16, 2.8)
    leather = make_material(Color("17191c"), 0.02, 0.79)
    leather_soft = make_material(Color("27292c"), 0.03, 0.87)
    screen = make_material(Color("102536"), 0.23, 0.22, 0.9)

func box(parent: Node3D, name_: String, pos: Vector3, dims: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    m.name = name_
    var bm := BoxMesh.new()
    bm.size = dims
    m.mesh = bm
    m.material_override = mat
    m.position = pos
    m.rotation = rot
    parent.add_child(m)
    return m

func cylinder(parent: Node3D, name_: String, pos: Vector3, r: float, height: float, mat: Material, sides: int = 24, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name_
    var mesh := CylinderMesh.new()
    mesh.top_radius = r
    mesh.bottom_radius = r
    mesh.height = height
    mesh.radial_segments = sides
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation = rot
    parent.add_child(mi)
    return mi

func torus(parent: Node3D, name_: String, pos: Vector3, inner_r: float, outer_r: float, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name_
    var mm := TorusMesh.new()
    mm.inner_radius = inner_r
    mm.outer_radius = outer_r
    mm.rings = 32
    mm.ring_segments = 12
    mi.mesh = mm
    mi.material_override = mat
    mi.position = pos
    mi.rotation = rot
    parent.add_child(mi)
    return mi

func surface(parent: Node3D, name_: String, polygons: Array, mat: Material) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for polygon in polygons:
        if polygon.size() < 3:
            continue
        for i in range(1, polygon.size() - 1):
            st.add_vertex(polygon[0])
            st.add_vertex(polygon[i])
            st.add_vertex(polygon[i + 1])
    st.generate_normals()
    var mi := MeshInstance3D.new()
    mi.name = name_
    mi.mesh = st.commit()
    mi.material_override = mat
    parent.add_child(mi)
    return mi

func quad(parent: Node3D, name_: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: Material) -> MeshInstance3D:
    return surface(parent, name_, [[a, b, c, d]], mat)

func bar(parent: Node3D, name_: String, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
    var direction := b - a
    var mesh := box(parent, name_, (a + b) * 0.5, Vector3(width, direction.length(), width), mat)
    mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
    return mesh

func add_car(root: Node3D) -> Dictionary:
    init_materials()
    car = Node3D.new()
    car.name = "VORTEX S4 / 1:1 escala"
    root.add_child(car)
    _chassis()
    _body()
    _front()
    _rear()
    _roof_and_glass()
    _cockpit()
    _doors()
    _bonnet_and_boot()
    _wheels()
    return {"root": car, "wheels": wheels, "steering_nodes": steering_nodes, "doors": doors, "hood": hood, "trunk": trunk, "steering_wheel": steering_wheel, "lamps": lamps}

func _chassis() -> void:
    box(car, "Estrutura base", Vector3(0, 0.48, 0), Vector3(1.70, 0.35, 4.35), carbon)
    box(car, "Soleira esquerda", Vector3(-0.89, 0.42, 0), Vector3(0.13, 0.19, 2.53), paint_dark)
    box(car, "Soleira direita", Vector3(0.89, 0.42, 0), Vector3(0.13, 0.19, 2.53), paint_dark)
    box(car, "Assoalho interior", Vector3(0, 0.72, 0.05), Vector3(1.75, 0.09, 2.78), leather)
    box(car, "Console", Vector3(0, 0.84, 0.12), Vector3(0.27, 0.21, 2.18), leather_soft)
    for x in [-0.91, 0.91]:
        for z in [-1.53, 1.54]:
            cylinder(car, "Disco freio", Vector3(x, 0.48, z), 0.29, 0.05, metal, 32, Vector3(0, 0, PI / 2))

func _body() -> void:
    # Faceted rocker and upper belt skins with arched wheel-well negative silhouettes.
    var segments := 70
    for side in [-1.0, 1.0]:
        for i in range(segments):
            var z0: float = -2.35 + i * 4.70 / segments
            var z1: float = -2.35 + (i + 1) * 4.70 / segments
            var bottom0 := _arch_y(z0)
            var bottom1 := _arch_y(z1)
            var width0 := _shell_width(z0)
            var width1 := _shell_width(z1)
            var top0 := _shell_top(z0)
            var top1 := _shell_top(z1)
            var p0 := Vector3(side * width0, bottom0, z0)
            var p1 := Vector3(side * width1, bottom1, z1)
            var p2 := Vector3(side * width1, top1, z1)
            var p3 := Vector3(side * width0, top0, z0)
            var material_: Material = paint if i % 7 < 5 else paint_gloss
            quad(car, "Lateral faceta %d - %d" % [int(side), i], p0, p1, p2, p3, material_)
        # Trim that travels below the side doors.
        bar(car, "Friso inferior", Vector3(side * 0.963, 0.36, -0.88), Vector3(side * 0.963, 0.36, 1.26), 0.042, carbon)
    box(car, "Spoiler frontal inferior", Vector3(0, 0.295, -2.365), Vector3(1.76, 0.075, 0.13), carbon)
    box(car, "Difusor traseiro inferior", Vector3(0, 0.31, 2.38), Vector3(1.80, 0.14, 0.10), carbon)
    # Hood and boot painted supporting shoulder transitions.
    for side in [-1.0, 1.0]:
        surface(car, "Ombro frontal", [[Vector3(side * 0.80, 1.06, -2.28), Vector3(side * 0.97, 0.89, -2.19), Vector3(side * 0.97, 1.05, -0.77), Vector3(side * 0.76, 1.20, -0.83)]], paint)
        surface(car, "Ombro traseiro", [[Vector3(side * 0.75, 1.16, 1.28), Vector3(side * 0.98, 1.04, 1.40), Vector3(side * 0.88, 1.04, 2.29), Vector3(side * 0.68, 1.14, 2.29)]], paint)

func _arch_y(z: float) -> float:
    var y := 0.36
    for hub_z in [-1.53, 1.54]:
        var dz: float = absf(z - hub_z)
        var r := 0.49
        if dz < r:
            y = maxf(y, 0.48 + sqrt(r * r - dz * dz))
    return y

func _shell_top(z: float) -> float:
    return 1.07 if absf(z) > 1.45 else 1.17

func _shell_width(z: float) -> float:
    return 0.88 if absf(z) > 2.10 else 0.96

func _front() -> void:
    # Grille with layered polygonal frame and individual small honeycomb cells.
    quad(car, "Grade base preta", Vector3(-0.74, 0.46, -2.375), Vector3(0.74, 0.46, -2.375), Vector3(0.67, 0.96, -2.375), Vector3(-0.67, 0.96, -2.375), carbon)
    var hex := [Vector3(-0.73, 0.47, -2.397), Vector3(0.73, 0.47, -2.397), Vector3(0.81, 0.78, -2.397), Vector3(0.64, 1.04, -2.397), Vector3(-0.64, 1.04, -2.397), Vector3(-0.81, 0.78, -2.397)]
    for i in range(hex.size()):
        bar(car, "Borda cromada grade", hex[i], hex[(i + 1) % hex.size()], 0.019, chrome)
    for row in range(7):
        for col in range(15):
            var cx: float = (col - 7) * 0.097 + (0.047 if row % 2 == 0 else 0.0)
            var cy: float = 0.52 + row * 0.068
            if absf(cx) > 0.64 - absf(cy - 0.74) * 0.22:
                continue
            for edge in range(6):
                var a: float = TAU * edge / 6.0
                var b: float = TAU * (edge + 1) / 6.0
                var p1 := Vector3(cx + 0.046 * cos(a), cy + 0.039 * sin(a), -2.407)
                var p2 := Vector3(cx + 0.046 * cos(b), cy + 0.039 * sin(b), -2.407)
                bar(car, "Colmeia", p1, p2, 0.008, metal)
    for side in [-1.0, 1.0]:
        surface(car, "Alojamento farol", [[Vector3(side * 0.42, 1.02, -2.392), Vector3(side * 0.95, 1.09, -2.25), Vector3(side * 0.89, 0.92, -2.25), Vector3(side * 0.56, 0.93, -2.395)]], carbon)
        quad(car, "Lente dianteira", Vector3(side * 0.45, 1.025, -2.409), Vector3(side * 0.89, 1.08, -2.26), Vector3(side * 0.84, 0.963, -2.28), Vector3(side * 0.56, 0.961, -2.41), glass)
        bar(car, "LED superior", Vector3(side * 0.46, 1.020, -2.425), Vector3(side * 0.87, 1.055, -2.285), 0.023, light_white)
        bar(car, "LED angular", Vector3(side * 0.87, 1.055, -2.285), Vector3(side * 0.77, 0.970, -2.32), 0.022, light_white)
        bar(car, "LED inferior", Vector3(side * 0.77, 0.970, -2.32), Vector3(side * 0.57, 0.972, -2.424), 0.019, light_white)
        var lamp := cylinder(car, "Projetor", Vector3(side * 0.71, 1.0, -2.411), 0.035, 0.045, light_white, 12, Vector3(PI / 2, 0, 0))
        lamps.append(lamp)
        box(car, "Entrada de ar", Vector3(side * 0.76, 0.49, -2.38), Vector3(0.22, 0.25, 0.04), carbon)
        for v in range(4):
            box(car, "Aleta entrada", Vector3(side * 0.76, 0.40 + 0.057 * v, -2.414), Vector3(0.18, 0.008, 0.01), metal)
    box(car, "Travessa parachoque dianteiro", Vector3(0, 0.99, -2.36), Vector3(1.50, 0.073, 0.12), paint_dark)

func _rear() -> void:
    box(car, "Traseira refletiva", Vector3(0, 0.98, 2.366), Vector3(1.70, 0.28, 0.11), paint)
    for side in [-1.0, 1.0]:
        quad(car, "Lanterna traseira", Vector3(side * 0.31, 1.080, 2.437), Vector3(side * 0.84, 1.080, 2.41), Vector3(side * 0.85, 0.960, 2.42), Vector3(side * 0.34, 0.985, 2.45), tail_glass)
        bar(car, "LED traseiro", Vector3(side * 0.33, 1.06, 2.455), Vector3(side * 0.82, 1.06, 2.435), 0.021, rear_light)
        bar(car, "LED traseiro canto", Vector3(side * 0.82, 1.06, 2.435), Vector3(side * 0.79, 1.002, 2.437), 0.018, rear_light)
        box(car, "Saida escape metal", Vector3(side * 0.66, 0.34, 2.473), Vector3(0.22, 0.075, 0.045), chrome)
        box(car, "Saida escape interior", Vector3(side * 0.66, 0.34, 2.500), Vector3(0.17, 0.042, 0.015), carbon)
    bar(car, "Linha cromada traseira", Vector3(-0.64, 0.90, 2.441), Vector3(0.64, 0.90, 2.441), 0.016, metal)
    box(car, "Area placa", Vector3(0, 0.725, 2.445), Vector3(0.38, 0.13, 0.027), carbon)
    box(car, "Placa", Vector3(0, 0.725, 2.462), Vector3(0.29, 0.075, 0.009), chrome)

func _roof_and_glass() -> void:
    # Cabin: A/B/C pillars, canopy and glossy transparent panes.
    var fbot_left := Vector3(-0.77, 1.17, -0.87)
    var fbot_right := Vector3(0.77, 1.17, -0.87)
    var ftop_left := Vector3(-0.69, 1.57, -0.30)
    var ftop_right := Vector3(0.69, 1.57, -0.30)
    quad(car, "Para-brisa laminado", fbot_left, fbot_right, ftop_right, ftop_left, glass)
    quad(car, "Reflexo para-brisa", Vector3(-0.49, 1.31, -0.676), Vector3(-0.41, 1.32, -0.664), Vector3(-0.30, 1.52, -0.36), Vector3(-0.39, 1.52, -0.36), black_glass)
    quad(car, "Teto metal", Vector3(-0.72, 1.585, -0.32), Vector3(0.72, 1.585, -0.32), Vector3(0.68, 1.60, 0.79), Vector3(-0.68, 1.60, 0.79), paint)
    quad(car, "Vidro traseiro", Vector3(-0.69, 1.55, 0.79), Vector3(0.69, 1.55, 0.79), Vector3(0.78, 1.18, 1.51), Vector3(-0.78, 1.18, 1.51), glass)
    for side in [-1.0, 1.0]:
        bar(car, "Pilar A", Vector3(side * 0.79, 1.17, -0.89), Vector3(side * 0.71, 1.595, -0.30), 0.046, paint_dark)
        bar(car, "Pilar C", Vector3(side * 0.70, 1.591, 0.78), Vector3(side * 0.80, 1.16, 1.52), 0.063, paint_dark)
        bar(car, "Trilho teto cromado", Vector3(side * 0.713, 1.597, -0.30), Vector3(side * 0.70, 1.602, 0.80), 0.023, chrome)
        bar(car, "Canal inferior janela", Vector3(side * 0.92, 1.166, -0.81), Vector3(side * 0.93, 1.171, 1.39), 0.021, chrome)
    for n in range(2):
        var z := -0.10 + n * 0.19
        bar(car, "Palheta do limpador", Vector3(-0.68, 1.207, -0.84 - n * 0.02), Vector3(0.27, 1.222, -0.84 - n * 0.02), 0.015, carbon)
    box(car, "Antena de barbatana", Vector3(0, 1.665, 0.63), Vector3(0.085, 0.11, 0.18), carbon)

func _cockpit() -> void:
    box(car, "Painel dianteiro", Vector3(0, 1.07, -0.83), Vector3(1.72, 0.22, 0.31), leather)
    box(car, "Faixa aluminio do painel", Vector3(0, 1.090, -0.98), Vector3(1.55, 0.019, 0.018), metal)
    box(car, "Cluster digital", Vector3(-0.40, 1.16, -0.99), Vector3(0.43, 0.18, 0.035), screen)
    box(car, "Midia central", Vector3(0.13, 1.17, -1.014), Vector3(0.35, 0.19, 0.027), screen)
    for x in [-0.62, -0.12, 0.48]:
        box(car, "Saida de ventilacao", Vector3(x, 1.02, -1.017), Vector3(0.15, 0.045, 0.026), carbon)
    steering_wheel = Node3D.new()
    steering_wheel.name = "Volante animavel"
    steering_wheel.position = Vector3(-0.46, 1.045, -0.60)
    car.add_child(steering_wheel)
    torus(steering_wheel, "Aro do volante", Vector3.ZERO, 0.15, 0.175, leather, Vector3(PI / 2, 0, 0))
    cylinder(steering_wheel, "Centro volante", Vector3(0, 0, 0), 0.045, 0.07, metal, 16, Vector3(PI / 2, 0, 0))
    for theta in [0.0, 2.1, 4.2]:
        bar(steering_wheel, "Raio volante", Vector3.ZERO, Vector3(0.135 * cos(theta), 0.135 * sin(theta), 0), 0.026, metal)
    bar(car, "Coluna direcao", Vector3(-0.46, 1.045, -0.59), Vector3(-0.46, 1.045, -0.92), 0.053, carbon)
    for z in [-0.20, 0.95]:
        for x in [-0.44, 0.44]:
            _seat(x, z)
    # Rear bench connects rear seats, creating the four-person cabin.
    box(car, "Banco traseiro continuo", Vector3(0, 0.77, 1.06), Vector3(1.58, 0.17, 0.66), leather_soft)
    box(car, "Cambio automatico", Vector3(0.08, 0.98, -0.15), Vector3(0.065, 0.21, 0.074), metal)
    box(car, "Alavanca cambio", Vector3(0.08, 1.07, -0.15), Vector3(0.09, 0.1, 0.12), leather)

func _seat(x: float, z: float) -> void:
    box(car, "Base do assento", Vector3(x, 0.85, z), Vector3(0.61, 0.19, 0.67), leather_soft)
    box(car, "Encosto do assento", Vector3(x, 1.11, z + 0.28), Vector3(0.60, 0.61, 0.16), leather, Vector3(-0.06, 0, 0))
    box(car, "Centro estofado", Vector3(x, 1.11, z + 0.185), Vector3(0.44, 0.45, 0.035), leather_soft, Vector3(-0.06, 0, 0))
    box(car, "Apoio de cabeca", Vector3(x, 1.49, z + 0.31), Vector3(0.30, 0.23, 0.18), leather)

func _doors() -> void:
    for side in [-1.0, 1.0]:
        for rear in [false, true]:
            var hinge_z := 0.29 if rear else -0.78
            var door := Node3D.new()
            door.name = "Porta %s %s (animavel)" % ["D" if side > 0.0 else "E", "traseira" if rear else "dianteira"]
            door.position = Vector3(side * 0.969, 0, hinge_z)
            car.add_child(door)
            var z0 := 0.015
            var z1 := 0.93 if rear else 1.01
            var window_back := 1.05 if rear else 1.16
            surface(door, "Painel da porta facetado", [[Vector3(0, 0.44, z0), Vector3(0, 0.45, z1), Vector3(0, 1.13, z1), Vector3(0, 1.13, z0)]], paint)
            bar(door, "Vinco angular lateral", Vector3(side * 0.010, 0.93, z0 + 0.05), Vector3(side * 0.010, 0.90, z1 - 0.04), 0.009, paint_gloss)
            box(door, "Macaneta", Vector3(side * 0.043, 1.085, z0 + 0.73), Vector3(0.045, 0.042, 0.16), chrome)
            var yl := 1.167
            var topz0 := 0.37 if rear else 0.13
            var topz1 := 0.76 if rear else 0.71
            var topy1 := 1.44 if rear else 1.54
            surface(door, "Vidro lateral cristal", [[Vector3(0.002 * side, yl, z0 + 0.05), Vector3(0.002 * side, yl, z1 - 0.03), Vector3(-side * 0.13, topy1, topz1), Vector3(-side * 0.13, 1.53, topz0)]], glass)
            bar(door, "Arco inferior vidro", Vector3(side * 0.010, yl, z0 + 0.05), Vector3(side * 0.010, yl, z1 - 0.04), 0.020, chrome)
            bar(door, "Guarnicao vidro dianteira", Vector3(0, yl, z0 + 0.05), Vector3(-side * 0.13, 1.53, topz0), 0.029, carbon)
            bar(door, "Guarnicao vidro traseira", Vector3(0, yl, z1 - 0.04), Vector3(-side * 0.13, topy1, topz1), 0.029, carbon)
            if not rear:
                box(door, "Retrovisor suporte", Vector3(side * 0.105, 1.20, 0.07), Vector3(0.19, 0.045, 0.07), carbon)
                box(door, "Retrovisor pintura", Vector3(side * 0.215, 1.235, 0.06), Vector3(0.21, 0.115, 0.18), paint)
                box(door, "Espelho real", Vector3(side * 0.33, 1.238, 0.065), Vector3(0.014, 0.079, 0.141), chrome)
                bar(door, "Pisca do retrovisor", Vector3(side * 0.326, 1.237, -0.005), Vector3(side * 0.326, 1.237, 0.111), 0.011, light_white)
            doors.append(door)
    # B pillars separate side windows and remain on body.
    for side in [-1.0, 1.0]:
        bar(car, "Pilar B", Vector3(side * 0.964, 1.13, 0.20), Vector3(side * 0.716, 1.59, 0.20), 0.058, carbon)

func _bonnet_and_boot() -> void:
    hood = Node3D.new()
    hood.name = "Capo - animavel"
    hood.position = Vector3(0, 1.15, -0.83)
    car.add_child(hood)
    var xs := [-0.83, -0.59, -0.26, 0.26, 0.59, 0.83]
    for i in range(xs.size() - 1):
        var a: float = xs[i]
        var b: float = xs[i + 1]
        var y0: float = -0.08 + 0.056 * (1.0 - absf((a + b) * 0.5))
        quad(hood, "Chapa capo faceta %d" % i, Vector3(a, y0, -1.43), Vector3(b, y0, -1.43), Vector3(b, 0.042, 0.0), Vector3(a, 0.042, 0.0), paint_gloss if i == 1 or i == 4 else paint)
    bar(hood, "Linha do capo E", Vector3(-0.80, -0.072, -1.43), Vector3(-0.80, 0.045, 0.0), 0.013, paint_dark)
    bar(hood, "Linha do capo D", Vector3(0.80, -0.072, -1.43), Vector3(0.80, 0.045, 0.0), 0.013, paint_dark)
    box(car, "Compartimento motor", Vector3(0, 0.88, -1.57), Vector3(1.36, 0.22, 0.99), carbon)
    box(car, "Tampa do motor", Vector3(0, 1.02, -1.62), Vector3(0.55, 0.13, 0.71), leather)
    for side in [-1.0, 1.0]:
        box(car, "Bateria e sensores", Vector3(side * 0.46, 1.02, -1.48), Vector3(0.22, 0.14, 0.38), metal)
    trunk = Node3D.new()
    trunk.name = "Porta malas - animavel"
    trunk.position = Vector3(0, 1.17, 1.53)
    car.add_child(trunk)
    for i in range(5):
        var x0 := -0.82 + i * 0.328
        var x1 := x0 + 0.328
        quad(trunk, "Tampa porta malas", Vector3(x0, 0.0, 0), Vector3(x1, 0.0, 0), Vector3(x1 * 0.93, -0.07, 0.77), Vector3(x0 * 0.93, -0.07, 0.77), paint)
    box(trunk, "Aerofolio discreto", Vector3(0, -0.039, 0.70), Vector3(1.38, 0.06, 0.085), paint_dark)
    box(car, "Bau escuro", Vector3(0, 0.93, 1.95), Vector3(1.54, 0.33, 0.56), carbon)

func _wheels() -> void:
    for side in [-1.0, 1.0]:
        for z in [-1.53, 1.54]:
            var steer := Node3D.new()
            steer.name = "Pivo esterco dianteiro" if z < 0 else "Pivo roda traseira"
            steer.position = Vector3(side * 0.925, 0.48, z)
            car.add_child(steer)
            if z < 0:
                steering_nodes.append(steer)
            var roll := Node3D.new()
            roll.name = "Roda animada - %s %s" % ["D" if side > 0 else "E", "F" if z < 0 else "T"]
            steer.add_child(roll)
            wheels.append(roll)
            var torus_rot := Vector3(0, 0, PI / 2)
            torus(roll, "Pneu borracha radial", Vector3.ZERO, 0.315, 0.420, rubber, torus_rot)
            cylinder(roll, "Parede pneu", Vector3(side * 0.065, 0, 0), 0.351, 0.138, rubber, 36, torus_rot)
            cylinder(roll, "Disco interior do aro", Vector3(side * 0.146, 0, 0), 0.286, 0.017, carbon, 32, torus_rot)
            cylinder(roll, "Disco freio perfurado", Vector3(side * 0.152, 0, 0), 0.220, 0.019, metal, 32, torus_rot)
            torus(roll, "Aro aluminio", Vector3(side * 0.169, 0, 0), 0.263, 0.289, wheel_metal, torus_rot)
            for i in range(10):
                var ang := TAU * i / 10
                var rr := 0.145
                var p1 := Vector3(side * 0.185, cos(ang) * 0.066, sin(ang) * 0.066)
                var p2 := Vector3(side * 0.185, cos(ang + 0.085) * 0.269, sin(ang + 0.085) * 0.269)
                bar(roll, "Raio alu %02d" % i, p1, p2, 0.035, wheel_metal)
            cylinder(roll, "Miolo do cubo", Vector3(side * 0.200, 0, 0), 0.062, 0.035, chrome, 18, torus_rot)
            for i in range(5):
                var ang := TAU * i / 5
                cylinder(roll, "Porca roda", Vector3(side * 0.224, 0.081 * cos(ang), 0.081 * sin(ang)), 0.013, 0.012, carbon, 8, torus_rot)
            # Tire tread grooves arranged on circumference.
            for i in range(30):
                var angle := TAU * i / 30.0
                var p := Vector3(side * 0.03, cos(angle) * 0.414, sin(angle) * 0.414)
                var groove := box(roll, "Sulco lateral pneu", p, Vector3(0.115, 0.007, 0.018), carbon)
                groove.rotation.x = angle

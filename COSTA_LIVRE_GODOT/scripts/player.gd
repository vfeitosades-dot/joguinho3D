extends CharacterBody3D

var camera_node: Camera3D
var controlling := true
var speed_walk := 4.4
var speed_run := 7.0
var anim_t := 0.0
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var visuals: Node3D

func _ready() -> void:
 name = "Jogador"
 var cs := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = 0.34
 capsule.height = 2.0
 cs.shape = capsule
 cs.position.y = 1.0
 add_child(cs)
 visuals = Node3D.new()
 visuals.name = "Visual"
 add_child(visuals)
 _make_avatar()

func _material(c: Color) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = c
 m.roughness = 0.82
 return m

func _cube(parent: Node3D, s: Vector3, p: Vector3, c: Color) -> MeshInstance3D:
 var n := MeshInstance3D.new()
 var cube := BoxMesh.new()
 cube.size = s
 n.mesh = cube
 n.material_override = _material(c)
 n.position = p
 parent.add_child(n)
 return n


func _rounded(parent: Node3D, size_3d: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
 var n := MeshInstance3D.new()
 var shape := SphereMesh.new()
 shape.radius = .5
 shape.height = 1.0
 shape.radial_segments = 12
 shape.rings = 6
 n.mesh = shape
 n.scale = size_3d
 n.position = at
 n.material_override = _material(tint)
 parent.add_child(n)
 return n

func _make_avatar() -> void:
 # Personagem semi-realista leve: malha arredondada, pecas independentes
 # e animacao de articulacoes sem skinning pesado.
 var coat := Color("26495a")
 var trousers := Color("222b39")
 var skin := Color("bd8d6a")
 var charcoal := Color("151c25")
 var leather := Color("d2bd9d")
 _rounded(visuals,Vector3(.73,.95,.43),Vector3(0,1.54,0),coat)
 _rounded(visuals,Vector3(.60,.31,.36),Vector3(0,1.13,.01),trousers)
 _rounded(visuals,Vector3(.52,.54,.43),Vector3(0,2.31,-.005),skin)
 _rounded(visuals,Vector3(.53,.24,.43),Vector3(0,2.56,.035),charcoal)
 _rounded(visuals,Vector3(.2,.13,.36),Vector3(0,2.49,.12),charcoal)
 _cube(visuals,Vector3(.038,.67,.045),Vector3(0,1.62,-.232),Color("c7a780"))
 _cube(visuals,Vector3(.14,.08,.043),Vector3(0,1.16,-.213),Color("af946b"))
 for side in [-1,1]:
  var fx := float(side)
  _rounded(visuals,Vector3(.08,.10,.08),Vector3(fx*.275,2.32,0),skin)
  _rounded(visuals,Vector3(.11,.075,.052),Vector3(fx*.123,2.35,-.21),charcoal)
 _rounded(visuals,Vector3(.12,.20,.13),Vector3(0,2.27,-.224),skin)
 _cube(visuals,Vector3(.19,.045,.041),Vector3(0,2.1,-.215),Color("75463c"))
 left_arm=Node3D.new()
 right_arm=Node3D.new()
 left_arm.position=Vector3(-.46,1.94,0)
 right_arm.position=Vector3(.46,1.94,0)
 visuals.add_child(left_arm)
 visuals.add_child(right_arm)
 for arm in [left_arm,right_arm]:
  _rounded(arm,Vector3(.24,.80,.28),Vector3(0,-.34,0),coat)
  _rounded(arm,Vector3(.22,.21,.23),Vector3(0,-.81,0),skin)
  _cube(arm,Vector3(.24,.06,.28),Vector3(0,-.68,0),charcoal)
 left_leg=Node3D.new()
 right_leg=Node3D.new()
 left_leg.position=Vector3(-.20,1.0,0)
 right_leg.position=Vector3(.20,1.0,0)
 visuals.add_child(left_leg)
 visuals.add_child(right_leg)
 for leg in [left_leg,right_leg]:
  _rounded(leg,Vector3(.31,.89,.37),Vector3(0,-.43,0),trousers)
  _rounded(leg,Vector3(.34,.18,.57),Vector3(0,-.87,-.10),leather)
  _cube(leg,Vector3(.35,.07,.58),Vector3(0,-.96,-.08),charcoal)

func set_in_vehicle(inside: bool) -> void:
 controlling = not inside
 visible = not inside
 set_physics_process(not inside)

func _physics_process(delta: float) -> void:
 if not controlling: return
 var ix := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
 var iz := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
 var dir := Vector3(ix,0,iz).normalized()
 if camera_node != null:
  var right := camera_node.global_transform.basis.x
  var forward := camera_node.global_transform.basis.z
  right.y=0
  forward.y=0
  dir=(right.normalized()*ix+forward.normalized()*iz).normalized()
 var running := Input.is_key_pressed(KEY_SHIFT)
 var v := speed_run if running else speed_walk
 velocity.x=move_toward(velocity.x,dir.x*v,delta*22.0)
 velocity.z=move_toward(velocity.z,dir.z*v,delta*22.0)
 if not is_on_floor(): velocity.y -= 17.0*delta
 elif Input.is_key_pressed(KEY_SPACE): velocity.y=6.0
 else: velocity.y=-.2
 move_and_slide()
 if dir.length()>.1:
  rotation.y=lerp_angle(rotation.y,atan2(-dir.x,-dir.z),minf(delta*11.0,1.0))
  anim_t += delta*(12.5 if running else 8.0)
 var sway := sin(anim_t)*(.6 if dir.length()>.1 else 0.0)
 left_leg.rotation.x=lerpf(left_leg.rotation.x,sway,delta*13.0)
 right_leg.rotation.x=lerpf(right_leg.rotation.x,-sway,delta*13.0)
 left_arm.rotation.x=lerpf(left_arm.rotation.x,-sway*.75,delta*13.0)
 right_arm.rotation.x=lerpf(right_arm.rotation.x,sway*.75,delta*13.0)
 visuals.position.y=sin(anim_t*2.0)*.024 if dir.length()>.1 and is_on_floor() else 0.0

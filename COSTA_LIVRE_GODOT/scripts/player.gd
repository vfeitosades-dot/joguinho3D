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

func _make_avatar() -> void:
 var blue = Color("244d67")
 var dark = Color("212934")
 var skin = Color("a97858")
 _cube(visuals,Vector3(.77,1.03,.38),Vector3(0,1.52,0),blue)
 _cube(visuals,Vector3(.68,.26,.38),Vector3(0,.95,0),dark)
 _cube(visuals,Vector3(.46,.49,.4),Vector3(0,2.27,0),skin)
 _cube(visuals,Vector3(.49,.15,.48),Vector3(0,2.53,-.01),Color("191a1e"))
 _cube(visuals,Vector3(.15,.06,.05),Vector3(-.12,2.3,-.22),Color("242424"))
 _cube(visuals,Vector3(.15,.06,.05),Vector3(.12,2.3,-.22),Color("242424"))
 left_arm=Node3D.new()
 right_arm=Node3D.new()
 left_arm.position=Vector3(-.52,1.93,0)
 right_arm.position=Vector3(.52,1.93,0)
 visuals.add_child(left_arm)
 visuals.add_child(right_arm)
 _cube(left_arm,Vector3(.23,.83,.28),Vector3(0,-.38,0),blue)
 _cube(right_arm,Vector3(.23,.83,.28),Vector3(0,-.38,0),blue)
 _cube(left_arm,Vector3(.24,.20,.24),Vector3(0,-.87,0),skin)
 _cube(right_arm,Vector3(.24,.20,.24),Vector3(0,-.87,0),skin)
 left_leg=Node3D.new()
 right_leg=Node3D.new()
 left_leg.position=Vector3(-.2,.98,0)
 right_leg.position=Vector3(.2,.98,0)
 visuals.add_child(left_leg)
 visuals.add_child(right_leg)
 _cube(left_leg,Vector3(.31,.85,.34),Vector3(0,-.44,0),dark)
 _cube(right_leg,Vector3(.31,.85,.34),Vector3(0,-.44,0),dark)
 _cube(left_leg,Vector3(.34,.16,.55),Vector3(0,-.89,-.11),Color("c4c9cd"))
 _cube(right_leg,Vector3(.34,.16,.55),Vector3(0,-.89,-.11),Color("c4c9cd"))

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

extends CharacterBody3D

var is_traffic := false
var is_driven := false
var waypoints: Array[Vector3] = []
var waypoint_idx := 0
var speed := 0.0
var max_speed := 23.0
var body_mesh: Node3D
var brake_lights: Array[MeshInstance3D] = []
var wheel_pivots: Array[Node3D] = []
var model_name := "sedan-sports"
var driver: Node3D

func _ready() -> void:
 collision_layer=1
 collision_mask=1
 var shape := CollisionShape3D.new()
 var cube := BoxShape3D.new()
 cube.size=Vector3(2.1,1.5,4.2)
 shape.shape=cube
 shape.position.y=.05
 add_child(shape)
 body_mesh=Node3D.new()
 body_mesh.name="CarroVisual"
 add_child(body_mesh)
 _make_visual()

func _mat(color: Color, metal: float = 0.0) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=0.42
 m.metallic=metal
 return m

func _block(parent: Node3D, s:Vector3,p:Vector3,c:Color) -> MeshInstance3D:
 var n:=MeshInstance3D.new()
 var m:=BoxMesh.new()
 m.size=s
 n.mesh=m
 n.material_override=_mat(c)
 n.position=p
 parent.add_child(n)
 return n

func _make_visual() -> void:
 var path="res://assets/kenney/car-kit/%s.glb" % model_name
 if ResourceLoader.exists(path):
  var packed=load(path)
  if packed is PackedScene:
   var inst=(packed as PackedScene).instantiate()
   body_mesh.add_child(inst)
   inst.scale=Vector3(1.45,1.45,1.45)
   inst.rotation.y=PI
   inst.position.y=-.65
 else:
  _block(body_mesh,Vector3(2.0,.65,4.0),Vector3(0,-.1,0),Color("b93136"))
  _block(body_mesh,Vector3(1.75,.65,2.25),Vector3(0,.48,.3),Color("374751"))
  _block(body_mesh,Vector3(1.64,.045,1.45),Vector3(0,.81,.1),Color("1b2e38"))
  for x in [-.96,.96]:
   for z in [-1.28,1.32]:
    var pivot=Node3D.new()
    pivot.position=Vector3(x,-.49,z)
    body_mesh.add_child(pivot)
    _block(pivot,Vector3(.23,.7,.7),Vector3.ZERO,Color("1b1c1d"))
    wheel_pivots.append(pivot)
 for x in [-.74,.74]:
  var light=_block(body_mesh,Vector3(.35,.16,.04),Vector3(x,.04,2.04),Color("b82128"))
  brake_lights.append(light)
  _block(body_mesh,Vector3(.40,.17,.04),Vector3(x,.03,-2.04),Color("eee7c8"))

func _physics_process(delta:float) -> void:
 if is_driven:
  var throttle=float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
  var steering=float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))-float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
  var max_v=34.0 if Input.is_key_pressed(KEY_SHIFT) else max_speed
  if Input.is_key_pressed(KEY_SPACE):
   speed=move_toward(speed,0.0,delta*32.0)
  else:
   speed=move_toward(speed,throttle*max_v,delta*(15.0 if throttle!=0 else 8.0))
  rotation.y+=steering*delta*1.7*clampf(speed/9.0,-1,1)
 elif is_traffic and waypoints.size()>0:
  var target=waypoints[waypoint_idx]
  var dir=(target-global_position)
  dir.y=0
  if dir.length()<9.0:
   waypoint_idx=(waypoint_idx+1)%waypoints.size()
  else:
   rotation.y=lerp_angle(rotation.y,atan2(-dir.x,-dir.z),delta*1.85)
  var target_speed=10.5
  if driver != null and driver.global_position.distance_to(global_position)<8.0:
   target_speed=2.0
  speed=move_toward(speed,target_speed,delta*8.0)
 else:
  speed=move_toward(speed,0.0,delta*8.0)
 velocity=-global_transform.basis.z*speed
 velocity.y=-1.0
 move_and_slide()
 for p in wheel_pivots:
  p.rotation.x += speed*delta*1.45
 for l in brake_lights:
  var mat = l.material_override as StandardMaterial3D
  mat.albedo_color=Color("ff3939") if is_driven and Input.is_key_pressed(KEY_SPACE) else Color("9c101e")

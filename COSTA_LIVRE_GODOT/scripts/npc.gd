extends Node3D

var human_id:=0
var goal:=Vector3.ZERO
var behavior:="CAMINHANDO"
var state_time:=0.0
var speed:=1.55
var t:=0.0
var crowd_goals: Array[Vector3]=[]
var cars: Array=[]
var left_leg:Node3D
var right_leg:Node3D
var left_arm:Node3D
var right_arm:Node3D
var rng:=RandomNumberGenerator.new()
var talking_time:=0.0
var nearby_player:Node3D

func _ready() -> void:
 rng.seed=human_id*191+7021
 speed=rng.randf_range(1.15,2.15)
 _create_body()
 _choose_goal()

func _mat(c:Color) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.albedo_color=c
 m.roughness=.87
 return m

func _mesh(parent:Node3D,s:Vector3,p:Vector3,c:Color) -> void:
 var n:=MeshInstance3D.new()
 var mesh:=BoxMesh.new()
 mesh.size=s
 n.mesh=mesh
 n.position=p
 n.material_override=_mat(c)
 parent.add_child(n)

func _rounded(parent:Node3D,size_3d:Vector3,at:Vector3,color:Color) -> void:
 var visual:=MeshInstance3D.new()
 var sphere:=SphereMesh.new()
 sphere.radius=.5
 sphere.height=1.0
 sphere.radial_segments=10
 sphere.rings=5
 visual.mesh=sphere
 visual.scale=size_3d
 visual.position=at
 visual.material_override=_mat(color)
 parent.add_child(visual)

func _create_body() -> void:
 var shirts=[Color("48677a"),Color("c78d54"),Color("58745d"),Color("ad6465"),Color("e3d4c2"),Color("383d4d"),Color("c49c64")]
 var skins=[Color("c18f69"),Color("83583d"),Color("e0b18b"),Color("a77b5e")]
 var pants=[Color("343944"),Color("333b39"),Color("615143"),Color("323b51")]
 var clothes=shirts[human_id%shirts.size()]
 var skin=skins[human_id%skins.size()]
 var pant=pants[human_id%pants.size()]
 var hair=Color("292820") if human_id%5 != 0 else Color("6c5035")
 _rounded(self,Vector3(.67,.85,.4),Vector3(0,1.48,0),clothes)
 _rounded(self,Vector3(.56,.26,.34),Vector3(0,1.09,0),pant)
 _rounded(self,Vector3(.44,.47,.4),Vector3(0,2.25,0),skin)
 _rounded(self,Vector3(.46,.19,.42),Vector3(0,2.49,.03),hair)
 _rounded(self,Vector3(.15,.17,.11),Vector3(0,2.19,-.22),skin)
 for side in [-1,1]:
  var fx=float(side)
  _rounded(self,Vector3(.07,.07,.048),Vector3(fx*.11,2.29,-.205),Color("34312b"))
  var arm:=Node3D.new()
  arm.position=Vector3(fx*.44,1.82,0)
  add_child(arm)
  _rounded(arm,Vector3(.21,.73,.24),Vector3(0,-.34,0),clothes)
  _rounded(arm,Vector3(.19,.19,.20),Vector3(0,-.77,0),skin)
  if side == -1: left_arm=arm
  else: right_arm=arm
  var leg:=Node3D.new()
  leg.position=Vector3(fx*.17,.99,0)
  add_child(leg)
  _rounded(leg,Vector3(.27,.84,.30),Vector3(0,-.42,0),pant)
  _rounded(leg,Vector3(.30,.16,.44),Vector3(0,-.84,-.06),Color("393630"))
  if side == -1: left_leg=leg
  else: right_leg=leg

func _choose_goal() -> void:
 if crowd_goals.is_empty():
  goal=global_position+Vector3(rng.randf_range(-10,10),0,rng.randf_range(-10,10))
 else:
  var candidates: Array[Vector3]=[]
  for point in crowd_goals:
   if point.distance_to(global_position)<125.0 and point.distance_to(global_position)>12.0:
    if abs(point.x-global_position.x)<13.0 or abs(point.z-global_position.z)<13.0:
     candidates.append(point)
  goal=candidates[rng.randi_range(0,candidates.size()-1)] if not candidates.is_empty() else crowd_goals[rng.randi_range(0,crowd_goals.size()-1)]
 behavior="CAMINHANDO"
 state_time=rng.randf_range(9.0,25.0)

func speak() -> String:
 talking_time=4.5
 behavior="CONVERSANDO"
 var phrases=["O vento da praia esta otimo hoje.","Vou visitar o pier mais tarde.","O transito no centro esta movimentado.","Tem um cafe legal no calcadao.","Estou indo encontrar meus amigos.","A cidade fica bonita no fim da tarde.","A avenida leva direto a praia."]
 return phrases[(human_id+rng.randi_range(0,3))%phrases.size()]

func _process(delta:float) -> void:
 if nearby_player!=null and nearby_player.global_position.distance_to(global_position)>150.0:return
 if talking_time>0:
  talking_time-=delta
  if talking_time<=0: _choose_goal()
  return
 state_time-=delta
 if state_time<=0 or global_position.distance_to(goal)<2.2:
  if behavior=="CAMINHANDO" and rng.randf()<.24:
   behavior="OBSERVANDO"
   state_time=rng.randf_range(1.0,4.5)
  else:
   _choose_goal()
 if behavior != "CAMINHANDO":
  _animate(delta,false)
  return
 var to=goal-global_position
 to.y=0
 if to.length()<.25:return
 var safe=true
 for car in cars:
  if is_instance_valid(car) and car.global_position.distance_to(global_position)<3.4:
   safe=false
   break
 if nearby_player!=null and nearby_player.global_position.distance_to(global_position)<.75:
  safe=false
 if safe:
  var d=to.normalized()
  global_position += d*delta*speed
  rotation.y=lerp_angle(rotation.y,atan2(-d.x,-d.z),minf(1.0,delta*5.0))
 _animate(delta,safe)

func _animate(delta:float,walking:bool) -> void:
 if walking: t+=delta*speed*5.5
 var v=sin(t)*(.47 if walking else 0.0)
 left_leg.rotation.x=lerpf(left_leg.rotation.x,v,delta*12.0)
 right_leg.rotation.x=lerpf(right_leg.rotation.x,-v,delta*12.0)
 left_arm.rotation.x=lerpf(left_arm.rotation.x,-v*.65,delta*12.0)
 right_arm.rotation.x=lerpf(right_arm.rotation.x,v*.65,delta*12.0)

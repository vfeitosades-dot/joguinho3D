extends Node3D
# Pontos de interesse artesanais: comercio na orla, quiosque, mirante e detalhes urbanos.
var game: Node3D
var mats: Dictionary = {}
var sign_words := ["MARINA","BRISA CAFE","COSTA SUL","MERCADO","ATELIER","HOTEL AREIA","LIVRARIA","PADARIA"]
func construct(g:Node3D) -> void:
 game=g
 _set_materials()
 _boardwalk()
 _coffee_kiosk()
 _lifeguard()
 _street_furniture()
 _coast_sign()

func _set_materials() -> void:
 var palette={"teal":Color("228c90"),"dark":Color("18333d"),"gold":Color("f4b964"),"cream":Color("f0e4ce"),"glass":Color("397b86"),"white":Color("fcf4df"),"wood":Color("806148"),"sand":Color("b99b70"),"red":Color("cf6958"),"leaf":Color("39735c"),"light":Color("fff2c6")}
 for key in palette:
  var mat:=StandardMaterial3D.new()
  mat.albedo_color=palette[key]
  mat.roughness=.6
  if key=="glass":
   mat.metallic=.24
   mat.roughness=.16
  if key=="light":
   mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  mats[key]=mat

func _box(p:Node3D,d:Vector3,t:Vector3,mat:String) -> MeshInstance3D:
 var m:=MeshInstance3D.new()
 var shape:=BoxMesh.new()
 shape.size=d
 m.mesh=shape
 m.position=t
 m.material_override=mats[mat]
 p.add_child(m)
 return m

func _cylinder(p:Node3D,top:float,bottom:float,h:float,t:Vector3,mat:String) -> void:
 var m:=MeshInstance3D.new()
 var shape:=CylinderMesh.new()
 shape.top_radius=top
 shape.bottom_radius=bottom
 shape.height=h
 shape.radial_segments=8
 m.mesh=shape
 m.position=t
 m.material_override=mats[mat]
 p.add_child(m)

func _sign(p:Node3D,word:String,t:Vector3,width:float=6.0) -> void:
 _box(p,Vector3(width,.95,.19),t,"dark")
 _box(p,Vector3(width-.17,.07,.23),t+Vector3(0,-.47,0),"gold")
 var sign:=Label3D.new()
 sign.text=word
 sign.font_size=64
 sign.pixel_size=.011
 sign.modulate=Color("fce7bb")
 sign.position=t+Vector3(0,-.18,-.15)
 p.add_child(sign)

func _boardwalk() -> void:
 var node:=Node3D.new()
 node.name="Calcadao_Vivo"
 add_child(node)
 for j in range(11):
  var z=float(j-5)*54.0
  _box(node,Vector3(5,.08,8),Vector3(300,.12,z),"cream")
  _box(node,Vector3(5,.16,.20),Vector3(300,.15,z-4),"teal")
  _box(node,Vector3(5,.16,.20),Vector3(300,.15,z+4),"teal")
  _box(node,Vector3(.16,1.35,.16),Vector3(301.8,.73,z),"dark")
  _box(node,Vector3(2.0,.12,.8),Vector3(302,1.41,z),"wood")
  _cylinder(node,.2,.22,.5,Vector3(305,.28,z+2.3),"sand")
  for side in [-1,1]:
   _box(node,Vector3(.16,2.45,.16),Vector3(296.8,1.25,z+side*7),"dark")
   _box(node,Vector3(.48,.2,.48),Vector3(296.8,2.48,z+side*7),"light")

func _coffee_kiosk() -> void:
 var p:=Node3D.new()
 p.name="Quiosque_Brisa_Cafe"
 p.position=Vector3(319,.07,-91)
 add_child(p)
 _box(p,Vector3(10,.25,8),Vector3(0,.15,0),"cream")
 _box(p,Vector3(8,3.5,5),Vector3(0,1.95,0),"wood")
 _box(p,Vector3(9.7,.43,6.6),Vector3(0,4.1,0),"teal")
 _box(p,Vector3(9.2,.1,.6),Vector3(0,3.6,-2.95),"gold")
 _box(p,Vector3(5,1.65,.09),Vector3(0,2.15,-2.58),"glass")
 _box(p,Vector3(7.4,.35,1.7),Vector3(0,1.3,-3.26),"cream")
 _sign(p,"BRISA CAFE",Vector3(0,4.0,-3.43),6.3)
 for n in range(4):
  var x=float(n-2)*2.8+1.3
  var z=-7.0-3.0*float(n%2)
  _cylinder(p,.08,.08,1.1,Vector3(x,.72,z),"dark")
  _cylinder(p,.82,.82,.14,Vector3(x,1.3,z),"cream")
  for i in 3:
   var a=float(i)*TAU/3.0
   _box(p,Vector3(.48,.52,.46),Vector3(x+cos(a)*1.16,.44,z+sin(a)*1.16),"teal")

func _lifeguard() -> void:
 var p:=Node3D.new()
 p.name="Posto_de_Observacao"
 p.position=Vector3(327,.06,154)
 add_child(p)
 for x in [-2,2]:
  for z in [-2,2]:
   _box(p,Vector3(.32,3,.32),Vector3(x,1.5,z),"wood")
 _box(p,Vector3(5,1.9,5),Vector3(0,3.2,0),"cream")
 _box(p,Vector3(6,.30,6),Vector3(0,4.35,0),"teal")
 _box(p,Vector3(3,.93,.10),Vector3(0,3.25,-2.55),"glass")
 _box(p,Vector3(1.1,.15,5),Vector3(-2.75,1.1,-1.5),"wood")
 _sign(p,"POSTO 07",Vector3(0,4.28,-2.94),4.8)

func _street_furniture() -> void:
 var p:=Node3D.new()
 p.name="Detalhes_Urbanos"
 add_child(p)
 for k in range(11):
  var z=float(k-5)*52.0
  _box(p,Vector3(.12,2.1,.12),Vector3(264,1.10,z),"dark")
  _box(p,Vector3(2.5,.18,.62),Vector3(264,1.65,z),"wood")
  _box(p,Vector3(2.52,.17,.55),Vector3(264,1.28,z),"wood")
  _box(p,Vector3(.18,.8,.18),Vector3(263.1,.52,z),"dark")
  _box(p,Vector3(.18,.8,.18),Vector3(264.9,.52,z),"dark")
  _cylinder(p,.26,.26,.82,Vector3(270,.42,z+13),"teal")
  _box(p,Vector3(.65,.12,.65),Vector3(270,.91,z+13),"dark")
 for i in range(8):
  var z=float(i-4)*73.0
  _box(p,Vector3(.16,5.1,.16),Vector3(307,2.55,z),"dark")
  _box(p,Vector3(1.5,.15,.15),Vector3(307.7,5.05,z),"dark")
  _box(p,Vector3(.63,.2,.65),Vector3(308.44,4.97,z),"light")

func _coast_sign() -> void:
 var p:=Node3D.new()
 p.name="Letreiro_Costa"
 p.position=Vector3(293,.1,203)
 add_child(p)
 _box(p,Vector3(11,4,.7),Vector3(0,2.1,0),"dark")
 _box(p,Vector3(11.4,.16,.83),Vector3(0,4.13,0),"gold")
 _sign(p,"COSTA LIVRE",Vector3(0,2.2,-.54),9.5)

func decorate_lot(parent:Node3D,world_pos:Vector3,width:float,depth:float,commercial:bool,index:int) -> void:
 if index%3 != 0: return
 var p:=Node3D.new()
 p.position=world_pos
 parent.add_child(p)
 if commercial:
  _sign(p,sign_words[posmod(index,sign_words.size())],Vector3(0,2.9,-depth*.45-.2),minf(8.0,width*.72))
  _box(p,Vector3(width*.57,.22,1.25),Vector3(0,2.25,-depth*.45-.85),"teal")
 else:
  _box(p,Vector3(width*.30,.1,1.1),Vector3(0,2.2,-depth*.45-.65),"wood")
  _box(p,Vector3(1.2,.24,2.4),Vector3(width*.34,.2,-depth*.45),"cream")

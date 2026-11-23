extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CarScript = preload("res://scripts/car.gd")
const NpcScript = preload("res://scripts/npc.gd")

const STREET_STEP := 70.0
const MAP_END := 350.0
const BEACH_X := 309.0
const SEA_X := 352.0

var player: CharacterBody3D
var player_car: CharacterBody3D
var cars: Array = []
var people: Array = []
var sidewalk_goals: Array[Vector3] = []
var camera: Camera3D
var sky_light: DirectionalLight3D
var water: MeshInstance3D
var active_chunks: Dictionary = {}
var hud_fps: Label
var hud_hint: Label
var hud_area: Label
var hud_title: Label
var hud_chat: Label
var chat_timer := 0.0
var debug_hints := true
var mouse_yaw := .65
var mouse_pitch := .27
var camera_dist := 7.8
var elapsed := 0.0
var check_timer := 0.0
var camera_target := Vector3.ZERO
var seed_base := 12027
var region_name := "CENTRO"
var materials: Dictionary = {}

func _ready() -> void:
 randomize()
 _setup_mats()
 _setup_lighting()
 _terrain()
 _roads()
 _beach()
 _pier()
 _sidewalk_paths()
 _spawn_player()
 _spawn_vehicles()
 _spawn_people()
 _make_hud()
 _stream_blocks(true)
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _setup_mats() -> void:
 for key in ["park","road","roadline","sidewalk","sand","sea","grass","concrete","white","wood","glass","shadow","black"]:
  var values={
   "park":Color("738361"),"road":Color("383e47"),"roadline":Color("d5d0b5"),
   "sidewalk":Color("bcbeb5"),"sand":Color("d9c095"),"sea":Color("438a9b"),
   "grass":Color("697d52"),"concrete":Color("a4a59d"),"white":Color("e4e1d1"),
   "wood":Color("84654a"),"glass":Color("55798a"),"shadow":Color("aeb4ae"),"black":Color("242d36")}
  var mat:=StandardMaterial3D.new()
  mat.albedo_color=values[key]
  mat.roughness=.86
  if key=="glass":
   mat.metallic=.18
   mat.roughness=.27
  if key=="sea":
   mat.roughness=.33
   mat.metallic=.1
   mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  materials[key]=mat

func _setup_lighting() -> void:
 var world_env:=WorldEnvironment.new()
 var environment:=Environment.new()
 environment.background_mode=Environment.BG_COLOR
 environment.background_color=Color("91bdd7")
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color("ced9de")
 environment.ambient_light_energy=.9
 environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world_env.environment=environment
 add_child(world_env)
 sky_light=DirectionalLight3D.new()
 sky_light.light_color=Color("ffefdc")
 sky_light.light_energy=1.25
 sky_light.shadow_enabled=false
 sky_light.rotation_degrees=Vector3(-48,-28,0)
 add_child(sky_light)
 camera=Camera3D.new()
 camera.current=true
 camera.fov=71.0
 camera.near=.16
 camera.far=255.0
 add_child(camera)

func _material(name:String) -> Material:
 return materials[name]

func _box(parent:Node3D,sz:Vector3,pos:Vector3,mat_name:String) -> MeshInstance3D:
 var m:=MeshInstance3D.new()
 var shape:=BoxMesh.new()
 shape.size=sz
 m.mesh=shape
 m.material_override=_material(mat_name)
 m.position=pos
 parent.add_child(m)
 return m

func _static_box(parent:Node3D,sz:Vector3,pos:Vector3) -> StaticBody3D:
 var body:=StaticBody3D.new()
 body.position=pos
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=sz
 collision.shape=shape
 body.add_child(collision)
 parent.add_child(body)
 return body

func _asset(pack:String,asset:String,parent:Node3D,pos:Vector3,scale_factor:float=1.0) -> bool:
 var path="res://assets/kenney/%s/%s.glb" % [pack,asset]
 if not ResourceLoader.exists(path):return false
 var packed=load(path)
 if not (packed is PackedScene):return false
 var instance=(packed as PackedScene).instantiate()
 parent.add_child(instance)
 instance.position=pos
 instance.scale=Vector3.ONE*scale_factor
 return true

func _terrain() -> void:
 _box(self,Vector3(710,1.0,710),Vector3(0,-.53,0),"park")
 _static_box(self,Vector3(710,1.0,710),Vector3(0,-.53,0))
 # agua sem colisao: o litoral fica no extremo leste da cidade
 water=_box(self,Vector3(760,.045,710),Vector3(SEA_X+380,-.18,0),"sea")
 _box(self,Vector3(28,.05,708),Vector3(332,.025,0),"sand")
 _box(self,Vector3(19,.07,708),Vector3(294,.035,0),"sidewalk")
 _box(self,Vector3(3,.11,708),Vector3(304,.075,0),"concrete")
 # faixa verde com pontos de descanso
 _box(self,Vector3(17,.08,706),Vector3(267,.025,0),"grass")

func _roads() -> void:
 for i in range(-4,5):
  var coord=float(i)*STREET_STEP
  _box(self,Vector3(12,.04,705),Vector3(coord,.04,0),"road")
  _box(self,Vector3(705,.04,12),Vector3(0,.045,coord),"road")
  for n in range(-11,12):
   var marking=float(n)*25.0
   if absf(marking-coord)<5.0:continue
   _box(self,Vector3(.21,.014,6),Vector3(coord,.073,marking),"roadline")
   _box(self,Vector3(6,.014,.21),Vector3(marking,.075,coord),"roadline")
  # meio-fio simples, conservando cruzamentos livres
  for s in [-1,1]:
   _box(self,Vector3(1.7,.055,710),Vector3(coord+float(s)*6.9,.072,0),"sidewalk")
   _box(self,Vector3(710,.055,1.7),Vector3(0,.074,coord+float(s)*6.9),"sidewalk")
 # estrada litoranea
 _box(self,Vector3(13,.047,705),Vector3(250,.055,0),"road")
 for zz in range(-310,311,24):
  _box(self,Vector3(.2,.02,7),Vector3(250,.087,float(zz)),"roadline")

func _beach() -> void:
 for i in range(24):
  var z=float(i-12)*26.0+7.0
  var beach_prop:=Node3D.new()
  beach_prop.position=Vector3(318,.09,z)
  add_child(beach_prop)
  if not _asset("city-kit-commercial","detail-parasol-a",beach_prop,Vector3.ZERO,2.6):
   _box(beach_prop,Vector3(.07,2.0,.07),Vector3(0,1.05,0),"wood")
   var shade:=MeshInstance3D.new()
   var cone:=CylinderMesh.new()
   cone.top_radius=.1
   cone.bottom_radius=1.65
   cone.height=.42
   shade.mesh=cone
   shade.material_override=_material("white")
   shade.position=Vector3(0,2.2,0)
   beach_prop.add_child(shade)
  _box(beach_prop,Vector3(1.1,.12,1.9),Vector3(2.6,.15,0),"white")
 for z in range(-300,301,48):
  _palm(Vector3(281,.12,float(z)+9.0),self)
  _box(self,Vector3(2.5,.25,1.05),Vector3(282,.35,float(z)+30.0),"wood")

func _palm(pos:Vector3,parent:Node3D) -> void:
 var pivot:=Node3D.new()
 pivot.position=pos
 parent.add_child(pivot)
 var trunk:=CylinderMesh.new()
 trunk.top_radius=.18
 trunk.bottom_radius=.28
 trunk.height=6.0
 var inst:=MeshInstance3D.new()
 inst.mesh=trunk
 inst.material_override=_material("wood")
 inst.position.y=3.0
 pivot.add_child(inst)
 for j in range(5):
  var leaf:=MeshInstance3D.new()
  var mesh:=BoxMesh.new()
  mesh.size=Vector3(.7,.13,4.3)
  leaf.mesh=mesh
  leaf.material_override=_material("grass")
  leaf.position=Vector3(0,5.95,-1.68)
  var wrap:=Node3D.new()
  wrap.rotation.y=float(j)*TAU/5.0
  wrap.add_child(leaf)
  pivot.add_child(wrap)

func _pier() -> void:
 var pier:=Node3D.new()
 pier.name="Pier_Mirante"
 pier.position=Vector3(403,0,73)
 add_child(pier)
 _box(pier,Vector3(136,.65,13),Vector3(0,.48,0),"wood")
 _static_box(pier,Vector3(136,.65,13),Vector3(0,.48,0))
 for ix in range(-8,9):
  var x=float(ix)*8.0
  for zz in [-5.8,5.8]:
   _box(pier,Vector3(.28,2.3,.28),Vector3(x,1.65,zz),"wood")
   _box(pier,Vector3(8.1,.17,.18),Vector3(x+4,2.30,zz),"wood")
 _box(pier,Vector3(18,.45,24),Vector3(68,.42,0),"wood")
 _asset("nature-kit","canoe",pier,Vector3(60,1.0,-5),2.2)

func _sidewalk_paths() -> void:
 for x in range(-4,5):
  for z in range(-4,5):
   var a=float(x)*STREET_STEP
   var b=float(z)*STREET_STEP
   sidewalk_goals.append(Vector3(a+9,0,b+9))
   sidewalk_goals.append(Vector3(a-9,0,b-9))
 for z in range(-5,6):
  sidewalk_goals.append(Vector3(282,0,float(z)*56.0))

func _spawn_player() -> void:
 player=PlayerScript.new()
 player.position=Vector3(230,1.0,14)
 add_child(player)
 player.camera_node=camera
 camera_target=player.position

func _spawn_vehicles() -> void:
 var choice=["sedan-sports","suv","taxi","hatchback-sports","sedan","van","suv-luxury"]
 var parked=[Vector3(231,.85,2),Vector3(161,.85,32),Vector3(91,.85,-36),Vector3(-48,.85,106),Vector3(-182,.85,-32),Vector3(21,.85,-154)]
 for idx in parked.size():
  var c:=CarScript.new()
  c.name="Veiculo_Estacionado_%02d"%idx
  c.model_name=choice[idx%choice.size()]
  c.position=parked[idx]
  c.driver=player
  add_child(c)
  cars.append(c)
 var loop=[Vector3(140,.85,-140),Vector3(140,.85,140),Vector3(-140,.85,140),Vector3(-140,.85,-140)]
 for i in range(5):
  var c:=CarScript.new()
  c.name="Transito_%02d"%i
  c.model_name=choice[(i+2)%choice.size()]
  c.is_traffic=true
  c.waypoints=loop
  c.waypoint_idx=i%loop.size()
  c.position=loop[i%loop.size()]+Vector3(0,0,float(i)*9.0)
  c.driver=player
  add_child(c)
  cars.append(c)

func _spawn_people() -> void:
 for i in range(24):
  var n:=NpcScript.new()
  n.name="Cidadao_%02d"%i
  n.human_id=i
  var p=sidewalk_goals[(i*13+47)%sidewalk_goals.size()]
  if i<7:p=Vector3(281,0,(float(i)-3.0)*40.0)
  n.position=p
  n.crowd_goals=sidewalk_goals
  n.cars=cars
  n.nearby_player=player
  add_child(n)
  people.append(n)

func _stream_blocks(force:bool=false) -> void:
 var center=player_car.global_position if player_car!=null else player.global_position
 var ix=int(floor((center.x+35.0)/STREET_STEP))
 var iz=int(floor((center.z+35.0)/STREET_STEP))
 var needed:Dictionary={}
 for x in range(ix-2,ix+3):
  for z in range(iz-2,iz+3):
   if x < -4 or x > 3 or z < -4 or z > 3:continue
   var key="%d_%d"%[x,z]
   needed[key]=true
   if not active_chunks.has(key):
    var chunk=Node3D.new()
    chunk.name="Distrito_%s"%key
    add_child(chunk)
    active_chunks[key]=chunk
    _build_block(x,z,chunk)
 for key in active_chunks.keys():
  if not needed.has(key):
   active_chunks[key].queue_free()
   active_chunks.erase(key)

func _build_block(ix:int,iz:int,parent:Node3D) -> void:
 var rng:=RandomNumberGenerator.new()
 rng.seed=seed_base+(ix+8)*621+(iz+8)*18371
 var x=(float(ix)+.5)*STREET_STEP
 var z=(float(iz)+.5)*STREET_STEP
 var dist=sqrt(x*x+z*z)
 var commerce=(ix>0 and ix<3) or (dist<170)
 var district_kind="commercial" if commerce else "suburban"
 var pieces=2 if dist<180.0 else 1
 if rng.randf()>.5:pieces=2
 for j in pieces:
  var offset=Vector3(-12 if j==0 else 12,0,6 if j==0 else -7)
  if pieces==1: offset=Vector3.ZERO
  var lot_x=x+offset.x
  var lot_z=z+offset.z
  var width=20.0 if pieces==2 else 32.0
  var depth=25.0 if pieces==2 else 30.0
  _box(parent,Vector3(width+2,.15,depth+3),Vector3(lot_x,.09,lot_z),"concrete")
  var building:=Node3D.new()
  building.position=Vector3(lot_x,.20,lot_z)
  parent.add_child(building)
  var height=rng.randf_range(14.0,28.0)
  var style=rng.randi_range(0,7)
  if commerce:
   var model="building-%s"%String.chr(97+style)
   if dist<145 and rng.randf()<.22:
    model="building-skyscraper-a" if j==0 else "building-skyscraper-b"
    height=49.0
   if not _asset("city-kit-commercial",model,building,Vector3.ZERO,width*.56):
    _fallback_building(building,width-3,depth-4,height,rng)
  else:
   var model2="building-type-%s"%String.chr(97+rng.randi_range(0,4))
   if not _asset("city-kit-suburban",model2,building,Vector3.ZERO,11.0):
    _fallback_building(building,width-2,depth-3,height*.55,rng)
  _static_box(building,Vector3(width-3,height*.8,depth-3),Vector3(0,height*.4,0))
 if rng.randf()<.72:
  var tree_name="tree-large" if rng.randf()<.45 else "tree-small"
  if not _asset("city-kit-suburban",tree_name,parent,Vector3(x-25,.13,z+21),5.5):
   _palm(Vector3(x-25,.11,z+21),parent)
 if rng.randf()<.5:
  _asset("city-kit-roads","light-curved",parent,Vector3(x-25,.14,z-27),3.1)
 if rng.randf()<.18:
  _asset("city-kit-roads","dumpster",parent,Vector3(x+24,.15,z+22),2.0)

func _fallback_building(parent:Node3D,w:float,d:float,h:float,rng:RandomNumberGenerator) -> void:
 var body_mat="white" if rng.randf()<.4 else "shadow"
 _box(parent,Vector3(w,h,d),Vector3(0,h*.5,0),body_mat)
 _box(parent,Vector3(w+1,.5,d+1),Vector3(0,h+.3,0),"black")
 var floors=mini(8,int(h/3.4))
 for level in range(floors):
  for xx in range(-1,2):
   for zz in [-1,1]:
    var window_h=float(level)*3.3+2.3
    _box(parent,Vector3(2.25,1.95,.08),Vector3(float(xx)*w*.27,window_h,zz*(d*.5+.055)),"glass")
    _box(parent,Vector3(.08,1.95,2.3),Vector3(zz*(w*.5+.055),window_h,float(xx)*d*.28),"glass")

func _make_hud() -> void:
 var canvas:=CanvasLayer.new()
 add_child(canvas)
 var titlebox:=ColorRect.new()
 titlebox.color=Color(0.035,0.085,0.12,.82)
 titlebox.position=Vector2(15,14)
 titlebox.size=Vector2(400,81)
 canvas.add_child(titlebox)
 hud_title=_label(canvas,"C O S T A   L I V R E",Vector2(27,19),25,Color("f4e9d2"))
 hud_area=_label(canvas,"CENTRO  |  SOL E BRISA  |  ILHA DOURADA",Vector2(29,58),13,Color("abdae7"))
 hud_fps=_label(canvas,"",Vector2(29,80),12,Color("e6e6e6"))
 hud_hint=_label(canvas,"WASD ANDAR  |  SHIFT CORRER  |  E CARRO  |  F CONVERSAR\nMOUSE CAMERA  |  RODA ZOOM  |  ESC LIBERAR  |  H DICAS",Vector2(23,471),13,Color("f3f5f1"))
 hud_chat=_label(canvas,"",Vector2(25,416),17,Color("ffe7aa"))

func _label(parent:Node,text_value:String,pos:Vector2,font_size:int,color:Color) -> Label:
 var label:=Label.new()
 label.text=text_value
 label.position=pos
 label.add_theme_color_override("font_color",color)
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
 label.add_theme_constant_override("shadow_offset_x",2)
 label.add_theme_constant_override("shadow_offset_y",2)
 parent.add_child(label)
 return label

func _input(event:InputEvent) -> void:
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  mouse_yaw-=event.relative.x*.004
  mouse_pitch=clampf(mouse_pitch+event.relative.y*.003,-.08,.82)
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
   camera_dist=maxf(3.5,camera_dist-.7)
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
   camera_dist=minf(15.0,camera_dist+.7)
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
  elif event.keycode==KEY_E:
   _toggle_car()
  elif event.keycode==KEY_F:
   _talk_to_citizen()
  elif event.keycode==KEY_H:
   debug_hints=not debug_hints
   hud_hint.visible=debug_hints

func _toggle_car() -> void:
 if player_car!=null:
  var exit_pos=player_car.global_position+player_car.global_transform.basis.x*3.0
  player.global_position=Vector3(exit_pos.x,1.0,exit_pos.z)
  player.set_in_vehicle(false)
  player_car.is_driven=false
  player_car=null
  _message("Voce saiu do carro")
  return
 var nearest=null
 var best:=5.0
 for c in cars:
  if not is_instance_valid(c):continue
  if c.is_traffic:continue
  var d=player.global_position.distance_to(c.global_position)
  if d<best:
   best=d
   nearest=c
 if nearest!=null:
  player_car=nearest
  player_car.is_driven=true
  player.set_in_vehicle(true)
  _message("DIRIGINDO  |  WASD mover  |  Espaco frear  |  E sair")
 else:
  _message("Aproxime-se de um carro estacionado e aperte E")

func _talk_to_citizen() -> void:
 if player_car!=null:return
 var best=3.7
 var chosen=null
 for p in people:
  if not is_instance_valid(p):continue
  var d=player.global_position.distance_to(p.global_position)
  if d<best:
   best=d
   chosen=p
 if chosen!=null:
  _message("MORADOR:  "+chosen.speak())
 else:
  _message("Aproxime-se de um pedestre para conversar")

func _message(msg:String) -> void:
 hud_chat.text=msg
 chat_timer=5.5

func _process(delta:float) -> void:
 elapsed+=delta
 check_timer+=delta
 if check_timer>.85:
  check_timer=0
  _stream_blocks()
 var focus=player_car.global_position if player_car!=null else player.global_position
 if player_car!=null:
  focus+=Vector3(0,.9,0)
 else:
  focus+=Vector3(0,1.55,0)
 camera_target=camera_target.lerp(focus,clampf(delta*8.0,0,1))
 var offset=Vector3(sin(mouse_yaw)*cos(mouse_pitch),sin(mouse_pitch)+.30,cos(mouse_yaw)*cos(mouse_pitch))*camera_dist
 camera.global_position=camera.global_position.lerp(camera_target+offset,clampf(delta*9.0,0,1))
 camera.look_at(camera_target,Vector3.UP)
 if focus.x>292:
  region_name="PRAIA DO SOL"
 elif focus.x>225:
  region_name="ORLA"
 elif focus.length()>215:
  region_name="BAIRROS"
 else:
  region_name="CENTRO"
 hud_area.text="%s  |  CIDADE COSTEIRA  |  ALPHA 0.1"%region_name
 hud_fps.text="FPS %d   |   SETORES %d   |   MORADORES %d   |   CARROS %d"%[int(Engine.get_frames_per_second()),active_chunks.size(),people.size(),cars.size()]
 if chat_timer>0:
  chat_timer-=delta
  if chat_timer<=0:hud_chat.text=""
 if water!=null:
  water.position.y=-.18+sin(elapsed*.7)*.012

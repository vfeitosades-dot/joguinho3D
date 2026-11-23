extends Control
# Mapa e minimapa desenhados na propria engine, sem texturas de terceiros.
var game: Node3D
var expanded := false
var pulse := 0.0
const BG := Color(0.04,0.095,0.125)
const SEA := Color(0.07,0.27,0.36)
const ROAD := Color(0.37,0.55,0.56,0.74)
const OUTLINE := Color(0.18,0.8,0.73)

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 clip_contents = true
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
 pulse += delta*2.5
 queue_redraw()

func _draw() -> void:
 var sz := size
 draw_rect(Rect2(Vector2.ZERO,sz),BG,true)
 if game == null or game.player == null: return
 var subject: Node3D = game.player_car if game.player_car != null else game.player
 var loc := subject.global_position
 var zoom := 0.72 if expanded else 1.65
 var pivot := sz*.5
 var sea_start := pivot.x+(312.0-loc.x)*zoom
 if sea_start < sz.x:
  draw_rect(Rect2(Vector2(maxf(0.0,sea_start),0),Vector2(sz.x-maxf(0,sea_start),sz.y)),SEA,true)
 for k in range(-4,5):
  var world_coord := float(k)*70.0
  var x := pivot.x+(world_coord-loc.x)*zoom
  var z := pivot.y+(world_coord-loc.z)*zoom
  draw_line(Vector2(x,0),Vector2(x,sz.y),ROAD,10 if expanded else 5)
  draw_line(Vector2(0,z),Vector2(sz.x,z),ROAD,10 if expanded else 5)
 var coast := pivot.x+(250.0-loc.x)*zoom
 draw_line(Vector2(coast,0),Vector2(coast,sz.y),ROAD,12 if expanded else 6)
 var beach := pivot.x+(294.0-loc.x)*zoom
 draw_line(Vector2(beach,0),Vector2(beach,sz.y),Color("d8c49b"),5)
 if game.missions != null:
  var target:Vector3 = game.missions.current_destination
  var dot := pivot+Vector2((target.x-loc.x)*zoom,(target.z-loc.z)*zoom)
  draw_circle(dot,7.5+sin(pulse)*1.8,Color(1.0,0.77,0.39))
  draw_arc(dot,12.0,0,TAU,32,Color(1.0,0.83,0.51,0.7),1.4)
 var yaw := subject.rotation.y
 var facing:=Vector2(-sin(yaw),-cos(yaw))
 draw_circle(pivot,7,OUTLINE)
 draw_line(pivot,pivot+facing*14,Color.WHITE,2.5,true)
 draw_arc(pivot,13,0,TAU,32,OUTLINE,1.5)
 if expanded:
  draw_string(ThemeDB.fallback_font,Vector2(18,25),"MAPA TATICO  /  COSTA LIVRE",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
  draw_string(ThemeDB.fallback_font,Vector2(18,sz.y-15),"OCEANO A LESTE   •   ESC PARA VOLTAR",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("adcfda"))

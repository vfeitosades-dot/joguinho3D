extends Node
# Campanha de exploracao civil com objetivos, recompensas e salvamento local.
var game: Node3D
var stage := 0
var completed := 0
var credits := 0
var objective_text := "Explore a cidade"
var current_destination := Vector3(300.0,0.5,73.0)
var marker: Node3D
var time_since_save := 0.0
const SAVE_PATH := "user://costa_livre_save.json"
const STAGES := [
 ["BEM-VINDO A ORLA", "Visite o mirante da praia", Vector3(300.0,0.5,73.0), 65],
 ["PONTO DE PARTIDA", "Entre em um carro estacionado", Vector3(231.0,0.9,2.0), 90],
 ["PASSEIO COSTEIRO", "Dirija ate o calçadao norte", Vector3(268.0,0.5,-196.0), 110],
 ["CONHECA OS MORADORES", "Converse com um pedestre", Vector3(281.0,0.5,-45.0), 55],
 ["VISTA PARA O MAR", "Va ate o pier sobre o oceano", Vector3(404.0,0.5,73.0), 140]
]

func _ready() -> void:
 _load()
 _create_marker()
 _set_objective()

func _load() -> void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
 if file == null: return
 var data = JSON.parse_string(file.get_as_text())
 if data is Dictionary:
  stage = clampi(int(data.get("stage",0)),0,STAGES.size()-1)
  credits = maxi(0,int(data.get("credits",0)))
  completed = maxi(0,int(data.get("completed",0)))

func _save() -> void:
 var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify({"stage":stage,"credits":credits,"completed":completed}))

func _create_marker() -> void:
 marker=Node3D.new()
 marker.name="Destino_Objetivo"
 game.add_child(marker)
 var ring := MeshInstance3D.new()
 var mesh := TorusMesh.new()
 mesh.inner_radius=2.0
 mesh.outer_radius=2.25
 mesh.rings=8
 mesh.ring_segments=26
 ring.mesh=mesh
 var mat := StandardMaterial3D.new()
 mat.albedo_color=Color(1.0,0.72,0.27,0.75)
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 ring.material_override=mat
 marker.add_child(ring)
 var label:=Label3D.new()
 label.text="OBJETIVO"
 label.font_size=36
 label.pixel_size=.012
 label.position.y=3.6
 label.modulate=Color(1.0,0.91,0.69)
 marker.add_child(label)
 marker.position=current_destination

func _set_objective() -> void:
 var row=STAGES[stage]
 objective_text=str(row[1])
 current_destination=row[2]
 if marker != null: marker.position=current_destination

func _advance() -> void:
 var prize=int(STAGES[stage][3])
 credits += prize
 completed += 1
 stage=(stage+1)%STAGES.size()
 _set_objective()
 _save()
 if game != null:
  game._message("MISSAO CONCLUIDA  +R$ %d  |  PROXIMO: %s" % [prize,objective_text])

func on_talk() -> void:
 if stage==3: _advance()

func on_enter_car() -> void:
 if stage==1: _advance()

func _process(delta: float) -> void:
 if game == null or game.player == null: return
 var actor: Node3D = game.player_car if game.player_car != null else game.player
 var dist = actor.global_position.distance_to(current_destination)
 if stage==0 and dist<16.0: _advance()
 elif stage==2 and dist<21.0 and game.player_car != null: _advance()
 elif stage==4 and dist<20.0: _advance()
 if marker != null:
  marker.position.y=current_destination.y + 1.1 + sin(Time.get_ticks_msec()*.002)*.21

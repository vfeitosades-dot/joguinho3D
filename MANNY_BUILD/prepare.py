import json, struct, hashlib, math, pathlib, urllib.request
import numpy as np
from scipy.spatial.transform import Rotation as R

project=pathlib.Path("GODOT_BASEPLATE")
source="https://huggingface.co/datasets/MazenVR/kimodo-rigs/resolve/main/ue5-manny.glb"
raw=urllib.request.urlopen(source,timeout=120).read()
assert hashlib.sha256(raw).hexdigest()=="530bff5ec089bf9ff4928aca9511251b92e285db39509c4fe06edd8483b1f9ec", "O GLB remoto difere do arquivo enviado pelo usuario."
magic,version,total=struct.unpack_from("<4sII",raw)
assert magic==b"glTF" and version==2 and total==len(raw)
js_len,js_type=struct.unpack_from("<II",raw,12)
j=json.loads(raw[20:20+js_len])
pos=20+js_len
blen,btype=struct.unpack_from("<II",raw,pos)
blob=bytearray(raw[pos+8:pos+8+blen])
assert js_type==0x4e4f534a and btype==0x004e4942
nodes=j["nodes"]
parent={c:i for i,n in enumerate(nodes) for c in n.get("children",[])}
def localrot(i):
    n=nodes[i]
    if "matrix" in n:
        a=np.array(n["matrix"]).reshape(4,4).T[:3,:3]
        return R.from_matrix(a/np.linalg.norm(a,axis=0))
    return R.from_quat(n.get("rotation",[0,0,0,1]))
def worldrot(i):
    return worldrot(parent[i])*localrot(i) if i in parent else localrot(i)
def delta(i,x=0,y=0,z=0):
    p=worldrot(parent[i]) if i in parent else R.identity()
    return (p.inv()*R.from_euler("xyz",[x,y,z],degrees=True)*p*localrot(i)).as_quat()
def accessor(a,kind):
    a=np.asarray(a,dtype="<f4")
    blob.extend(b"\0"*((-len(blob))%4))
    off=len(blob); payload=a.tobytes(); blob.extend(payload)
    v=len(j["bufferViews"])
    j["bufferViews"].append({"buffer":0,"byteOffset":off,"byteLength":len(payload)})
    idx=len(j["accessors"])
    d={"bufferView":v,"componentType":5126,"count":len(a),"type":kind}
    if kind=="SCALAR": d.update(min=[float(a.min())],max=[float(a.max())])
    j["accessors"].append(d)
    return idx
ids=[8,10,12,16,18,19,45,46,79,80,81,71,72,73]
def pose(name,t):
    p=2*math.pi*t; s=math.sin(p)
    v={i:(0,0,0) for i in ids}; bob=0
    v[18]=(0,0,-28); v[45]=(0,0,28); v[19]=(15,0,0); v[46]=(15,0,0)
    if name=="Idle":
        bob=.006*s; v[12]=(1.4*s,0,0); v[18]=(1.8*s,0,-28); v[45]=(-1.8*s,0,28); v[16]=(0,2*s,0)
    elif name in ("Walk","Run"):
        run=name=="Run"; A=40 if run else 25; B=35 if run else 22
        bob=(.018 if run else .012)*(math.cos(2*p)-1)
        v[8]=(-8 if run else -2,0,0); v[10]=(0,4*s,0); v[12]=(-2,-7*s,0); v[16]=(4 if run else 1,2*s,0)
        for side,thigh,calf,foot,arm,elbow in [(1,79,80,81,18,19),(-1,71,72,73,45,46)]:
            phase=s*side; swing=max(0,phase); knee=(55 if run else 38)*swing**1.3+7
            v[thigh]=(-A*phase,0,0); v[calf]=(knee,0,0); v[foot]=(-.65*knee+A*phase*.42,0,0)
            v[arm]=(B*phase,0,-28*side); v[elbow]=(-25 if run else 9,0,0)
    elif name in ("Jump","Fall"):
        k=math.sin(math.pi*min(1,max(0,t))) if name=="Jump" else .4
        v[8]=(-4,0,0); v[10]=(-5,0,0); v[18]=(-26-12*k,0,-14); v[45]=(-15-10*k,0,14)
        v[19]=(-15,0,0); v[46]=(-15,0,0)
        v[79]=(-25-19*k,0,0); v[80]=(33+14*k,0,0); v[81]=(-12,0,0)
        v[71]=(-10-12*k,0,0); v[72]=(45+8*k,0,0); v[73]=(-18,0,0)
    return v,bob
for name,duration in [("Idle",2.4),("Walk",.77),("Run",.59),("Jump",.34),("Fall",.6)]:
    times=np.linspace(0,duration,25); inp=accessor(times,"SCALAR")
    samples=[pose(name,float(t/duration)) for t in times]
    samplers=[]; channels=[]
    for i in ids:
        q=np.stack([delta(i,*v[i]) for v,_ in samples])
        for k in range(1,len(q)):
            if np.dot(q[k-1],q[k])<0: q[k]*=-1
        out=accessor(q,"VEC4")
        channels.append({"sampler":len(samplers),"target":{"node":i,"path":"rotation"}})
        samplers.append({"input":inp,"output":out,"interpolation":"LINEAR"})
    tr=np.stack([np.array(nodes[8]["translation"])+np.array([0,bob,0]) for _,bob in samples])
    out=accessor(tr,"VEC3")
    channels.append({"sampler":len(samplers),"target":{"node":8,"path":"translation"}})
    samplers.append({"input":inp,"output":out,"interpolation":"LINEAR"})
    j.setdefault("animations",[]).append({"name":name,"channels":channels,"samplers":samplers})
j["buffers"][0]["byteLength"]=len(blob)
js=json.dumps(j,separators=(",",":"),ensure_ascii=False).encode()
js+=b" "*((-len(js))%4); blob.extend(b"\0"*((-len(blob))%4))
out=struct.pack("<4sII",b"glTF",2,12+8+len(js)+8+len(blob))+struct.pack("<II",len(js),0x4e4f534a)+js+struct.pack("<II",len(blob),0x004e4942)+blob
asset=project/"assets/manny"
asset.mkdir(parents=True,exist_ok=True)
(asset/"Manny_motion.glbdata").write_bytes(out)
player=project/"scripts/player.gd"
old=player.read_text()
controls=old[old.index("func _setup_controls()"):old.index("func _create_humanoid()")]
physics=old[old.index("func _physics_process"):old.index("\tvar moving: bool")]
tail=old[old.index("# O projeto C++ original"):]
new='''extends CharacterBody3D

const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 7.5
const JUMP_VELOCITY: float = 7.4
const GRAVITY: float = 22.0
const MODEL_PATH: String = "res://assets/manny/Manny_motion.glbdata"

var _body_visual: Node3D
var _anim: AnimationPlayer
var _clips: Dictionary = {}
var _state: String = ""

func _ready() -> void:
	_setup_controls()
	floor_snap_length = 0.32
	_create_collision()
	_create_humanoid()

'''+controls+'''func _create_humanoid() -> void:
	_body_visual = Node3D.new()
	_body_visual.name = "Modelo_Manny"
	add_child(_body_visual)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(MODEL_PATH)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: Error = doc.append_from_buffer(bytes, "", state)
	if err != OK:
		push_error("Falha ao carregar Manny: " + str(err))
		return
	var model: Node = doc.generate_scene(state)
	if not model is Node3D:
		push_error("Manny sem cena 3D.")
		return
	var pivot := Node3D.new()
	pivot.name = "AjusteModelo"
	_body_visual.add_child(pivot)
	pivot.scale = Vector3.ONE * 0.7278
	pivot.rotation.y = PI
	pivot.add_child(model)
	_anim = _find_animation_player(model)
	if _anim == null:
		push_error("Manny sem AnimationPlayer.")
		return
	for clip: StringName in _anim.get_animation_list():
		var lower: String = String(clip).to_lower()
		for key: String in ["idle", "walk", "run", "jump", "fall"]:
			if lower == key or lower.ends_with("/" + key):
				_clips[key] = clip
				var anim: Animation = _anim.get_animation(clip)
				anim.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "walk", "run", "fall"] else Animation.LOOP_NONE
	_play("idle")
	if _clips.size() == 5:
		print("MANNY_READY: 5 clips")
	else:
		push_error("Manny: faltam clipes: " + str(_clips))

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _play(state: String) -> void:
	if _anim == null or _state == state or not _clips.has(state):
		return
	_state = state
	var clip: StringName = _clips[state]
	_anim.play(clip, 0.12)

'''+physics+'''	var moving: bool = move_direction.length_squared() > 0.01
	if not is_on_floor():
		_play("jump" if velocity.y > 0.0 else "fall")
	elif moving:
		_play("run" if speed == RUN_SPEED else "walk")
	else:
		_play("idle")

'''+tail
player.write_text(new)
preset=project/"export_presets.cfg"
preset.write_text(preset.read_text().replace('include_filter=""','include_filter="*.glbdata, CREDITS.txt"').replace('script_export_mode=1','script_export_mode=0'))
credits="""Baseplate Godot - Manny
Modelo: UE5 Male Mannequin - Manny - Web Ready, SketchPunk.
Fonte: https://sketchfab.com/3d-models/ue5-male-mannequin-manny-web-ready-9fcaadd206f449c2ab446d84350df370
Distribuicao: https://huggingface.co/datasets/MazenVR/kimodo-rigs
Licenca indicada na fonte: CC BY 4.0 https://creativecommons.org/licenses/by/4.0/
Design Manny e Unreal Engine: Epic Games. A licenca indicada nao confirma direitos independentes sobre o design original.
Alteracoes: animacoes proprias Idle, Walk, Run, Jump, Fall e ajuste de escala/orientacao.
Godot 4.4.1: MIT https://godotengine.org/license/
"""
(project/"CREDITS.txt").write_text(credits)
print("Modelo verificado; animacoes:",[a["name"] for a in j["animations"]])

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
# Original gait design, using reference poses and analytic two-bone leg IK.
def local_matrix(i):
    n=nodes[i]
    if "matrix" in n: return np.array(n["matrix"]).reshape(4,4).T
    m=np.eye(4); m[:3,:3]=localrot(i).as_matrix()@np.diag(n.get("scale",[1,1,1]))
    m[:3,3]=n.get("translation",[0,0,0])
    return m
rest=[local_matrix(i) for i in range(len(nodes))]
def rest_world(i):
    return rest_world(parent[i])@rest[i] if i in parent else rest[i]
rw=[rest_world(i) for i in range(len(nodes))]
def rotation(m):
    a=m[:3,:3]
    return R.from_matrix(a/np.linalg.norm(a,axis=0))
def unit(a): return a/max(np.linalg.norm(a),1e-9)
def between(a,b):
    a,b=unit(a),unit(b); c=np.cross(a,b); d=np.clip(np.dot(a,b),-1,1)
    if np.linalg.norm(c)<1e-8:
        return R.identity() if d>0 else R.from_rotvec(unit(np.cross(a,[1,0,0] if abs(a[0])<.8 else [0,1,0]))*math.pi)
    return R.from_rotvec(unit(c)*math.atan2(np.linalg.norm(c),d))
def smooth(t):
    t=max(0,min(1,t)); return t*t*(3-2*t)
def ease(a,b,t): return a+(b-a)*smooth(t)
ids=[8,9,10,11,12,13,14,15,16,17,18,19,22,44,45,46,49,71,72,73,74,79,80,81,82]
scale=.7278
speeds={"Walk":1.55,"Run":3.4}
durations={"Idle":3.2,"Walk":1.0,"Run":.72,"Jump":.34,"Fall":.65,"Land":.25}
def step(name,t):
    run=name=="Run"; t=t%1; stance=.39 if run else .61
    d=speeds[name]*durations[name]/scale; front=d*stance/2
    if t<stance:
        u=t/stance; z=front-d*t
        pitch=ease(-10,0,u/.18) if u<.18 else ease(0,26 if run else 22,(u-.67)/.33)
        lift=max(0,math.sin(math.radians(pitch)))*.17
    else:
        u=(t-stance)/(1-stance)
        z=-front+2*front*smooth(u)-d*(1-stance)*u*(1-u)*(1-2*u)
        lift=(.36 if run else .17)*math.sin(math.pi*u)**1.55+.17*math.sin(math.radians(26 if run else 22))*(1-u)
        pitch=ease(26 if run else 22,-10,u)
    return z,lift,pitch
def pose(name,t):
    p=2*math.pi*t; wave=math.sin(p); cycle=math.cos(p)
    rot={i:(0.,0.,0.) for i in ids}
    rot[18]=(-3,0,-27); rot[45]=(-3,0,27)
    rot[19]=(-10,0,0); rot[46]=(-10,0,0)
    rot[22]=(2,0,-3); rot[49]=(2,0,3)
    off=np.array([0.,-.065,0.]); targets=[]
    if name in speeds:
        run=name=="Run"
        off=np.array([.038*wave,-(.21 if run else .15)+(.055 if run else .027)*(-math.cos(2*p)),0])
        rot[8]=(4 if run else 1,5*cycle,-2.6*wave)
        for i in [9,10,11,12,13]: rot[i]=(2.2 if run else .45,-1.8*cycle,.55*wave)
        rot[14]=(-3 if run else -1,-cycle,0); rot[16]=(-4 if run else -1,0,-.5*wave)
        for side,cl,arm,elbow,hand,th,ca,ft,ball in [(1,17,18,19,22,79,80,81,82),(-1,44,45,46,49,71,72,73,74)]:
            u=(t+(0 if side==1 else .5))%1; swing=math.cos(2*math.pi*u-.16)
            rot[cl]=(1.5*swing,0,-1.5*side)
            rot[arm]=((29 if run else 17)*swing,2*side,-(25 if run else 29)*side)
            rot[elbow]=(-(52 if run else 15)+(10 if run else 5)*swing,0,0)
            rot[hand]=(4*swing,0,2*side)
            z,lift,pitch=step(name,u)
            target=rw[ft][:3,3].copy()+np.array([-.028*side,lift,z])
            targets.append((th,ca,ft,ball,target,pitch))
    elif name=="Idle":
        off=np.array([.025*wave,-.065+.009*cycle,0])
        rot[8]=(0,1.2*wave,-1.5*wave); rot[12]=(-1.2*cycle,-1.5*wave,.5*wave)
        rot[13]=(-.8*cycle,0,0); rot[16]=(1.3*wave,1.3*wave,0)
        for th,ca,ft,ball in [(79,80,81,82),(71,72,73,74)]:
            targets.append((th,ca,ft,ball,rw[ft][:3,3].copy(),0))
    elif name=="Land":
        k=math.sin(math.pi*t)**1.2; off=np.array([0,-.065-.24*k,0])
        rot[8]=(8*k,0,0); rot[10]=(7*k,0,0); rot[12]=(8*k,0,0); rot[16]=(-10*k,0,0)
        rot[18]=(-14*k,0,-22); rot[45]=(-14*k,0,22)
        rot[19]=(-18,0,0); rot[46]=(-18,0,0)
        for th,ca,ft,ball in [(79,80,81,82),(71,72,73,74)]:
            target=rw[ft][:3,3].copy(); target[2]+=.08*k
            targets.append((th,ca,ft,ball,target,0))
    else:
        k=smooth(t) if name=="Jump" else .72+.09*wave
        off=np.array([0,-.065-.045*k,0])
        rot[8]=(5+5*k,0,0); rot[10]=(-4*k,0,0); rot[12]=(-4*k,0,0)
        rot[18]=(-36-23*k,0,-20); rot[45]=(-28-18*k,0,20)
        rot[19]=(-32-18*k,0,0); rot[46]=(-32-18*k,0,0); rot[16]=(-4,0,0)
        for side,th,ca,ft,ball in [(1,79,80,81,82),(-1,71,72,73,74)]:
            target=rw[ft][:3,3].copy(); target[1]+=(.25 if side==1 else .19)*k+.08
            target[2]+=(.31 if side==1 else -.14)*k
            targets.append((th,ca,ft,ball,target,12 if name=="Jump" else 0))
    lr={i:R.from_quat(delta(i,*rot[i])) for i in ids}
    ht=np.array(nodes[8]["translation"])+np.linalg.solve(rw[parent[8]][:3,:3],off)
    def world(i):
        m=rest[i].copy()
        if i in lr: m[:3,:3]=lr[i].as_matrix()@np.diag(nodes[i].get("scale",[1,1,1]))
        if i==8: m[:3,3]=ht
        return world(parent[i])@m if i in parent else m
    def aim(i,child,target):
        current=world(i); direction=world(child)[:3,3]-current[:3,3]
        desired=between(direction,target-current[:3,3])*rotation(current)
        lr[i]=rotation(world(parent[i])).inv()*desired
    for th,ca,ft,ball,target,pitch in targets:
        h=world(th)[:3,3]
        l1=np.linalg.norm(rw[ca][:3,3]-rw[th][:3,3]); l2=np.linalg.norm(rw[ft][:3,3]-rw[ca][:3,3])
        v=target-h; length=min(l1+l2-.004,max(abs(l1-l2)+.004,np.linalg.norm(v)))
        axis=unit(v); target=h+axis*length
        pole=np.array([0.,0.,1.]); pole=unit(pole-axis*np.dot(pole,axis))
        a=(l1*l1-l2*l2+length*length)/(2*length)
        knee=h+axis*a+pole*math.sqrt(max(0,l1*l1-a*a))
        aim(th,ca,knee); aim(ca,ft,target)
        want=R.from_euler("x",pitch,degrees=True)*rotation(rw[ft])
        lr[ft]=rotation(world(parent[ft])).inv()*want
        lr[ball]=R.from_quat(delta(ball,-max(0,pitch)*.5,0,0))
    return {i:lr[i].as_quat() for i in ids},ht
for name,duration in durations.items():
    times=np.linspace(0,duration,max(25,round(duration*60)+1)); inp=accessor(times,"SCALAR")
    samples=[pose(name,float(t/duration)) for t in times]
    if name in ("Idle","Walk","Run","Fall"): samples[-1]=samples[0]
    samplers=[]; channels=[]
    for i in ids:
        q=np.stack([v[i] for v,_ in samples])
        for k in range(1,len(q)):
            if np.dot(q[k-1],q[k])<0: q[k]*=-1
        out=accessor(q,"VEC4")
        channels.append({"sampler":len(samplers),"target":{"node":i,"path":"rotation"}})
        samplers.append({"input":inp,"output":out,"interpolation":"LINEAR"})
    out=accessor(np.stack([ht for _,ht in samples]),"VEC3")
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
physics=physics.replace("\tif not is_on_floor():","\tvar was_grounded: bool = is_on_floor()\n\tif not is_on_floor():",1).replace("\tvelocity.x = move_direction.x * speed\n\tvelocity.z = move_direction.z * speed","\tvar accel: float = 12.0 if move_direction.length_squared() > 0.01 else 16.0\n\tvelocity.x = move_toward(velocity.x, move_direction.x * speed, accel * delta)\n\tvelocity.z = move_toward(velocity.z, move_direction.z * speed, accel * delta)")
tail=old[old.index("# O projeto C++ original"):]
new='''extends CharacterBody3D

const WALK_SPEED: float = 1.55
const RUN_SPEED: float = 3.4
const JUMP_VELOCITY: float = 7.4
const GRAVITY: float = 22.0
const MODEL_PATH: String = "res://assets/manny/Manny_motion.glbdata"

var _body_visual: Node3D
var _anim: AnimationPlayer
var _clips: Dictionary = {}
var _state: String = ""
var _land_time: float = 0.0

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
		for key: String in ["idle", "walk", "run", "jump", "fall", "land"]:
			if lower == key or lower.ends_with("/" + key):
				_clips[key] = clip
				var anim: Animation = _anim.get_animation(clip)
				anim.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "walk", "run", "fall"] else Animation.LOOP_NONE
	_play("idle")
	if _clips.size() == 6:
		print("MANNY_READY: 6 clips")
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

'''+physics+'''	var actual_speed: float = Vector2(velocity.x, velocity.z).length()
	if not was_grounded and is_on_floor():
		_land_time = 0.25
	_land_time = maxf(0.0, _land_time - delta)
	if not is_on_floor():
		_land_time = 0.0
		_play("jump" if velocity.y > 0.0 else "fall")
	elif _land_time > 0.0:
		_play("land")
	elif actual_speed > 0.12:
		var running: bool = actual_speed > 2.05
		_play("run" if running else "walk")
		if _anim != null:
			_anim.speed_scale = clampf(actual_speed / (RUN_SPEED if running else WALK_SPEED), 0.35, 1.35)
	else:
		_play("idle")
	if _anim != null and _state in ["idle", "jump", "fall", "land"]:
		_anim.speed_scale = 1.0

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
Alteracoes: seis animacoes proprias, trajetorias de pes e IK analitica. Referencias visuais: https://caveacademy.com/wiki/post-production-shots/animation/animation-training/introduction-to-animation-course/animating-a-walk-cycle/ ; https://www.animatornotebook.com/learn/walking-part-1 ; https://mocap.cs.cmu.edu/ (sem dados incorporados).
Godot 4.4.1: MIT https://godotengine.org/license/
"""
(project/"CREDITS.txt").write_text(credits)
print("Modelo verificado; animacoes:",[a["name"] for a in j["animations"]])

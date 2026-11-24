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
# Retarget original Quaternius CC0 animation curves to the uploaded Manny.
from scipy.spatial.transform import Slerp
import os, re
url="https://github.com/WaviestSun/atelier-packs/releases/download/characters-1/UAL1_Standard.glb"
pack=pathlib.Path(os.environ["UAL_GLB"]).read_bytes() if "UAL_GLB" in os.environ else urllib.request.urlopen(url,timeout=120).read()
assert hashlib.sha256(pack).hexdigest()=="69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997", "UAL differs from the uploaded ZIP"
n=struct.unpack_from("<I",pack,12)[0]
sj=json.loads(pack[20:20+n]); sb=pack[28+n:]
sn=sj["nodes"]; sp={c:i for i,x in enumerate(sn) for c in x.get("children",[])}
def matrix(x):
    if "matrix" in x: return np.array(x["matrix"]).reshape(4,4).T
    m=np.eye(4); m[:3,:3]=R.from_quat(x.get("rotation",[0,0,0,1])).as_matrix()@np.diag(x.get("scale",[1,1,1]))
    m[:3,3]=x.get("translation",[0,0,0]); return m
def worlds(local,parents):
    out={}
    def calc(i):
        if i not in out: out[i]=calc(parents[i])@local[i] if i in parents else local[i]
        return out[i]
    return [calc(i) for i in range(len(local))]
def rot(m):
    a=m[:3,:3]; return R.from_matrix(a/np.linalg.norm(a,axis=0))
def unit(a): return a/max(np.linalg.norm(a),1e-9)
def between(a,b):
    a,b=unit(a),unit(b); cross=np.cross(a,b); d=np.clip(np.dot(a,b),-1,1)
    if np.linalg.norm(cross)<1e-8:
        return R.identity() if d>0 else R.from_rotvec(unit(np.cross(a,[1,0,0] if abs(a[0])<.8 else [0,1,0]))*math.pi)
    return R.from_rotvec(unit(cross)*math.atan2(np.linalg.norm(cross),d))
sr=[matrix(x) for x in sn]; tr=[matrix(x) for x in nodes]
sw=worlds(sr,sp); tw=worlds(tr,parent)
S={x["name"].lower():i for i,x in enumerate(sn)}
T={re.sub(r"_\d+$","",x["name"].lower()):i for i,x in enumerate(nodes)}
# Keep the five-segment Manny spine, distributing source motion over its chain.
pairs={"pelvis":"pelvis","spine_01":"spine_01","spine_03":"spine_02","spine_05":"spine_03","neck_01":"neck_01","head":"head"}
for side in ("l","r"):
    for name in ("clavicle","upperarm","lowerarm","hand","thigh","calf","foot","ball"):
        pairs[name+"_"+side]=name+"_"+side
    for finger in ("index","middle","ring","pinky","thumb"):
        for k in range(1,4):
            name=f"{finger}_{k:02d}_{side}"
            if name in T and name in S: pairs[name]=name
mapping={T[t]:S[q] for t,q in pairs.items()}
# Align anatomical axes in the reference T pose (source) vs Manny A pose (target).
children={}
for side in ("l","r"):
    for a,b in [("clavicle","upperarm"),("upperarm","lowerarm"),("lowerarm","hand"),("thigh","calf"),("calf","foot"),("foot","ball")]:
        children[a+"_"+side]=(b+"_"+side,b+"_"+side)
    children["hand_"+side]=("middle_01_"+side,"middle_01_"+side)
    for finger in ("index","middle","ring","pinky","thumb"):
        for k in range(1,3):
            a=f"{finger}_{k:02d}_{side}"; b=f"{finger}_{k+1:02d}_{side}"
            children[a]=(b,b)
cal={}
for name,src in pairs.items():
    ti,si=T[name],S[src]; ref=rot(tw[ti])
    if name in children:
        a,b=children[name]
        if a in T and b in S:
            ref=between(tw[T[a]][:3,3]-tw[ti][:3,3],sw[S[b]][:3,3]-sw[si][:3,3])*ref
    cal[ti]=rot(sw[si]).inv()*ref
# For terminal fingers and toes use the preceding bone's anatomical correction.
for name,src in pairs.items():
    ti,si=T[name],S[src]
    if name.startswith(("index_03","middle_03","ring_03","pinky_03","thumb_03","ball_")):
        p=parent[ti]
        if p in cal:
            correction=rot(sw[mapping[p]])*cal[p]*rot(tw[p]).inv()
            cal[ti]=rot(sw[si]).inv()*correction*rot(tw[ti])
def readacc(i):
    a=sj["accessors"][i]; v=sj["bufferViews"][a["bufferView"]]
    width={"SCALAR":1,"VEC3":3,"VEC4":4}[a["type"]]
    return np.ndarray((a["count"],width),dtype="<f4",buffer=sb,offset=v.get("byteOffset",0)+a.get("byteOffset",0),strides=(v.get("byteStride",4*width),4)).copy()
def sample_channel(a,c,times):
    sampler=a["samplers"][c["sampler"]]; ts=readacc(sampler["input"]).ravel(); vals=readacc(sampler["output"])
    if len(ts)==1: return np.repeat(vals,len(times),axis=0)
    tt=np.clip(times,ts[0],ts[-1])
    if c["target"]["path"]=="rotation": return Slerp(ts,R.from_quat(vals))(tt).as_quat()
    return np.stack([np.interp(tt,ts,vals[:,k]) for k in range(vals.shape[1])],axis=1)
hip=T["pelvis"]; sh=S["pelvis"]
ratio=tw[hip][1,3]/sw[sh][1,3]
clips={"Idle":"Idle_Loop","Walk":"Walk_Loop","Run":"Jog_Fwd_Loop","Jump":"Jump_Start","Fall":"Jump_Loop","Land":"Jump_Land","Enter":"Sitting_Enter","Drive":"Driving_Loop","Exit":"Sitting_Exit"}
library={a["name"]:a for a in sj["animations"]}
ids=sorted(mapping)
for name,original in clips.items():
    a=library[original]
    dur=max(float(readacc(k["input"])[-1,0]) for k in a["samplers"])
    # The jump-start clip has a long airborne tail; keep the actual launch.
    used=min(dur,.40) if name=="Jump" else dur
    times=np.linspace(0,used,max(2,round(used*30)+1))
    if name=="Land": output_times=times*(.52/used)
    elif name=="Jump": output_times=times*(.33/used)
    else: output_times=times
    channels_src={}
    for c in a["channels"]:
        path=c["target"]["path"]
        if path in ("rotation","translation"): channels_src[c["target"]["node"],path]=sample_channel(a,c,times)
    frames={i:[] for i in ids}; hips=[]
    for k in range(len(times)):
        sl=[x.copy() for x in sr]
        for (i,path),values in channels_src.items():
            if path=="rotation": sl[i][:3,:3]=R.from_quat(values[k]).as_matrix()@np.diag(sn[i].get("scale",[1,1,1]))
            else: sl[i][:3,3]=values[k]
        spose=worlds(sl,sp)
        # Transfer pelvis bob and sway, keeping the controller in charge of root motion.
        offset=(spose[sh][:3,3]-sw[sh][:3,3])*ratio
        ht=tr[hip][:3,3]+np.linalg.solve(tw[parent[hip]][:3,:3],offset)
        world={}
        def solve(i):
            if i in world: return world[i]
            pm=solve(parent[i]) if i in parent else np.eye(4)
            m=tr[i].copy()
            if i in mapping:
                desired=rot(spose[mapping[i]])*cal[i]
                local=rot(pm).inv()*desired
                m[:3,:3]=local.as_matrix()@np.diag(nodes[i].get("scale",[1,1,1]))
                frames[i].append(local.as_quat())
            if i==hip: m[:3,3]=ht
            world[i]=pm@m; return world[i]
        for i in ids: solve(i)
        # Reduce stance height differences caused by slightly different limb lengths.
        if name in ("Idle","Walk","Run","Land"):
            ta=min(solve(T["ball_"+side])[1,3] for side in ("l","r"))
            sa=min(spose[S["ball_"+side]][1,3] for side in ("l","r"))
            correction=float(np.clip(sa*ratio-ta,-.12,.12))
            ht=ht+np.linalg.solve(tw[parent[hip]][:3,:3],[0,correction,0])
        hips.append(ht)
    inp=accessor(output_times,"SCALAR"); samplers=[]; channels=[]
    def track(i,path,values,kind):
        out=accessor(values,kind)
        channels.append({"sampler":len(samplers),"target":{"node":i,"path":path}})
        samplers.append({"input":inp,"output":out,"interpolation":"LINEAR"})
    for i in ids:
        q=np.array(frames[i])
        if name in ("Idle","Walk","Run","Fall","Drive"): q[-1]=q[0]
        for k in range(1,len(q)):
            if np.dot(q[k-1],q[k])<0:q[k]*=-1
        assert np.isfinite(q).all() and len(q)==len(times)
        track(i,"rotation",q,"VEC4")
    if name in ("Idle","Walk","Run","Fall","Drive"): hips[-1]=hips[0]
    track(hip,"translation",np.array(hips),"VEC3")
    j.setdefault("animations",[]).append({"name":name,"channels":channels,"samplers":samplers})
    print("UAL retarget:",original,"->",name,"bones",len(ids),"frames",len(times))
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
const RUN_SPEED: float = 4.25
const JUMP_VELOCITY: float = 7.4
const GRAVITY: float = 22.0
const MODEL_PATH: String = "res://assets/manny/Manny_motion.glbdata"

var _body_visual: Node3D
var _anim: AnimationPlayer
var _clips: Dictionary = {}
var _state: String = ""
var _land_time: float = 0.0
var wall_touch: Node
var motion_speeds: Dictionary = {}
var start_remaining: float = 0.0
var jump_clip: String = ""


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
	pivot.scale = Vector3.ONE * 0.6600
	pivot.rotation.y = PI
	pivot.add_child(model)
	wall_touch = preload("res://scripts/wall_touch.gd").new()
	add_child(wall_touch)
	wall_touch.call("setup", self, _body_visual, model)
	_anim = _find_animation_player(model)
	if _anim == null:
		push_error("Manny sem AnimationPlayer.")
		return
	for clip: StringName in _anim.get_animation_list():
		var lower: String = String(clip).to_lower()
		for key: String in ["idle", "walk", "run", "jump", "fall", "land", "enter", "drive", "exit"]:
			if lower == key or lower.ends_with("/" + key):
				_clips[key] = clip
				var anim: Animation = _anim.get_animation(clip)
				anim.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "walk", "run", "fall", "drive"] else Animation.LOOP_NONE
	if _clips.size() == 9:
		print("MANNY_READY: 9 clips")
	else:
		push_error("Manny: faltam clipes: " + str(_clips))
	var skeleton := wall_touch.get("skeleton") as Skeleton3D
	if skeleton != null:
		motion_speeds = preload("res://scripts/motion_loader.gd").load_pack(_anim, skeleton, _clips)
	_play("idle")

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
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.12 if state.begins_with("jump") else 0.20)
	if state in ["enter", "drive", "exit"] and wall_touch != null:
		wall_touch.call("release_now")

'''+physics+'''	if wall_touch != null:
		wall_touch.call("update_contact", delta, move_direction)
	var actual_speed: float = Vector2(velocity.x, velocity.z).length()
	if not was_grounded and is_on_floor():
		_land_time = 0.52
	_land_time = maxf(0.0, _land_time - delta)
	if not is_on_floor():
		_land_time = 0.0
		start_remaining = 0.0
		if motion_speeds.is_empty():
			_play("jump" if velocity.y > 0.0 else "fall")
		elif was_grounded and velocity.y > 0.0:
			jump_clip = "jump_forward" if actual_speed > 0.8 else "jump_up"
			_play(jump_clip)
		elif not _state.begins_with("jump") or (_anim != null and not _anim.is_playing()):
			_play("fall")
	elif _land_time > 0.0:
		jump_clip = ""
		_play("land")
	elif actual_speed > 0.12:
		if motion_speeds.is_empty():
			var running: bool = actual_speed > 2.05
			_play("run" if running else "walk")
			if _anim != null:
				_anim.speed_scale = clampf(actual_speed / (RUN_SPEED if running else WALK_SPEED), 0.35, 1.35)
		else:
			if _state == "idle" and actual_speed < 1.8 and not Input.is_action_pressed("sprint"):
				start_remaining = 0.65
				_play("start_walk")
			if start_remaining > 0.0 and actual_speed < 2.0:
				start_remaining -= delta
			else:
				start_remaining = 0.0
				var next: String = "sprint" if actual_speed > 3.05 else ("jog" if actual_speed > 1.8 else "walk")
				_play(next)
				if _anim != null:
					_anim.speed_scale = clampf(actual_speed / maxf(0.1, float(motion_speeds.get(next, 1.2))), 0.65, 1.45)
	else:
		start_remaining = 0.0
		_play("idle")
	if _anim != null and _state in ["idle", "jump", "jump_up", "jump_forward", "fall", "land", "start_walk"]:
		_anim.speed_scale = 1.0

'''+tail
new=new.replace("collider.position.y = 0.97","collider.position.y = 0.86").replace("capsule.height = 1.9","capsule.height = 1.72").replace("capsule.radius = 0.32","capsule.radius = 0.30")
new=new.replace("get_tree().quit()","pass")
player.write_text(new)
preset=project/"export_presets.cfg"
preset.write_text(preset.read_text().replace('include_filter=""','include_filter="*.glbdata, CREDITS.txt"').replace('script_export_mode=1','script_export_mode=0'))
credits="""Baseplate Godot - Manny
Modelo: UE5 Male Mannequin - Manny - Web Ready, SketchPunk.
Fonte: https://sketchfab.com/3d-models/ue5-male-mannequin-manny-web-ready-9fcaadd206f449c2ab446d84350df370
Distribuicao: https://huggingface.co/datasets/MazenVR/kimodo-rigs
Licenca indicada na fonte: CC BY 4.0 https://creativecommons.org/licenses/by/4.0/
Design Manny e Unreal Engine: Epic Games. A licenca indicada nao confirma direitos independentes sobre o design original.
Animacoes: Universal Animation Library Standard, Quaternius (CC0 1.0). https://quaternius.itch.io/universal-animation-library ; https://creativecommons.org/publicdomain/zero/1.0/ ; Retarget dos seis clipes para Manny. Sem root motion.
Godot 4.4.1: MIT https://godotengine.org/license/
"""
(project/"CREDITS.txt").write_text(credits)
print("Modelo verificado; animacoes:",[a["name"] for a in j["animations"]])

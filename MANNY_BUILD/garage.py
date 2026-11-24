import pathlib, json, hashlib, urllib.request, shutil, wave, math
import numpy as np
from PIL import Image
import io, struct
from doors import split_door
from damage_shapes import add_damage_shapes
project=pathlib.Path("GODOT_BASEPLATE")
base=pathlib.Path("MANNY_BUILD")
assets=project/"assets/garage"
assets.mkdir(parents=True,exist_ok=True)
data=[
("sport-sedan","Sport Sedan","f17f4ab1b646743e5593266262b447744ea82aaf096d8a24863b1010bab6d7bf",2.10,4.81,1.45,.345,27,5.8,.36,.05,-.20),
("grand-tourer","Grand Tourer","7998bce260ca45c5f0a5a9eea5ceb06c76c0f61399e1e2394c4dcaca0383c9c4",2.08,4.78,1.33,.355,30,6.0,.36,.00,-.28),
("muscle-coupe","Muscle Coupe","f3fc9864f2850c3cd62e9655f8529ce2a0641f1b863b9a9c1196dc4a9c9fc890",2.11,4.87,1.37,.35,28,5.5,.37,.01,-.32),
("hot-hatchback","Hot Hatchback","fab901c9018e8c95d7157cb88427a458e865028d5547f00065310147cc5366ab",2.10,4.22,1.50,.325,23,5.1,.36,.10,-.20),
("luxury-limousine","Luxury Limousine","24e1f842ff96a02e149367f7cc8776ef4d7e05d20f7ec94f6845887077effaab",2.30,5.49,1.64,.39,24,4.2,.40,.20,.13),
("luxury-suv","Luxury SUV","40990c9f7c06e5407d8f52186ec2a393322e339acfaf88cd8a50e382daa5f8b8",2.35,4.96,1.85,.39,22,4.7,.41,.27,-.11),
("electric-fastback","Electric Fastback","d7dae8863d0b6fc4fd42a6201b19f86cb67f3e3497fbe385d602396941939929",2.10,4.60,1.40,.345,28,7.0,.37,.04,-.08)]
def compact_glb(raw,name,length):
    n=struct.unpack_from("<I",raw,12)[0]
    j=json.loads(raw[20:20+n])
    payload=bytearray(raw[28+n:])
    split_door(j,payload,name)
    add_damage_shapes(j,payload,length)
    # Preserve geometry, materials, nodes, UVs and original image indices.
    for img in j.get("images",[]):
        if "bufferView" not in img: continue
        view=j["bufferViews"][img["bufferView"]]
        offset=view.get("byteOffset",0)
        image=Image.open(io.BytesIO(payload[offset:offset+view["byteLength"]]))
        if max(image.size)<=512: continue
        image.thumbnail((512,512),Image.Resampling.LANCZOS)
        out=io.BytesIO()
        image.save(out,format="PNG")
        while len(payload)%4: payload.append(0)
        view["byteOffset"]=len(payload)
        view["byteLength"]=len(out.getvalue())
        payload.extend(out.getvalue())
        img["mimeType"]="image/png"
    while len(payload)%4: payload.append(0)
    j["buffers"][0]["byteLength"]=len(payload)
    # Older graphics drivers can be sensitive to large normal-map shader variants.
    # Retain the PBR base colors, roughness and metallic textures.
    for m in j.get("materials",[]):
        m.pop("normalTexture",None)
        m.pop("occlusionTexture",None)
        if m.get("name","").startswith("Paint"):
            surface=m.setdefault("pbrMetallicRoughness",{})
            surface["roughnessFactor"]=min(float(surface.get("roughnessFactor",1.0)),.20)
            surface["metallicFactor"]=max(.32,float(surface.get("metallicFactor",0.0)))
            # Avoid requiring an additional clearcoat shader on integrated graphics.

    encoded=json.dumps(j,separators=(",",":")).encode()
    encoded+=b" "*((-len(encoded))%4)
    return struct.pack("<4sII",b"glTF",2,12+8+len(encoded)+8+len(payload))+struct.pack("<I4s",len(encoded),b"JSON")+encoded+struct.pack("<I4s",len(payload),b"BIN\x00")+payload

fitting={
"sport-sedan":(.615,-.25,.35,.76,.180),
"grand-tourer":(.545,-.29,.30,.72,.178),
"muscle-coupe":(.570,-.29,.30,.72,.184),
"hot-hatchback":(.615,-.17,.32,.74,.180),
"electric-fastback":(.635,-.16,.35,.82,.178),
"luxury-suv":(.875,-.13,.53,.84,.190),
"luxury-limousine":(.690,.12,.36,1.15,.200)}
handle_fitting={
"sport-sedan":(.86,-.10,1490),
"grand-tourer":(.79,-.60,1720),
"muscle-coupe":(.80,-.60,1770),
"hot-hatchback":(.87,-.12,1330),
"electric-fastback":(.88,-.10,1880),
"luxury-suv":(1.04,-.12,2320),
"luxury-limousine":(.98,.10,2180)}
catalog=[]
for name,title,sha,w,l,h,r,top,accel,sx,sy,sz in data:
    url="https://models.vinish.dev/realistic-cars/"+name+".glb"
    req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0"})
    raw=urllib.request.urlopen(req,timeout=120).read()
    assert hashlib.sha256(raw).hexdigest()==sha, "Asset differs from uploaded model: "+name
    (assets/(name+".glbdata")).write_bytes(compact_glb(raw,name,l))
    hy,hz,py,pz,gr=fitting[name]
    handle_y,handle_z,mass=handle_fitting[name]
    catalog.append(dict(file=name,title=title,width=w,length=l,height=h,radius=r,top=top,accel=accel,seat_x=sx,seat_y=sy,seat_z=sz,hip_y=hy,hip_z=hz,pedal_y=py,pedal_z=pz,grip_radius=gr,handle_y=handle_y,handle_z=handle_z,mass=mass))
    print("VERIFIED",name,len(raw))
(assets/"catalog.json").write_text(json.dumps(catalog))
rng=np.random.default_rng(4242)
grain=rng.integers(155,222,(128,128),dtype=np.uint8)
Image.fromarray(grain).convert("RGB").save(assets/"asphalt.png")
# Small procedurally painted alpha textures, no volumetric clouds or screen-space ray tracing.
from PIL import ImageFilter
yy,xx=np.mgrid[0:128,0:256]
field=np.zeros((128,256),np.float32)
for cx,cy,rx,ry in [(52,74,48,28),(91,56,56,40),(132,51,49,44),(175,64,51,30),(209,76,38,23),(139,83,82,26)]:
    field=np.maximum(field,np.exp(-2.1*((xx-cx)/rx)**2-2.1*((yy-cy)/ry)**2))
noise=np.zeros_like(field)
for dim,weight in [(8,.14),(20,.07),(48,.035)]:
    im=Image.fromarray(rng.integers(0,255,(dim,dim*2),dtype=np.uint8)).resize((256,128),Image.Resampling.BICUBIC)
    noise+=(np.asarray(im,dtype=np.float32)/255-.5)*weight
alpha=np.clip((field+noise-.14)*1.55,0,1)
shade=np.clip(1-(yy/128)*.18,0,1)
rgba=np.zeros((128,256,4),dtype=np.uint8)
for i,k in enumerate([1,.99,.98]):rgba[:,:,i]=np.uint8(shade*255*k)
rgba[:,:,3]=np.uint8(alpha*255)
Image.fromarray(rgba,"RGBA").save(assets/"cloud.png")
yy,xx=np.mgrid[-1:1:256j,-1:1:256j]
rr=np.sqrt(xx*xx+yy*yy); ang=np.arctan2(yy,xx)
halo=np.exp(-rr*rr*9)*.35+np.exp(-rr*rr*85)*.65
rays=(np.maximum(np.cos(ang*6+.5),0)**22)*np.exp(-rr*4)*.18
alpha=np.clip((halo+rays)*np.clip((1-rr)*4,0,1),0,1)
rgba=np.zeros((256,256,4),dtype=np.uint8);rgba[:,:,:3]=[255,244,214];rgba[:,:,3]=np.uint8(alpha*255)
Image.fromarray(rgba,"RGBA").save(assets/"sun_glow.png")
# Original looped synthetic engine audio; no external audio license required.
rate=22050
t=np.arange(rate*2)/rate
signal=sum(np.sin(2*np.pi*f*t)*a for f,a in [(40,.23),(80,.18),(120,.08),(160,.05),(240,.025)])
with wave.open(str(assets/"engine.wav"),"wb") as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes((signal*24000).astype("<i2").tobytes())
# Original, short, low-volume chassis impact sound.
impact_t=np.arange(int(rate*.32))/rate
impact=(.36*np.sin(2*np.pi*(82*impact_t-70*impact_t**2))+.09*rng.standard_normal(len(impact_t)))*np.exp(-impact_t*19)
with wave.open(str(assets/"impact.wav"),"wb") as out:
    out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(np.clip(impact*28000,-32767,32767).astype("<i2").tobytes())
preset=project/"export_presets.cfg"
preset.write_text(preset.read_text().replace("*.glbdata, CREDITS.txt","*.glbdata, *.json, CREDITS.txt"))
for src,dest in [("garage.gd","main.gd"),("vehicle.gd","vehicle.gd"),("wall_touch.gd","wall_touch.gd"),("dashboard.gd","dashboard.gd"),("motion_loader.gd","motion_loader.gd"),("sky_fx.gd","sky_fx.gd")]:
    shutil.copyfile(base/src,project/"scripts"/dest)
settings=project/"project.godot"
s=settings.read_text().replace('viewport_width=1280','viewport_width=1280').replace('viewport_height=720','viewport_height=720').replace('window/stretch/mode="canvas_items"','window/stretch/mode="viewport"')
s=s.replace("config/name=\"Baseplate 3D\"","config/name=\"Motor Lab\"")
s=s.replace("[application]","[application]\n\nconfig/description=\"Motor Lab - Compatibility\"")
s=s.replace('[physics]','[physics]\ncommon/physics_interpolation=true\ncommon/physics_ticks_per_second=60')
settings.write_text(s)
preset.write_text(preset.read_text().replace("debug/export_console_wrapper=1","debug/export_console_wrapper=0").replace("texture_format/bptc=true","texture_format/bptc=false").replace("binary_format/embed_pck=true","binary_format/embed_pck=true\napplication/modify_resources=false"))
credits=project/"CREDITS.txt"
with credits.open("a") as f:
    f.write("\nMotor Lab cars: vinish.dev (https://vinish.dev/free-3d-models/realistic-cars), CC BY 4.0.\n")
    for item in catalog: f.write(item["title"]+" by vinish.dev; GLB adapted: textures capped at 512px, simplified material maps, polished paint, front/rear localized deformation shapes, approximate extracted driver door, wheel and steering motion.\n")
    f.write("https://creativecommons.org/licenses/by/4.0/\nOriginal synthetic engine loop.\n")

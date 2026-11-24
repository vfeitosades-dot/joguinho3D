import numpy as np

def add_damage_shapes(j, payload, length):
    mesh=j["meshes"][0]
    def positions(primitive):
        a=j["accessors"][primitive["attributes"]["POSITION"]]
        v=j["bufferViews"][a["bufferView"]]
        return np.ndarray((a["count"],3),dtype="<f4",buffer=payload,offset=v.get("byteOffset",0)+a.get("byteOffset",0),strides=(v.get("byteStride",12),4)).copy()
    exterior=[positions(p) for p in mesh["primitives"] if j["materials"][p["material"]]["name"].startswith("Paint")]
    pts=np.concatenate(exterior,axis=0)
    front=float(pts[:,2].max()); rear=float(pts[:,2].min())
    def store(delta):
        delta=np.asarray(delta,dtype="<f4")
        while len(payload)%4: payload.append(0)
        b=len(j["bufferViews"]); j["bufferViews"].append(dict(buffer=0,byteOffset=len(payload),byteLength=delta.nbytes,target=34962))
        payload.extend(delta.tobytes())
        a=len(j["accessors"])
        j["accessors"].append(dict(bufferView=b,componentType=5126,count=len(delta),type="VEC3",min=delta.min(0).tolist(),max=delta.max(0).tolist()))
        return a
    for p in mesh["primitives"]:
        xyz=positions(p); x,y,z=xyz.T
        name=j["materials"][p["material"]]["name"]
        # No distortion of seats, windows, axles, steering, or wheels.
        shell=not name.startswith(("Seat","Glass","Frit","Screen","Headliner","Belt","Carpet","Skin","Trim","Speaker","Pedal","Spring","Damper","Caliper","Bolt","Cast","Pad","Chassis","Steel","Wiper","Mirror","Handle","Arch"))
        p["targets"]=[]
        for end,sign in [(front,1),(rear,-1)]:
            depth=np.clip(1-np.abs(z-end)/max(.58,length*.14),0,1)
            weight=depth*depth*(3-2*depth)
            delta=np.zeros_like(xyz)
            if shell:
                delta[:,2]=-sign*weight*(.24+.045*np.cos(x*5.0))
                delta[:,1]=weight*.035*np.sin(x*4.2+1.0)
                delta[:,0]=weight*x*.025
            p["targets"].append({"POSITION":store(delta)})
    mesh["extras"]={**mesh.get("extras",{}),"targetNames":["FrontDent","RearDent"]}
    mesh["weights"]=[0.0,0.0]
    print("DAMAGE_SHAPES",len(mesh["primitives"]),front,rear)

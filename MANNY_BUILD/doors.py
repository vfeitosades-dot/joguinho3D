import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
D={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}
T={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
BOUNDS={
'sport-sedan':(-.243,.907,.529,.576,.908),
'grand-tourer':(-.713,.793,.471,.48,.906),
'muscle-coupe':(-.712,.798,.394,.527,.922),
'hot-hatchback':(-.238,.868,.606,.586,.885),
'electric-fastback':(-.178,.968,.656,.605,.925),
'luxury-suv':(-.178,.963,.638,.583,.986),
'luxury-limousine':(-.023,1.297,.813,.630,.980)}
def access(j,b,i):
    a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];d=np.dtype(D[a['componentType']]);k=T[a['type']]
    return np.ndarray((a['count'],k),d,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',d.itemsize*k),d.itemsize)).copy()
def split_door(j,b,name):
    lo,hi,glass_hi,xlo,xhi=BOUNDS[name]
    body=j['meshes'][0]
    original=[];door=[]
    def idx(a):
        a=np.asarray(a,dtype='<u4').ravel()
        while len(b)%4:b.append(0)
        vi=len(j['bufferViews']);j['bufferViews'].append(dict(buffer=0,byteOffset=len(b),byteLength=a.nbytes,target=34963));b.extend(a.tobytes())
        ai=len(j['accessors']);j['accessors'].append(dict(bufferView=vi,componentType=5125,count=len(a),type='SCALAR',min=[int(a.min())],max=[int(a.max())]));return ai
    for p in body['primitives']:
        m=j['materials'][p['material']]['name']
        pts=access(j,b,p['attributes']['POSITION'])
        tri=access(j,b,p['indices']).reshape(-1,3)
        xyz=pts[tri]; center=xyz.mean(axis=1)
        selected=np.zeros(len(tri),dtype=bool)
        if m.startswith('Paint') or m.startswith('Glass') or m in ('Handle_Cup','Mirror','Mirror_Case'):
            _,inv=np.unique(np.round(pts,4),axis=0,return_inverse=True)
            t=inv[tri]; graph=coo_matrix((np.ones(t.size),(t.flatten(),np.roll(t,1,axis=1).flatten())),shape=(inv.max()+1,inv.max()+1))
            _,lab=connected_components(graph,directed=False); groups=lab[t[:,0]]
            for k in np.unique(groups):
                mask=groups==k; q=xyz[mask].reshape(-1,3);a=q.min(0);z=q.max(0)
                if m.startswith('Paint'):
                    is_panel=a[0]>=xlo-.045 and a[2]>=lo-.045 and z[2]<=hi+.045 and a[1]>.24 and (z[2]-a[2]>.4 or a[0]>.80)
                    if is_panel:selected|=mask
                    elif name=='grand-tourer' and a[0]<0 and z[0]>.8 and a[2]>=lo-.02 and z[2]<=hi+.02 and a[1]>.24:
                        selected|=mask & (xyz[:,:,0].min(axis=1)>.45)
                elif m.startswith('Glass'):
                    if a[0]>.48 and a[2]>=lo-.06 and z[2]<=glass_hi+.055:selected|=mask
                elif a[0]>.60 and a[2]>=lo-.04 and z[2]<=hi+.04:selected|=mask
        elif m in ('Gap','Seal','Frit','Chrome','Trim','Trim_Tan','Skin','Skin_Tan','Speaker','Piano'):
            # Separate the door-side trim only; leave central cabin, fenders and windshield.
            selected=(xyz[:,:,0].min(axis=1)>.64)&(xyz[:,:,2].min(axis=1)>lo+.015)&(xyz[:,:,2].max(axis=1)<hi-.04)&(xyz[:,:,1].min(axis=1)>.29)
        if selected.any():
            d=dict(p);d['indices']=idx(tri[selected]);door.append(d)
        if (~selected).any():
            q=dict(p)
            if selected.any():q['indices']=idx(tri[~selected])
            original.append(q)
    assert len(door)>0 and len(original)>0,name
    body['primitives']=original
    mi=len(j['meshes']);j['meshes'].append(dict(name='DriverDoor',primitives=door))
    pivot=[xhi*.91,0.0,hi-.04]
    ni=len(j['nodes']);j['nodes'].append(dict(name='DriverDoorPivot',translation=pivot,children=[ni+1]))
    j['nodes'].append(dict(name='DriverDoorMesh',translation=[-x for x in pivot],mesh=mi))
    j['nodes'][0].setdefault('children',[]).append(ni)
    print('HINGED_DOOR',name,len(door))

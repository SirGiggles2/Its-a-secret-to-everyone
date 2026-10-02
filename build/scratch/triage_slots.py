import json,glob,os
ARR={0x28:'ObjTimer',0x3D0:'AnimCounter',0x3E4:'AnimFrame',0xC0:'ShoveDir',0xD3:'ShoveDist',0x405:'Metastate',0x485:'HP',0x4BF:'Attr',0x492:'Uninit',0x394:'GridOff',0x3A8:'PosFrac',0x3BC:'QSpeed',0x412:'PushTimer?'}
def slotof(a):
    for b,n in ARR.items():
        if b<=a<b+12: return n,a-b
    return None,None
out={}
for f in sorted(glob.glob('tools/lockstep/baselines/*.json')):
    d=json.load(open(f)); p=d['preset']; R='builds/reports/lockstep/'+p
    try: n=open(R+'/nes.ram','rb').read(); g=open(R+'/gen.ram','rb').read()
    except: continue
    T=min(len(n),len(g))//2048
    for k,t0 in d['cells'].items():
        a=int(k,16)
        if t0<1: continue
        nm,s=slotof(a)
        if nm is None or s==0: continue
        live=0; ndiff=0
        for t in range(t0,T):
            if n[t*2048+a]!=g[t*2048+a]:
                ndiff+=1
                if n[t*2048+0x34F+s] or g[t*2048+0x34F+s]: live+=1
        out.setdefault((nm,s),[]).append((p,t0,ndiff,live))
for (nm,s),v in sorted(out.items()):
    L=sum(x[3] for x in v)
    print(f"{nm}+{s:<2} presets {len(v):2} live-diff-ticks {L:5}  e.g. "+", ".join(f"{p}@{t}(d{nd},live{lv})" for p,t,nd,lv in v[:3]))

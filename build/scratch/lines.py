import struct,sys
d='builds/reports/lockstep/%s/'%sys.argv[1]
r=open(d+'gen.fram','rb').read(); tk=open(d+'gen.frtick','rb').read()
out={}
for i in range(len(r)//2048):
    t=struct.unpack('>H',tk[2*i:2*i+2])[0]; row=r[i*2048:(i+1)*2048]
    if row[0xEB]==0x38 and row[0x12]==5: out[t]=row[0x1FF]
import json; json.dump(out,open(sys.argv[2],'w'))
v=sorted(out.values()); print(len(v),'ticks; max',hex(v[-1]),'p90',hex(v[int(len(v)*.9)]))

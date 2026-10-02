import sys,subprocess,struct
m=open(sys.argv[1],'rb').read()
nm=open(sys.argv[2]).read()
sym={l.split()[2]:int(l.split()[0],16) for l in nm.splitlines() if len(l.split())==3}
hp=struct.unpack('>I',m[sym['heap']&0xFFFF:(sym['heap']&0xFFFF)+4])[0]&0xFFFFFF
print('heap ptr',hex(hp))
a=hp
for i in range(40):
    h=struct.unpack('>H',m[a&0xFFFF:(a&0xFFFF)+2])[0]
    if h==0: print('end at',hex(a)); break
    size=h&0xFFFE; used=h&1
    print(hex(a),'size',hex(size),'used' if used else 'free', '-> data',hex(a+2),'..',hex(a+size))
    a+=size

import sys
d='builds/reports/lockstep/%s/'%sys.argv[1]; t=int(sys.argv[2])
x0,y0,x1,y1=[int(v) for v in sys.argv[3:7]]
oam=open(d+'nes.f%05d.oam'%t,'rb').read()
print('NES', ' '.join('[%d]%d,%d %02X/%02X'%(i//4,oam[i+3],oam[i]-7,oam[i+1],oam[i+2]) for i in range(0,256,4) if oam[i]<0xEF and oam[i+1]!=0x1C and x0-8<=oam[i+3]<=x1 and y0-16<=oam[i]-7<=y1))
v=open(d+'gen.f%05d.vram'%t,'rb').read()
s=0;seen=set();out=[]
while s not in seen and len(out)<80:
    seen.add(s); e=0xF400+s*8
    y=(((v[e]<<8)|v[e+1])&0x3FF)-128; at=(v[e+4]<<8)|v[e+5]; x=(((v[e+6]<<8)|v[e+7])&0x1FF)-128
    if x0-16<=x<=x1 and y0-16<=y<=y1: out.append('[%d]%d,%d t%03X p%d%s%s%s sz%X'%(s,x,y,at&0x7FF,(at>>13)&3,'h' if at&0x800 else '','v' if at&0x1000 else '','P' if at&0x8000 else '',v[e+2]))
    s=v[e+3]&0x7F
    if s==0: break
print('GEN',' | '.join(out))

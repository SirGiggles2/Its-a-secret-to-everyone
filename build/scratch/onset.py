import sys
p,s,t0=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]); span=int(sys.argv[4]) if len(sys.argv)>4 else 4
R='builds/reports/lockstep/'+p
n=open(R+'/nes.ram','rb').read();g=open(R+'/gen.ram','rb').read()
for t in range(t0-span,t0+span):
  a=n[t*2048:];b=g[t*2048:]
  f=lambda r:'ty%02X st%02X ac%02X af%02X x%02X y%02X d%02X tm%02X ms%02X'%(r[0x34F+s],r[0xAC+s],r[0x3D0+s],r[0x3E4+s],r[0x70+s],r[0x84+s],r[0x98+s],r[0x28+s],r[0x405+s])
  print('t%d gm%02X r%02X NES %s | GEN %s'%(t,a[0x12],a[0xEB],f(a),f(b)))

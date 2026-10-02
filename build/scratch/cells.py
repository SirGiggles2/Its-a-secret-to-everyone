import sys
def cells(n, addrs, lo=0, hi=10**9, side='nes'):
    r=open('builds/reports/lockstep/%s/%s.ram'%(n,side),'rb').read(); N=len(r)//2048
    prev=None
    for t in range(N):
        if t<lo or t>hi: continue
        m=r[t*2048:(t+1)*2048]
        v=tuple(m[a] for a in addrs)
        if v!=prev: print(side,t,' '.join('%03X=%02X'%(a,x) for a,x in zip(addrs,v)))
        prev=v
if __name__=='__main__':
    n=sys.argv[1]; side=sys.argv[2]; lo=int(sys.argv[3]); hi=int(sys.argv[4])
    cells(n,[int(a,16) for a in sys.argv[5:]],lo,hi,side)

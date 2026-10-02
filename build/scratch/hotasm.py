import subprocess,sys,bisect
import os; tc=os.path.abspath('build/toolchain/sgdk_bin/bin')+os.sep
elf='build/debug_project/out/Debug.out'
fn=sys.argv[1]; prof=sys.argv[2]; top=int(sys.argv[3]) if len(sys.argv)>3 else 25
nm=subprocess.run([tc+'nm.exe','-n',elf],capture_output=True,text=True).stdout.split('\n')
syms=[(int(l.split()[0],16)&0xFFFFFF,l.split()[2]) for l in nm if len(l.split())==3 and l.split()[1] in 'tTWw']
syms.sort()
i=[k for k,(a,n) in enumerate(syms) if n==fn][0]
lo,hi=syms[i][0],syms[i+1][0]
hits={}
for l in open(prof):
    if l.startswith('#'): continue
    a,n=l.split(); a=int(a,16)&0xFFFFFF
    if lo<=a<hi: hits[a]=hits.get(a,0)+int(n)
dis=subprocess.run([tc+'objdump.exe','-d','--start-address=0x%x'%lo,'--stop-address=0x%x'%hi,elf],capture_output=True,text=True).stdout.split('\n')
rows=[]
for l in dis:
    p=l.strip().split(':',1)
    try: a=int(p[0],16)
    except: continue
    rows.append((a,l.strip()))
tot=sum(hits.values())
print(fn,'own instr',tot,'range',hex(lo),hex(hi))
# print hot regions: lines with hits, sorted by address, only those >= threshold
for a,l in rows:
    h=hits.get(a,0)
    if h>=top: print('%5d  %s'%(h,l[:110]))

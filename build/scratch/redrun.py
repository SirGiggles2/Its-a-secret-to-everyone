import sys,glob,re
sys.path.insert(0,'tools/lockstep')
import screen_diff as S
for d in sys.argv[1:]:
    fs=sorted(int(re.search(r'v(\d+)',f).group(1)) for f in glob.glob(d+'/gen.v*.vram'))
    hits=0
    for f in fs:
        t=f'v{f:05d}'
        fr=S.gen_frame(open(f'{d}/gen.{t}.vram','rb').read(),open(f'{d}/gen.{t}.cram','rb').read(),open(f'{d}/gen.{t}.vsram','rb').read(),7)
        for y in range(224):
            run=best=0
            for w in fr[y]:
                r,g,b=(w>>1)&7,(w>>5)&7,(w>>9)&7
                if r>=4 and r>g+1 and r>b+1: run+=1; best=max(best,run)
                else: run=0
            if best>=24:
                print(d.split('/')[-1],f,'line',y,'run',best); hits+=1
                break
    print(d,'frames',len(fs),'frames with red run',hits)

import sys,glob,re
sys.path.insert(0,'tools/lockstep')
import screen_diff as S
d=sys.argv[1]
fs=sorted(int(re.search(r'v(\d+)',f).group(1)) for f in glob.glob(d+'/gen.v*.vram'))
def comp(f):
    t=f'v{f:05d}'
    return S.gen_frame(open(f'{d}/gen.{t}.vram','rb').read(),open(f'{d}/gen.{t}.cram','rb').read(),open(f'{d}/gen.{t}.vsram','rb').read(),7)
ref=comp(fs[0])
for f in fs[::2]:
    fr=comp(f)
    hud=sum(1 for y in range(56) for x in range(256) if fr[y][x]!=ref[y][x])
    red=[]
    for y in range(224):
        row=fr[y]
        r=sum(1 for w in row if ((w>>1)&7)>=5 and ((w>>5)&7)<=2 and ((w>>9)&7)<=2)
        if r>=64: red.append((y,r))
    print(f, 'hud_changed',hud,'red_rows',red[:6])

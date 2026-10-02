import sys
sys.path.insert(0,'tools/lockstep')
import screen_diff as S
from PIL import Image
d=sys.argv[1]; out=sys.argv[2]; fr_ids=[int(x) for x in sys.argv[3:]]
def rgb(w): return (((w>>1)&7)*36,((w>>5)&7)*36,((w>>9)&7)*36)
m=Image.new('RGB',(264*len(fr_ids),224))
for i,f in enumerate(fr_ids):
    t=f'v{f:05d}'
    fr=S.gen_frame(open(f'{d}/gen.{t}.vram','rb').read(),open(f'{d}/gen.{t}.cram','rb').read(),open(f'{d}/gen.{t}.vsram','rb').read(),7)
    for y in range(224):
        for x in range(256): m.putpixel((i*264+x,y),rgb(fr[y][x]))
m.resize((m.width*2,m.height*2),Image.NEAREST).save(out)

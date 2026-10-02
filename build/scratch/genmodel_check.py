import sys,re,json
sys.path.insert(0,'tools/lockstep')
import screen_diff as sd, frame_diff as fd
from pathlib import Path
pals=json.load(open('tools/lockstep/frame_palettes.json'))['gen_rgb_to_cram']
rows=[]
for gp in sorted(Path('builds/reports/lockstep').glob('*/gen.f*.png')):
    d=gp.parent; tag=gp.name[4:10]
    need=[d/f'gen.{tag}.{x}' for x in ('vram','cram','vsram')]
    if not all(p.exists() for p in need): continue
    gen=sd.gen_frame(*(p.read_bytes() for p in need),7)
    px=fd.rgb_list(gp)
    bad=[(i%256,i//256,pals.get('%02X%02X%02X'%px[i]),gen[i//256][i%256]) for i in range(256*224) if pals.get('%02X%02X%02X'%px[i])!=gen[i//256][i%256]]
    if bad: rows.append((len(bad),str(gp),bad[:3]))
rows.sort(reverse=True)
for r in rows[:15]: print(r)
print(len(rows),'snapshots with model/render disagreement')

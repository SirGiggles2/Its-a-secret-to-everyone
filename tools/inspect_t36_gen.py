import json, sys
d = json.load(open(sys.argv[1] if len(sys.argv)>1 else 'builds/reports/t36_cave_gen_capture.json'))
t = d['trace']
keys_show = ('mode','sub','obj_x','obj_xf','obj_y','obj_yf','obj_dir','held','prev_held')
for i in range(640, 720):
    row = f"t={i:3d} "
    for k in keys_show:
        if k in t:
            v = t[k][i]
            row += f"{k}=${v:02X} " if isinstance(v,int) else f"{k}={v} "
    print(row)

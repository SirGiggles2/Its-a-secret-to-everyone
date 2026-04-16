import json
nes = json.load(open('builds/reports/t36_cave_nes_capture.json'))['trace']
gen = json.load(open('builds/reports/t36_cave_gen_capture.json'))['trace']
print("=== cave interior walk_down range ===")
print(f"{'t':>4} | NES mode objstate movedir facedir obj_y | GEN mode objstate movedir facedir obj_y")
for i in [280, 300, 400, 500, 600, 640, 646, 647, 650, 660, 680, 700, 720]:
    n = f"${nes['mode'][i]:02X} ${nes.get('objstate',[0]*840)[i]:02X}       ${nes.get('movedir',[0]*840)[i]:02X}      ${nes.get('facedir',[0]*840)[i]:02X}      ${nes['obj_y'][i]:02X}"
    g = f"${gen['mode'][i]:02X} ${gen.get('objstate',[0]*840)[i]:02X}       ${gen.get('movedir',[0]*840)[i]:02X}      ${gen.get('facedir',[0]*840)[i]:02X}      ${gen['obj_y'][i]:02X}"
    print(f"{i:>4} | {n} | {g}")

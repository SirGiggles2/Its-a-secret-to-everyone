import json
d = json.load(open('builds/reports/t36_cave_nes_capture.json'))
t = d['trace']
n = len(t['t'])
print(f"len={n} scenario_length={d.get('scenario_length')}")
# find mode transitions
prev = t['mode'][0]
print(f"t=0 mode=${prev:02X}")
for i in range(1, n):
    m = t['mode'][i]
    if m != prev:
        print(f"t={i} mode ${prev:02X} -> ${m:02X}  link=(${t['obj_x'][i]:02X},${t['obj_y'][i]:02X}) room=${t['room'][i]:02X}")
        prev = m

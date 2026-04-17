import re

def parse(path):
    data = {}
    for line in open(path):
        m = re.match(r'ENEMY_SNAP t=(\d+)', line)
        if m:
            t = int(m.group(1))
            slots = {}
            for s in re.finditer(r'slot(\d) id=\$([0-9A-F]+) x=\$([0-9A-F]+) y=\$([0-9A-F]+) dir=\$([0-9A-F]+)', line):
                slots[int(s.group(1))] = (s.group(3), s.group(4), s.group(5))
            data[t] = slots
    return data

n = parse('builds/reports/t38_enemy_nes_capture.txt')
g = parse('builds/reports/t38_enemy_gen_capture.txt')
first = None
for t in sorted(n.keys()):
    if t < 300 or t > 430: continue
    if t not in g: continue
    diffs = []
    for s in range(1, 5):
        if s in n[t] and s in g[t] and n[t][s] != g[t][s]:
            diffs.append(f's{s}: NES({n[t][s][0]},{n[t][s][1]},d{n[t][s][2]}) vs GEN({g[t][s][0]},{g[t][s][1]},d{g[t][s][2]})')
    if diffs:
        if first is None:
            first = t
            print(f'FIRST DIVERGENCE: t={t}')
        print(f't={t}: ' + ' | '.join(diffs))
        if t > first + 10: break

"""bboxcheck.py <preset>: snap ticks after SelectedItemSlot/item/sword/menu changes, diff HUD."""
import subprocess, sys, re
ROOT = r'C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY'
name = sys.argv[1]
d = ROOT + '/builds/reports/lockstep/' + name
r = open(d + '/nes.ram', 'rb').read(); n = len(r) // 2048
cells = [0x656, 0x657, 0xE1, 0xE0] + list(range(0x657, 0x67F))
ticks = []
for t in range(1, n - 3):
    a = r[(t - 1) * 2048:t * 2048]; b = r[t * 2048:(t + 1) * 2048]
    if any(a[c] != b[c] for c in cells) and b[0x12] == 5:
        ticks += [t + 1, t + 2]
ticks = sorted(set(ticks))[:40]
if not ticks: print(name, 'no changes'); sys.exit()
subprocess.run([sys.executable, ROOT + r'\tools\lockstep\run_lockstep.py', ROOT + r'\tools\lockstep\presets\%s.json' % name,
                '--full', '--snap', ','.join(map(str, ticks))], capture_output=True)
bad = 0
for t in ticks:
    out = subprocess.run([sys.executable, ROOT + r'\tools\lockstep\screen_diff.py', d, str(t), '--window-rows', '7'], capture_output=True, text=True).stdout
    if 'not supported' in out: continue
    rows = [int(m.group(1)) for m in re.finditer(r'cell \(\s*\d+,\s*(\d+)\)', out)]
    if any(y < 7 for y in rows):
        bad += 1; print(' ', t, [l.strip() for l in out.splitlines() if 'cell (' in l][:2])
print(name, 'checked', len(ticks), 'HUD diffs', bad)

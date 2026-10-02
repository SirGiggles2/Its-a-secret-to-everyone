"""hudcheck.py <preset> [max]: snap the ticks after each status-bar value change
(hearts, rupees, bombs, keys) in mode 5 and screen-diff them."""
import subprocess, sys, re
ROOT = r'C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY'
name = sys.argv[1]; mx = int(sys.argv[2]) if len(sys.argv) > 2 else 12
d = ROOT + r'\builds\reports\lockstep\%s\\' % name
r = open(d + 'nes.ram', 'rb').read(); n = len(r) // 2048
cells = (0x66F, 0x670, 0x66D, 0x658, 0x66E)
ticks = []
for t in range(1, n - 3):
    a = r[(t - 1) * 2048:t * 2048]; b = r[t * 2048:(t + 1) * 2048]
    if b[0x12] == 5 and any(a[c] != b[c] for c in cells):
        ticks += [t, t + 1, t + 2]
ticks = sorted(set(ticks))
if len(ticks) > mx * 3:
    step = len(ticks) // (mx * 3)
    ticks = ticks[::max(1, step)][:mx * 3]
if not ticks:
    print(name, 'no changes'); sys.exit()
subprocess.run([sys.executable, ROOT + r'\tools\lockstep\run_lockstep.py',
                ROOT + r'\tools\lockstep\presets\%s.json' % name, '--full',
                '--snap', ','.join(map(str, ticks))], capture_output=True)
bad = []
for t in ticks:
    out = subprocess.run([sys.executable, ROOT + r'\tools\lockstep\screen_diff.py', d.rstrip('\\'), str(t),
                          '--window-rows', '7'], capture_output=True, text=True).stdout
    cellrows = [int(m.group(2)) for m in re.finditer(r'cell \(\s*(\d+),\s*(\d+)\)', out)]
    if any(y < 8 for y in cellrows):
        bad.append((t, [l.strip() for l in out.splitlines() if 'cell (' in l and int(re.search(r',\s*(\d+)\)', l).group(1)) < 8][:3]))
print(name, 'checked', len(ticks), 'HUD diffs', len(bad))
for b in bad[:8]: print(' ', b)

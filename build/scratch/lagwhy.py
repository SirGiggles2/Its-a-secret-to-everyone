"""lagwhy.py <preset> <tick> [--profile]: frames of a slow tick + optional PC profile."""
import struct, subprocess, sys
ROOT = r'C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY'
name, tick = sys.argv[1], int(sys.argv[2])
d = ROOT + r'\builds\reports\lockstep\%s\\' % name
b = open(d + 'gen.frtick', 'rb').read(); n = len(b) // 2
ticks = struct.unpack('>%dH' % n, b)
f = open(d + 'gen.fram', 'rb').read()
fr = [i for i in range(n) if tick - 1 <= ticks[i] <= tick + 1]
for i in fr:
    m = f[i * 2048:(i + 1) * 2048]
    print('f%d t%d gm%02X sub%02X 1FF=%02X 1FE=%d room %02X' % (i, ticks[i], m[0x12], m[0x13], m[0x1FF], m[0x1FE], m[0xEB]))
if '--profile' in sys.argv:
    work = [i for i in range(n) if ticks[i] == tick]
    a, z = work[0] - 1, work[-1]
    subprocess.run([sys.executable, ROOT + r'\tools\lockstep\run_lockstep.py',
                    ROOT + r'\tools\lockstep\presets\%s.json' % name, '--full',
                    '--pc-profile', '%d:%d' % (a, z), '--report-suffix', '_why'],
                   capture_output=True)
    out = subprocess.run([sys.executable, ROOT + r'\tools\lockstep\pc_profile.py',
                          d.rstrip('\\') + r'_why\gen.pcprof'], capture_output=True, text=True).stdout
    print('\n'.join(out.splitlines()[:18]))

import sys, os
from pathlib import Path
sys.path.insert(0,str(Path('tools/lockstep').resolve()))
import run_lockstep
run_lockstep.GEN_ROM=Path('builds/playtests/Debug-T178.md').resolve()
original_build = run_lockstep.presets.build
def isolated_build(spec):
    p = original_build(spec)
    p['name'] += os.environ.get('CODEX_REPORT_SUFFIX', '_codex_t178_fixed')
    return p
run_lockstep.presets.build = isolated_build
raise SystemExit(run_lockstep.main())

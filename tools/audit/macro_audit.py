import sys, subprocess, re
sys.path.insert(0, r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\debug")
import build_debug as b
srcs = [s for s, _ in b.TITLE_C_SOURCES + b.ROOMROM_C_SOURCES]
names = ["LINK_X", "LINK_Y", "OBJ_STATE", "CUR_LEVEL", "NES_OBJ_INV_TIMER_BASE"]
for src in srcs:
    text = (b.ROOT / src).read_text(encoding="utf-8", errors="replace")
    used = [n for n in names if re.search(rf"\b{n}\b", text)]
    if not used: continue
    cmd = [str(x) for x in b.gcc_prefix() + b.CFLAGS + b.include_args() + ["-E", "-dM", str(b.ROOT / src)]]
    out = subprocess.run(cmd, cwd=b.PROJ, capture_output=True, text=True).stdout
    defs = {}
    for n in used:
        m = re.search(rf"^#define {n}(\(\w+\))? (.*)$", out, re.M)
        defs[n] = m.group(2).strip() if m else "UNDEF"
    print(src, defs)

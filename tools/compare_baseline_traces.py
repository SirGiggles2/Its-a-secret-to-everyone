"""Compare NES vs Genesis baseline trace data at state-matched frames."""
import sys
from pathlib import Path

ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
OUT_FILE = ROOT / "builds" / "reports" / "baseline_comparison.txt"
_out = open(OUT_FILE, "w", encoding="utf-8")
_orig_print = print
def print(*args, **kw):
    kw["file"] = _out
    _orig_print(*args, **kw)
    _orig_print(*args)  # also echo to console
NES_TRACE = ROOT / "builds" / "reports" / "items_baseline_nes" / "nes_trace.txt"
GEN_TRACE = ROOT / "builds" / "reports" / "items_baseline_gen" / "gen_trace.txt"

ITEM_HEADER = "frame,gameMode,phase,subphase,frameCtr,curVScroll,curHScroll,ppuCtrl,switchReq,tileBufSel,lineCounter,vramHi,vramLo,textIndex,objYTick,vsram0,ppuScrlX,ppuScrlY,hintQCount,hintPendSplit,introScrollMode,stagedMode,stagedHintCtr,stagedBase,stagedEvent,activeHintCtr,stagedSegment,activeSegment,activeBase,activeEvent,spriteVisible,attrIndex,itemRow"

def parse_trace(path):
    lines = path.read_text().splitlines()
    header = ITEM_HEADER.split(",")
    rows = {}
    for line in lines:
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split(",")
        if len(parts) < 10:
            continue
        frame = int(parts[0])
        row = {}
        for i, col in enumerate(header):
            if i < len(parts):
                row[col] = parts[i]
            else:
                row[col] = "??"
        # Build state key: phase, subphase, curV, lineCounter
        key = (row.get("phase",""), row.get("subphase",""), row.get("curVScroll",""), row.get("lineCounter",""))
        rows[key] = row
    return rows

nes = parse_trace(NES_TRACE)
gen = parse_trace(GEN_TRACE)

shared_keys = sorted(set(nes) & set(gen))

# Print comparison for a selection of interesting frames
print(f"Total NES frames: {len(nes)}")
print(f"Total GEN frames: {len(gen)}")
print(f"Shared state keys: {len(shared_keys)}")
print()

# Show some representative pairs
interesting = [
    ("01", "02", "00", "D8"),  # curV=0, late scroll
    ("01", "02", "28", "10"),  # curV=28, early scroll
    ("01", "02", "E8", "D0"),  # curV=E8, worst mismatch
    ("01", "02", "BD", "A5"),  # curV=BD, mid scroll
    ("01", "02", "DA", "C2"),  # curV=DA, near wrap
]

for key in interesting:
    if key in nes and key in gen:
        n = nes[key]
        g = gen[key]
        print(f"=== State: phase={key[0]} sub={key[1]} curV={key[2]} lineC={key[3]} ===")
        print(f"  NES frame={n['frame']:>5s}  GEN frame={g['frame']:>5s}  (offset={int(g['frame'])-int(n['frame'])})")
        print(f"  NES: ppuCtrl={n['ppuCtrl']} switchReq={n['switchReq']} textIdx={n['textIndex']} itemRow={n['itemRow']} attrIdx={n['attrIndex']}")
        print(f"  GEN: ppuCtrl={g['ppuCtrl']} switchReq={g['switchReq']} textIdx={g['textIndex']} itemRow={g['itemRow']} attrIdx={g['attrIndex']}")
        print(f"  GEN scroll: vsram0={g['vsram0']} ppuScrlY={g['ppuScrlY']} activeBase={g['activeBase']} activeEvent={g['activeEvent']}")
        print(f"  GEN mode: introScrollMode={g['introScrollMode']} activeSeg={g['activeSegment']} stagedSeg={g['stagedSegment']}")
        print(f"  Sprites: NES={n['spriteVisible']} GEN={g['spriteVisible']}")
        print()
    else:
        print(f"=== State key {key} not found in both traces ===")
        print()

# Also show first 3 and last 3 shared
print("=== First 3 shared pairs ===")
for key in shared_keys[:3]:
    n = nes[key]
    g = gen[key]
    print(f"  phase={key[0]} sub={key[1]} curV={key[2]} lineC={key[3]} | NES={n['frame']} GEN={g['frame']} off={int(g['frame'])-int(n['frame'])}")

print("\n=== Last 3 shared pairs ===")
for key in shared_keys[-3:]:
    n = nes[key]
    g = gen[key]
    print(f"  phase={key[0]} sub={key[1]} curV={key[2]} lineC={key[3]} | NES={n['frame']} GEN={g['frame']} off={int(g['frame'])-int(n['frame'])}")

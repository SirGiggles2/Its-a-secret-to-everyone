import os
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
GEN_DIR = ROOT / "builds" / "reports" / "items_seq_gen_fix2"
NES_DIR = ROOT / "builds" / "reports" / "items_baseline_nes"
OUT_DIR = ROOT / "builds" / "reports" / "item_scroll_analysis"
OUT_DIR.mkdir(parents=True, exist_ok=True)

def parse_trace(path):
    import csv
    if not path.exists(): return []
    lines = path.read_text().splitlines()
    header = lines[1][2:].split(",")
    return list(csv.DictReader(lines[2:], fieldnames=header))

gen_rows = parse_trace(GEN_DIR / "gen_fix2_trace.txt")
nes_rows = parse_trace(NES_DIR / "nes_trace.txt")

gen_by_v = {int(r["curVScroll"], 16): r for r in gen_rows if int(r["phase"], 16) == 1 and int(r["subphase"], 16) == 2}
nes_by_v = {int(r["curVScroll"], 16): r for r in nes_rows if int(r["phase"], 16) == 1 and int(r["subphase"], 16) == 2}

v_targets = [0x20, 0x40, 0x60, 0x80, 0xA0, 0xC0, 0xDF, 0xFA, 0x1A]

md_lines = ["# Detailed Item Scroll Analysis\n\n"]
carousel = ["````carousel\n"]

for v in v_targets:
    if v not in gen_by_v or v not in nes_by_v:
        continue
    gen_frame = int(gen_by_v[v]["frame"])
    nes_frame = int(nes_by_v[v]["frame"])
    
    gen_path = GEN_DIR / f"gen_fix2_f{gen_frame:05d}.png"
    nes_path = NES_DIR / f"nes_f{nes_frame:05d}.png"
    
    if not gen_path.exists() or not nes_path.exists():
        continue
        
    gimg = Image.open(gen_path).convert("RGB")
    nimg = Image.open(nes_path).convert("RGB")
    
    # Create Side-by-side
    w, h = gimg.size
    combined = Image.new("RGB", (w * 2, h))
    combined.paste(nimg, (0, 0))
    combined.paste(gimg, (w, 0))
    
    out_name = f"compare_v{v:02X}.png"
    out_path = OUT_DIR / out_name
    combined.save(out_path)
    
    # Calculate a simple diff image to highlight teleporting areas
    diff = ImageChops.difference(nimg, gimg)
    diff_path = OUT_DIR / f"diff_v{v:02X}.png"
    diff.save(diff_path)
    
    carousel.append(f"![curV={v:02X} : NES {nes_frame} (Left) vs GEN {gen_frame} (Right)]({out_path})\n")
    carousel.append("<!-- slide -->\n")
    carousel.append(f"![Diff for curV={v:02X}]({diff_path})\n")
    carousel.append("<!-- slide -->\n")

if carousel[-1] == "<!-- slide -->\n":
    carousel.pop()
carousel.append("````\n")

md_lines.extend(carousel)
(OUT_DIR / "inspection.md").write_text("".join(md_lines))
print("Analysis generated at", OUT_DIR / "inspection.md")

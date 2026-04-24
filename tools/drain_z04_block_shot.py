"""One-shot rewrite: replace drained z_04 bodies with jmp c_<name> trampolines.
Deletes data tables now in C.
"""
import re
from pathlib import Path

PATH = Path("src/zelda_translated/z_04.asm")
src = PATH.read_text().splitlines()

# Map: label -> (kind, c_target)
#   kind = "jmp" -> emit `Label: \n    jmp c_target`
#   kind = "delete" -> remove label and body entirely (data or dead static)
PLAN = {
    "BlockPushDirections":   ("delete", None),
    "UpdateBlock":           ("jmp",    "c_update_block"),
    "UpdateBlock_JumpTable": ("delete", None),
    "UpdateBlock0Idle":      ("delete", None),
    "DrawBlock":             ("jmp",    "c_draw_block"),
    "UpdateBlock1Moving":    ("delete", None),
    "UpdateBlock2Done":      ("delete", None),
    "ShotBounceWidths":      ("delete", None),
    "ShotBounceHeights":     ("delete", None),
    "UpdateMonsterShot":     ("jmp",    "c_update_monster_shot"),
    "L_DrawShot":            ("jmp",    "c_draw_shot"),
    "BounceShot":            ("jmp",    "c_bounce_shot"),
    "CheckShotLinkCollision":("jmp",    "c_check_shot_link_collision"),
    "FireballQSpeedsX":      ("delete", None),
    "FireballQSpeedsY":      ("delete", None),
    "UpdateFireball":        ("jmp",    "c_update_fireball"),
    "Fireball_MoveOneAxis":  ("delete", None),
}

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")

# Find body ranges: each label runs to next public label (or `even` boundary).
# Public label = not _anon_, _L_, __far_, __local_ (leave those merged with parent body — they may be in middle of another fn).
# Approach: build flat list of (line_idx, label_or_None). For each PLAN label, body = its line .. next PUBLIC label-1.

PUBLIC = re.compile(r"^[A-Za-z][A-Za-z0-9_]*:")

# Collect public label lines
public_lines = []
for i, line in enumerate(src):
    m = LABEL_RE.match(line)
    if not m:
        continue
    name = m.group(1)
    if name.startswith(("_anon_", "_L_", "__far_", "__local_")):
        continue
    public_lines.append((i, name))

# Build map name -> (start_idx, end_idx_exclusive)
ranges = {}
for j, (idx, name) in enumerate(public_lines):
    end = public_lines[j+1][0] if j+1 < len(public_lines) else len(src)
    # But trim back trailing blank/even lines that belong to next fn alignment
    # (preserve them to keep alignment safe for next public label)
    ranges[name] = (idx, end)

# Build set of indices to DELETE and dict of indices to REPLACE (start_idx -> new_block)
delete = set()
replace_at = {}

for name, (kind, target) in PLAN.items():
    if name not in ranges:
        print(f"WARN: label {name} not found")
        continue
    a, b = ranges[name]
    # Don't delete a preceding `even` we don't own; trim our range to start at the label line itself.
    # Trim trailing blank lines so we don't delete spacing before next label.
    end = b
    while end > a+1 and src[end-1].strip() == "":
        end -= 1
    # Also trim trailing `even` directive (alignment for following label)
    if end > a+1 and src[end-1].strip().lower() == "even":
        end -= 1
    # Mark all lines in [a, end) for delete
    for k in range(a, end):
        delete.add(k)
    if kind == "jmp":
        replace_at[a] = [f"{name}:", f"    jmp     {target}"]

out = []
for i, line in enumerate(src):
    if i in replace_at:
        out.extend(replace_at[i])
        continue
    if i in delete:
        continue
    out.append(line)

PATH.write_text("\n".join(out) + "\n")
print(f"Rewrote {PATH}; lines {len(src)} -> {len(out)}")

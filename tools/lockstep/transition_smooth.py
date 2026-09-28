"""Room-transition smoothness report (NES vs Genesis, per video frame).

    python tools/lockstep/transition_smooth.py <report_dir> [--frames]

Needs a run_lockstep --frame-dump capture: <dir>/{nes,gen}.fram (2 KB NES
RAM per video frame) and <dir>/{nes,gen}.fvdp (capture.lua: NES = OAM 256
bytes; GEN = VSRAM 4 + H scroll table 4 + SAT 640 bytes, all as the frame
ends).

A transition is a run of video frames with GameMode ($12) 6 or 7, plus the
mode 4 frames that follow it, up to the next mode 5 frame. Per transition:

- kind: OW/UW (CurLevel $10) and H/V (ObjDir $98 on the first mode 7 frame);
- frames: video frames from the first mode 6 frame to mode 5;
- cam: the camera move per frame. NES: CurHScroll ($FD) for H, the
  VScrollAddr ($58/$E2) row for V (8 px a row). GEN: plane A H scroll word
  (negated) / VSRAM word 0;
- link: Link's sprite position on screen (NES shadow OAM sprite $12 at
  $0248, GEN SAT 4 as the VDP holds it)
  and "world" = sprite + camera. While the room scrolls under a riding
  Link the world value is constant on a frame that shows the camera and the
  sprite from the same game tick;
- GEN wline: VDP V counter ($01FD) when the tick wrote the plane scroll.
  Lines $38-$DF are the playfield: a write there tears the frame (lines
  $00-$37 are the HUD window, no plane shows). $FF = queued for VBlank;
- GEN overrun: $01FE, frames the previous tick ran past its own;
- GEN pops: from 3 frames before to 3 after the transition, frames where
  the camera moves by anything but 0 or the scroll speed (OW 4, UW 2 px;
  mod the 512 px plane) or a shown Link sprite moves more than it (a
  preset-stage teleport of Link's RAM position is skipped).

Verdict line "SMOOTH: PASS" = on the Genesis every scroll frame moves the
camera by exactly the speed (vertical included: Room scroll SMOOTH), no
tear, no pop; else "SMOOTH: FAIL" with the counts.
"""
from __future__ import annotations

import argparse
from pathlib import Path

ROW = 0x800
HUD_LINES = 7 * 8
GEN_VDP = 648
NES_VDP = 256


def rows(path: Path, size: int) -> list[bytes]:
    b = path.read_bytes()
    if len(b) % size:
        raise SystemExit(f"{path.name}: {len(b)} bytes is not a multiple of {size}")
    return [b[i:i + size] for i in range(0, len(b), size)]


def s16(v: int) -> int:
    return v - 0x10000 if v & 0x8000 else v


def nes_vrow(r: bytes) -> int:
    """VScrollAddr ($58 hi, $E2 lo) as a play-area row count. NT 0 rows
    start at $2100 (row 0), NT 2 at $2800 (row 22 continues NT 0's $23A0)."""
    a = (r[0x58] << 8) | r[0xE2]
    if 0x2800 <= a < 0x2C00:
        return 22 + (a - 0x2800) // 32
    return (a - 0x2100) // 32


def frame_info(sys: str, r: bytes, v: bytes) -> dict:
    d = {"gm": r[0x12], "sub": r[0x13], "upd": r[0x11], "fc": r[0x15], "lvl": r[0x10],
         "dir": r[0x98], "x": r[0x70], "y": r[0x84]}
    if sys == "NES":
        d["hcam"] = r[0xFD] | ((r[0x5F] & 1) << 8)
        d["vcam"] = nes_vrow(r) * 8
        # Shadow OAM ($0200 page): the NMI shows it with this frame's
        # scroll cells (the OAM domain is the previous frame's DMA).
        d["sy"], d["sx"] = r[0x200 + 18 * 4], r[0x200 + 18 * 4 + 3]
    else:
        d["vcam"] = s16((v[0] << 8) | v[1])
        d["hcam"] = -s16((v[4] << 8) | v[5])
        sat = v[8 + 4 * 8: 8 + 5 * 8]
        d["sy"] = (((sat[0] << 8) | sat[1]) & 0x3FF) - 128
        d["sx"] = (((sat[6] << 8) | sat[7]) & 0x1FF) - 128
        d["wline"], d["over"], d["tend"] = r[0x1FD], r[0x1FE], r[0x1FF]
    return d


def transitions(frames: list[dict]) -> list[tuple[int, int]]:
    out, i, n = [], 0, len(frames)
    while i < n:
        if frames[i]["gm"] == 6 and (i == 0 or frames[i - 1]["gm"] == 5):
            j = i
            while j < n and frames[j]["gm"] in (4, 6, 7):
                j += 1
            # A scroll: mode 7 reaches Sub3 (ScrollWorld). A level exit
            # through a door leaves mode 7 at Sub1 on the NES and never
            # enters it on the Genesis (its exit load): not a scroll.
            if any(frames[k]["gm"] == 7 and frames[k]["sub"] == 3 for k in range(i, j)):
                out.append((i, j))
            i = j
        else:
            i += 1
    return out


def kind(frames: list[dict], a: int, b: int) -> str:
    f7 = next(frames[k] for k in range(a, b) if frames[k]["gm"] == 7)
    side = "UW" if f7["lvl"] else "OW"
    hv = "H" if f7["dir"] & 3 else "V"
    return f"{side}-{hv}"


def deltas(vals: list[int]) -> list[int]:
    return [vals[i] - vals[i - 1] for i in range(1, len(vals))]


def runs(ds: list[int]) -> str:
    """Compact run-length text of a delta list: 0x3 4x1 ..."""
    if not ds:
        return "-"
    out, cur, n = [], ds[0], 0
    for d in ds:
        if d == cur:
            n += 1
        else:
            out.append(f"{cur:+d}x{n}")
            cur, n = d, 1
    out.append(f"{cur:+d}x{n}")
    return " ".join(out)


def report(sys: str, frames: list[dict], a: int, b: int, per_frame: bool) -> dict:
    k = kind(frames, a, b)
    axis = "hcam" if k.endswith("H") else "vcam"
    spr = "sx" if k.endswith("H") else "sy"
    scroll = [i for i in range(a, b) if frames[i]["gm"] == 7 and frames[i]["sub"] == 3
              and frames[i]["upd"]]
    s0 = max(scroll[0] - 1, a) if scroll else a
    s1 = scroll[-1] + 2 if scroll else b
    cams = [frames[i][axis] for i in range(s0, min(s1, b))]
    sgn = 1 if k.endswith("H") else 1
    worlds = [frames[i][spr] + sgn * frames[i][axis] for i in range(s0, min(s1, b))]
    res = {"kind": k, "frames": b - a, "scroll_frames": len(scroll),
           "cam": runs(deltas(cams)), "world": runs(deltas(worlds))}
    if sys == "GEN":
        moved = [i for i in range(s0 + 1, min(s1, b))
                 if frames[i][axis] != frames[i - 1][axis]]
        # Lines 0-55 are the HUD window (ROOMROM_HUD_ROWS 7): no plane
        # shows there. $FF = committed in VBlank.
        res["tear"] = sum(1 for i in moved if HUD_LINES <= frames[i]["wline"] < 0xE0)
        res["moves"] = len(moved)
        res["wlines"] = sorted({frames[i]["wline"] for i in moved})
        res["over"] = sum(1 for i in range(a, b) if frames[i]["over"])
    if per_frame:
        res["rows"] = [(i, frames[i]["gm"], frames[i]["sub"], frames[i]["fc"], frames[i][axis],
                        frames[i][spr], frames[i].get("wline", -1)) for i in range(a, b)]
    return res


def wrap(v: int) -> int:
    return ((v + 256) % 512) - 256


def teleported(frames: list[dict], i: int) -> bool:
    """Link's RAM X/Y ($70/$84) jumped more than a step within the last 3
    game ticks (FrameCounter values): a preset stage wrote it. The sprite
    shows such a write 2 ticks later (t111_dark_candle, t131_uw_doors)."""
    fcs, j = set(), i
    while j >= 1 and len(fcs | {frames[j]["fc"]}) <= 3:
        fcs.add(frames[j]["fc"])
        if abs(frames[j]["x"] - frames[j - 1]["x"]) > 8 or            abs(frames[j]["y"] - frames[j - 1]["y"]) > 8:
            return True
        j -= 1
    return False


def pops(frames: list[dict], a: int, b: int, speed: int) -> list[str]:
    out = []
    for i in range(max(a - 3, 1), min(b + 4, len(frames))):
        f, p = frames[i], frames[i - 1]
        for ax in ("hcam", "vcam"):
            d = wrap(f[ax] - p[ax])
            if d not in (0, speed, -speed):
                out.append(f"f{i - a} {ax} {d:+d} gm{f['gm']:02X}.{f['sub']:02X}")
        # Link sprite jumps, unless a preset stage teleported him.
        tele = teleported(frames, i)
        if f["sy"] > -32 and p["sy"] > -32 and not tele:
            dx, dy = f["sx"] - p["sx"], f["sy"] - p["sy"]
            if abs(dx) > speed or abs(dy) > speed:
                out.append(f"f{i - a} link {dx:+d},{dy:+d} gm{f['gm']:02X}.{f['sub']:02X}")
    return out


def load(d: Path, sys: str) -> list[dict]:
    tag = sys.lower()
    fr = rows(d / f"{tag}.fram", ROW)
    fv = rows(d / f"{tag}.fvdp", GEN_VDP if sys == "GEN" else NES_VDP)
    if len(fr) != len(fv):
        raise SystemExit(f"{tag}: {len(fr)} RAM frames vs {len(fv)} video frames")
    return [frame_info(sys, r, v) for r, v in zip(fr, fv)]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", type=Path)
    ap.add_argument("--frames", action="store_true", help="per-frame rows")
    a = ap.parse_args()
    data = {s: load(a.dir, s) for s in ("NES", "GEN")}
    tr = {s: transitions(f) for s, f in data.items()}
    print(f"transitions NES={len(tr['NES'])} GEN={len(tr['GEN'])}")
    fails = []
    if len(tr["NES"]) != len(tr["GEN"]):
        fails.append("transition count")
    for n, (tn, tg) in enumerate(zip(tr["NES"], tr["GEN"])):
        rn = report("NES", data["NES"], *tn, a.frames)
        rg = report("GEN", data["GEN"], *tg, a.frames)
        print(f"\n#{n} {rn['kind']}/{rg['kind']}  frames NES {rn['frames']} GEN {rg['frames']}"
              f"  scroll frames NES {rn['scroll_frames']} GEN {rg['scroll_frames']}")
        print(f"  NES cam   {rn['cam']}")
        print(f"  GEN cam   {rg['cam']}")
        print(f"  NES world {rn['world']}")
        print(f"  GEN world {rg['world']}")
        print(f"  GEN tear {rg['tear']}/{rg['moves']} moves  write lines {rg['wlines']}"
              f"  overrun frames {rg['over']}")
        speed = 4 if rg["kind"].startswith("OW") else 2
        pp = pops(data["GEN"], *tg, speed)
        print(f"  GEN pops {len(pp)}" + (": " + "; ".join(pp) if pp else ""))
        steady = rg["cam"].split()[1:] if rg["moves"] else []
        uneven = [r for r in steady if not r.startswith(f"{'+' if r[0] == '+' else '-'}{speed}x")]
        if rg["tear"] or pp or uneven or rg["kind"] != rn["kind"]:
            fails.append(f"#{n} {rg['kind']} tear={rg['tear']} pops={len(pp)} uneven={uneven}")
        if a.frames:
            for s, r in (("NES", rn), ("GEN", rg)):
                for row in r["rows"]:
                    print(f"    {s} f{row[0]} gm{row[1]:02X}.{row[2]:02X} fc{row[3]:02X}"
                          f" cam{row[4]} spr{row[5]} wl{row[6]:02X}")
    print()
    print("SMOOTH: " + ("PASS" if not fails else "FAIL  " + " | ".join(fails)))
    return 0 if not fails else 1


if __name__ == "__main__":
    raise SystemExit(main())

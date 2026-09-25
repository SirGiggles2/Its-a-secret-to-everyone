"""Focused T-110 comparison of the bomb / fire object slots $10 and $11.

Both captures replay the same controller script from the lockstep sync.
Genesis handles input later in its frame than the NES (T-102), so the two
timelines are aligned on the first game tick at which either weapon slot
becomes active, then compared tick by tick (one snapshot per advancing
FrameCounter, as verify_scroll.py does). Fields: every NES object cell the
bomb / fire code owns for slots $10/$11, plus the inventory and Link cells
it writes. Missing or short captures are errors. This is not an all-RAM or
graphics verdict; sprites are checked separately.
"""
import argparse
import json
from pathlib import Path

from diff import load

SLOT_FIELDS = {
    "ObjState": 0xAC, "ObjTimer": 0x28, "ObjX": 0x70, "ObjY": 0x84,
    "ObjDir": 0x98, "ObjGridOffset": 0x394, "ObjPosFrac": 0x3A8,
    "ObjQSpeedFrac": 0x3BC, "ObjAnimCounter": 0x3D0, "ObjAnimFrame": 0x3E4,
}
GLOBAL_FIELDS = {
    "InvBombs": 0x658, "UsedCandle": 0x513, "HeartValues": 0x66F,
    "HeartPartial": 0x670,
}


def fields():
    out = {}
    for name, base in SLOT_FIELDS.items():
        for slot in (0x10, 0x11):
            out[f"{name}+{slot}"] = base + slot
    out.update(GLOBAL_FIELDS)
    return out


def ticks(frames):
    result = []
    for f, r in enumerate(frames):
        if result and result[-1][1][0x15] == r[0x15]:
            result[-1] = (f, r)
        else:
            result.append((f, r))
    return result


def first_active(tl):
    return next((i for i, (_, r) in enumerate(tl) if r[0xBC] or r[0xBD]), None)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path)
    ap.add_argument("--ticks", type=int, required=True,
                    help="ticks to compare from the first active tick")
    ap.add_argument("--gen-lag", type=int, default=0,
                    help="Genesis ticks behind NES at activation; T-102: Genesis "
                         "reads input after UpdateBombOrFire, NES before (1)")
    a = ap.parse_args()
    launches, tl, start, frames = {}, {}, {}, {}
    for p in ("nes", "gen"):
        launch = json.loads((a.directory / f"run_{p}" / "launch.json").read_text())
        if launch["exit_code"] != 0:
            raise SystemExit(f"ERROR: {p} runner failed")
        launches[p] = launch["rom_sha256"]
        frames[p] = load(a.directory / p)
        tl[p] = ticks(frames[p])
        start[p] = first_active(tl[p])
        if p == "gen" and start[p] is not None:
            start[p] += a.gen_lag
        if start[p] is None:
            raise SystemExit(f"ERROR: {p} never activated slot $10/$11")
        if len(tl[p]) < start[p] + a.ticks:
            raise SystemExit(f"ERROR: {p} has {len(tl[p]) - start[p]} ticks after "
                             f"activation, need {a.ticks}")
    fl = fields()
    failures = []
    for t in range(a.ticks):
        nf, nr = tl["nes"][start["nes"] + t]
        gf, gr = tl["gen"][start["gen"] + t]
        for name, addr in fl.items():
            if nr[addr] != gr[addr]:
                failures.append({"tick": t, "nes_video_frame": nf, "gen_video_frame": gf,
                                 "field": name, "nes": nr[addr], "gen": gr[addr]})
    first = {}
    for fail in failures:
        first.setdefault(fail["field"], fail)
    result = {"scope": "weapon slots $10/$11 object cells + InvBombs/UsedCandle/hearts",
              "alignment": "first tick with ObjState $10 or $11 nonzero; one snapshot "
                           "per advancing FrameCounter",
              "gen_lag_ticks": a.gen_lag,
              "lag_video_frames": {p: sum(1 for i in range(1, len(fr)) if fr[i][0x15] == fr[i - 1][0x15])
                                   for p, fr in frames.items()},
              "not_verified": ["all RAM", "OAM / SAT bytes", "CRAM grayscale", "audio"],
              "rom_sha256": launches, "fields": fl,
              "first_active_video_frame": {p: tl[p][start[p]][0] for p in tl},
              "compared_ticks": a.ticks, "first_divergence_by_field": first,
              "failure_count": len(failures),
              "verdict": "FAIL" if failures else "PASS"}
    (a.directory / "weapon-result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"{a.directory.name}: {result['verdict']} ({a.ticks} ticks, gen_lag "
          f"{a.gen_lag}, {len(failures)} differing cells, lag frames "
          f"{result['lag_video_frames']})")
    for name, fail in sorted(first.items(), key=lambda kv: kv[1]["tick"]):
        print(f"  {name}: tick {fail['tick']} nes={fail['nes']:02X} gen={fail['gen']:02X}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())

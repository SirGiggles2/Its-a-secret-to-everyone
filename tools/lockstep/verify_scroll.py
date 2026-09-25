"""Focused T-105 comparison of recorded controller-driven room crossings.

Compare completed game ticks, taking the last snapshot when FrameCounter is
unchanged across video frames (NES layout and native upload can span VBlanks).
Report raw video timing separately; this is not an all-RAM or graphics verdict.
No state is injected by this verifier. Missing/short captures are errors.
"""
import argparse
import json
from pathlib import Path

from diff import load

FIELDS = {
    "IsUpdatingMode": 0x11, "GameMode": 0x12, "GameSubmode": 0x13,
    "ObjX": 0x70, "ObjY": 0x84, "ObjDir": 0x98, "RoomId": 0xEB,
    "ObjGridOffset": 0x394, "ObjPosFrac": 0x3A8,
}


def crossings(frames):
    starts = [i for i, r in enumerate(frames)
              if r[0x12] == 6 and (i == 0 or frames[i - 1][0x12] != 6)]
    result = []
    for start in starts:
        ticks = []
        for f in range(start, len(frames)):
            r = frames[f]
            if ticks and ticks[-1][1][0x15] == r[0x15]:
                ticks[-1] = (f, r)
            else:
                ticks.append((f, r))
        resume = next((i for i, (_, r) in enumerate(ticks)
                       if r[0x12] == 5 and r[0x11] == 1), None)
        if resume is None or len(ticks) < resume + 25:
            raise SystemExit(f"ERROR: crossing at frame {start} lacks resume + 24 ticks")
        result.append((start, resume, ticks[:resume + 25]))
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path)
    ap.add_argument("--crossings", type=int, required=True)
    a = ap.parse_args()
    if a.crossings < 1:
        raise SystemExit("ERROR: expected crossings must be positive")
    data = {p: crossings(load(a.directory / p)) for p in ("nes", "gen")}
    launches = {}
    for p in data:
        launch = json.loads((a.directory / f"run_{p}" / "launch.json").read_text())
        if launch["exit_code"] != 0 or len(data[p]) != a.crossings:
            raise SystemExit(f"ERROR: {p} runner failed or wrong crossing count ({len(data[p])})")
        launches[p] = launch["rom_sha256"]
    rows = []
    for n, (nes, gen) in enumerate(zip(data["nes"], data["gen"])):
        failures = []
        if nes[1] != gen[1] or len(nes[2]) != len(gen[2]):
            failures.append({"reason": "game tick counts differ"})
        for tick, ((nf, nr), (gf, gr)) in enumerate(zip(nes[2], gen[2])):
            for name, addr in FIELDS.items():
                if nr[addr] != gr[addr]:
                    failures.append({"tick": tick, "nes_video_frame": nf,
                                     "gen_video_frame": gf, "field": name,
                                     "nes": nr[addr], "gen": gr[addr]})
        rows.append({"crossing": n + 1, "nes_start": nes[0], "gen_start": gen[0],
                     "nes_resume": nes[2][nes[1]][0], "gen_resume": gen[2][gen[1]][0],
                     "transition_ticks": {"nes": nes[1], "gen": gen[1]},
                     "compared_ticks": min(len(nes[2]), len(gen[2])),
                     "failures": failures, "verdict": "FAIL" if failures else "PASS"})
    result = {"scope": "nine state fields, leave/scroll/enter + 24 gameplay ticks",
              "alignment": "last video snapshot per advancing FrameCounter",
              "not_verified": ["all RAM", "sprite animation", "graphics bytes", "audio"],
              "rom_sha256": launches, "fields": FIELDS, "crossings": rows,
              "verdict": "PASS" if all(r["verdict"] == "PASS" for r in rows) else "FAIL"}
    (a.directory / "scroll-result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"{a.directory.name}: {result['verdict']} ({len(rows)} crossings)")
    for row in rows:
        print(f"  crossing {row['crossing']}: {row['compared_ticks']} ticks; "
              f"{len(row['failures'])} differing cells; "
              f"video resume NES {row['nes_resume']} / GEN {row['gen_resume']}")
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

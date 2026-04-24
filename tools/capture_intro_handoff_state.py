"""Capture the legacy frontend RAM state at the moment file-select is entered."""
import argparse, json, os, subprocess, sys
from pathlib import Path

HANDOFF_ADDRS = [
    ("mode_value",              0x0012),
    ("submode_value",           0x0013),
    ("frontend_demo_phase",     0x042C),
    ("frontend_demo_subphase",  0x042D),
    ("front_start_release_gate",0x042B),
    ("vram_force_blank_gate",   0x083D),
    ("frontend_delay_timer",    0x0528),
    ("room_mode_timer",         0x0011),
    ("item_sfx_secondary",      0x0600),
    ("room_transfer_buf_select",0x0014),
]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", required=True)
    ap.add_argument("--bizhawk", default=os.environ.get("CODEX_BIZHAWK_ROOT"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--out-chr")
    ap.add_argument("--out-cram")
    args = ap.parse_args()

    if not args.bizhawk:
        print("error: --bizhawk or CODEX_BIZHAWK_ROOT required", file=sys.stderr)
        sys.exit(2)

    probe = Path(__file__).parent / "bizhawk_intro_handoff_capture.lua"
    if not probe.exists():
        print(f"error: probe not found: {probe}", file=sys.stderr)
        sys.exit(2)

    env = os.environ.copy()
    env["INTRO_STATE_DUMP"]  = args.out
    env["INTRO_STATE_ADDRS"] = ",".join(f"{n}:{a:04x}" for n, a in HANDOFF_ADDRS)
    if args.out_chr:  env["INTRO_CHR_DUMP"]  = args.out_chr
    if args.out_cram: env["INTRO_CRAM_DUMP"] = args.out_cram

    emuhawk = Path(args.bizhawk) / "EmuHawk.exe"
    cmd = [str(emuhawk), f"--lua={probe}", args.rom]
    rc = subprocess.call(cmd, env=env)
    if rc != 0:
        sys.exit(rc)

    if not Path(args.out).exists():
        print(f"error: probe did not emit {args.out}", file=sys.stderr)
        sys.exit(3)

    with open(args.out) as f:
        data = json.load(f)
    if "error" in data:
        print(f"error: probe reported failure: {data['error']}", file=sys.stderr)
        sys.exit(3)

    print(f"captured handoff state -> {args.out}")

if __name__ == "__main__":
    main()

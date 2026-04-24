# Drain Agent Prompt Template

Copy this template and fill in the `{{PLACEHOLDERS}}` before dispatching
an implementer subagent for a C drain task.

---

You are draining a family of NES 6502→M68K-translated asm functions into
owned C in a Zelda NES→Genesis transpiler project. Goal: port raw asm
bodies from `src/zelda_translated/{{BANK}}.asm` to C in the target runtime
module listed below.

## REPO ROOT
`C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY`

## YOUR FAMILY: {{FAMILY_NAME}}

Source asm functions in `src/zelda_translated/{{BANK}}.asm`:

{{LIST_OF_LABELS_WITH_LINE_NUMBERS}}

Read the asm range(s) listed to see bodies before porting.

## TARGET
Append ported C to `src/{{RUNTIME_FILE}}.c`. Follow existing conventions
in that file (read top-to-bottom first to learn style + macro usage).

## NAMING
Prefix new C functions with `enrt_` (or appropriate prefix for your
runtime — see `tools/emit_gen_wrappers.py:23` `PREFIX_HEADERS`). Data
tables: `static const unsigned char <prefix>_<lower_snake>[] = {...};`.
Replace M68K jump-table dispatch (`jsr _m68k_tablejump`) with plain C
`switch` on the state byte. Name new C functions in lower_snake_case.

## RAM ABI
Read `src/nes_abi.h` and the runtime's private header
(e.g. `src/enemy_runtime_private.h`) for the `RAM(addr)` macro and
`ENEMY_*` accessors. Asm `($XXXX,A4)` addressing translates to
`RAM(0xXXXX + slot)`; prefer existing typed accessor macros when they
match.

## CARRY/CCR RULES
If your C function returns a carry-like flag, use `unsigned int` returning
`0x100` (CARRY_SET) or `0`; the entry shim will `ori #$11,CCR` on set and
`andi #$EE,CCR` on clear so M68K `addx`/`subx` in remaining asm see the
6502 carry bit. If in doubt, check whether asm callers use `BCS`/`BCC`
on the return.

## RESTRICTIONS — DO NOT TOUCH
- `src/gen/{{BANK}}.c` (forwarders — controller regenerates)
- `tools/gen_wrappers/{{BANK}}_manifest.json` (controller updates)
- `src/enemy_runtime.h` / other runtime header (controller adds decls)
- `src/zelda_translated/{{BANK}}.asm` (controller replaces bodies with
  trampolines via `tools/drain_finalize.py`)
- Any other agent's target runtime file (if running in parallel)

## DO TOUCH
- `src/{{RUNTIME_FILE}}.c` — append your ported C here
- `src/c_shims.asm` — ONLY for new IMPORT shims if your C calls back into
  asm (e.g. `c_draw_arrow` calling asm `DrawArrow`). Do NOT write the
  entry shim (`c_<your_fn_name>`) — controller does that.

## BUILD VERIFY
Run `powershell -Command "& cmd.exe /c '.\build.bat 2>&1'"` to verify your
C compiles. Build should succeed (even though new C is not yet wired into
z_04.c forwarders — controller handles that after).

## REPORTING (CRITICAL)
Return a report with:
1. List of new C function names + signatures (e.g.
   `void enrt_update_block(unsigned int slot)`)
2. Any new IMPORT shims added to c_shims.asm (name + line numbers)
3. Tricky semantic decisions (jump table flattening, carry return, dual-axis
   helpers, data layout assumptions)
4. Build status (PASS/FAIL with error excerpt)
5. Status: `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`

## STANDING MEMORY FACTS
- `TURBO_LINK equ 1` in `src/genesis_shell.asm:44` enables Link no-clip
  debug patches (P39/P40/P40b in `tools/transpile_6502.py:6599+`). Do
  not worry about collision parity for Link-specific code; leave as-is.
- T34 parity probe is a regression detector — but T34 FAIL at t=172 is
  expected while TURBO_LINK is on.

Do not modify files outside DO TOUCH. Do not commit. Stay focused on your
family only.

---

## Controller workflow (for orchestrator, not the agent)

After the agent(s) return DONE:

1. Write a plan JSON describing the ports:
```json
{
  "bank": "z_04",
  "entries": [
    {"name": "UpdateBlock", "target": "enrt_update_block",
     "sig": "void (unsigned int slot)", "kind": "jmp"},
    {"name": "BlockPushDirections", "kind": "delete"}
  ]
}
```

2. Run:
```bash
python tools/drain_finalize.py --plan plan.json --build
```

3. Commit.

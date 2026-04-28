# Toolchain Inventory (locked at S0)

| Tool | Path resolution rule | Resolved version | Resolved location |
|---|---|---|---|
| `vasmm68k_mot.exe` | `build.bat` Locate vasmm68k_mot block | vasm 2.0e; M68k cpu backend 2.8; motorola syntax module 3.19d | `<sibling-repo>/NES-TO-SEGA-GENESIS/build/toolchain/vasmm68k_mot.exe` |
| `m68k-elf-gcc.exe` | `build/toolchain/sgdk_bin/bin/gcc.exe` | gcc (crosstool-NG UNKNOWN) 13.2.0 | `<sibling-repo>/NES-TO-SEGA-GENESIS/build/toolchain/sgdk_bin/bin/gcc.exe` |
| `m68k-elf-ld.exe`  | same dir | GNU ld (crosstool-NG UNKNOWN) 2.40 | same dir as gcc |
| `m68k-elf-objcopy.exe` | same dir | GNU objcopy (crosstool-NG UNKNOWN) 2.40 | same dir as gcc |
| `python` | `build.bat` Locate Python block | Python 3.14.0 | system `PATH` |
| BizHawk (NES core) | <see Reference Contract> | filled in Task 6 | n/a |
| BizHawk (Genesis core) | <see Reference Contract> | filled in Task 6 | n/a |

## Notes (corrected from plan literal — reality differed)

- vasmm68k uses **Motorola syntax** (`vasmm68k_mot`), not Mit/GAS.
- The C compiler is **m68k-elf-gcc 13.2.0 from a crosstool-NG build**, NOT the
  SGDK 1.x bundled toolchain (which ships with GCC 6.3). The plan's wording
  "SGDK 1.x distribution" was inaccurate; this codebase uses the
  crosstool-NG-built newer toolchain that SGDK 2.x recommends.
- The toolchain is **the SGDK 2.x compiler distribution.** This matters for the
  SGDK pivot decided 2026-04-27: we will adopt the full SGDK runtime/library on
  top of the compiler we already use, rather than rolling our own render layer.
  See spec Section 4 (Architecture) for the SGDK integration plan.
- The `-fcall-saved-a4` flag in `build.bat` enforces the existing A4 = NES_RAM
  base contract; that flag may need revisiting under SGDK because SGDK
  conventionally keeps A5 reserved for hardware register access. To be
  resolved during SGDK integration audit (Task 3.5).

## Open issues recorded at S0 (not blocking close)

1. **Toolchain lives outside FINAL TRY** — resolves to a sibling repo path
   `NES-TO-SEGA-GENESIS/build/toolchain/`. Anyone cloning FINAL TRY alone
   cannot build. Reproducibility contract (spec Section 0) is at risk on a
   fresh clone.
   - **Owner:** S1 build-pipeline rewire.
   - **Options:** vendor toolchain into FINAL TRY's `build/toolchain/`, use a
     git submodule, or document a `setup.bat` that downloads SGDK to a known
     local path.
   - **Decision deferred** to S1 stage planning; S0 acceptance does not
     require fresh-clone reproducibility, only "current build still produces
     working ROM."

2. **SGDK adoption is now Path E** (decided after T3 reviewed reality). Spec
   Section 4 (Architecture) and Section 7 (Stages) amended; see commits
   tagged `s0: sgdk pivot`.

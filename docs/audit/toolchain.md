# Toolchain Inventory (locked at S0)

| Tool | Path resolution rule | Resolved version |
|---|---|---|
| `vasmm68k_mot.exe` | `build.bat` Locate vasmm68k_mot block | vasm 2.0e; M68k cpu backend 2.8; motorola syntax module 3.19d |
| `m68k-elf-gcc.exe` | `build/toolchain/sgdk_bin/bin/gcc.exe` | gcc.exe (crosstool-NG UNKNOWN) 13.2.0 |
| `m68k-elf-ld.exe`  | same dir | GNU ld (crosstool-NG UNKNOWN) 2.40 |
| `m68k-elf-objcopy.exe` | same dir | GNU objcopy (crosstool-NG UNKNOWN) 2.40 |
| `python` | `build.bat` Locate Python block | Python 3.14.0 |
| BizHawk (NES core) | <see Reference Contract> | filled in Task 6 |
| BizHawk (Genesis core) | <see Reference Contract> | filled in Task 6 |

## Notes

- vasmm68k uses **Motorola syntax** (`vasmm68k_mot`), not Mit/GAS.
- m68k-elf-gcc is the SGDK 1.x distribution (`build/toolchain/sgdk_bin/`).
- The `-fcall-saved-a4` flag in `build.bat` enforces the existing A4 = NES_RAM
  base contract; that flag will be reviewed during the RAM-convention migration
  but stays untouched in S0.

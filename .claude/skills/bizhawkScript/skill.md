---
name: bizhawkScript
description: Launch BizHawk with a Lua script and the current ROM. Pass the Lua script path as the argument.
argument-hint: <path-to-lua-script>
user-invocable: true
---

# BizHawk Script Launcher

Launch BizHawk with a Lua probe script and the current ROM build.

## Instructions

1. The argument is the path to the Lua script. It can be a relative path from the project root (e.g. `tools/scroll_watch.lua`) or an absolute path.
2. The BizHawk directory is: `C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64`
3. The executable is `EmuHawk.exe` inside that directory.

## Launch procedure

BizHawk crashes on paths containing `.claude` or other dotfile directories due to .NET path validation. To avoid this:

1. **Copy the Lua script** into the BizHawk directory (`C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\`).
2. **Copy the ROM** into the BizHawk directory as `whatif.md`.
3. **Launch with relative filenames only** — no absolute paths in the arguments.

```bash
# Step 1: Copy files into BizHawk dir
cp "<SCRIPT_PATH>" "/c/Users/Jake Diggity/Documents/GitHub/VDP rebirth tools and asms/BizHawk-2.11-win-x64/<SCRIPT_NAME>"
cp "<ROM_PATH>" "/c/Users/Jake Diggity/Documents/GitHub/VDP rebirth tools and asms/BizHawk-2.11-win-x64/whatif.md"

# Step 2: Launch with relative names
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList @('--lua=<SCRIPT_NAME>','whatif.md') -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

**Without Lua script (ROM only):**

```bash
cp "<ROM_PATH>" "/c/Users/Jake Diggity/Documents/GitHub/VDP rebirth tools and asms/BizHawk-2.11-win-x64/whatif.md"
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList @('whatif.md') -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

## Lua script rules for Genesis

- BizHawk Genesis `mainmemory` domain is 64KB (68K work RAM at $FF0000-$FFFFFF).
- Use **offsets from 0x0000**, not absolute 68K addresses. E.g. `$FF00FC` → `mainmemory.read_u8(0x00FC)`.
- Use Lua 5.4 operators (`>>`, `&`) instead of deprecated `bit.rshift`/`bit.band`.
- Use `gui.drawText` (not `gui.text`) and `gui.drawBox` for overlays.

## Rules

- Always use `powershell -Command "Start-Process ..."` with `-ArgumentList @(...)` array syntax to launch.
- Always copy files into BizHawk dir first — never pass paths containing `.claude` or dotfile directories.
- Verify the Lua script file exists before launching.
- Do NOT use `cmd.exe /c`, `start ""`, bat files, or `&` backgrounding.

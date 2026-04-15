---
name: bizhawkScript
description: Launch BizHawk with a Lua script and the current ROM. Pass the Lua script path as the argument.
argument-hint: <path-to-lua-script>
user-invocable: true
---

# BizHawk Script Launcher

Launch BizHawk with a Lua probe script and the current ROM build.

## Paths

- BizHawk dir: `C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64`
- Executable : `EmuHawk.exe` inside that directory
- Project root: `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\`
- Worktree ROM: usually at `<worktree>\builds\whatif.md` — use the worktree you're in, NOT the project root's builds dir

## CRITICAL path-format rule (learned the hard way)

BizHawk's .NET `FileIOPermission.EmulateFileIOPermissionChecks` rejects certain path formats passed on the command line. Known failure cases:
- Paths containing a dot-prefixed directory segment (e.g. `.claude`)
- Paths containing spaces combined with `--lua=` argument parsing
- Worktree paths like `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\magical-chatelet\builds\whatif.md` → throws `System.NotSupportedException: The given path's format is not supported` and BizHawk crashes on startup.

**Workaround that WORKS:** Copy the ROM and the Lua script into a short, space-free, dot-free directory such as `C:\tmp\` and launch from there.

```bash
mkdir -p /c/tmp
cp "<worktree>/builds/whatif.md" /c/tmp/whatif.md
cp "<path-to-lua>" /c/tmp/<script-name>.lua
```

## Launch command (EXACT working form)

Use PowerShell `Start-Process` with a COMMA-SEPARATED `-ArgumentList`. Each element is a single-quoted PowerShell string — do NOT use escaped double quotes. This is the only form that has been verified to launch both a ROM and a Lua script reliably.

**With Lua script (the normal case):**

```bash
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList '--lua=C:\tmp\<script>.lua','C:\tmp\whatif.md' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

**Without Lua script (ROM only):**

```bash
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList 'C:\tmp\whatif.md' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

### What does NOT work (do not use any of these)

- `cmd.exe /c "cd /d ... && start EmuHawk.exe ..."` — Git Bash mangles `/c` and `/d` into path prefixes.
- `cmd.exe //c "..."` with `start ""` — intermittently returns `Access is denied` and never launches GUI.
- Bat files or `&` backgrounding from bash.
- `-ArgumentList '\"--lua=PATH\",\"ROM\"'` with escaped quotes — may launch but passes both as one garbled arg.
- Any path containing `.claude`, `FINAL TRY`, or a worktree path, passed directly to `--lua=` or as the ROM.

## Verification after launch

Immediately after launching, verify EmuHawk is actually alive. Bash's exit code from `powershell Start-Process` is meaningless (it always returns 0 even if Start-Process failed internally), so do this:

```bash
cd /c && cmd.exe //c "tasklist" 2>&1 | grep -i hawk
```

Expected: one line like `EmuHawk.exe   <PID>   Console   1   <mem> K`. A healthy ROM-loaded process is typically 250–700 MB resident. If nothing shows up, the launch failed silently — re-check the path rules above.

## Memory-domain gotcha when writing Lua probes

BizHawk's `68K RAM` domain for Genesis is ONLY 64 KB (work RAM), indexed `0..0xFFFF`. It is NOT the full M68K address space. To read from M68K `$FF0B00`, use offset `0x0B00` in the `68K RAM` domain:

```lua
memory.read_u8(0x0B00, "68K RAM")   -- reads $FF0B00
```

Using `0xFF0B00` will produce `attempted read of 16714496 outside the memory size of 65536` warnings and return zero.

## gui.text signature gotcha

In this BizHawk version, prefer the 3-argument form `gui.text(x, y, text)`. The 6-argument form with color + anchor (`gui.text(x, y, text, fg, bg, "bottomleft")`) throws `NLua.Exceptions.LuaScriptException: Invalid arguments to method call`.

## Workflow summary

1. Stage files: `cp "<worktree>/builds/whatif.md" /c/tmp/whatif.md` and copy the Lua script to `C:\tmp\<name>.lua`.
2. Launch with the exact PowerShell command form above, using only `C:\tmp\` paths.
3. Verify with `tasklist | grep -i hawk`.
4. Open `Tools → Lua Console` in BizHawk to view script output.

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
2. If the argument is a relative path, prepend the project root: `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\`
3. The ROM is always: `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md`
4. The BizHawk directory is: `C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64`
5. The executable is `EmuHawk.exe` inside that directory.

## Launch command

Use PowerShell `Start-Process` — this is the only reliable way to launch BizHawk GUI from Claude Code on this system.

**Without Lua script (ROM only):**

```bash
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList '\"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md\"' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

**With Lua script:**

```bash
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList '\"--lua=<ABSOLUTE_SCRIPT_PATH>\",\"<ROM_PATH>\"' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

## Rules

- Always use `powershell -Command "Start-Process ..."` to launch.
- All paths must be absolute Windows paths with backslashes.
- Verify the Lua script file exists before launching.
- Do NOT use `cmd.exe /c`, `start ""`, bat files, or `&` backgrounding.

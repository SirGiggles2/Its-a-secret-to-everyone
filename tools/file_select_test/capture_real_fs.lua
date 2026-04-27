-- capture_real_fs.lua: boot Redux NES ROM, advance to FS, screenshot.
-- Uses Windows backslash paths per memory feedback_bizhawk_lua_paths.md.

local REPO_ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\.claude\\worktrees\\native-file-select"
local OUT_PNG   = REPO_ROOT .. "\\tools\\file_select_test\\cmp\\real_redux_fs.png"

os.execute('mkdir "' .. REPO_ROOT .. '\\tools\\file_select_test\\cmp" 2>nul')

-- Boot. Advance past title sequence.
for f = 1, 300 do emu.frameadvance() end

-- Press Start to enter FS.
joypad.set({ ["P1 Start"] = true }, 1)
emu.frameadvance()
emu.frameadvance()
joypad.set({}, 1)

-- Settle on FS screen.
for f = 1, 240 do emu.frameadvance() end

client.screenshot(OUT_PNG)
print("[capture_real_fs] PNG saved to " .. OUT_PNG)
client.exit()

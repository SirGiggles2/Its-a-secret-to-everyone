-- probe_fs_midi_lifecycle.lua
-- NEW-v3.4 verification probe: confirms FS MIDI subsystem activates on FS entry
-- and deactivates on FS exit, and that music_player runtime state advances
-- (proves MIDI is actually playing, not just a flag flip).

local FLAG       = 0xFFE120  -- s_music_midi_active
local NES_GM     = 0xFF0012  -- NES gamemode
local MS_PLAY    = 0xFFE140  -- MIDI_STATE.MS_PLAY_PTR (long)
local MS_TIME    = 0xFFE14C  -- MIDI_STATE.MS_TIME_NEXT (word)

local out_path = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/music_test/out/fs_midi_lifecycle.txt"
os.execute('mkdir "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\tools\\music_test\\out" 2>nul')

local f = io.open(out_path, "w")
if not f then print("FAIL: cannot open output") return end

f:write("phase, frame, gamemode, midi_active, ms_play_ptr, ms_time_next\n")

local function snap(label)
    local gm   = memory.readbyte(NES_GM,  "M68K BUS")
    local fl   = memory.readbyte(FLAG,    "M68K BUS")
    local pp   = memory.read_u32_be(MS_PLAY, "M68K BUS")
    local tn   = memory.read_u16_be(MS_TIME, "M68K BUS")
    f:write(string.format("%s, %d, 0x%02X, 0x%02X, 0x%08X, 0x%04X\n",
        label, emu.framecount(), gm, fl, pp, tn))
end

-- Brief boot blanking (~1s), then snapshot
for i = 1, 60 do emu.frameadvance() end
snap("title")

-- Press Start to advance to FS
for i = 1, 4 do
    joypad.set({Start = true}, 1)
    emu.frameadvance()
end
joypad.set({Start = false}, 1)

-- Wait for gamemode to flip + flag to flip
for i = 1, 30 do emu.frameadvance() end
snap("fs_t1")

for i = 1, 60 do emu.frameadvance() end
snap("fs_t2")

-- Screenshot mid-FS to inspect rendering state
client.screenshot("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/music_test/out/fs_screenshot.png")

for i = 1, 120 do emu.frameadvance() end
snap("fs_t3")

-- Press A to attempt slot pick
for i = 1, 4 do
    joypad.set({A = true}, 1)
    emu.frameadvance()
end
joypad.set({A = false}, 1)

for i = 1, 60 do emu.frameadvance() end
snap("post_A")

f:close()
client.exit()

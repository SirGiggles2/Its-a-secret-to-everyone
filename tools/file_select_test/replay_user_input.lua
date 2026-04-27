-- replay_user_input.lua — replay timing captured by record_input.lua
-- (frames 121-124 = Start). Capture screen 60 frames after Start.
local OUT = "C:\\tmp\\fs_play_replay.png"
local PROBE = "C:\\tmp\\fs_play_probe.txt"

while emu.framecount() < 121 do emu.frameadvance() end
joypad.set({ Start = true }, 1)
while emu.framecount() < 125 do emu.frameadvance() end
joypad.set({}, 1)
for f = 1, 60 do emu.frameadvance() end

-- Press A on slot 0 (cursor default) to trigger FS_HANDOFF.
joypad.set({ A = true }, 1)
for f = 1, 4 do emu.frameadvance() end
joypad.set({}, 1)
for f = 1, 120 do emu.frameadvance() end

client.screenshot(OUT)
local p   = memory.read_u8(0x07F2, "68K RAM")
local vbm = memory.read_u8(0x0FFC, "68K RAM")
local gm  = memory.read_u8(0x0012, "68K RAM")
local sm  = memory.read_u8(0x0013, "68K RAM")
local fh = io.open(PROBE, "w")
fh:write(string.format("frame=%d probe=%02X vblank=%02X gm=%02X sm=%02X\n",
    emu.framecount(), p, vbm, gm, sm))
fh:close()
client.exit()

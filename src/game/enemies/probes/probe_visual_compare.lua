-- probe_visual_compare.lua — full gameplay snapshot for NES-vs-Genesis diff.
-- Boot Debug.md, enter debug mode, take screenshots at:
--   0: room $77 (cave entrance) — Link boot pose, sword level 1
--   1: walk LEFT into room $76 — first enemies (octoroks)
--   2: swing sword 60 frames — should hit/kill octoroks
--   3: room $76 settled post-combat
-- Output: C:\tmp\probe_visual_{0..3}.png + .txt with HUD state
--
-- BizHawk Genesis joypad names: CamelCase {Left=true} not {LEFT=true}.

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end
local function hold(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local OUT = "C:\\tmp\\probe_visual_compare.txt"
local f = io.open(OUT, "w")
f:write("probe_visual_compare\n====================\n\n")

local function snap(tag, shot_path)
    f:write(string.format("== %s ==\n", tag))
    f:write(string.format("  frame=%d GameMode=$%02X RoomId=$%02X\n",
        emu.framecount(), R(0x0012), R(0x00EB)))
    f:write(string.format("  Link=($%02X,$%02X) face=$%02X\n",
        R(0x0070), R(0x0084), R(0x008C)))
    f:write(string.format("  inv: sword=$%02X bombs=$%02X rupees=$%02X keys=$%02X\n",
        R(0x0657), R(0x0658), R(0x065B), R(0x066E)))
    f:write(string.format("  hearts: cur=$%02X max=$%02X partial=$%02X\n",
        R(0x066F), R(0x067C), R(0x0670)))
    local alive = 0
    for slot=1,11 do
        if R(0x0492 + slot) ~= 0 then alive = alive + 1 end
    end
    f:write(string.format("  enemies_alive=%d\n", alive))
    for slot=1,11 do
        if R(0x0492 + slot) ~= 0 then
            f:write(string.format("    slot%02d: type=$%02X hp=$%02X xy=($%02X,$%02X)\n",
                slot, R(0x034F + slot), R(0x0485 + slot),
                R(0x0070 + slot), R(0x0084 + slot)))
        end
    end
    f:write("\n")
    if shot_path then client.screenshot(shot_path) end
end

-- Boot + enter debug-mode gameplay.
idle(40)
press({A=true, B=true, C=true}, 30)
idle(60)
snap("0 room $77 cave entrance start", "C:\\tmp\\probe_visual_0.png")

-- Walk LEFT 120 frames to scroll into room $76.
hold({Left=true}, 120)
idle(60)
snap("1 room $76 entered (post-scroll)", "C:\\tmp\\probe_visual_1.png")

-- Swing sword 60 frames — repeated A taps. NES sword needs face+A.
for i=1,30 do
    joypad.set({A=true}, 1); emu.frameadvance()
    joypad.set({}, 1); emu.frameadvance()
end
snap("2 post-sword-swing 60 frames", "C:\\tmp\\probe_visual_2.png")

-- Settle 60 frames, see what's left.
idle(60)
snap("3 room $76 settled", "C:\\tmp\\probe_visual_3.png")

f:close()
client.exit()

-- probe_scroll_transition.lua — verify OW room scroll transition.
-- Boots Debug.md, enters debug mode, walks Link west off room $77
-- into room $76. Snapshots before/during/after, takes screenshots.
--
-- NES truth: OW room $77 is starting room (cave entrance). Walking
-- west scrolls into room $76 — same nibble pattern wraps via the
-- column-decrement scroll path. Room $76 has enemies (octoroks).
--
-- Output: C:\tmp\probe_scroll_transition_{0,1,2}.png + .txt

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local OUT = "C:\\tmp\\probe_scroll_transition.txt"

-- Boot + enter debug-mode gameplay.
idle(40)
press({A=true, B=true, C=true}, 30)
idle(60)

local f = io.open(OUT, "w")
f:write("probe_scroll_transition\n========================\n\n")

local function snap(tag, shot_path)
    f:write(string.format("== %s ==\n", tag))
    f:write(string.format("  frame=%d GameMode=$%02X RoomId=$%02X\n",
        emu.framecount(), R(0x0012), R(0x00EB)))
    f:write(string.format("  Link=($%02X,$%02X) face=$%02X scroll_dir=$%02X\n",
        R(0x0070), R(0x0084), R(0x008C), R(0x0011)))
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

-- Snapshot 0: pre-walk (room $77 start).
snap("pre-walk room $77", "C:\\tmp\\probe_scroll_transition_0.png")

-- Phase: walk LEFT 120 frames to scroll west into room $76.
-- BizHawk Genesis button names: CamelCase {Left=true} not {LEFT=true}.
for f_n=1,120 do
    joypad.set({Left=true}, 1)
    emu.frameadvance()
end

-- Snapshot 1: mid-scroll or post-scroll.
snap("post-walk 120 frames LEFT", "C:\\tmp\\probe_scroll_transition_1.png")

-- Idle 60 frames more for scroll to settle.
idle(60)

snap("settled +60 frames", "C:\\tmp\\probe_scroll_transition_2.png")

-- Phase: try walking RIGHT 60 frames (should re-enter $77 or hold).
for f_n=1,60 do
    joypad.set({Right=true}, 1)
    emu.frameadvance()
end

snap("after RIGHT 60", "C:\\tmp\\probe_scroll_transition_3.png")

f:close()
gui.text(8, 8, string.format("scroll: room=$%02X", R(0x00EB)))
client.exit()

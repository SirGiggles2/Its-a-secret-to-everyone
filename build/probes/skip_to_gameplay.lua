-- Phase W: hit A+B+C+Start chord at title to advance through FS to
-- gameplay. Tries multiple BizHawk Genesis button name styles since
-- prior probe with {Start=true} did not advance.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or "."
local SHOTS = OUT .. "/shots"
os.execute('mkdir "' .. SHOTS:gsub("/", "\\") .. '" 2>nul')

local function shot(n)
    client.screenshot(SHOTS .. "/" .. n)
    print("shot: " .. n .. " frame=" .. emu.framecount())
end

local function press_all(label, frames)
    -- Hold every plausible button name for `frames` frames
    local btns = {
        Start = true, S = true,
        A = true, B = true, C = true,
        ["P1 Start"] = true, ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true,
    }
    for i = 1, frames do
        joypad.set(btns, 1)
        emu.frameadvance()
    end
    joypad.set({}, 1)
    for i = 1, 8 do emu.frameadvance() end
    if label then shot(label) end
end

-- Boot wait
for i = 1, 120 do emu.frameadvance() end
shot("w1_title.png")

-- Burst 1: chord at title -> handoff to FS
press_all("w2_after_chord_1.png", 12)
for i = 1, 90 do emu.frameadvance() end
shot("w3_settle_1.png")

-- Burst 2: chord at FS -> select file -> gameplay
press_all("w4_after_chord_2.png", 12)
for i = 1, 120 do emu.frameadvance() end
shot("w5_settle_2.png")

-- Burst 3: any extra screen
press_all("w6_after_chord_3.png", 12)
for i = 1, 120 do emu.frameadvance() end
shot("w7_settle_3.png")

-- Final state dump
local game_mode = memory.read_u8(0x0012, "68K RAM")
local game_submode = memory.read_u8(0x0013, "68K RAM")
local cur_room = memory.read_u8(0x00EB, "68K RAM")
local cur_level = memory.read_u8(0x0010, "68K RAM")
local intro_sentinel = memory.read_u8(0x07FF, "68K RAM")
local intro_phase = memory.read_u8(0x07F0, "68K RAM")
local handoff_flag = memory.read_u8(0x07F2, "68K RAM")
print(string.format("RAM: GameMode=$%02X Submode=$%02X CurRoom=$%02X CurLevel=$%02X intro_sentinel=$%02X phase=$%02X handoff=$%02X",
    game_mode, game_submode, cur_room, cur_level, intro_sentinel, intro_phase, handoff_flag))

local f = io.open(SHOTS .. "/skip_to_gameplay.log", "w")
f:write(string.format("end frame=%d\n", emu.framecount()))
f:write(string.format("GameMode=$%02X Submode=$%02X CurRoom=$%02X CurLevel=$%02X\n",
    game_mode, game_submode, cur_room, cur_level))
f:write(string.format("intro_sentinel=$%02X (expect $A1 if intro_main entered)\n", intro_sentinel))
f:write(string.format("intro_phase=$%02X (PHASE enum at nes_ram[$07F0])\n", intro_phase))
f:write(string.format("handoff_flag=$%02X (expect $AA if intro_start_pressed fired)\n", handoff_flag))
if game_mode == 0x05 then
    f:write("RESULT: gameplay reached (Mode 5 Play)\n")
elseif handoff_flag == 0xAA then
    f:write("RESULT: passed intro handoff but stuck pre-gameplay (FS likely)\n")
elseif intro_sentinel == 0xA1 then
    f:write("RESULT: in intro, chord did not trigger handoff\n")
else
    f:write("RESULT: pre-intro or post-crash\n")
end
f:close()
print("done")

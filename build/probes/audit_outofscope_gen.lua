-- A3 Out-of-Scope baseline — Genesis side.
-- Captures Octorok ($07-$0A) + Tektite ($0D-$0E) state for 240 frames
-- after force-spawning each type into slot 1 via the FX probe arm.
-- Output: C:\tmp\baseline_outofscope_gen.txt
--
-- Probe arm: $FF77D0 magic = 'F','X' (0x46, 0x58)
-- Format: [magic_0=$46][magic_1=$58][type][x][y][dir][slot][habitat][room]
-- See src/game/enemies/enemy_loop.c:1215 (enemy_loop_probe_force_spawn_arm).

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

-- Enter ROOMROM mode.
idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

local f = io.open("C:/tmp/baseline_outofscope_gen.txt", "w")
f:write("# Genesis out-of-scope baseline | type slot fr T:X:Y:D:Q:A:HP:St:Ms:Tm:StTm:Hit:SDir:SDist\n")

local OUT_OF_SCOPE_TYPES = {0x07, 0x08, 0x09, 0x0A, 0x0D, 0x0E}

for _, t in ipairs(OUT_OF_SCOPE_TYPES) do
    -- Arm force-spawn: slot 1, x=$80, y=$78, dir=$01 (right), habitat=0 (OW), room=$77.
    W(0x77D0, 0x46)  -- 'F'
    W(0x77D1, 0x58)  -- 'X'
    W(0x77D2, t)
    W(0x77D3, 0x80)
    W(0x77D4, 0x78)
    W(0x77D5, 0x01)
    W(0x77D6, 0x01)
    W(0x77D7, 0x00)
    W(0x77D8, 0x77)
    emu.frameadvance()

    -- Wait for spawn to land.
    for _ = 1, 4 do emu.frameadvance() end

    -- Force-poke Random[0..12] for deterministic AI.
    W(0x8018, 0x40)
    for i = 1, 12 do W(0x8018 + i, 0x00) end

    -- Capture 240 frames.
    for fr = 0, 239 do
        local slot = 1
        f:write(string.format(
            "T$%02X s%d f%3d %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n",
            t, slot, fr,
            R(0x834F + slot), R(0x8070 + slot), R(0x8084 + slot),
            R(0x808C + slot), R(0x83BC + slot), R(0x84BF + slot),
            R(0x84B8 + slot), R(0x80AC + slot), R(0x84D8 + slot),
            R(0x8028 + slot), R(0x803D + slot), R(0x84F0 + slot),
            R(0x8490 + slot), R(0x8498 + slot)))
        emu.frameadvance()
    end

    -- Clear arm + slot before next type.
    W(0x77D0, 0)
    W(0x77D1, 0)
    -- enemy_loop_force_spawn clears all slots itself when re-armed.
end

f:close()
client.exit()

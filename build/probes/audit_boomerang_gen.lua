-- $5C boomerang live test. Spawn $05 Blue Goriya via FX arm. Wait for
-- boomerang spawn ($5C in another slot). Capture state machine
-- transitions for 600 frames.
--
-- Goriya shoot path: enrt_walker_set_input_dir_and_try_shooting_boomerang
-- spawns $5C in empty slot when ENEMY_MOVE_TIMER==0 + ObjWantsToShoot==1.
-- Goriya pre-state slot needs to be in goriya AI body.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

-- FX-spawn $05 BlueGoriya at slot 1.
W(0x77D0, 0x46) W(0x77D1, 0x58)
W(0x77D2, 0x05) W(0x77D3, 0x80) W(0x77D4, 0x78)
W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
emu.frameadvance()
idle(5)

-- Random poke.
W(0x8018, 0x40)
for i = 1, 12 do W(0x8018 + i, 0x00) end

local f = io.open("C:/tmp/audit_boomerang_gen.txt", "w")
f:write("# $5C boomerang live test - Goriya $05 in slot 1, watching all slots for boomerang\n")
f:write("# fields: fr | s1 (Goriya): T X Y D Q St Tm WTS | s_boom (boomerang): T X Y D Q State ObjMovingLimit ObjRefId GridOff\n")
f:write("\n")

local last_boom_slot = nil

for fr = 0, 599 do
    local gs = 1
    -- Find boomerang slot (any $5C across slots 2..11).
    local bs = nil
    for s = 2, 11 do
        if R(0x834F + s) == 0x5C then
            bs = s
            break
        end
    end

    if bs and not last_boom_slot then
        f:write(string.format("# >>> boomerang spawned at slot %d frame %d <<<\n", bs, fr))
        last_boom_slot = bs
    elseif not bs and last_boom_slot then
        f:write(string.format("# <<< boomerang slot %d destroyed at frame %d <<<\n", last_boom_slot, fr))
        last_boom_slot = nil
    end

    -- Goriya cells.
    local gline = string.format("fr%3d gs%d T$%02X X$%02X Y$%02X D$%02X Q$%02X St$%02X Tm$%02X WTS$%02X",
        fr, gs,
        R(0x834F + gs), R(0x8070 + gs), R(0x8084 + gs),
        R(0x8098 + gs), R(0x83BC + gs), R(0x80AC + gs),
        R(0x8028 + gs), R(0x8412 + gs))

    if bs then
        local bline = string.format(" | bs%d T$%02X X$%02X Y$%02X D$%02X Q$%02X State$%02X ML$%02X Ref$%02X GO$%02X",
            bs,
            R(0x834F + bs), R(0x8070 + bs), R(0x8084 + bs),
            R(0x8098 + bs), R(0x83BC + bs), R(0x80AC + bs),
            R(0x8380 + bs), R(0x842C + bs), R(0x8394 + bs))
        f:write(gline .. bline .. "\n")
    else
        f:write(gline .. "\n")
    end

    emu.frameadvance()
end

f:close()
client.exit()

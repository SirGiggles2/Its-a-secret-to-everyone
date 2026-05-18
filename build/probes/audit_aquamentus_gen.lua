-- Live verify B6.1: Aquamentus shove-reset tail fires.
-- Spawn $3D Aquamentus via FX arm. Manually set ObjShoveDir to $07
-- pre-frame. After enrt_update_aquamentus runs, c_reset_shove_info
-- should zero it. Capture ObjShoveDir + ObjMetastate over 30 frames.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

-- FX-spawn Aquamentus slot 1.
W(0x77D0, 0x46) W(0x77D1, 0x58)
W(0x77D2, 0x3D) W(0x77D3, 0x80) W(0x77D4, 0x78)
W(0x77D5, 0x02) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
emu.frameadvance()
idle(5)

-- Force-poke Random.
W(0x8018, 0x40)
for i = 1, 12 do W(0x8018 + i, 0x00) end

local f = io.open("C:/tmp/audit_aquamentus_gen.txt", "w")
f:write("# Aquamentus shove-reset live verify\n")
f:write("# Each iter: poke ObjShoveDir=$07 BEFORE frame, log AFTER frame.\n")
f:write("# Post-fix: ObjShoveDir should be $00 after frame (reset_shove_info ran).\n")
f:write("# Pre-fix:  ObjShoveDir would remain $07 (tail never ran).\n")
f:write("# Also log ObjShoveDistance ($04C9+slot), Metastate ($04D8+slot).\n")
f:write("\n")
f:write("iter pre_ShDir pre_ShDist post_ShDir post_ShDist post_Meta\n")

for iter = 0, 9 do
    -- Poke shove cells BEFORE frame.
    W(0x80C1, 0x07)  -- ObjShoveDir[slot 1] = $07
    W(0x84CA, 0x10)  -- ObjShoveDistance[slot 1] = $10 (approx)
    local pre_dir  = R(0x80C1)
    local pre_dist = R(0x84CA)

    emu.frameadvance()  -- Aquamentus update runs

    local post_dir  = R(0x80C1)
    local post_dist = R(0x84CA)
    local post_meta = R(0x84D9)

    f:write(string.format("%2d %02X %02X %02X %02X %02X\n",
        iter, pre_dir, pre_dist, post_dir, post_dist, post_meta))
end

f:close()
client.exit()

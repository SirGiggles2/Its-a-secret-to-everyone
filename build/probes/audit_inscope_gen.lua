-- Live audit probe — Genesis side. Force-spawns each in-scope enemy
-- type via FX arm and captures T1 cells for 240 frames.
--
-- Captured cells per slot per frame:
--   T:type X:obj_x Y:obj_y D:dir Q:qspeed_frac St:state Ms:metastate
--   ATt:obj_timer ST:shoot_timer WTS:wants_to_shoot HR:hit_reaction
--   SHD:shove_dir SHS:shove_dist HP:mon_hp INV:invincibility_mask

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

local f = io.open("C:/tmp/audit_inscope_gen.txt", "w")
f:write("# Genesis in-scope audit | fields: type slot fr T X Y D Q St Ms Tm SHT WTS HR ShDir ShDist HP InvMsk\n")

local IN_SCOPE = {
    -- Walker
    0x01, 0x02,            -- Lynel
    0x03, 0x04,            -- Moblin
    0x05, 0x06,            -- Goriya
    0x0B, 0x0C,            -- Darknut
    0x10,                  -- Rope
    0x12,                  -- Vire
    0x13, 0x14, 0x15,      -- Zol/RedZol/Gel
    0x16, 0x17,            -- PolsVoice/LikeLike
    0x1E,                  -- Armos
    0x21,                  -- Ghini
    0x27,                  -- Wallmaster
    0x28,                  -- Rope (alt)
    0x2A,                  -- Stalfos
    0x2B, 0x2C, 0x2D,      -- Bubble
    0x30,                  -- Gibdo
    0x3F, 0x40,            -- GuardFire / StandingFire
    -- Flyer
    0x1A,                  -- Peahat
    0x1B, 0x1C, 0x1D,      -- Keese
    0x22,                  -- FlyingGhini
    -- Jumper
    0x0F,                  -- BlueLeever
    -- Projectile + monster shots wire to spawner; tested separately
}

for _, t in ipairs(IN_SCOPE) do
    -- Arm force-spawn: slot 1, x=$80 y=$78 dir=$01 (right) habitat=0(OW) room=$77.
    W(0x77D0, 0x46) W(0x77D1, 0x58)
    W(0x77D2, t) W(0x77D3, 0x80) W(0x77D4, 0x78)
    W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
    emu.frameadvance()
    for _ = 1, 4 do emu.frameadvance() end

    -- Force-poke Random for deterministic AI.
    W(0x8018, 0x40)
    for i = 1, 12 do W(0x8018 + i, 0x00) end

    -- Capture 240 frames.
    for fr = 0, 239 do
        local s = 1
        f:write(string.format(
            "T$%02X s%d f%3d %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X\n",
            t, s, fr,
            R(0x834F+s),   -- type
            R(0x8070+s),   -- X
            R(0x8084+s),   -- Y
            R(0x808C+s),   -- dir (NES ObjDir+1 at 0x8C+slot... actually facing dir = 0x0098, let me use real one)
            R(0x83BC+s),   -- qspd
            R(0x80AC+s),   -- state
            R(0x84D8+s),   -- metastate
            R(0x8028+s),   -- obj timer
            R(0x8451+s),   -- shoot timer
            R(0x8412+s),   -- wants to shoot
            R(0x84F0+s),   -- hit reaction
            R(0x80C0+s),   -- shove dir
            R(0x84C9+s),   -- shove dist (approx — best guess)
            R(0x84B8+s),   -- HP
            R(0x84B2+s),   -- invincibility mask
            R(0x8098+s),   -- facing dir (real)
            0))
        emu.frameadvance()
    end

    W(0x77D0, 0) W(0x77D1, 0)
end

f:close()
client.exit()

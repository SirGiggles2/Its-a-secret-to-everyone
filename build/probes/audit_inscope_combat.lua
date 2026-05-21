-- audit_inscope_combat.lua — extends audit_inscope_gen to cover
-- combat dimensions (knockback, drops, respawn). For each in-scope
-- enemy type:
--   1. Spawn via $FF77D0 arm at (x=$60, y=$78), Link at slot 0
--      auto at $80,$78 — adjacent.
--   2. Wait 4 frames for spawn settle.
--   3. Capture pre-hit state.
--   4. Simulate sword damage by force-decrementing MON_HP to 0,
--      then write COMBAT_DAMAGE_AMOUNT to trigger death path on
--      next tick.
--   5. Capture per-frame for 30f post-damage:
--      ShoveDir, ShoveDist, MON_HP, ENEMY_HIT_REACTION, alive flag
--   6. Capture frame of drop spawn (look for new slot type $60..$66).
--   7. Re-arm same room, observe if enemy persists (respawn test).

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

-- Boot + chord to enter gameplay
idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

local f = io.open("C:/tmp/audit_inscope_combat.txt", "w")
f:write("# Genesis in-scope combat audit\n")
f:write("# fields: type evt frame hp inv_react shove_dir shove_dist alive_flag drop_slot drop_type\n")

local IN_SCOPE = {
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06,    -- Lynel/Moblin/Goriya
    0x0B, 0x0C,                             -- Darknut
    0x10,                                   -- Rope (walker)
    0x12,                                   -- Vire
    0x13, 0x14, 0x15,                       -- Zol/RedZol/Gel
    0x16, 0x17,                             -- PolsVoice/LikeLike
    0x1A,                                   -- Peahat
    0x1B, 0x1C, 0x1D,                       -- Keese
    0x1E,                                   -- Armos
    0x21,                                   -- Ghini
    0x22,                                   -- FlyingGhini
    0x27,                                   -- Wallmaster
    0x28,                                   -- Rope (alt)
    0x2A,                                   -- Stalfos
    0x2B, 0x2C, 0x2D,                       -- Bubble
    0x30,                                   -- Gibdo
    0x3F, 0x40,                             -- GuardFire/StandingFire
}

for _, t in ipairs(IN_SCOPE) do
    -- Spawn enemy slot 1 adjacent to Link
    W(0x77D0, 0x46) W(0x77D1, 0x58)
    W(0x77D2, t) W(0x77D3, 0x60) W(0x77D4, 0x78)
    W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, 0x00) W(0x77D8, 0x77)
    emu.frameadvance()
    for _ = 1, 4 do emu.frameadvance() end

    -- Force RNG seed deterministic
    W(0x8018, 0x40)
    for i = 1, 12 do W(0x8018 + i, 0x00) end

    local s = 1
    local pre_hp = R(0x8485+s)
    f:write(string.format("T$%02X PRE  f0  hp=%02X inv=%02X shdir=%02X shdist=%02X alive=%02X\n",
        t, pre_hp, R(0x84F0+s), R(0x80C0+s), R(0x80D3+s), R(0x8492+s)))

    -- Simulate sword damage: force MON_HP to lethal value + shove_dir
    -- to right (Link facing right when adjacent). Real sword swing
    -- collision would trigger combat_deal_damage. Simulate end state:
    -- HP=0 -> combat_handle_monster_died fires next tick.
    W(0x8485+s, 0x00)        -- MON_HP = 0
    W(0x80C0+s, 0x01)        -- shove dir = right
    W(0x80D3+s, 0x10)        -- shove dist = 16px

    for fr = 1, 30 do
        emu.frameadvance()
        local alive = R(0x8492+s)
        local hp = R(0x8485+s)
        local shdir = R(0x80C0+s)
        local shdist = R(0x80D3+s)
        local inv = R(0x84F0+s)
        f:write(string.format("T$%02X POST f%-2d hp=%02X inv=%02X shdir=%02X shdist=%02X alive=%02X\n",
            t, fr, hp, inv, shdir, shdist, alive))
    end

    -- Drop check: scan all slots for type $60-$66 (DroppedItem)
    local drop_slot = -1
    local drop_type = 0
    for ds = 1, 11 do
        local dt = R(0x834F+ds)
        if dt >= 0x60 and dt <= 0x66 then
            drop_slot = ds
            drop_type = dt
            break
        end
    end
    f:write(string.format("T$%02X DROP slot=%d type=%02X\n", t, drop_slot, drop_type))

    -- Respawn check: clear current spawn + re-arm same room, see if
    -- enemy re-appears or stays gone.
    -- (Skip for now — would require full room re-load via load_room
    --  which isn't trivially probe-triggerable without scene change.)

    -- Clear arm magic
    W(0x77D0, 0) W(0x77D1, 0)
end

f:close()
client.exit()

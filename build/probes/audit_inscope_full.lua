-- audit_inscope_full.lua — comprehensive Genesis-side enemy parity audit.
-- Extends audit_inscope_gen + audit_inscope_combat:
--   1. Adds boss family $31-$48 (Aquamentus, Dodongo, Gohma, Gleeok, etc.)
--   2. Per-type knockback (shdist countdown trace per type for 20 frames)
--   3. Drop sub-type capture (which item dropped per kill)
--
-- Each type yields one row to stdout:
--   T$XX init=HP,Inv,Tm knockback=shdist_decrement_seq drop=item_subtype

local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

-- Boot to gameplay
idle(60)
for _ = 1, 30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
joypad.set({},1)
idle(60)

local f = io.open("C:/tmp/audit_inscope_full.txt", "w")
f:write("# Comprehensive Genesis enemy audit — init + knockback + drop\n")
f:write("# format: type init_HP init_Inv init_Tm init_qspd knockback_seq drop_item_subtype\n")

local ALL_TYPES = {
    -- Walker
    {0x01, "BlueLynel"},   {0x02, "RedLynel"},
    {0x03, "BlueMoblin"},  {0x04, "RedMoblin"},
    {0x05, "BlueGoriya"},  {0x06, "RedGoriya"},
    {0x0B, "BlueDarknut"}, {0x0C, "RedDarknut"},
    {0x10, "RedLeever"},   -- jumper but probe-friendly
    {0x12, "Vire"},
    {0x13, "Zol"},         {0x14, "RedZol"},     {0x15, "Gel"},
    {0x16, "PolsVoice"},   {0x17, "LikeLike"},
    {0x1A, "Peahat"},
    {0x1B, "BlueKeese"},   {0x1C, "RedKeese"},   {0x1D, "BlackKeese"},
    {0x1E, "Armos"},
    {0x21, "Ghini"},       {0x22, "FlyingGhini"},
    {0x27, "Wallmaster"},  {0x28, "Rope"},
    {0x2A, "Stalfos"},
    {0x2B, "BlueBubble"},  {0x2C, "RedBubble"},  {0x2D, "BlueBubble2"},
    {0x30, "Gibdo"},
    {0x3F, "GuardFire"},   {0x40, "StandingFire"},
    -- Boss family (audit extension)
    {0x31, "Dodongo1"},    {0x32, "Dodongo2"},
    {0x33, "BlueGohma"},   {0x34, "RedGohma"},
    {0x38, "DigdoggerL"},  {0x39, "DigdoggerS"},
    {0x3A, "RedLamnola"},  {0x3B, "BlueLamnola"},
    {0x3C, "Manhandla"},
    {0x3D, "Aquamentus"},
    {0x3E, "Ganon"},
    {0x41, "Moldorm"},
    {0x47, "RedPatra"},    {0x48, "BluePatra"},
}

for _, entry in ipairs(ALL_TYPES) do
    local t, name = entry[1], entry[2]

    -- Arm spawn: slot 1, adjacent to Link at $80,$78. Use UW habitat
    -- for boss types (need dungeon environment for some), OW for rest.
    local habitat = (t >= 0x31 and t <= 0x48) and 0x01 or 0x00
    local room = (habitat == 1) and 0x35 or 0x77   -- boss room $35 for UW

    W(0x77D0, 0x46) W(0x77D1, 0x58)
    W(0x77D2, t) W(0x77D3, 0x60) W(0x77D4, 0x78)
    W(0x77D5, 0x01) W(0x77D6, 0x01) W(0x77D7, habitat) W(0x77D8, room)
    emu.frameadvance()
    for _ = 1, 4 do emu.frameadvance() end

    -- Force RNG deterministic
    W(0x8018, 0x40)
    for i = 1, 12 do W(0x8018 + i, 0x00) end

    local s = 1
    local init_hp = R(0x8485+s)
    local init_inv = R(0x84B2+s)
    local init_tm = R(0x8028+s)
    local init_qspd = R(0x83BC+s)

    -- Knockback: poke shdir=right + shdist=$10, trace decrement over 20 frames
    W(0x80C0+s, 0x01)
    W(0x80D3+s, 0x10)
    local knockback_seq = {}
    for fr = 1, 20 do
        emu.frameadvance()
        knockback_seq[#knockback_seq+1] = string.format("%02X", R(0x80D3+s))
    end

    -- Death dispatch: combat_force_kill via $FF77E0
    W(0x77E0, 0x44) W(0x77E1, 0x44)
    W(0x77E2, s) W(0x77E3, 0x10) W(0x77E4, 0xFF)
    emu.frameadvance()
    -- Wait for slot to transition to drop (or stay empty for NoDropTypes)
    for _ = 1, 10 do emu.frameadvance() end

    -- Read drop sub-type. NES DroppedItem at slot=$60 type; sub-type may be
    -- in ObjState or Metastate. Capture multiple candidates.
    local drop_type = R(0x834F+s)
    local drop_state = R(0x80AC+s)
    local drop_meta = R(0x84D8+s)
    local drop_anim = R(0x83E4+s)

    f:write(string.format(
        "T$%02X (%-13s) init=HP%02X,Inv%02X,Tm%02X,Q%02X knockback=%s drop=T%02X,St%02X,Ms%02X,A%02X\n",
        t, name, init_hp, init_inv, init_tm, init_qspd,
        table.concat(knockback_seq, ","),
        drop_type, drop_state, drop_meta, drop_anim))

    -- Clear arms
    W(0x77D0, 0) W(0x77D1, 0)
    W(0x77E0, 0) W(0x77E1, 0)
end

f:close()
client.exit()

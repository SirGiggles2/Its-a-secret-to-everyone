-- Phase 8 Task 8.11 Boss Matrix sweep.
--
-- For each wired boss type, force the boss into slot 1 + tick frames.
-- Goal: prove the dispatch table doesn't crash for any boss type and
-- that the gameplay frame counter keeps advancing across the sweep.
--
-- This is the Phase 8 closing matrix per master plan §Task 8.11:
--   - every boss room can load (proxied: every boss type dispatches)
--   - no sprite overflow failure (frame counter doesn't stall)
-- Kill / reward / room-clear gates need real boss rooms; deferred to
-- Phase 9 dungeon-traversal work where dungeon geometry is wired.

local OUT = os.getenv("CODEX_PROBE_OUT") or "C:/tmp"

-- NES RAM offsets (M68K $FF0000 + offset = "68K RAM" domain offset).
local OBJ_TYPE_BASE   = 0x034F  -- ENEMY_TYPE(slot)
local OBJ_X_BASE      = 0x0070  -- ENEMY_X(slot)
local OBJ_Y_BASE      = 0x0084  -- ENEMY_Y(slot)
local OBJ_AI_STATE    = 0x0444
local OBJ_HP_BASE     = 0x0485
local OBJ_ALIVE_BASE  = 0x0492
local FC_BASE         = 0x7202  -- gameplay frame counter (be u16)

local function tick(n) for _=1,n do emu.frameadvance() end end
local function press(btn, n)
    n = n or 4
    joypad.set(btn, 1)
    tick(n)
    joypad.set({}, 1)
end
local function read_fc()
    return memory.read_u8(FC_BASE, "68K RAM") * 256
         + memory.read_u8(FC_BASE+1, "68K RAM")
end

-- Boot + enter gameplay (Start at title, A+B+C debug entry).
tick(60)
press({Start=true}, 4); tick(40)
joypad.set({A=true, B=true, C=true}, 1); tick(30)
joypad.set({}, 1); tick(60)

local fc_after_enter = read_fc()
print(string.format("BOSS-MATRIX: post-enter fc=%d", fc_after_enter))

-- Boss-type roster (from src/game/enemies/enemy_loop.c init_fns table).
local bosses = {
    {0x31, "dodongo"},
    {0x32, "dodongo_alt"},
    {0x33, "blue_gohma"},
    {0x34, "red_gohma"},
    {0x38, "digdogger1"},
    {0x39, "digdogger2"},
    {0x3A, "lamnola1"},
    {0x3B, "lamnola2"},
    {0x3C, "manhandla"},
    {0x3D, "aquamentus"},
    {0x3E, "ganon"},
    {0x41, "moldorm"},
    {0x42, "gleeok1"},
    {0x43, "gleeok2"},
    {0x44, "gleeok3"},
    {0x45, "gleeok4"},
    {0x46, "gleeok_head"},
    {0x47, "patra1"},
    {0x48, "patra2"},
}

local results = {}
local crashed = false
local prev_fc = read_fc()

for i, entry in ipairs(bosses) do
    local t, name = entry[1], entry[2]

    -- Wipe slots 1..11 so previous boss state can't bleed.
    for slot = 1, 11 do
        memory.write_u8(OBJ_TYPE_BASE   + slot, 0, "68K RAM")
        memory.write_u8(OBJ_X_BASE      + slot, 0, "68K RAM")
        memory.write_u8(OBJ_Y_BASE      + slot, 0, "68K RAM")
        memory.write_u8(OBJ_AI_STATE    + slot, 0, "68K RAM")
        memory.write_u8(OBJ_HP_BASE     + slot, 0, "68K RAM")
        memory.write_u8(OBJ_ALIVE_BASE  + slot, 0, "68K RAM")
    end

    -- Force boss into slot 1.
    memory.write_u8(OBJ_TYPE_BASE  + 1, t,    "68K RAM")
    memory.write_u8(OBJ_X_BASE     + 1, 0x80, "68K RAM")
    memory.write_u8(OBJ_Y_BASE     + 1, 0x80, "68K RAM")
    memory.write_u8(OBJ_AI_STATE   + 1, 0,    "68K RAM")
    memory.write_u8(OBJ_HP_BASE    + 1, 0x40, "68K RAM")
    memory.write_u8(OBJ_ALIVE_BASE + 1, 1,    "68K RAM")

    tick(45)

    local alive  = memory.read_u8(OBJ_ALIVE_BASE  + 1, "68K RAM")
    local typ    = memory.read_u8(OBJ_TYPE_BASE   + 1, "68K RAM")
    local x      = memory.read_u8(OBJ_X_BASE      + 1, "68K RAM")
    local y      = memory.read_u8(OBJ_Y_BASE      + 1, "68K RAM")
    local state  = memory.read_u8(OBJ_AI_STATE    + 1, "68K RAM")
    local hp     = memory.read_u8(OBJ_HP_BASE     + 1, "68K RAM")
    local fc_now = read_fc()
    local fc_delta = fc_now - prev_fc
    prev_fc = fc_now

    if fc_delta < 30 then
        crashed = true
    end

    local row = string.format(
        "$%02X %-12s alive=%d type=$%02X x=%3d y=%3d state=%2d hp=%3d fc=%d delta=%d",
        t, name, alive, typ, x, y, state, hp, fc_now, fc_delta)
    results[#results+1] = row
    print(row)

    client.screenshot(string.format("%s/boss_matrix_%02X_%s.png", OUT, t, name))
end

-- Final frame count.
local fc_final = read_fc()
local f = io.open(OUT .. "/boss_matrix_report.txt", "w")
f:write("Phase 8 Task 8.11 Boss Matrix sweep\n")
f:write("===================================\n\n")
f:write(string.format("post-enter frame_counter = %d\n", fc_after_enter))
f:write(string.format("final frame_counter      = %d\n\n", fc_final))
f:write(string.format("Tested %d boss types:\n\n", #bosses))
for _, r in ipairs(results) do
    f:write(r .. "\n")
end
f:write("\n")
if crashed then
    f:write("VERDICT: at least one boss type stalled the gameplay tick.\n")
else
    f:write("VERDICT: all boss types dispatched without stalling the runtime.\n")
end
f:close()

print(string.format("BOSS-MATRIX: final fc=%d crashed=%s", fc_final, tostring(crashed)))
client.exit()

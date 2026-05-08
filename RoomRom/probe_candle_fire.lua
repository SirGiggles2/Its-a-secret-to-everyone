-- probe_candle_fire.lua — Codex H1..H6 diagnostic
-- Boot UW $73, B_ITEM_BOOMERANG default. Cycle Z 3x to CANDLE,
-- press B, watch $FF7280 (arrow_active). Then dump SAT slot 4.

do
    local ok = pcall(function() memory.usememorydomain("68K RAM") end)
    if not ok then memory.usememorydomain("Main RAM") end
end

local DBG = 0x7280
local fcount = 0
local prev_active = 0

while true do
    local active = memory.read_u8(DBG)
    if active ~= prev_active then
        print(string.format("[f=%d] arrow_active %d -> %d", fcount, prev_active, active))
        prev_active = active
    end

    -- s_b_item = B_ITEM_CANDLE at boot (temp diagnostic).
    -- B press at fcount 200 + every 100 thereafter.
    local input = {}
    if fcount == 200 or fcount == 201 then input.B = true end
    if fcount > 300 and (fcount % 120) == 0 then input.B = true end
    joypad.set(input, 1)

    -- Write state every 30 frames to a log file.
    if fcount % 30 == 0 then
        local f = io.open("C:\\tmp\\candle_fire_log.txt", "a")
        if f then
            f:write(string.format("[f=%d] arrow_active=%d s_b_item_byte=??\n",
                                  fcount, active))
            f:close()
        end
    end

    fcount = fcount + 1
    emu.frameadvance()
end

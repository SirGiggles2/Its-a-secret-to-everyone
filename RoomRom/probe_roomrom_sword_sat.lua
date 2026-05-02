-- probe_roomrom_sword_sat.lua (v2 — domain probe + per-frame screenshot)

local OUT_DIR = "C:\\tmp"
local FACINGS = { "down", "up", "left", "right" }
local DIR_KEY = { down="Down", up="Up", left="Left", right="Right" }

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function settle(frames)
    for _ = 1, frames do safe_set({}); emu.frameadvance() end
end

local function press_held(pad, hold)
    for _ = 1, (hold or 1) do safe_set(pad); emu.frameadvance() end
end

local DOMAIN_CANDIDATES = {
    "VRAM", "VRAM (VDP)", "VDP", "MD VRAM",
    "68K RAM", "Main RAM", "System Bus",
}

local function try_read_u8(domain, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local SAT_BASE = 0xF400

local function dump_sat_slot(slot)
    local base = SAT_BASE + slot * 8
    for _, d in ipairs({"VRAM", "VRAM (VDP)", "VDP", "MD VRAM"}) do
        local b0 = try_read_u8(d, base)
        if b0 ~= nil then
            local bytes = { b0 }
            for i = 1, 7 do bytes[i+1] = try_read_u8(d, base + i) or 0 end
            return d, bytes
        end
    end
    return nil, {0,0,0,0,0,0,0,0}
end

local function fmt_slot(slot)
    local d, b = dump_sat_slot(slot)
    return string.format(
        "slot %d (dom=%s): Y=%02X%02X size=%02X link=%02X TA=%02X%02X X=%02X%02X",
        slot, d or "?", b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
end

local lines = {}
do
    local ok, list = pcall(function() return memory.getmemorydomainlist() end)
    if ok and list then
        table.insert(lines, "memory domains:")
        local n = list.Count or #list
        for i = 0, n - 1 do
            local d = list[i]
            table.insert(lines, "  " .. tostring(d))
        end
    end
end
table.insert(lines, "system_id=" .. (emu.getsystemid() or "?"))

settle(180)

for _, facing in ipairs(FACINGS) do
    local dir_pad = { [DIR_KEY[facing]] = true, ["P1 " .. DIR_KEY[facing]] = true }
    press_held(dir_pad, 8)
    settle(2)

    local a_pad = { A = true, ["P1 A"] = true }
    press_held(a_pad, 1)
    safe_set({})

    table.insert(lines, string.format("=== facing %s ===", facing))

    for f = 1, 18 do
        if f == 3 or f == 8 or f == 13 or f == 16 then
            client.screenshot(string.format("%s\\roomrom_sword_%s_f%02d.png",
                OUT_DIR, facing, f))
            table.insert(lines, string.format("  f%02d %s", f, fmt_slot(0)))
            table.insert(lines, string.format("       %s", fmt_slot(1)))
        end
        emu.frameadvance()
    end

    settle(20)
end

do
    local f = assert(io.open(OUT_DIR .. "\\roomrom_sword_sat.txt", "w"))
    f:write(table.concat(lines, "\n") .. "\n")
    f:close()
end

client.exit()

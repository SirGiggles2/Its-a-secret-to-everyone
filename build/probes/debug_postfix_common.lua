local M = {}

M.OUT_ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\probes"

function M.mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"') end
end

function M.domain_exists(name)
    local ok, domains = pcall(memory.getmemorydomainlist)
    if not ok then return false end
    for _, domain in ipairs(domains) do
        if domain == name then return true end
    end
    return false
end

function M.domain_list_string()
    local ok, domains = pcall(memory.getmemorydomainlist)
    if not ok then return "unavailable" end
    return table.concat(domains, ",")
end

function M.detect_domains()
    if M.domain_exists("68K RAM") then
        M.RAM_DOMAIN = "68K RAM"
        M.RAM_BASE = 0
    elseif M.domain_exists("M68K RAM") then
        M.RAM_DOMAIN = "M68K RAM"
        M.RAM_BASE = 0
    elseif M.domain_exists("M68K BUS") then
        M.RAM_DOMAIN = "M68K BUS"
        M.RAM_BASE = 0x00FF0000
    else
        return false
    end

    M.VRAM_DOMAIN = "VRAM"
    if not M.domain_exists("VRAM") and M.domain_exists("VDP VRAM") then
        M.VRAM_DOMAIN = "VDP VRAM"
    end

    M.A4_BASE = M.RAM_BASE + 0x7000
    M.NES_BASE = M.RAM_BASE + 0x8000
    return true
end

function M.wait_domains(frames)
    for _ = 1, frames do
        if M.detect_domains() then return true end
        emu.frameadvance()
    end
    return false
end

function M.require_domains()
    if M.RAM_DOMAIN then return end
    if not M.wait_domains(600) then
        error("no Genesis RAM domain found; available=" .. M.domain_list_string())
    end
end

M.INVENTORY_BASE = 0x001C
M.SAT_BASE = 0xF400

function M.rd(addr)
    M.require_domains()
    return memory.read_u8(M.RAM_BASE + addr, M.RAM_DOMAIN)
end

function M.wr(addr, val)
    M.require_domains()
    memory.write_u8(M.RAM_BASE + addr, val, M.RAM_DOMAIN)
end

function M.rd_a4(off)
    M.require_domains()
    return memory.read_u8(M.A4_BASE + off, M.RAM_DOMAIN)
end

function M.rd_nes(off)
    M.require_domains()
    return memory.read_u8(M.NES_BASE + off, M.RAM_DOMAIN)
end

function M.frame()
    return M.rd_a4(2) * 256 + M.rd_a4(3)
end

function M.pad(buttons)
    local p = {}
    for _, b in ipairs(buttons or {}) do
        p[b] = true
        p["P1 " .. b] = true
    end
    return p
end

function M.advance(frames, buttons)
    local p = M.pad(buttons)
    for _ = 1, frames do
        joypad.set(p, 1)
        emu.frameadvance()
    end
end

function M.press(buttons, hold, release)
    M.advance(hold or 2, buttons)
    M.advance(release or 4, {})
end

function M.boot_debug()
    local saw_magic = false
    for _ = 1, 180 do
        emu.frameadvance()
        if M.rd_a4(0) == 0xA4 and M.rd_a4(1) == 0x4A then
            saw_magic = true
            break
        end
    end
    if not saw_magic then return false, "A4 magic never appeared" end

    for _ = 1, 180 do
        if M.rd_nes(0x07F0) == 1 then break end
        emu.frameadvance()
    end
    if M.rd_nes(0x07F0) ~= 1 then return false, "title display phase not reached" end

    M.advance(30, {"A", "B", "C"})
    M.advance(1, {})

    for _ = 1, 300 do
        emu.frameadvance()
        if M.rd_a4(13) == 1 then
            M.advance(240, {})
            return true, "entered"
        end
    end
    return false, "A+B+C did not enter debug runtime"
end

function M.arm_heavy_mirror()
    M.wr(0x73F8, 0x52)
    M.wr(0x73F9, 0x50)
    M.wr(0x73FA, 0x01)
end

function M.clear_probe_control()
    M.wr(0x73F8, 0)
    M.wr(0x73F9, 0)
    M.wr(0x73FA, 0)
end

function M.seed_inventory()
    local b = M.INVENTORY_BASE
    M.wr(b + 0, 0x07)  -- bow + wand + boomerang item bits
    M.wr(b + 1, 99)    -- bombs
    M.wr(b + 2, 1)     -- wood arrow
    M.wr(b + 3, 1)     -- bow owned
    M.wr(b + 4, 2)     -- red candle
    M.wr(b + 20, 0)    -- rupees high byte
    M.wr(b + 21, 99)   -- rupees low byte
    M.wr(b + 23, 0x33) -- max/current hearts
    M.wr(b + 26, 1)    -- wood boomerang
    M.wr(b + 29, 99)   -- max bombs
    M.wr(b + 30, 0)    -- rupees_to_add
    M.wr(b + 31, 0)    -- rupees_to_sub
end

function M.read_sat_slot(slot)
    M.require_domains()
    local base = M.SAT_BASE + slot * 8
    local function vram_u16(off)
        return memory.read_u8(base + off, M.VRAM_DOMAIN) * 256
             + memory.read_u8(base + off + 1, M.VRAM_DOMAIN)
    end
    return {
        y = vram_u16(0),
        size_link = vram_u16(2),
        attr = vram_u16(4),
        x = vram_u16(6),
    }
end

function M.slot_offscreen(slot)
    local s = M.read_sat_slot(slot)
    return s.x <= 100 and s.y <= 100
end

function M.slot_active(slot)
    return not M.slot_offscreen(slot)
end

function M.wait_slot_active(slot, frames)
    for _ = 1, frames do
        emu.frameadvance()
        if M.slot_active(slot) then return true end
    end
    return false
end

function M.wait_slot_offscreen(slot, frames)
    for _ = 1, frames do
        emu.frameadvance()
        if M.slot_offscreen(slot) then return true end
    end
    return false
end

function M.json_array(values)
    local out = {}
    for i, v in ipairs(values or {}) do out[i] = tostring(v) end
    return "[" .. table.concat(out, ",") .. "]"
end

function M.write_json(path, report)
    M.mkdir_for(path)
    local f = assert(io.open(path, "w"))
    f:write("{\n")
    local first = true
    for _, row in ipairs(report) do
        if not first then f:write(",\n") end
        first = false
        f:write('  "' .. row[1] .. '": ')
        if row.kind == "raw" then
            f:write(tostring(row[2]))
        elseif type(row[2]) == "number" then
            f:write(tostring(row[2]))
        elseif type(row[2]) == "boolean" then
            f:write(row[2] and "true" or "false")
        else
            f:write('"' .. tostring(row[2]):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"')
        end
    end
    f:write("\n}\n")
    f:close()
end

return M

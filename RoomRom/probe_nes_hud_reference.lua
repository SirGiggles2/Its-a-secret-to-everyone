-- probe_nes_hud_reference.lua
-- Boot NES Zelda to overworld at room $77, dump HUD region:
--   * CIRAM nametable rows 0..7 (NT $2000..$20FF) - tile indices
--   * Attribute table $23C0..$23DF (covers NT rows 0..7)
--   * PALRAM 32 bytes
--   * Screenshot

local OUT_JSON = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_hud_reference.json"
local OUT_PNG  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_hud_reference.png"

local ROOM_ID        = 0x00EB
local CUR_LEVEL      = 0x0010
local GAME_MODE      = 0x0012
local GAME_SUB       = 0x0013
local CUR_SAVE_SLOT  = 0x0016
local NAME_PROGRESS  = 0x0421
local SAVE_ACTIVE0   = 0x0633
local SAVE_ACTIVE1   = 0x0634
local SAVE_ACTIVE2   = 0x0635
local ROOM_TRANS     = 0x004C

local CIRAM_BASE = 0x0000
local ATTR_BASE  = 0x03C0

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

local function read_domain_u8(domain, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local function ciram_u8(addr)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local v = read_domain_u8(d, addr)
        if v ~= nil then return v end
    end
    return 0
end

local PAL_DOMAIN = nil
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and domains then
        for _, d in ipairs(domains) do
            local name = (type(d) == "table") and (d.Name or tostring(d)) or tostring(d)
            local lower = name:lower()
            if lower:find("pal") or lower:find("palette") then
                local size_ok, size = pcall(memory.getmemorydomainsize, name)
                if size_ok and size and size <= 64 then
                    PAL_DOMAIN = name
                    break
                end
            end
        end
    end
end

local function palram_u8(addr)
    if PAL_DOMAIN then
        local v = read_domain_u8(PAL_DOMAIN, addr)
        if v ~= nil then return v end
    end
    return 0
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }

local function schedule(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return end
    input_state.button = button
    input_state.hold_left = hold_frames or 1
    input_state.release_left = 0
    input_state.release_after = release_frames or 8
end

local function build_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then
            input_state.release_left = input_state.release_after
        end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

local function boot_to_overworld()
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME, FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
    local flow = BOOT_TO_FS1
    local last_name = u8(NAME_PROGRESS)
    local name_events = 0
    for frame = 1, 20000 do
        local mode = u8(GAME_MODE)
        local slot = u8(CUR_SAVE_SLOT)
        local name = u8(NAME_PROGRESS)
        local active0 = u8(SAVE_ACTIVE0)
        local active1 = u8(SAVE_ACTIVE1)
        local active2 = u8(SAVE_ACTIVE2)
        if flow == BOOT_TO_FS1 then
            if mode == 0x01 then flow = SELECT_REGISTER else schedule("Start", 2, 3) end
        elseif flow == SELECT_REGISTER then
            if slot == 0x03 then flow = ENTER_REGISTER else schedule("Down", 1, 10) end
        elseif flow == ENTER_REGISTER then
            if mode == 0x0E then flow = TYPE_NAME; last_name = name
            elseif mode == 0x01 then schedule("Start", 2, 14) end
        elseif flow == TYPE_NAME then
            if name ~= last_name then name_events = name_events + 1; last_name = name end
            if name_events >= 5 then flow = FINISH_NAME else schedule("A", 1, 10) end
        elseif flow == FINISH_NAME then
            if mode ~= 0x0E then flow = WAIT_GAMEPLAY
            elseif slot ~= 0x03 then schedule("Select", 1, 10)
            else schedule("Start", 2, 14) end
        elseif flow == WAIT_GAMEPLAY then
            if mode == 0x01 then flow = START_GAME end
        elseif flow == START_GAME then
            if mode ~= 0x01 then flow = WAIT_GAMEPLAY
            else
                local target_slot = 0x00
                if active0 == 0 and active1 ~= 0 then target_slot = 0x01
                elseif active0 == 0 and active1 == 0 and active2 ~= 0 then target_slot = 0x02 end
                if slot ~= target_slot then schedule(target_slot > slot and "Down" or "Up", 1, 10)
                else schedule("Start", 2, 14) end
            end
        end
        safe_set(build_pad())
        emu.frameadvance()
        if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0
           and u8(ROOM_ID) == 0x77 and u8(ROOM_TRANS) == 0 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function dump_hud_nt()
    local rows = {}
    for row = 0, 7 do
        local vals = {}
        local base = CIRAM_BASE + row * 32
        for col = 0, 31 do
            vals[#vals + 1] = ciram_u8(base + col)
        end
        rows[#rows + 1] = vals
    end
    return rows
end

local function dump_hud_attr()
    local vals = {}
    -- AT covers 32 cols x 32 rows in 8x8 quads. HUD = NT rows 0..7 = AT rows 0..1 = 16 bytes (2 rows of 8)
    for i = 0, 15 do
        vals[#vals + 1] = ciram_u8(ATTR_BASE + i)
    end
    return vals
end

local function dump_palram()
    local vals = {}
    for i = 0, 31 do vals[#vals + 1] = palram_u8(i) end
    return vals
end

local function j1(t)
    local s = {}
    for i = 1, #t do s[#s + 1] = tostring(t[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end

local function j2(rows)
    local s = {}
    for i = 1, #rows do s[#s + 1] = j1(rows[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end

local system_id = emu.getsystemid() or "?"
local ok_boot = false
local err = nil
local hud_nt, hud_attr, palram = nil, nil, nil

if system_id ~= "NES" then
    err = "wrong_system_" .. system_id
else
    ok_boot = boot_to_overworld()
    if not ok_boot then
        err = "failed_to_boot_to_overworld"
    else
        hud_nt = dump_hud_nt()
        hud_attr = dump_hud_attr()
        palram = dump_palram()
        client.screenshot(OUT_PNG)
    end
end

local f = assert(io.open(OUT_JSON, "w"))
f:write("{\n")
f:write('  "system_id": "', system_id, '",\n')
f:write('  "boot_ok": ', tostring(ok_boot), ',\n')
if err then f:write('  "error": "', err, '",\n') end
f:write('  "room_id": ', tostring(ok_boot and 0x77 or -1), ',\n')
if hud_nt   then f:write('  "hud_nt_rows": ', j2(hud_nt), ',\n') end
if hud_attr then f:write('  "hud_attr": ',    j1(hud_attr), ',\n') end
if palram   then f:write('  "palram": ',      j1(palram), '\n') end
f:write("}\n")
f:close()

client.exit()

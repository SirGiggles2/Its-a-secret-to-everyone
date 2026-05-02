-- probe_nes_item_chr_manifest.lua
-- Captures live NES item CHR/OAM evidence for RoomRom item atlas generation.
--
-- Output defaults:
--   RoomRom/out/nes_item_chr_manifest_probe.json
--   RoomRom/out/nes_item_chr_pt0.bin
--
-- Use with BizHawk --lua after launching Zelda 1 or Redux.  The probe uses
-- the CHR memory domain for pattern bytes; PPU Bus is not used as a CHR
-- substitute.

local OUT_JSON = os.getenv("CODEX_ITEM_CHR_OUT")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\\out\\nes_item_chr_manifest_probe.json"
local OUT_CHR = os.getenv("CODEX_ITEM_CHR_BIN")
    or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\\out\\nes_item_chr_pt0.bin"
local ROM_ID = os.getenv("CODEX_ITEM_CHR_ROM_ID") or "orig"

local CUR_LEVEL          = 0x0010
local GAME_MODE          = 0x0012
local GAME_SUB           = 0x0013
local CUR_SAVE_SLOT      = 0x0016
local ROOM_ID            = 0x00EB
local ROOM_TRANS         = 0x004C
local NAME_PROGRESS      = 0x0421
local SAVE_ACTIVE0       = 0x0633
local SAVE_ACTIVE1       = 0x0634
local SAVE_ACTIVE2       = 0x0635
local LINK_X             = 0x0070
local LINK_Y             = 0x0084
local SELECTED_ITEM_SLOT = 0x0656
local ITEMS              = 0x0657
local INV_BOMBS          = 0x0658
local INV_ARROW          = 0x0659
local BOW                = 0x065A
local INV_CANDLE         = 0x065B
local INV_BOOK           = 0x0661
local INV_BOOMERANG      = 0x0674
local INV_MAGIC_BOOMERANG= 0x0675

local function use_sys() memory.usememorydomain("System Bus") end
local function u8(addr) use_sys(); return memory.read_u8(addr & 0xFFFF) end
local function w8(addr, val) use_sys(); memory.write_u8(addr & 0xFFFF, val & 0xFF) end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function settle(frames)
    for _ = 1, frames do safe_set({}); emu.frameadvance() end
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
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME,
          FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
    local flow = BOOT_TO_FS1
    local last_name = u8(NAME_PROGRESS)
    local name_events = 0
    for _ = 1, 20000 do
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
            settle(30)
            return true
        end
    end
    return false
end

local function memory_domains()
    local out = {}
    local ok, list = pcall(function() return memory.getmemorydomainlist() end)
    if ok and list then
        local n = list.Count or #list
        for i = 0, n - 1 do table.insert(out, tostring(list[i])) end
    end
    return out
end

local function select_chr_domain()
    local domains = memory_domains()
    for _, want in ipairs({"CHR", "CHR RAM", "CHR VRAM", "CHR ROM", "CHR VROM", "VRAM"}) do
        for _, d in ipairs(domains) do
            if d == want then return d end
        end
    end
    return nil
end

local function read_chr_bytes(domain, start_addr, count)
    memory.usememorydomain(domain)
    local bytes = {}
    for i = 0, count - 1 do bytes[i + 1] = memory.read_u8(start_addr + i) end
    return bytes
end

local function snapshot_oam()
    local out = {}
    use_sys()
    for slot = 0, 63 do
        local base = 0x0200 + slot * 4
        local y    = memory.read_u8(base + 0)
        local tile = memory.read_u8(base + 1)
        local attr = memory.read_u8(base + 2)
        local x    = memory.read_u8(base + 3)
        if y < 0xF0 then
            table.insert(out, {slot=slot, y=y, tile=tile, attr=attr, x=x})
        end
    end
    return out
end

local function press(button, frames)
    local pad = { [button] = true, ["P1 " .. button] = true }
    for _ = 1, frames do safe_set(pad); emu.frameadvance() end
    safe_set({})
end

local function hold_dir(dir, frames)
    local pad = { [dir] = true, ["P1 " .. dir] = true }
    for _ = 1, frames do safe_set(pad); emu.frameadvance() end
end

local function capture_action(label, setup_fn, trigger_button)
    if setup_fn then setup_fn() end
    settle(4)
    press(trigger_button, 2)
    local frames = {}
    for f = 1, 36 do
        frames[f] = {frame=f, link_x=u8(LINK_X), link_y=u8(LINK_Y), oam=snapshot_oam()}
        emu.frameadvance()
    end
    settle(20)
    return {label=label, frames=frames}
end

local function jval(v)
    if v == nil then return "null" end
    local t = type(v)
    if t == "number" then return tostring(v) end
    if t == "string" then return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
    if t == "boolean" then return v and "true" or "false" end
    if t == "table" then
        local n = 0
        for k, _ in pairs(v) do
            if type(k) == "number" then n = n + 1 else n = -1; break end
        end
        local parts = {}
        if n >= 0 then
            for i = 1, n do parts[i] = jval(v[i]) end
        else
            for k, vv in pairs(v) do table.insert(parts, '"' .. tostring(k) .. '":' .. jval(vv)) end
        end
        return (n >= 0 and "[" or "{") .. table.concat(parts, ",") .. (n >= 0 and "]" or "}")
    end
    return "null"
end

local sysid = emu.getsystemid() or "?"
if sysid ~= "NES" then
    local f = io.open(OUT_JSON .. ".error", "w")
    if f then f:write("wrong_system_" .. sysid); f:close() end
    client.exit()
end

if not boot_to_overworld() then
    local f = io.open(OUT_JSON .. ".error", "w")
    if f then f:write("boot_failed"); f:close() end
    client.exit()
end

w8(ITEMS, 1)
w8(INV_BOMBS, 8)
w8(INV_ARROW, 1)
w8(BOW, 1)
w8(INV_CANDLE, 1)
w8(INV_BOOK, 1)
w8(INV_BOOMERANG, 1)
w8(INV_MAGIC_BOOMERANG, 0)
settle(30)

local chr_domain = select_chr_domain()
if chr_domain == nil then
    local f = io.open(OUT_JSON .. ".error", "w")
    if f then f:write("no_chr_domain:" .. table.concat(memory_domains(), ",")); f:close() end
    client.exit()
end

local actions = {}
table.insert(actions, capture_action("sword_down", function() hold_dir("Down", 8) end, "A"))
table.insert(actions, capture_action("sword_up", function() hold_dir("Up", 8) end, "A"))
table.insert(actions, capture_action("sword_left", function() hold_dir("Left", 8) end, "A"))
table.insert(actions, capture_action("sword_right", function() hold_dir("Right", 8) end, "A"))
table.insert(actions, capture_action("boomerang", function() w8(SELECTED_ITEM_SLOT, 0) end, "B"))
table.insert(actions, capture_action("bomb", function() w8(SELECTED_ITEM_SLOT, 1) end, "B"))
table.insert(actions, capture_action("arrow", function() w8(SELECTED_ITEM_SLOT, 2) end, "B"))
table.insert(actions, capture_action("candle", function() w8(SELECTED_ITEM_SLOT, 4) end, "B"))
table.insert(actions, capture_action("rod", function() w8(SELECTED_ITEM_SLOT, 8) end, "B"))

local chr = read_chr_bytes(chr_domain, 0x0000, 0x1000)
do
    local f = assert(io.open(OUT_CHR, "wb"))
    for i = 1, #chr do f:write(string.char(chr[i] % 256)) end
    f:close()
end

local result = {
    schema_version = 1,
    rom_id = ROM_ID,
    system_id = sysid,
    chr_domain = chr_domain,
    memory_domains = memory_domains(),
    chr_bin = OUT_CHR,
    actions = actions,
}

do
    local f = assert(io.open(OUT_JSON, "w"))
    f:write(jval(result))
    f:close()
end

client.exit()

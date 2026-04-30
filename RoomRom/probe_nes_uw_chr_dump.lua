-- probe_nes_uw_chr_dump.lua
-- Boot, warp to L1Q1, settle, dump PPU $0000-$0FFF (256 BG tiles, 4096
-- bytes) to a binary file. Captures whichever CHR bank the engine has
-- live, so works on vanilla and Redux equally.
--
-- Env contract:
--   CODEX_UW_CHR_OUT_BIN -- path to write 4096-byte PPU pattern table dump

local CUR_LEVEL    = 0x0010
local GAME_MODE    = 0x0012
local GAME_SUB     = 0x0013
local CUR_SAVE_SLOT = 0x0016
local IS_UPDATING_MODE = 0x0011
local TARGET_MODE  = 0x005B
local TARGET_MIRROR = 0x0602
local CUR_PPU_MASK = 0x00FE
local ROOM_ID      = 0x00EB
local NAME_PROGRESS = 0x0421
local SAVE_ACTIVE0 = 0x0633
local SAVE_ACTIVE1 = 0x0634
local SAVE_ACTIVE2 = 0x0635
local ROOM_TRANS   = 0x004C

local OUT_BIN = os.getenv("CODEX_UW_CHR_OUT_BIN") or "RoomRom/out/nes_uw_chr.bin"

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr & 0xFFFF, val & 0xFF)
end

local function read_domain_u8(domain, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local CHR_DOMAINS = {"PPU Bus", "PPU", "PPU RAM", "CHR VRAM", "CHR ROM", "VRAM"}
local function chr_u8(addr)
    for _, d in ipairs(CHR_DOMAINS) do
        local v = read_domain_u8(d, addr)
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

local function warp_to_uw1()
    w8(CUR_LEVEL, 1)
    w8(TARGET_MODE, 0x02)
    w8(TARGET_MIRROR, 0x02)
    w8(GAME_MODE, 0x10)
    w8(GAME_SUB, 0x00)
    safe_set({})
    for f = 1, 1500 do
        emu.frameadvance()
        if u8(CUR_LEVEL) == 1 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0
           and u8(IS_UPDATING_MODE) == 1 and (u8(CUR_PPU_MASK) % 0x20) >= 0x18 then
            for _ = 1, 60 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function dump_chr()
    -- Z1 underworld uses PPUCTRL bit 4 set: BG patterns at PPU $1000-$1FFF
    -- (sprites live at $0000-$0FFF). Dump the BG bank.
    local f = assert(io.open(OUT_BIN, "wb"))
    for addr = 0x1000, 0x1FFF do
        f:write(string.char(chr_u8(addr) % 256))
    end
    f:close()
end

local system_id = emu.getsystemid() or "?"
if system_id ~= "NES" then
    local f = io.open(OUT_BIN .. ".error", "w")
    if f then f:write("wrong_system_" .. system_id); f:close() end
    client.exit()
end

if not boot_to_overworld() then
    local f = io.open(OUT_BIN .. ".error", "w")
    if f then f:write("boot_failed"); f:close() end
    client.exit()
end

if not warp_to_uw1() then
    local f = io.open(OUT_BIN .. ".error", "w")
    if f then f:write("warp_failed"); f:close() end
    client.exit()
end

dump_chr()
client.exit()
